/// Copyright (C) 2022-2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// cosim_test_infra.dart
/// Utility for launching cosimulation in tests.
///
/// 2022
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';

Future<void> connectCosim(
  String testName, {
  bool enableLogging = false,
  bool dumpWaves = false,
}) async {
  if (enableLogging) {
    Logger.root.level = Level.ALL;
    final loggerSubscription = Logger.root.onRecord.listen(print);
    unawaited(
        Simulator.simulationEnded.then((_) => loggerSubscription.cancel()));
  }

  await Cosim.connectCosimulation(CosimWrapConfig(
    SystemVerilogSimulator.icarus,
    directory: 'tmp_cosim/$testName',
    enableLogging: enableLogging,
    dumpWaves: dumpWaves,
  ));
}
