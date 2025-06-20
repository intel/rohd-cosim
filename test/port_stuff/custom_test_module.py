"""
Copyright (C) 2022-2025 Intel Corporation
SPDX-License-Identifier: BSD-3-Clause

custom_test.py
Custom python cocotb test to connect ROHD cosim via port

2022 October 28
Author: Max Korbel <max.korbel@intel.com>
"""

import sys
import os
import cocotb

PATH_TO_ROOT = '../../../'

# disable some pylint things since this runs in an unusual environment
#pylint: disable=import-error,wrong-import-position,no-value-for-parameter

sys.path.append(f'{PATH_TO_ROOT}/python/')
import rohd_port_connector

sys.path.append(f'{PATH_TO_ROOT}/test/port_stuff/tmp_output/')
import cosim_test_module

dart_fail = os.getenv('DART_FAIL')
dart_fail_async = os.getenv('DART_FAIL_ASYNC')
dart_hang = os.getenv('DART_HANG')
separate_dart_launch = os.getenv('SEPARATE_DART_LAUNCH')
python_fail = os.getenv('PYTHON_FAIL')

@cocotb.test()
async def custom_test(dut):
    """
    A custom cocotb test that runs launch_on_port for port testing.
    """
    print('Starting custom_test')

    def dart_command(port):
        cmd = [
            "dart", 
            f"{PATH_TO_ROOT}/test/port_stuff/port_launch.dart", 
            "--port", str(port)
        ]
        if dart_fail is not None:
            cmd += ["--fail"]
        if dart_fail_async is not None:
            cmd += ["--failAsync"]
        if dart_hang is not None:
            cmd += ["--hang"]
        return cmd

    await rohd_port_connector.launch_on_port(
        cosim_test_module=cosim_test_module,
        dut=dut,
        dart_command = dart_command if not separate_dart_launch else None,
        log_name='custom_test',
        enable_logging=False,
        dart_connect_timeout = 5 if not separate_dart_launch else None,
    )

    if python_fail:
        raise Exception("Python test failure injected")
