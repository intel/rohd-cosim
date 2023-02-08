# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# build.sh
# A simple build script for pair testing.
#
# 2022
# Author: Max Korbel <max.korbel@intel.com>
#

mkdir -p tmp_output
cd tmp_output

iverilog -g2012 -s pairing_top -o pair.out -f ../cmds.f ../pair_mods.sv 