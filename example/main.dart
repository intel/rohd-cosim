/// Copyright (C) 2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// main.dart
/// Example of using a `CosimWrapConfig` with ROHD Cosim.
///
/// 2023 February 13
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: avoid_print

// Import the ROHD package.
import 'package:rohd/rohd.dart';

// Import the ROHD Cosim package.
import 'package:rohd_cosim/rohd_cosim.dart';

// Define a class Counter that extends ROHD's abstract
// `ExternalSystemVerilogModule` class and add the `Cosim` mixin.
class Counter extends ExternalSystemVerilogModule with Cosim {
  // For convenience, map interesting outputs to short variable names for
  // consumers of this module.
  Logic get val => output('val');

  // This counter was written with 8-bit width.
  static const int width = 8;

  // We must provide instructions for where to find the SystemVerilog that
  // is used to build the wrapped module.
  // Note that the path is relative to where we will configure the SystemVerilog
  // simulator to be running.
  @override
  List<String>? get verilogSources => ['../counter.sv'];

  Counter(Logic en, Logic reset, Logic clk, {super.name = 'counter'})
      // The `definitionName` is the name of the SystemVerilog module
      // we're instantiating.
      : super(definitionName: 'Counter') {
    // Register inputs and outputs of the module in the constructor.
    // These name *must* match the names of the ports in the SystemVerilog
    // module that we are wrapping.
    en = addInput('en', en);
    reset = addInput('reset', reset);
    clk = addInput('clk', clk);
    addOutput('val', width: width);
  }
}

// Let's simulate with this counter a little, generate a waveform, and take a
// look at generated SystemVerilog.  This little simulation mirrors closely the
// original example from ROHD:
// https://github.com/intel/rohd/blob/main/example/example.dart
Future<void> main({bool noPrint = false}) async {
  // Define some local signals.
  final en = Logic(name: 'en');
  final reset = Logic(name: 'reset');

  // Generate a simple clock.  This will run along by itself as
  // the Simulator goes.
  final clk = SimpleClockGenerator(10).clk;

  // Make our cosimulated counter.
  final counter = Counter(en, reset, clk);

  // Before we can simulate or generate code with the counter, we need
  // to build it.
  await counter.build();

  // **Important for Cosim!**
  // We must connect to the cosimulation process with configuration information.
  await Cosim.connectCosimulation(CosimWrapConfig(
    // The SystemVerilog will simulate with Icarus Verilog
    SystemVerilogSimulator.icarus,

    // We can generate waves from the SystemVerilog simulator.
    dumpWaves: !noPrint,

    // Let's specify where we want our SystemVerilog simulation to run.
    // This is the directory where temporary files, waves, and output
    // logs may appear.
    directory: './example/tmp_cosim/',
  ));

  // Now let's try simulating!

  // Let's start off with a disabled counter and asserting reset.
  en.inject(0);
  reset.inject(1);

  // Attach a waveform dumper so we can see what happens in the ROHD simulator.
  // Note that this is a separate VCD file from what the SystemVerilog simulator
  // will dump out.
  if (!noPrint) {
    WaveDumper(counter, outputPath: './example/tmp_cosim/rohd_waves.vcd');
  }

  // Drop reset at time 25.
  Simulator.registerAction(25, () => reset.put(0));

  // Raise enable at time 45.
  Simulator.registerAction(45, () => en.put(1));

  // Print a message every time the counter value changes.
  counter.val.changed.listen((event) {
    if (!noPrint) {
      print('Value of the counter changed @${Simulator.time}: $event');
    }
  });

  // Print a message when we're done with the simulation!
  Simulator.registerAction(100, () {
    if (!noPrint) {
      print('Simulation completed!');
    }
  });

  // Set a maximum time for the simulation so it doesn't keep running forever.
  Simulator.setMaxSimTime(100);

  // Kick off the simulation.
  await Simulator.run();

  // We can take a look at the waves now.
  if (!noPrint) {
    print('To view waves, check out waves with a waveform viewer'
        ' (e.g. `gtkwave waves.vcd` and `gtkwave rohd_waves.vcd`).');
  }
}
