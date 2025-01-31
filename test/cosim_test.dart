// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_test.dart
// Basic tests for cosim
//
// 2022 January 11
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

class ExampleTopModule extends Module {
  Logic get a => input('a');
  Logic get aBar => output('a_bar');

  late final ExampleCosimModule ecm;
  ExampleTopModule(Logic a) : super(name: 'exTopMod') {
    a = addInput('a', a);
    final aBar = addOutput('a_bar');

    ecm = ExampleCosimModule(a, Logic());
    aBar <= ecm.aBar;
  }
}

class ExampleCosimModule extends ExternalSystemVerilogModule with Cosim {
  Logic get aBar => output('a_bar');
  Logic get bSame => output('b_same');

  @override
  List<String> get verilogSources => ['../../test/cosim_mod.sv'];

  ExampleCosimModule(Logic a, Logic b, {super.name = 'ecm'})
      : super(definitionName: 'my_cosim_test_module') {
    addInput('a', a);
    addInput('b', b);
    addOutput('a_bar');
    addOutput('b_same');
    addOutput('c_none');

    // TODO(mkorbel1): test 0-width ports, https://github.com/intel/rohd-cosim/issues/9
    // test that 0-width works ok
    // addInput('d_in', Logic(width: 0), width: 0);
    // addOutput('d_out', width: 0);
  }
}

class DoubleCosimModuleTop extends Module {
  Logic get a => input('a');
  Logic get aBar1 => output('a_bar1');
  Logic get aBar2 => output('a_bar2');

  DoubleCosimModuleTop(Logic a) : super(name: 'exTopModDouble') {
    a = addInput('a', a);
    final aBar1 = addOutput('a_bar1');
    final aBar2 = addOutput('a_bar2');

    final ecm1 = ExampleCosimModule(a, Logic(), name: 'ecm1');
    final ecm2 = ExampleCosimModule(a, Logic(), name: 'ecm2');
    aBar1 <= ecm1.aBar;
    aBar2 <= ecm2.aBar;
  }
}

class ExampleTopModuleWithInouts extends Module {
  late final ExampleCosimModuleInOut ecm;

  ExampleTopModuleWithInouts(LogicNet a, LogicNet b) {
    a = addInOut('a', a);
    b = addInOut('b', b);

    ecm = ExampleCosimModuleInOut(a, b);
  }
}

class ExampleCosimModuleInOut extends ExternalSystemVerilogModule with Cosim {
  @override
  List<String> get verilogSources => ['../../test/cosim_mod_inout.sv'];

  ExampleCosimModuleInOut(LogicNet a, LogicNet b)
      : super(definitionName: 'my_cosim_test_module_nets') {
    addInOut('a', a);
    addInOut('b', b);
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    test('simple push and check', () async {
      final a = Logic();
      final mod = ExampleTopModule(a);
      await mod.build();

      await CosimTestingInfrastructure.connectCosim('simple_push_n_check',
          systemVerilogSimulator: sim);

      Simulator.registerAction(2, () {
        a.put(1);
      });
      Simulator.registerAction(3, () {
        expect(mod.aBar.value, equals(LogicValue.zero));
      });
      Simulator.registerAction(4, () {
        a.put(0);
      });
      Simulator.registerAction(5, () {
        expect(mod.aBar.value, equals(LogicValue.one));
      });
      await Simulator.run();
    });

    if (sim != SystemVerilogSimulator.verilator) {
      // verilator does not support inout connections: https://github.com/verilator/verilator/issues/2844

      group('inout', () {
        test('simple push and check with inout', () async {
          final a = LogicNet();
          final b = LogicNet();
          final mod = ExampleTopModuleWithInouts(a, b);
          await mod.build();

          await CosimTestingInfrastructure.connectCosim(
              'simple_push_n_check_with_inout',
              systemVerilogSimulator: sim);

          // in the a -> b direction
          Simulator.registerAction(2, () {
            a.put(1);
          });
          Simulator.registerAction(3, () {
            expect(b.value, equals(LogicValue.one));
          });
          Simulator.registerAction(4, () {
            a.put(0);
          });
          Simulator.registerAction(5, () {
            expect(b.value, equals(LogicValue.zero));
          });

          // break contention
          Simulator.registerAction(6, () {
            a.put(LogicValue.z);
          });

          // in the b -> a direction
          Simulator.registerAction(7, () {
            b.put(1);
          });
          Simulator.registerAction(9, () {
            expect(a.value, equals(LogicValue.one));
          });
          Simulator.registerAction(10, () {
            b.put(0);
          });
          Simulator.registerAction(11, () {
            expect(a.value, equals(LogicValue.zero));
          });

          await Simulator.run();
        });

        test('simple push and check with inout contention', () async {
          final a = Logic();
          final b = Logic();
          final mod = ExampleTopModuleWithInouts(
              LogicNet()..gets(a), LogicNet()..gets(b));
          await mod.build();

          await CosimTestingInfrastructure.connectCosim(
              'simple_push_n_check_with_inout',
              systemVerilogSimulator: sim);

          // in the a -> b direction
          Simulator.registerAction(2, () {
            a.put(1);
          });
          Simulator.registerAction(3, () {
            expect(mod.inOut('a').value, equals(LogicValue.one));
            expect(mod.inOut('b').value, equals(LogicValue.one));
          });

          // contention
          Simulator.registerAction(6, () {
            b.put(0);
          });
          Simulator.registerAction(7, () {
            expect(mod.inOut('a').value, equals(LogicValue.x));
            expect(mod.inOut('b').value, equals(LogicValue.x));
          });

          // break contention, b -> a direction
          Simulator.registerAction(9, () {
            expect(mod.inOut('a').value, equals(LogicValue.zero));
            expect(mod.inOut('b').value, equals(LogicValue.zero));
          });

          await Simulator.run();
        });
      });
    }

    test('comb latency', () async {
      final a = Logic();
      final mod = ExampleTopModule(a);
      await mod.build();

      await CosimTestingInfrastructure.connectCosim('comb_latency',
          systemVerilogSimulator: sim);

      mod.aBar.changed.listen((event) {
        if (Simulator.time == 2) {
          expect(event.newValue, equals(LogicValue.zero));
        } else if (Simulator.time == 4) {
          expect(event.newValue, equals(LogicValue.one));
        } else {
          throw Exception('aBar changed at an unexpected time!');
        }
      });

      Simulator.registerAction(2, () {
        a.put(1);
      });
      Simulator.registerAction(4, () {
        a.put(0);
      });

      await Simulator.run();
    });

    test('simple simcompare', () async {
      final a = Logic();
      final mod = ExampleTopModule(a);
      await mod.build();

      await CosimTestingInfrastructure.connectCosim('simple_simcompare',
          systemVerilogSimulator: sim);

      final vectors = [
        Vector({'a': 1}, {'a_bar': 0}),
        Vector({'a': 0}, {'a_bar': 1}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);
    });

    if (sim != SystemVerilogSimulator.verilator) {
      // verilator does not support 4-value simulation
      test('4-value', () async {
        final mod = ExampleCosimModule(Logic(), Logic());
        await mod.build();

        await CosimTestingInfrastructure.connectCosim('fourval',
            systemVerilogSimulator: sim);

        final vectors = [
          Vector({'b': 0}, {'b_same': 0}),
          Vector({'b': 1}, {'b_same': 1}),
          Vector({'b': LogicValue.x}, {'b_same': LogicValue.x}),
          Vector({'b': LogicValue.z}, {'b_same': LogicValue.z}),
        ];
        await SimCompare.checkFunctionalVector(mod, vectors);
      });
    }

    test('double module', () async {
      final a = Logic();
      final mod = DoubleCosimModuleTop(a);
      await mod.build();

      await CosimTestingInfrastructure.connectCosim('double_module',
          systemVerilogSimulator: sim);

      final vectors = [
        Vector({'a': 1}, {'a_bar1': 0, 'a_bar2': 0}),
        Vector({'a': 0}, {'a_bar1': 1, 'a_bar2': 1}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);
    });

    test('simple push and check with waves', () async {
      final a = Logic();
      final mod = ExampleTopModule(a);
      await mod.build();

      const dirName = 'simple_push_n_check_w_waves';

      await CosimTestingInfrastructure.connectCosim(dirName,
          dumpWaves: true,
          cleanupAfterSimulationEnds: false,
          systemVerilogSimulator: sim);

      Simulator.registerAction(2, () {
        a.put(1);
      });
      Simulator.registerAction(3, () {
        expect(mod.aBar.value, equals(LogicValue.zero));
      });
      Simulator.registerAction(4, () {
        a.put(0);
      });
      Simulator.registerAction(5, () {
        expect(mod.aBar.value, equals(LogicValue.one));
      });
      await Simulator.run();

      expect(
          File('tmp_cosim/${sim.name}_simple_push_n_check_w_waves/waves.vcd')
              .existsSync(),
          isTrue);

      await CosimTestingInfrastructure.cleanupCosim(dirName, sim);
    });
  });

  test('iverilog simcompare', () async {
    final a = Logic();
    final mod = ExampleTopModule(a);
    await mod.build();

    final vectors = [
      Vector({'a': 1}, {'a_bar': 0}),
      Vector({'a': 0}, {'a_bar': 1}),
    ];
    final simResult = SimCompare.iverilogVector(mod, vectors,
        iverilogExtraArgs: ['./test/cosim_mod.sv']);
    expect(simResult, equals(true));
  });
}
