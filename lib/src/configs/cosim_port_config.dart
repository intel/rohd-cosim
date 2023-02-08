/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// cosim_port_config.dart
/// Definition for CosimPortConfig.
///
/// 2022 October 27
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:rohd_cosim/src/configs/configs.dart';

/// Configuration to connect to cosimulation on a specified port.
class CosimPortConfig extends CosimConfig {
  /// The port to connect to for cosimulation.
  final int port;

  /// Creates a configuration to connect to cosimulation on port [port].
  ///
  /// By default, [throwOnUnexpectedEnd] is set to `false` because when
  /// the SV simulator is the launcher of the Dart process it is not
  /// unlikely for it to be the initiator of the end of the test as well.
  CosimPortConfig(
    this.port, {
    super.enableLogging,
    super.throwOnUnexpectedEnd = false,
  });

  @override
  Future<CosimConnection> connect() async {
    // ignore: close_sinks
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port)
        // ignore: avoid_types_on_closure_parameters
        .catchError((Object error, StackTrace stackTrace) {
      print('Caught exception during socket connection: $error');
      print('> Stack trace:\n$stackTrace');
      // ignore: only_throw_errors
      throw error;
    });
    // ignore: avoid_types_on_closure_parameters
    socket.handleError((Object error, StackTrace stackTrace) {
      print('Caught exception from socket via port configuration: $error');
      print('> Stack trace:\n$stackTrace');
      print('Not rethrowing!');
    });

    return CosimConnection(socket);
  }
}
