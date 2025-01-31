// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ff_test.dart
// Basic tests for cosim with sequential logic
//
// 2022 January 11
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

class CosimFFMod extends ExternalSystemVerilogModule with Cosim {
  Logic get q => output('q');

  @override
  List<String> get verilogSources => ['../../test/cosim_ff.sv'];

  CosimFFMod(Logic clk, Logic d, {super.name = 'cffm'})
      : super(definitionName: 'my_cosim_ff') {
    addInput('clk', clk);
    addInput('d', d);
    addOutput('q');
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test('simple ff', () async {
      final d = Logic();
      final clk = SimpleClockGenerator(10).clk;
      final mod = CosimFFMod(clk, d);
      await mod.build();

      const dirName = 'simple_ff';

      await CosimTestingInfrastructure.connectCosim(dirName,
          systemVerilogSimulator: sim);

      final vectors = [
        Vector({'d': 0}, {}),
        Vector({'d': 1}, {'q': 0}),
        Vector({'d': 1}, {'q': 1}),
        Vector({'d': 0}, {'q': 1}),
        Vector({'d': 0}, {'q': 0}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);
    });
  });
}
