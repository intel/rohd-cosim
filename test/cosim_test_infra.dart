// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_test_infra.dart
// Utility for launching cosimulation in tests.
//
// 2022
// Author: Max Korbel <max.korbel@intel.com>

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

abstract class CosimTestingInfrastructure {
  static const _tmpCosimDir = 'tmp_cosim';

  /// Connects the cosimulation, optionally with [enableLogging] and
  /// [dumpWaves].  Puts temporary files into a common area.
  ///
  /// Make sure to call [cleanupCosim] afterwards.  If you set
  /// [cleanupAfterSimulationEnds] it will do it automatically for you.
  static Future<void> connectCosim(
    String testName, {
    required SystemVerilogSimulator systemVerilogSimulator,
    bool enableLogging = false,
    bool dumpWaves = false,
    bool cleanupAfterSimulationEnds = true,
  }) async {
    if (enableLogging) {
      Logger.root.level = Level.ALL;
      final loggerSubscription = Logger.root.onRecord.listen(print);
      Simulator.registerEndOfSimulationAction(loggerSubscription.cancel);
    }

    await Cosim.connectCosimulation(CosimWrapConfig(
      systemVerilogSimulator,
      directory: tempDirName(testName, systemVerilogSimulator),
      enableLogging: enableLogging,
      dumpWaves: dumpWaves,
    ));

    if (cleanupAfterSimulationEnds) {
      // wait a second to do it so that the SV simulator can shut down
      Simulator.registerEndOfSimulationAction(() async {
        await cleanupCosim(testName, systemVerilogSimulator);
      });
    }
  }

  /// Creates a test group for each supported simulator.
  static void testPerSimulator(
      void Function(SystemVerilogSimulator sim) buildTests) {
    for (final sim in [
      SystemVerilogSimulator.icarus,
      SystemVerilogSimulator.verilator
    ]) {
      group(sim.name, () {
        buildTests(sim);
      });
    }
  }

  /// Constructs the temporary directory path for a test.
  static String tempDirName(
          String testName, SystemVerilogSimulator simulator) =>
      '$_tmpCosimDir/${simulator.name}_$testName';

  /// Deletes temporary files created by [connectCosim].
  static Future<void> cleanupCosim(
      String testName, SystemVerilogSimulator simulator) async {
    await delayedDeleteDirectory(tempDirName(testName, simulator));
  }

  /// Deletes a directory at [directoryPath] (recursively) after
  /// [delay] seconds.
  static Future<void> delayedDeleteDirectory(String directoryPath,
      {int delay = 1}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    final dir = Directory(directoryPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}
