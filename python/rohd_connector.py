"""
Copyright (C) 2022-2023 Intel Corporation
SPDX-License-Identifier: BSD-3-Clause

rohd_connector.py
Code to connect a python cocotb process to ROHD

2022 January 9
Author: Max Korbel <max.korbel@intel.com>
"""

import logging
import socket
from time import sleep
import select
import time
import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

# pylint: disable=broad-exception-caught, multiple-statements
# pylint: disable=too-many-arguments, too-many-locals, too-many-branches, too-many-statements, too-many-instance-attributes


class RohdConnector:
    """
    A connector for communicating between the ROHD simulator and another simulator.
    """

    def __init__(
        self,
        enable_logging=False,
        listen_timeout=5,
        tick_timeout=5,
        clk_ratio=1000,
        clk_units="ps",
        dart_connect_timeout=120,
    ):
        self.enable_logging = enable_logging

        # this remains None until the socket is connected
        self.sock = None
        self._create_socket()

        # track if listener should remain active
        self.continue_listen = True

        self.output_map = {}
        self.time = 0  # clk_units
        self.listen_timeout = listen_timeout
        self.tick_timeout = tick_timeout
        self.dart_connect_timeout = dart_connect_timeout

        self.clk_units = clk_units

        # this is the ratio of tick to time
        # 1000 means time progresses (1000 x clk_units) per tick
        self.clk_ratio = clk_ratio

        # if true, indicates that we're in the middle of a tick!
        self.mid_tick = False

        if self.enable_logging:
            cocotb.log.setLevel(logging.DEBUG)

        self.shutdown_requested = False

        # last time a message was received from the dart side, for timeout calculations
        self.last_message_received_time = None

    def _create_socket(self):
        self.init_sock = socket.socket()
        self.init_sock.bind(("", 0))
        self.init_sock.listen()
        self.socket_port = self.init_sock.getsockname()[1]

    def connect_to_socket(self):
        """
        Creates a socket on `self.socket_port` and attempts to connect to it.
        """
        print(
            f"ROHD COSIM SOCKET:{self.socket_port}", flush=True
        )  # critical for connection
        if self.dart_connect_timeout:
            self.init_sock.settimeout(self.dart_connect_timeout)
        try:
            conn, _addr = self.init_sock.accept()
            conn.setblocking(False)
            self.sock = conn
        except socket.timeout:
            self._error(
                f"Socket connection timed out after {self.dart_connect_timeout} seconds!"
            )

    def _sock_send(self, message: str):
        try:
            self.sock.send((f"@{self.time}:" + message + "\n").encode())
        except Exception as exception:
            self._error(
                f'Encountered error when sending message "{message}": {exception}'
            )

    def _error(self, message: str):
        print(f"ERROR: {message}", flush=True)
        # raise RuntimeError(message)
        self.shutdown()

    def shutdown(self):
        """
        Attempts to gracefully shut down the ROHD simulator, the socket connection, and all
        listeners within this connector.
        """

        print("Shutting down cosimulation socket.")

        try:
            if not self.shutdown_requested:
                # prevent infinite recursion from sock_send->shutdown
                self.shutdown_requested = True
                self._sock_send("END")

                # give some time for the END to get there
                sleep(1)

            self.continue_listen = False
            self.sock.shutdown(socket.SHUT_RDWR)
            self.sock.close()
        except Exception as exception:
            print(
                f"Encountered exception during disconnection, but ignoring: {exception}",
                flush=True,
            )

    @cocotb.coroutine
    async def listen_for_stimulus(self, name_to_signal_map):
        """
        Starts the process of listening for stimulus from the ROHD simulator.
        """

        if self.enable_logging:
            print("Listening for stimulus...")
        self.continue_listen = True
        pending_message = ""
        self.sock.setblocking(False)
        # self.sock.settimeout(1)

        while self.continue_listen:
            # https://docs.python.org/3/howto/sockets.html#non-blocking-sockets
            try:
                timeout_s = self.listen_timeout  # seconds
                ready_to_read, _ready_to_write, _in_error = select.select(
                    [self.sock], [], [], timeout_s
                )
            except select.error:
                if self.enable_logging:
                    print(
                        "Detected socket shutdown, ending cosim execution!", flush=True
                    )
                self.sock.shutdown(socket.SHUT_RDWR)
                self.sock.close()
                self.continue_listen = False
                break

            if not ready_to_read and self.mid_tick:
                # not necessarily an error, since maybe SV simulator called $finish
                print("Timeout waiting for tick to complete in Simulator!", flush=True)
                self.shutdown()
                break

            if (
                self.last_message_received_time is not None
                and (time.time() - self.last_message_received_time)
                > self.dart_connect_timeout
            ):
                self._error(
                    "Timeout waiting for Dart messages!  Perhaps the Dart side has hung "
                    "or died without shutting down the connection gracefully."
                )
                break

            if len(ready_to_read) > 0:
                self.last_message_received_time = time.time()

                try:
                    full_message = pending_message + self.sock.recv(1024).decode(
                        "ascii"
                    )
                except Exception as exception:
                    print(
                        f"Encountered exception when reading from socket: {exception}"
                    )
                    print("It is possible the ROHD process has unexpectedly ended.")
                    self._error("Communication with ROHD process failed.")
                    # break

                pending_message = ""
                split_message = full_message.split(";")

                # if we didn't get a full message, save the tail for next time
                if not full_message.endswith(";"):
                    pending_message = split_message[-1]
                    split_message = split_message[0:-1]

                for message in split_message:
                    message = message.strip()
                    if not message:
                        continue

                    if self.enable_logging:
                        print(f"Received message: {message}")
                    if message.startswith("TICK:"):
                        # Format:   TICK:<newTimeInNs>
                        split_message = message.split(":")
                        new_time = int(split_message[1])
                        await self._tick(new_time)

                    elif message.startswith("DRIVE:"):
                        # Format:   DRIVE:<signalName>:<newValueInBinary>
                        # Example:  DRIVE:apple:01XZ1100
                        split_message = message.split(":")
                        signal_name = split_message[1]
                        binary_string = split_message[2]
                        logic_value = LogicArray(binary_string)
                        if signal_name not in name_to_signal_map:
                            self._error(
                                f'Signal "{signal_name}" not set up for driving!  Unable to drive.'
                            )

                        try:
                            name_to_signal_map[signal_name].value = logic_value
                        except Exception as exception:
                            self._error(f"Failed to write {signal_name}: {exception}")

                    elif message == "END":
                        if self.enable_logging:
                            print("Finishing listening for stimulus")
                        self.shutdown()
                        break
                    else:
                        self._error(f"Unknown message received: {message}")

        if self.enable_logging:
            print("Listener loop ended.")

        # shutdown the dart side so it knows things have ended gracefully
        self.shutdown()

    @cocotb.coroutine
    async def listen_to_signal(self, signal_name, signal):
        """
        Sets up a listener for `signal` named `signal_name` so that changes can be
        communicated over to the ROHD simulator.
        """

        self.output_map[signal_name] = signal

        # at the start, send everything for initial values
        while True:
            if self.enable_logging:
                print(f"Sending update {signal_name}={str(signal.value)}")
            self._sock_send(f"UPDATE:{signal_name}={str(signal.value)}")
            await cocotb.triggers.Edge(signal)

    @cocotb.coroutine
    async def _tick(self, new_time: int):  # ns
        self.mid_tick = True

        if self.enable_logging:
            print(f">>> current time: {self.time}, new_time: {new_time}")
        if self.time >= self.clk_ratio * (new_time + 1):
            self._error("Too many ticks or time incorrect!")
        elif (self.time - self.time % self.clk_ratio) == new_time * self.clk_ratio:
            # another tick in the same timestamp!

            # https://docs.cocotb.org/en/stable/triggers.html
            await Timer(1, units="step")

            self.time += 1
        else:
            await Timer(new_time * self.clk_ratio - self.time, units=self.clk_units)
            self.time = new_time * self.clk_ratio  # clk_units

        # this code sends all outputs every tick
        # for signal_name, signal in self.output_map.items():
        #     if self.enable_logging: print(f'Sending update {signal_name}={str(signal.value)}')
        #     self.sock_send(f"UPDATE:{signal_name}={str(signal.value)}")

        self._sock_send("TICK_COMPLETE")

        self.mid_tick = False
