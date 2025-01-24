// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// sampling_test.dart
// Tests for flop sampling with cosim.
//
// 2022 December 28
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/vcd_parser.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

class SamplingModule extends ExternalSystemVerilogModule with Cosim {
  @override
  List<String> get verilogSources => ['../../test/sampling_test.sv'];

  Logic get sampled => output('sampled');

  SamplingModule(Logic clk, Logic pushValid, Logic pushData)
      : super(definitionName: 'sampling_module') {
    addInput('clk', clk);
    addInput('push_valid', pushValid);
    addInput('push_data', pushData, width: 8);
    addOutput('sampled', width: 8);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test('sampling', () async {
      final pushValid = Logic();
      final pushData = Logic(width: 8);
      final clk = SimpleClockGenerator(10).clk;
      final mod = SamplingModule(clk, pushValid, pushData);
      await mod.build();

      var count = 0;
      clk.posedge.listen((event) {
        Simulator.injectAction(() {
          pushValid.put(count.isEven);
          pushData.put(count++);
        });
      });

      const testName = 'sampling_test';
      final dirName = CosimTestingInfrastructure.tempDirName(testName, sim);

      await CosimTestingInfrastructure.connectCosim(testName,
          dumpWaves: true,
          cleanupAfterSimulationEnds: false,
          systemVerilogSimulator: sim);

      Simulator.setMaxSimTime(100);

      clk.negedge.listen((event) {
        final drivenCount = count - 1;
        if (drivenCount > 0) {
          expect(
            mod.sampled.value.toInt(),
            equals(drivenCount.isEven ? drivenCount - 2 : drivenCount - 1),
          );
        }
      });

      await Simulator.run();

      // wait for VCD to finish populating, takes time for some reason
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(File('$dirName/waves.vcd').existsSync(), isTrue);

      final vcdContents = File('$dirName/waves.vcd').readAsStringSync();
      for (var countI = 1; countI < 10; countI++) {
        final checkTime = (10 * countI + 5) * 1000;
        final expectedValue =
            LogicValue.ofInt(countI.isEven ? countI - 2 : countI - 1, 8);
        expect(
            VcdParser.confirmValue(
              vcdContents,
              'sampled',
              checkTime,
              expectedValue,
            ),
            isTrue,
            reason:
                'at $countI @$checkTime: expected `sampled` == $expectedValue');
      }

      await CosimTestingInfrastructure.cleanupCosim(testName, sim);
    });
  });
}
