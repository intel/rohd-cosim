[![License](https://img.shields.io/badge/License-BSD--3-blue)](https://github.com/intel/rohd/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](https://github.com/intel/rohd-cosim/blob/main/CODE_OF_CONDUCT.md)

ROHD Cosim
==========

ROHD Framework Co-simulation (ROHD Cosim) is a Dart package built upon the [Rapid Open Hardware Development (ROHD) framework](https://github.com/intel/rohd) for cosimulation between the ROHD Simulator and a SystemVerilog simulator.

Common use cases include:
- Instantiating a SystemVerilog module within a ROHD Module and running a simulation.
- Using ROHD and the [ROHD Verification Framework (ROHD-VF)](https://github.com/intel/rohd-vf) to build a testbench for a SystemVerilog module.
- Connecting and simulating a ROHD and ROHD-VF developed functional model to a empty shell located within a SystemVerilog hierarchy.
- Developing a mixed-simulation model where portions of design and/or testbench are in ROHD/ROHD-VF and other are in SystemVerilog or other languages which can run in or interact with a SystemVerilog simulator.

When you instantiate a SystemVerilog module within the ROHD simulator with ROHD Cosim, from the perspective of the rest of the ROHD environment it looks just like any other ROHD module.  You can run simulations, set breakpoints and debug, etc. even with the SystemVerilog simulator running in cosimulation.

## Prerequisites

ROHD Cosim relies on a python package called [cocotb](https://docs.cocotb.org/en/stable/) and its GPI library for communicating to SystemVerilog simulators.  The cocotb libraries have good support for a variety of simulators and have been used by many silicon and FPGA projects.

Detailed instructions for installing cocotb are available here: https://docs.cocotb.org/en/stable/install.html.  The instructions generally boil down to:
```
pip install cocotb
```

You will also need your favorite SystemVerilog simulator to do cosimulation between ROHD and SystemVerilog modules.  ROHD Cosim does *not* do any SystemVerilog parsing or SystemVerilog simulation itself.

## Using ROHD Cosim

There are two steps to using ROHD Cosim:
### 1. Wrap your SystemVerilog module

Wrap your SystemVerilog module with ROHD's [`ExternalSystemVerilogModule`](https://intel.github.io/rohd/rohd/ExternalSystemVerilogModule-class.html) and apply the `Cosim` mixin.

For example, here are corresponding SystemVerilog module definitions and a wrapper for it with Cosim.

```verilog
// example_cosim_module.v
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
```

```dart
// example_cosim_module.dart
class ExampleCosimModule extends ExternalSystemVerilogModule with Cosim {
  Logic get aBar => output('a_bar');
  Logic get bSame => output('b_same');

  @override
  List<String> get verilogSources => ['./example_cosim_module.v'];

  ExampleCosimModule(Logic a, Logic b, {String name = 'ecm'})
      : super(definitionName: 'my_cosim_test_module', name: name) {
    addInput('a', a);
    addInput('b', b);
    addOutput('a_bar');
    addOutput('b_same');
    addOutput('c_none');
  }
}
```

You can add inputs and output using any mechanism, including ROHD [`Interface`](https://intel.github.io/rohd/rohd/Interface-class.html)s.

### 2. Generate a connector and start the cosimulation.

Call the `Cosim.connectToSimulation` function with an appropriate configuration after `Module.build` to connect to the SystemVerilog simulator.


### Additional information
- Note that for cosimulation to execute, the ROHD `Simulator` must be running.
- Note that with the cosimulation process running in a unit test suite, you have an additional thing to reset each `tearDown`: `Cosim.reset()`.
- The ROHD Cosim test suite in `test/` is a good reference for some examples of how to set things up.

##  Cosimulation Configurations

There are three different types of configuration that can be used when connecting to the SystemVerilog simulation: "wrap", "custom", and "port".

### Wrap Configuration
The wrap configuration is the simplest way to get started with cosimulation if you don't already have an existing build and simulation system set up for the SystemVerilog module.

Pass a `CosimWrapConfig` object into the `Cosim.connectToSimulation` call with information about which simulator you want to use and let ROHD Cosim take care of the rest!  It will automatically create a wrapper with all SystemVerilog submodules for each that needs to be cosimulated.

The below diagram shows how the wrap configuration connects to your simulation.  ROHD will generate a Makefile and connector for your design, and then connect to it by listening to some port information coming through stdout from the simulation process.

![Wrap Config Diagram](https://github.com/intel/rohd-cosim/raw/main/doc/diagrams/wrap.png)

### Custom Configuration

A custom configuration is a good approach if you already have a build system set up for your design and want to make the minimum changes possible.

Pass a `CosimCustomConfig` object into the `Cosim.connectToSimulation` call with information about how to launch the simulation and it will handle the rest.

ROHD Cosim will generate a cocotb-based python connector which is launched by the simulation process.

ROHD Cosim communicates with the python connector through a local socket.  ROHD watches for a special string with port information that comes from stdout via the python connector for how to connect.  If you mask `stdout` (e.g. to some other file), you need to find another way to pass that information through.

Your SystemVerilog build will need to be configured to properly integrate the cocotb libraries.  You can follow these instructions for your choice of simulator: https://docs.cocotb.org/en/stable/custom_flows.html

You will need to set some environment variables during simulation so that cocotb can determine what to run:
```
# Modules to search for test functions (should match python file name and module path generated by ROHD Cosim)
export MODULE=cosim_test_module
 
export TOPLEVEL_LANG=verilog
 
# TOPLEVEL is the name of the toplevel module in your Verilog build
export TOPLEVEL=top_tb
```

You will also need to ensure the following plusarg is passed to your simulation:
```
+define+COCOTB_SIM=1
```

The diagram below shows how the custom configuration connects to your simulation.  Your custom build flow generates the simulation executable, and then ROHD cosim takes care of the rest similar to the wrap configuration.

![Custom Config Diagram](https://github.com/intel/rohd-cosim/raw/main/doc/diagrams/custom.png)

### Port Configuration

A port configuration is an even more specialized config in case you have not only your own custom build system, but a custom simulation run system as well.  With the port configuration, you create a `PortConfig` object to the `Cosim.connectToSimulation` call with information about what unix socket port it should connect to.  In this way, it is no longer necessary for ROHD Cosim to be the launcher of the SystemVerilog simulation: another process can launch the simulation and then ROHD Cosim can attach at the specified port.

To build this system may require some custom python code to manually pass the port information where it needs to go.  The file `python/rohd_port_connector.py` can help with a lot of this.

Check out `test/port_test.dart` for a good example of how to make this work.

The diagram below shows how the port configuration connects to your simulation.  Your custom build flow generates the simulation executable, and your custom run flow starts the simulation.  You must create some mechanism, such as through a custom cocotb test, to pass port information back to ROHD cosim.  In this diagram, the custom test is launching the actual ROHD process with a port argument on the command line.

![Port Config Diagram](https://github.com/intel/rohd-cosim/raw/main/doc/diagrams/port.png)

----------------
2022 September 9  
Author: Max Korbel <<max.korbel@intel.com>>

 
Copyright (C) 2022-2023 Intel Corporation  
SPDX-License-Identifier: BSD-3-Clause
