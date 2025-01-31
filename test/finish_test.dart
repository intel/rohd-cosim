// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// finish_test.dart
// Test if the simulator calls $finish before cosim is done.
//
// 2022 November 2
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:rohd_cosim/src/exceptions/unexpected_end_of_simulation.dart';
import 'package:test/test.dart';
import 'cosim_test_infra.dart';

class FinishModule extends ExternalSystemVerilogModule with Cosim {
  @override
  List<String> get verilogSources => ['../../test/cosim_finish.sv'];

  @override
  List<String>? get extraArgs => [
        if (simulator == SystemVerilogSimulator.verilator) '--timing',
      ];

  final SystemVerilogSimulator simulator;

  FinishModule(Logic clk, {required this.simulator})
      : super(definitionName: 'finish_module') {
    addInput('clk', clk);
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test(r'handle $finish properly and end', () async {
      final mod = FinishModule(SimpleClockGenerator(10).clk, simulator: sim);
      await mod.build();

      const dirName = 'finish_test';

      await CosimTestingInfrastructure.connectCosim(
        dirName,
        cleanupAfterSimulationEnds: false,
        systemVerilogSimulator: sim,
      );

      Simulator.setMaxSimTime(100);

      var unexpectedEnd = false;
      try {
        await Simulator.run();
      } on UnexpectedEndOfSimulation {
        unexpectedEnd = true;
      }

      // expect the unexpected
      expect(unexpectedEnd, isTrue);

      await CosimTestingInfrastructure.cleanupCosim(dirName, sim);
    });
  });
}
