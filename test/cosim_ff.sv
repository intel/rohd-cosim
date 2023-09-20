// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_ff.sv
// A simple SystemVerilog module for testing flip-flop cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module my_cosim_ff(
	input logic clk,
	input logic d,
	output logic q
);

always_ff @(posedge clk) q <= d;

endmodule