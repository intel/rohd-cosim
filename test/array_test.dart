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

  group('cosim array', () {
    //TODO: walking ones
    //TODO: 2xunpacked dims

    test('2 packed, 0 unpacked', () async {
      final mod = CosimArrayMod(Logic(width: 6));
      await mod.build();

      const dirName = 'simple_array_2p0u';

      await CosimTestingInfrastructure.connectCosim(dirName);

      final vectors = [
        Vector({'a': 0}, {'b': 0}),
        Vector({'a': LogicValue.ofString('01xz10')},
            {'b': LogicValue.ofString('01xz10')}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);

      await CosimTestingInfrastructure.cleanupCosim(dirName);
    });

    test('2 packed, 1 unpacked', () async {
      final mod = CosimArrayMod(Logic(width: 6 * 4), numUnpackedDimensions: 1);
      await mod.build();

      const dirName = 'simple_array_2p1u';

      await CosimTestingInfrastructure.connectCosim(dirName);

      final vectors = [
        Vector({'a': 0}, {'b': 0}),
        Vector({'a': LogicValue.ofString('01xz10' * 4)},
            {'b': LogicValue.ofString('01xz10' * 4)}),
      ];
      await SimCompare.checkFunctionalVector(mod, vectors);

      await CosimTestingInfrastructure.cleanupCosim(dirName);
    });
  });
}
