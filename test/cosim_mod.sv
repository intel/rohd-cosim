// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_mod.sv
// A simple SystemVerilog module for testing combinational cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module my_cosim_test_module(
    input logic a,
    input logic b,
    output logic a_bar,
    output logic b_same,
    output logic c_none
);

assign a_bar = ~a;
assign b_same = b;
assign c_none = 0;

endmodule