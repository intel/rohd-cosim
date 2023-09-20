# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# build.sh
# A simple build script for hierarchical testing.
#
# 2022
# Author: Max Korbel <max.korbel@intel.com>

mkdir -p tmp_output
cd tmp_output

# export COCOTB_HDL_TIMEUNIT=1ns
# export COCOTB_HDL_TIMEPRECISION=1ps

iverilog -g2012 -s top_mod -o hier.out -f ../cmds.f ../hier_mods.sv 