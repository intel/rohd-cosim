// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_bus.sv
// A simple SystemVerilog module for testing cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module my_cosim_bus(
	input logic[3:0] a,
	output logic[3:0] b
);

assign b = a;

endmodule