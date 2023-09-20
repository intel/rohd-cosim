# Copyright (C) 2022-2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause
#
# build.sh
# A simple build script for port testing.
#
# 2022
# Author: Max Korbel <max.korbel@intel.com>

mkdir -p $OUT_DIR
cd $OUT_DIR

iverilog -g2012 -s top_mod -o hier.out -f ../cmds.f $EXTRA_ARGS ../hier_mods.sv 