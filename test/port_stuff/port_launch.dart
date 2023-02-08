/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// port_launch.dart
/// Utility for port_test.dart, launches the actual cosim via cli.
///
/// 2022 October 27
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', mandatory: true)
    ..addFlag('fail')
    ..addFlag('failAsync')
    ..addFlag('hang');
  final results = parser.parse(args);

  final port = int.parse(results['port'] as String);
  final fail = results['fail'] as bool;
  final failAsync = results['failAsync'] as bool;
  final hang = results['hang'] as bool;
  await runCosim(port, fail: fail, failAsync: failAsync, hang: hang);
}

class BottomMod extends ExternalSystemVerilogModule with Cosim {
  @override
  String get cosimHierarchy => 'submod';

  Logic get aBar => output('a_bar');

  BottomMod(Logic a) : super(definitionName: 'bottom_mod') {
    addInput('a', a);
    addOutput('a_bar');

    // test that zero-width ports are ignored
    addInput('x_zero', Logic(width: 0), width: 0);
    addOutput('y_zero', width: 0);
  }
}

const bool enableLogging = true;

Future<void> runCosim(int port,
    {required bool fail, required bool failAsync, required bool hang}) async {
  // var portStuffDir = './test/port_stuff/';
  // var outDirPath = '$portStuffDir/tmp_output/';

  void expectEqual(dynamic a, dynamic b) {
    if (a != b) {
      throw Exception('$a != $b');
    }
  }

  print('Building module...');
  final a = Logic();
  final mod = BottomMod(a);
  await mod.build();

  // ignore: dead_code
  if (enableLogging) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(print);
  }

  print('Connecting to cosimulation on port $port...');
  await Cosim.connectCosimulation(
      CosimPortConfig(port, enableLogging: enableLogging));

  print('Starting simulation...');

  mod.aBar.changed.listen((event) {
    print('checking @ ${Simulator.time}');
    if (Simulator.time == 2) {
      expectEqual(event.newValue, LogicValue.zero);
    } else if (Simulator.time == 4) {
      expectEqual(event.newValue, LogicValue.one);
    } else {
      throw Exception('aBar changed at an unexpected time!');
    }
  });

  Simulator.registerAction(2, () {
    print('putting 1');
    a.put(1);
  });
  Simulator.registerAction(4, () {
    print('putting 0');
    a.put(0);
  });

  if (fail) {
    print('Setting up to fail on the dart side.');
    Simulator.registerAction(3, () {
      throw Exception('Failure intentionally injected');
    });
  }

  if (failAsync) {
    print('Setting up to async fail on the dart side.');
    unawaited(a.changed.first.then(
        (value) => throw Exception('Async failure intentionally injected')));
  }

  if (hang) {
    print('Setting up to hang on the dart side.');
    Simulator.registerAction(3, () async {
      print('About to hang...');
      Simulator.injectAction(() async {
        await Future<void>.delayed(const Duration(seconds: 10));
      });
    });
  }

  Simulator.registerEndOfSimulationAction(() {
    print('End of ROHD Simulation!');
  });

  print('Done setting up vectors, launching simulation!');

  await Simulator.run();

  print('Simulation has completed!');
}
