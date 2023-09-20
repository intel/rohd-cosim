// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// hier_mods.sv
// SystemVerilog modules for hierarchical cosimulation.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

module top_mod();

    bottom_mod submod(.a(), .a_bar());

endmodule : top_mod

module bottom_mod(
    input logic a,
    output logic a_bar
);

assign a_bar = ~a;

endmodule : bottom_mod