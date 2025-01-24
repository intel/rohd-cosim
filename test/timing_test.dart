// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// timing_test.dart
// Tests for timing sensitivities with cosim.
//
// 2022 December 28
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/vcd_parser.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';
import 'cosim_test_infra.dart';

class TimingTestModule extends ExternalSystemVerilogModule with Cosim {
  @override
  List<String> get verilogSources => ['../../test/timing_test.sv'];

  Logic get initOut => output('init_out');

  TimingTestModule(Logic clk, Logic reset)
      : super(definitionName: 'timing_test_module') {
    addInput('clk', clk);
    addInput('reset', reset);
    addOutput('init_out', width: 8);
  }
}

void main() {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test('multiple injections arrive at proper timestamp', () async {
      final reset = Logic();
      final clk = SimpleClockGenerator(10).clk;
      final mod = TimingTestModule(clk, reset);
      await mod.build();

      const testName = 'multi_inject_time';
      final dirName = CosimTestingInfrastructure.tempDirName(testName, sim);

      await CosimTestingInfrastructure.connectCosim(testName,
          dumpWaves: true, cleanupAfterSimulationEnds: false);

      Simulator.registerAction(12, () {
        reset.put(0);
      });
      Simulator.registerAction(22, () {
        reset.put(1);
      });
      Simulator.registerAction(37, () {
        reset.put(0);
      });

      Simulator.setMaxSimTime(100);

      await Simulator.run();

      // wait for VCD to finish populating, takes time for icarus for some reason
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(File('$dirName/waves.vcd').existsSync(), isTrue);

      final vcdContents = File('$dirName/waves.vcd').readAsStringSync();

      for (var t = 1; t < 100; t++) {
        final expectedClkValue = t % 10 < 5 ? LogicValue.zero : LogicValue.one;

        final vcdTime = t * 1000;
        expect(
            VcdParser.confirmValue(
                vcdContents, 'clk', vcdTime, expectedClkValue),
            isTrue,
            reason: 'Expected clk to be $expectedClkValue at $vcdTime.');

        final expectedResetValue = t < 12
            ? LogicValue.z
            : t < 22
                ? LogicValue.zero
                : t < 37
                    ? LogicValue.one
                    : LogicValue.zero;
        VcdParser.confirmValue(
            vcdContents, 'reset', vcdTime, expectedResetValue);
      }

      await CosimTestingInfrastructure.cleanupCosim(
          testName, SystemVerilogSimulator.icarus);
    });

    test('inject on edge shows up on same edge', () async {
      final reset = Logic()..put(0);
      final clk = SimpleClockGenerator(10).clk;
      final mod = TimingTestModule(clk, reset);

      await mod.build();

      const testName = 'edge_injection';
      final dirName = CosimTestingInfrastructure.tempDirName(testName, sim);

      await CosimTestingInfrastructure.connectCosim(testName,
          dumpWaves: true, cleanupAfterSimulationEnds: false);

      Simulator.setMaxSimTime(100);

      clk.posedge.listen((event) {
        reset.inject(~reset.value);
      });

      await Simulator.run();

      // wait for VCD to finish populating, takes time for icarus for some reason
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(File('$dirName/waves.vcd').existsSync(), isTrue);

      final vcdContents = File('$dirName/waves.vcd').readAsStringSync();

      // the edges are off by some #steps since they come after the edge
      expect(VcdParser.confirmValue(vcdContents, 'reset', 5005, LogicValue.one),
          isTrue);
      expect(
          VcdParser.confirmValue(vcdContents, 'reset', 10000, LogicValue.one),
          isTrue);
      expect(
          VcdParser.confirmValue(vcdContents, 'reset', 15005, LogicValue.zero),
          isTrue);
      expect(
          VcdParser.confirmValue(vcdContents, 'reset', 20000, LogicValue.zero),
          isTrue);

      await CosimTestingInfrastructure.cleanupCosim(
          testName, SystemVerilogSimulator.icarus);
    });

    test('initially driven signals show up properly', () async {
      final clk = SimpleClockGenerator(10).clk;
      final mod = TimingTestModule(clk, Logic());

      await mod.build();

      const dirName = 'init_drive';

      await CosimTestingInfrastructure.connectCosim(dirName);

      Simulator.setMaxSimTime(100);

      Simulator.registerAction(1, () {
        expect(mod.initOut.value, equals(LogicValue.ofInt(0xa5, 8)));
      });

      Simulator.registerAction(77, () {
        expect(mod.initOut.value, equals(LogicValue.ofInt(0xa5, 8)));
      });

      await Simulator.run();
    });
  });
}
