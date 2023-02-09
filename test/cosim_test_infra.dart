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
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';

class CosimTestingInfrastructure {
  static const _tmpCosimDir = 'tmp_cosim';

  /// Connects the cosimulation, optionally with [enableLogging] and
  /// [dumpWaves].  Puts temporary files into a common area.
  ///
  /// Make sure to call [cleanupCosim] afterwards.  If you set
  /// [cleanupAfterSimulationEnds] it will do it automatically for you.
  static Future<void> connectCosim(
    String testName, {
    bool enableLogging = false,
    bool dumpWaves = false,
    bool cleanupAfterSimulationEnds = true,
  }) async {
    if (enableLogging) {
      Logger.root.level = Level.ALL;
      final loggerSubscription = Logger.root.onRecord.listen(print);
      unawaited(
          Simulator.simulationEnded.then((_) => loggerSubscription.cancel()));
    }

    await Cosim.connectCosimulation(CosimWrapConfig(
      SystemVerilogSimulator.icarus,
      directory: '$_tmpCosimDir/$testName',
      enableLogging: enableLogging,
      dumpWaves: dumpWaves,
    ));

    if (cleanupAfterSimulationEnds) {
      // wait a second to do it so that the SV simulator can shut down
      unawaited(Simulator.simulationEnded.then((_) =>
          Future<void>.delayed(const Duration(seconds: 1))
              .then((_) => cleanupCosim(testName))));
    }
  }

  /// Deletes temporary files created by [connectCosim].
  static void cleanupCosim(String testName) {
    Directory('$_tmpCosimDir/$testName').deleteSync(recursive: true);
  }
}
