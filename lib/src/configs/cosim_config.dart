// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_config.dart
// Definition for CosimConfig.
//
// 2022 October 27
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:io';

import 'package:rohd_cosim/src/exceptions/unexpected_end_of_simulation.dart';

/// Represents a connection to a cosimulation.
class CosimConnection {
  /// A socket to communicate with the cosimulation.
  final Socket socket;

  /// A flow to run as part of disconnection from cosimulation.
  ///
  /// By default, this is doing nothing.
  final Future<void> Function() disconnect;

  /// A default function for [disconnect] which does nothing.
  static Future<void> _defaultDisconnect() async {}

  /// A connection to cosimulation via [socket].
  ///
  /// Will run [disconnect] when the cosimulation is over.
  CosimConnection(this.socket, {this.disconnect = _defaultDisconnect});

  /// A regular expression for usage in [extractSocketPort].
  static final _cosimSocketRegex = RegExp(r'ROHD COSIM SOCKET:(\d+)');

  /// Extracts a socket number from a stdout [message] from the cosimulation
  /// process.  Returns `null` if no socket number is found in [message].
  static int? extractSocketPort(String message) {
    final match = _cosimSocketRegex.firstMatch(message);
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    return null;
  }
}

/// Configuration information for cosimulation.
abstract class CosimConfig {
  /// If true, additional debug logging will be enabled for cosimulation.
  final bool enableLogging;

  /// If true, throws an [UnexpectedEndOfSimulation] exception in case the
  /// cosimulation ends unexpectedly.  Otherwise, just prints a warning.
  final bool throwOnUnexpectedEnd;

  /// Constructs information for cosimulation.
  ///
  /// Additional debug logging is enabled via [enableLogging].  Can optionally
  /// throw an exception if cosimulation ends unexpectedly by setting
  /// [throwOnUnexpectedEnd] to `true`.
  const CosimConfig({
    this.enableLogging = false,
    this.throwOnUnexpectedEnd = true,
  });

  /// Initializes the connection to cosimulation.
  Future<CosimConnection> connect();
}
