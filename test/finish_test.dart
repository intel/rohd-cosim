/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// finish_test.dart
/// Test if the simulator calls $finish before cosim is done.
///
/// 2022 November 2
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:rohd_cosim/src/exceptions/unexpected_end_of_simulation.dart';
import 'package:test/test.dart';
import 'cosim_test_infra.dart';

class FinishModule extends ExternalSystemVerilogModule with Cosim {
  @override
  List<String> get verilogSources => ['../../test/cosim_finish.sv'];

  FinishModule(Logic clk) : super(definitionName: 'finish_module') {
    addInput('clk', clk);
  }
}

Future<void> main() async {
  tearDown(() async {
    // TODO(mkorbel1): await Simulator.reset() here, https://github.com/intel/rohd-cosim/issues/10
    // ignore: unawaited_futures
    Simulator.reset();
    await Cosim.reset();
  });

  test(r'handle $finish properly and end', () async {
    final mod = FinishModule(SimpleClockGenerator(10).clk);
    await mod.build();

    const dirName = 'finish_test';

    await CosimTestingInfrastructure.connectCosim(dirName,
        cleanupAfterSimulationEnds: false);

    Simulator.setMaxSimTime(100);

    var unexpectedEnd = false;
    try {
      await Simulator.run();
    } on UnexpectedEndOfSimulation {
      unexpectedEnd = true;
    }

    // expect the unexpected
    expect(unexpectedEnd, isTrue);

    CosimTestingInfrastructure.cleanupCosim(dirName);
  });
}
