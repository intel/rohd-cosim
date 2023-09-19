#!/bin/bash

# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# sim.sh
# A simple simulation run script for port testing.
#
# 2022
# Author: Max Korbel <max.korbel@intel.com>

export MODULE=custom_test_module
export TOPLEVEL_LANG=verilog
export TOPLEVEL=top_mod


cd $OUT_DIR
ln -s ../custom_test_module.py custom_test_module.py
vvp -M $(cocotb-config --lib-dir) -m $(cocotb-config --lib-name vpi icarus) hier.out +define+COCOTB_SIM=1 