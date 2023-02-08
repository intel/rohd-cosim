/// Copyright (C) 2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// rohd_cosim_exception.dart
/// Base class for all ROHD Cosim exceptions
///
/// 2023 January 9
/// Author: Max Korbel <max.korbel@intel.com>
///

/// A base type of exception that ROHD-specific exceptions inherit from.
abstract class RohdCosimException implements Exception {
  /// A description of what this exception means.
  final String message;

  /// Creates a new exception with description [message].
  RohdCosimException(this.message);

  @override
  String toString() => message;
}
