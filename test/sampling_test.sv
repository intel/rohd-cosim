/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// sampling_test.sv
/// A simple SystemVerilog module for testing sampling in cosimulation.
///
/// 2022
/// Author: Max Korbel <max.korbel@intel.com>
///

module sampling_module (
    input logic clk,
    input logic push_valid,
    input logic[7:0] push_data,
    output logic[7:0] sampled
);

always_ff @(posedge clk) begin
    if(push_valid) begin
        sampled <= push_data;
    end else begin
        sampled <= sampled;
    end
end

endmodule : sampling_module