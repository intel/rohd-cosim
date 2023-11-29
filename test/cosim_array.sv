// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_array.sv
// A simple SystemVerilog module for testing cosimulation with arrays.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

// 2 packed, 2 unpacked
module my_cosim_array_2p2u(
	input  logic[2:0][1:0] a [4:0][3:0],
	output logic[2:0][1:0] b [4:0][3:0]
);

assign b = a;

endmodule

// 2 packed, 1 unpacked
module my_cosim_array_2p1u(
	input  logic[2:0][1:0] a [3:0],
	output logic[2:0][1:0] b [3:0]
);

assign b = a;

endmodule

// 2 packed, 0 unpacked
module my_cosim_array_2p0u(
	input  logic[2:0][1:0] a,
	output logic[2:0][1:0] b
);

assign b = a;

endmodule