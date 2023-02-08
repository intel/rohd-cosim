/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// cosim_finish.sv
/// A simple SystemVerilog module for testing $finish cosimulation.
///
/// 2022
/// Author: Max Korbel <max.korbel@intel.com>
///

module finish_module(input logic clk);
    initial begin
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $display("Finishing simulation...");
        $finish;
    end
endmodule : finish_module