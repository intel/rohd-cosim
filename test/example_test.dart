/// Copyright (C) 2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// example_test.dart
/// Tests to make sure that the examples don't break.
///
/// 2023 February 13
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import '../example/main.dart' as counter;
import 'cosim_test_infra.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  test('counter example', () async {
    await counter.main(noPrint: true);
    await CosimTestingInfrastructure.delayedDeleteDirectory(
        './example/tmp_cosim');
  });
}
