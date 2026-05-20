// Copyright (C) 2022-2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// pair_test.dart
// Test with a pair of models talking through hierarchy.
//
// 2022 October 21
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';

enum PairDirection { leftToRight, rightToLeft, misc }

class PairIntf extends Interface<PairDirection> {
  Logic get lrValid => port('lrValid');
  Logic get lrData => port('lrData');

  Logic get rlValid => port('rlValid');
  Logic get rlData => port('rlData');

  Logic get clk => port('clk');

  PairIntf() {
    setPorts([
      Logic.port('lrValid'),
      Logic.port('lrData', 64),
    ], [
      PairDirection.leftToRight
    ]);
    setPorts([
      Logic.port('rlValid'),
      Logic.port('rlData', 512),
    ], [
      PairDirection.rightToLeft
    ]);
    setPorts([Logic.port('clk')], [PairDirection.misc]);
  }

  @override
  Interface<PairDirection> clone() => PairIntf();
}

class LeftSide extends ExternalSystemVerilogModule with Cosim {
  @override
  final String cosimHierarchy = 'left';

  LeftSide(PairIntf intf) : super(definitionName: 'left_side', name: 'left') {
    PairIntf().connectIO(this, intf,
        inputTags: {PairDirection.leftToRight},
        outputTags: {PairDirection.rightToLeft});
  }
}

class RightSide extends ExternalSystemVerilogModule with Cosim {
  @override
  final String cosimHierarchy = 'right';

  RightSide(PairIntf intf)
      : super(definitionName: 'right_side', name: 'right') {
    PairIntf().connectIO(this, intf,
        inputTags: {PairDirection.rightToLeft},
        outputTags: {PairDirection.leftToRight});
  }
}

void main() async {
  const pairStuffDir = './test/pair_stuff/';
  const outDirPath = '$pairStuffDir/tmp_output/';

  Future<void> cleanup() async {
    await CosimTestingInfrastructure.delayedDeleteDirectory(outDirPath);
  }

  setUp(() async {
    await cleanup();
  });

  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
    await cleanup();
  });

  test('pair test', () async {
    // first build
    final buildResult =
        Process.runSync('./build.sh', [], workingDirectory: pairStuffDir);

    expect(buildResult.exitCode, equals(0),
        reason:
            [buildResult.stdout, buildResult.stderr].join('\n ======== \n'));

    // then run cosim
    final rightIntf = PairIntf();
    final rightSide = RightSide(rightIntf);

    final leftIntf = PairIntf();
    final leftSide = LeftSide(leftIntf);

    final clk = SimpleClockGenerator(10).clk;

    await rightSide.build();
    await leftSide.build();

    await Cosim.connectCosimulation(
      CosimCustomConfig(
        (directory) => Process.start(
          './sim.sh',
          [],
          workingDirectory: pairStuffDir,
        ),
        directory: outDirPath,
        enableLogging: true,
      ),
    );

    unawaited(Simulator.run());

    await clk.nextNegedge;

    Simulator.injectAction(() {
      rightIntf.rlValid.put(1);
      rightIntf.rlData.put(0xff);
    });

    await clk.nextPosedge;

    expect(leftIntf.rlData.value, equals(LogicValue.ofInt(0xff, 512)));

    await clk.nextPosedge;

    await Simulator.endSimulation();
  });
}
