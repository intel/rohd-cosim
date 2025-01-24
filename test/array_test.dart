// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// array_test.dart
// Tests for array functionality
//
// 2023 November 28
// Author: Max Korbel <max.korbel@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

class CosimArrayMod extends ExternalSystemVerilogModule with Cosim {
  LogicArray get b => output('b') as LogicArray;

  @override
  List<String> get verilogSources => ['../../test/cosim_array.sv'];

  CosimArrayMod(
    Logic a, {
    super.name = 'arraymod',
    int numUnpackedDimensions = 0,
  })  : assert(numUnpackedDimensions >= 0 && numUnpackedDimensions <= 2,
            'only supports 0,1,2'),
        super(definitionName: 'my_cosim_array_2p${numUnpackedDimensions}u') {
    final dimensions = [
      if (numUnpackedDimensions >= 2) 5,
      if (numUnpackedDimensions >= 1) 4,
      3,
    ];

    addInputArray('a', a,
        dimensions: dimensions,
        elementWidth: 2,
        numUnpackedDimensions: numUnpackedDimensions);
    addOutputArray('b',
        dimensions: dimensions,
        elementWidth: 2,
        numUnpackedDimensions: numUnpackedDimensions);
  }
}

Future<void> main() async {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  CosimTestingInfrastructure.testPerSimulator((sim) {
    group('cosim array', () {
      List<Vector> walkingOnes(int width) {
        final vectors = <Vector>[];
        for (var i = 0; i < width; i++) {
          final shiftedOne = LogicValue.ofInt(1, width) << i;
          vectors.add(Vector({'a': shiftedOne}, {'b': shiftedOne}));
        }
        return vectors;
      }

      test('2 packed, 0 unpacked', () async {
        final mod = CosimArrayMod(Logic(width: 6));
        await mod.build();

        const dirName = 'simple_array_2p0u';

        await CosimTestingInfrastructure.connectCosim(dirName,
            systemVerilogSimulator: sim);

        final vectors = [
          Vector({'a': 0}, {'b': 0}),
          if (sim != SystemVerilogSimulator.verilator)
            Vector({'a': LogicValue.ofString('01xz10')},
                {'b': LogicValue.ofString('01xz10')}),
          ...walkingOnes(6)
        ];
        await SimCompare.checkFunctionalVector(mod, vectors);
      });

      if (sim != SystemVerilogSimulator.verilator) {
        // TODO(mkorbel1): enable these tests when verilator and cocotb supports
        //  unpacked array ports, https://github.com/cocotb/cocotb/issues/3446
        test('2 packed, 1 unpacked', () async {
          final mod =
              CosimArrayMod(Logic(width: 6 * 4), numUnpackedDimensions: 1);
          await mod.build();

          const dirName = 'simple_array_2p1u';

          await CosimTestingInfrastructure.connectCosim(dirName,
              systemVerilogSimulator: sim);

          final vectors = [
            Vector({'a': 0}, {'b': 0}),
            if (sim != SystemVerilogSimulator.verilator)
              Vector({'a': LogicValue.ofString('01xz10' * 4)},
                  {'b': LogicValue.ofString('01xz10' * 4)}),
            ...walkingOnes(24),
          ];

          await SimCompare.checkFunctionalVector(mod, vectors);
        });

        test('2 packed, 2 unpacked', () async {
          final mod =
              CosimArrayMod(Logic(width: 6 * 4 * 5), numUnpackedDimensions: 2);
          await mod.build();

          const dirName = 'simple_array_2p2u';

          await CosimTestingInfrastructure.connectCosim(dirName,
              systemVerilogSimulator: sim);

          final vectors = [
            Vector({'a': 0}, {'b': 0}),
            if (sim != SystemVerilogSimulator.verilator)
              Vector({'a': LogicValue.ofString('01xz10' * 4 * 5)},
                  {'b': LogicValue.ofString('01xz10' * 4 * 5)}),
            ...walkingOnes(120),
          ];
          await SimCompare.checkFunctionalVector(mod, vectors);
        });
      }
    });
  });
}
