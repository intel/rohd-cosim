// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// timing_test.sv
// A simple SystemVerilog module for testing initial value cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module timing_test_module (
    input logic clk,
    input logic reset,
    output logic[7:0] init_out
);

initial begin
    init_out = 8'ha5;
end

endmodule : timing_test_module