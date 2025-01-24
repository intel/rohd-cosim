"""
Copyright (C) 2023-2025 Intel Corporation
SPDX-License-Identifier: BSD-3-Clause

rohd_port_connector.py
Custom python cocotb utility to connect ROHD cosim via port

2023 January 7
Author: Max Korbel <max.korbel@intel.com>
"""

import subprocess
from time import sleep
import logging
import traceback
import rohd_connector
import cocotb

# pylint: disable=broad-exception-caught, multiple-statements
# pylint: disable=too-many-arguments, too-many-locals, too-many-branches, too-many-statements, too-many-positional-arguments
# pylint: disable=consider-using-with


class RohdLoggerHandler(logging.Handler):
    """
    A custom handler to detect when cocotb detects the simulator finished.
    """

    def __init__(self, connector: rohd_connector.RohdConnector):
        logging.Handler.__init__(self)
        self.connector = connector

    def handle(self, record):
        if record.levelno > 30:
            # if there's anything above WARNING, then KILL THIS!
            print("ROHD Port Connector detected a failure from cocotb, exiting!")
            self.connector.shutdown()

    def emit(self, record):
        pass


@cocotb.coroutine
async def launch_on_port(
    cosim_test_module,
    dut,
    dart_command,
    log_name: str = "port_launch",
    enable_logging: bool = False,
    listen_timeout=5,
    tick_timeout=5,
    clk_ratio=1000,
    clk_units="ps",
    dart_connect_timeout=None,
):
    """
    `dart_command` should be a reference to a function which accepts a port as an argument.
    If `dart_command` is None, then no dart thread will be launched.  This is useful
    if you want to launch your own dart process with the debugger attached.

    Use `dart_connect_timeout` to as the number of seconds to wait before assuming the dart
    process is never going to connect.  It will default to `None` if no `dart_command` is provided.
    """

    do_dart_launch = dart_command is not None

    if not dart_connect_timeout and do_dart_launch:
        dart_connect_timeout = 120

    print("Starting launch_on_port")
    connector = rohd_connector.RohdConnector(
        enable_logging=enable_logging,
        listen_timeout=listen_timeout,
        tick_timeout=tick_timeout,
        clk_ratio=clk_ratio,
        clk_units=clk_units,
        dart_connect_timeout=dart_connect_timeout,
    )

    def run_dart_thread() -> subprocess.Popen:
        print("Launching dart...")
        with open(f"{log_name}.stdout.log", "w", encoding="utf-8") as out, open(
            f"{log_name}.stderr.log", "w", encoding="utf-8"
        ) as err:
            print("Dart process running, waiting for it to finish...")
            dart_process: subprocess.Popen = subprocess.Popen(
                dart_command(connector.socket_port), stdout=out, stderr=err
            )

            return dart_process

    dart_process: subprocess.Popen = None
    if do_dart_launch:
        dart_process = run_dart_thread()

    print("Connecting to socket...")

    # this will timeout after a while and fail
    connector.connect_to_socket()

    print("Socket is connected!")

    # For some reason, when cocotb detects that something failed the simulation
    # just hangs, so let's attach this handler to kill after any error!
    logging.getLogger("cocotb.regression").addHandler(
        RohdLoggerHandler(connector=connector)
    )

    try:
        print("Starting to send and receive signal changes...")

        if do_dart_launch:
            # stop if the dart thread ends OR the listener ends
            print("starting connection task")
            connection_task = cocotb.start_soon(
                cosim_test_module.setup_connections(dut, connector)
            )
            await connection_task.join()

            if enable_logging:
                print("Port connector loop has completed!")
                print(f"Dart thread alive? -- {dart_process.poll() is None}")
                print(f"Connection task done? -- {connection_task.done()}")

            try:
                dart_process.wait(timeout=2)
                if enable_logging:
                    print("Dart process completed gracefully.")

            except subprocess.TimeoutExpired:
                print(
                    "Dart process is still running, attempting a graceful shutdown..."
                )
                connector.shutdown()
                sleep(2)

                if dart_process.poll() is None:
                    print("Dart process did not gracefully shutdown, sending terminate")
                    dart_process.terminate()

                sleep(1)

                if dart_process.poll() is None:
                    print("Dart process did not terminate, sending kill")
                    dart_process.kill()

                sleep(1)

                if dart_process.poll() is None:
                    print("Dart process could not be killed.")

            dart_exit_code = dart_process.poll()
            print(f"Dart process exit code: {dart_exit_code}")

            if dart_exit_code != 0:
                print("ERROR: Dart process ended with non-zero exit code!")

        else:
            await cosim_test_module.setup_connections(dut, connector)

    except Exception as exception:
        traceback.print_exc()
        fail_msg = f"ERROR: Exception encountered during cosim: {exception}"
        print(fail_msg, flush=True)
        connector.shutdown()
        print("ERROR: Test failed due to exception.")

    if enable_logging:
        print("launch_on_port completed!")
