// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// bus_test.dart
// Basic tests for cosim with busses
//
// 2022 January 11
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

class CosimBusMod extends ExternalSystemVerilogModule with Cosim {
  Logic get b => output('b');

  @override
  List<String> get verilogSources => ['../../test/cosim_bus.sv'];

  CosimBusMod(Logic a, {super.name = 'cffm'})
      : super(definitionName: 'my_cosim_bus') {
    addInput('a', a, width: 4);
    addOutput('b', width: 4);
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test('simple bus', () async {
      final mod = CosimBusMod(Logic(width: 4));
      await mod.build();

      const dirName = 'simple_bus';

      await CosimTestingInfrastructure.connectCosim(dirName,
          systemVerilogSimulator: sim);

      final vectors = [
        Vector({'a': 0}, {'b': 0}),
        Vector({'a': 0x3}, {'b': 0x3}),
        if (sim != SystemVerilogSimulator.verilator)
          Vector({'a': LogicValue.ofString('01xz')},
              {'b': LogicValue.ofString('01xz')}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);
    });
  });
}
