/// Copyright (C) 2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// rohd_cosim_exception.dart
/// Base class for all ROHD Cosim exceptions
///
/// 2023 January 9
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd_cosim/src/exceptions/rohd_cosim_exception.dart';

/// An exception thrown when the simulation ends unexpectedly.
class UnexpectedEndOfSimulation extends RohdCosimException {
  /// Creates an exception indicating that cosimulation has ended
  /// unexpectedly, with [message] providing more details on the
  /// reason and/or context.
  UnexpectedEndOfSimulation(super.message);
}
