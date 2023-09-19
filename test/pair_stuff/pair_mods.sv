// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pair_mods.sv
// SystemVerilog modules for pair cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module left_side (
    input logic clk,
    input logic rlValid,
    input logic[511:0] rlData,
    output logic lrValid,
    output logic[63:0] lrData
);

initial begin
    @(posedge rlValid);
    $display("rlValid posedge");
end

endmodule : left_side

module right_side (
    input logic clk,
    input logic lrValid,
    input logic[63:0] lrData,
    output logic rlValid,
    output logic[511:0] rlData
);

endmodule : right_side

module pairing_top;
    logic rlValid, lrValid;
    logic[63:0] lrData;
    logic[511:0] rlData;
    logic clk;

    left_side left(clk, rlValid, rlData, lrValid, lrData);
    right_side right(clk, lrValid, lrData, rlValid, rlData);
endmodule : pairing_top