// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_mod_inout.sv
// A simple SystemVerilog module for testing combinational cosimulation with inout ports.
//
// 2025 January
// Author: Max Korbel <max.korbel@intel.com>

// A special module for connecting two nets bidirectionally
module net_connect #(parameter WIDTH=1) (w, w); 
    inout wire[WIDTH-1:0] w;
endmodule

module my_cosim_test_module_nets(
    inout wire a,
    inout wire b
);

net_connect net_connect(a, b);

endmodule