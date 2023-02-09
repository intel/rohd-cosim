/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// hier_test.dart
/// Tests with levels of hierarchy and custom build & sim flows.
///
/// 2022 September 8
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd/src/utilities/simcompare.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

class BottomMod extends ExternalSystemVerilogModule with Cosim {
  @override
  String get cosimHierarchy => 'submod';

  Logic get aBar => output('a_bar');

  BottomMod(Logic a) : super(definitionName: 'bottom_mod') {
    addInput('a', a);
    addOutput('a_bar');
  }
}

void main() {
  const hierStuffDir = './test/hier_stuff/';
  const outDirPath = '$hierStuffDir/tmp_output/';

  void cleanup() {
    final outDir = Directory(outDirPath);
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }
  }

  setUp(cleanup);

  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
    cleanup();
  });

  test('hier test', () async {
    // first build
    final buildResult =
        Process.runSync('./build.sh', [], workingDirectory: hierStuffDir);

    expect(buildResult.exitCode, equals(0),
        reason:
            [buildResult.stdout, buildResult.stderr].join('\n ======== \n'));

    // then run cosim
    final a = Logic();
    final mod = BottomMod(a);
    await mod.build();

    await Cosim.connectCosimulation(
      CosimCustomConfig(
        (directory) => Process.start(
          './sim.sh',
          [],
          workingDirectory: hierStuffDir,
        ),
        directory: outDirPath,
      ),
    );

    final vectors = [
      Vector({'a': 0}, {'a_bar': 1}),
      Vector({'a': 1}, {'a_bar': 0}),
      Vector({'a': LogicValue.z}, {'a_bar': LogicValue.x}),
    ];
    await SimCompare.checkFunctionalVector(mod, vectors);
  });
}
