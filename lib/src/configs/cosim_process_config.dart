// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_process_config.dart
// Definition for CosimProcessConfig.
//
// 2022 September 8
// Author: Max Korbel <max.korbel@intel.com>

// ignore_for_file: close_sinks

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:rohd_cosim/src/exceptions/unexpected_end_of_simulation.dart';

/// Abstract class for configurations that can be passed to start a
/// cosimulation.
///
/// By default, just creates the connector, which is useful at least as a
/// reference.
abstract class CosimProcessConfig extends CosimConfig {
  /// The default directory to place the cosim generated outputs.
  static const _defaultCosimDirectory = './cosim_gen/';

  /// Directory where files will be dumped into.
  final String directory;

  /// Creates a configuration which launches a sub-process to cosimulate with.
  const CosimProcessConfig({
    this.directory = _defaultCosimDirectory,
    super.enableLogging,
    super.throwOnUnexpectedEnd,
  });

  @override
  Future<CosimConnection> connect() async {
    Cosim.generateConnector(directory: directory, enableLogging: enableLogging);

    return _connectToCosim(
      startCosimProcess,
      directory,
      throwOnUnexpectedEnd: throwOnUnexpectedEnd,
    );
  }

  /// Starts the execution of the SystemVerilog simulator with all
  /// proper arguments to accept communication from ROHD.
  Future<Process> startCosimProcess(String directory);

  /// Starts the cosimulation by starting [startCosimProcess] in a subprocess.
  ///
  /// Assumes that socket information can be printed through stdout.
  static Future<CosimConnection> _connectToCosim(
    Future<Process> Function(String directory) startCosimProcess,
    String directory, {
    required bool throwOnUnexpectedEnd,
  }) async {
    /// Socket connection to the cosimulation process.
    ///
    /// This is set to null at the end of the simulation after disconnection.
    Socket? socket;

    IOSink? outFileSink;

    var hasEnded = false;

    final procFuture = startCosimProcess(directory);

    final socketConnectionCompleter = Completer<void>();

    // set up logging during cosimulation, including cleanup.
    final cosimLogFile = File('$directory/rohd_cosim.log');
    outFileSink = cosimLogFile.openWrite();

    /// Logs a message related to cosim to the log file.
    void cosimLog(String message) {
      if (hasEnded) {
        return;
      }
      outFileSink?.write(message);
    }

    unawaited(procFuture.then((proc) {
      proc.stdout.transform(utf8.decoder).forEach((msg) async {
        Cosim.logger?.finest('SIM STDOUT:\n$msg');
        cosimLog(msg);

        if (!socketConnectionCompleter.isCompleted) {
          final socketNumber = CosimConnection.extractSocketPort(msg);

          if (socketNumber != null) {
            socket = await Socket.connect(
                InternetAddress.loopbackIPv4, socketNumber);
            socketConnectionCompleter.complete();
          }
        }
      });

      proc.stderr.transform(utf8.decoder).forEach((msg) {
        Cosim.logger?.warning('SIM STDERR:\n$msg');
        cosimLog(msg);
      });

      proc.exitCode.then((value) {
        Cosim.logger?.fine('SIM EXIT CODE: $value');

        if (value != 0) {
          throw Exception('Non-zero exit code $value thrown by cosim process.'
              ' See log file for more details.');
        }

        if (!hasEnded) {
          if (throwOnUnexpectedEnd) {
            Simulator.throwException(
                UnexpectedEndOfSimulation('Unexpected end of cosimulation!'
                    '  See log file for more details.'),
                StackTrace.current);
          }
          Cosim.endCosim();
        }
      });
    }));

    Cosim.logger?.finer('Waiting for socket to connect...');
    await socketConnectionCompleter.future;
    Cosim.logger?.finer('Socket connected!');

    Future<void> disconnect() async {
      hasEnded = true;

      try {
        await outFileSink?.flush();

        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        // in case we're unable to flush, log it in case it's helpful
        Cosim.logger?.finest('Failed to flush: $e');
      }

      final tmpOutfileSink = outFileSink;
      outFileSink = null;

      try {
        await tmpOutfileSink?.close();

        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        // in case we're unable to close, log it in case it's helpful
        Cosim.logger?.finest('Failed to close: $e');
      }
    }

    return CosimConnection(socket!, disconnect: disconnect);
  }
}
