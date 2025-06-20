// Copyright (C) 2022-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// port_test.dart
// Test where the python launches the dart, passing port over cli.
//
// 2022 October 27
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'cosim_test_infra.dart';
import 'port_stuff/port_launch.dart';

void main() async {
  const portStuffDir = './test/port_stuff/';
  String outDirPathOf(String outDirName) => '$portStuffDir/$outDirName/';

  Future<void> cleanup(String outDirName) async {
    final outDirPath = outDirPathOf(outDirName);
    await CosimTestingInfrastructure.delayedDeleteDirectory(outDirPath);
  }

  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  /// Returns stdout of process.
  Future<String> runPortTest({
    required String outDirName,
    bool dartFail = false,
    bool finish = false,
    bool enableLogging = false,
    bool failAsync = false,
    bool hang = false,
    bool separateDartLaunch = false,
    bool pythonFail = false,
  }) async {
    await cleanup(outDirName);

    final runEnv = {
      'OUT_DIR': outDirName,
      if (dartFail) 'DART_FAIL': '1',
      if (finish) 'EXTRA_ARGS': '-DDO_FINISH',
      if (failAsync) 'DART_FAIL_ASYNC': '1',
      if (hang) 'DART_HANG': '1',
      if (separateDartLaunch) 'SEPARATE_DART_LAUNCH': '1',
      if (pythonFail) 'PYTHON_FAIL': '1',
    };

    // first build
    final buildResult = Process.runSync(
      './build.sh',
      [],
      workingDirectory: portStuffDir,
      environment: runEnv,
    );

    expect(buildResult.exitCode, equals(0),
        reason:
            [buildResult.stdout, buildResult.stderr].join('\n ======== \n'));

    // need to build module to generate connector
    await BottomMod(Logic()).build();
    Cosim.generateConnector(
        directory: outDirPathOf(outDirName), enableLogging: enableLogging);

    final proc = await Process.start(
      './sim.sh',
      [],
      workingDirectory: portStuffDir,
      environment: runEnv,
    );

    final stdoutBuffer = StringBuffer();
    unawaited(proc.stdout.transform(utf8.decoder).forEach((msg) async {
      stdoutBuffer.write(msg);

      if (enableLogging) {
        // ignore: avoid_print
        print(msg);
      }

      if (separateDartLaunch) {
        final socketNumber = CosimConnection.extractSocketPort(msg);
        if (socketNumber != null) {
          unawaited(runCosim(socketNumber,
              dartFail: dartFail,
              failAsync: failAsync,
              hang: hang,
              doPrint: enableLogging));
        }
      }
    }));

    final exitCode = await proc.exitCode;

    expect(exitCode, equals(0));

    final stdoutContents = stdoutBuffer.toString();

    expect(stdoutContents,
        isNot(contains('ERROR: Exception encountered during cosim')));

    return stdoutContents;
  }

  test('port test normal', () async {
    const outDirName = 'tmp_normal';

    final stdoutContents = await runPortTest(outDirName: outDirName);

    expect(stdoutContents, contains('PASS=1'));

    await cleanup(outDirName);
  });

  test('port test dart fail', () async {
    const outDirName = 'tmp_dart_fail';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, dartFail: true);

    // if vvp is still sticking around, this test will time out

    // make sure exception occurred in dart
    final stderrLogContents =
        File('${outDirPathOf(outDirName)}/custom_test.stderr.log')
            .readAsStringSync();
    expect(stderrLogContents, contains('Failure intentionally injected'));

    // make sure error is communicated
    expect(stdoutContents, contains('ERROR:'));

    await cleanup(outDirName);
  });

  test('port test with finish passes', () async {
    const outDirName = 'tmp_finish';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, finish: true);

    expect(stdoutContents, contains('detected a failure from cocotb'));

    await cleanup(outDirName);
  });

  test('port test dart fail async', () async {
    const outDirName = 'tmp_dart_fail_async';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, failAsync: true);

    // if vvp is still sticking around, this test will time out

    // make sure exception occurred in dart
    final stderrLogContents =
        File('${outDirPathOf(outDirName)}/custom_test.stderr.log')
            .readAsStringSync();
    expect(stderrLogContents, contains('Async failure intentionally injected'));

    // make sure error is communicated
    expect(stdoutContents, contains('ERROR:'));

    await cleanup(outDirName);
  });

  test('port test dart hang timeout', () async {
    const outDirName = 'tmp_dart_hang';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, hang: true);

    // if vvp is still sticking around, this test will time out

    // make sure error is communicated
    expect(stdoutContents, contains('ERROR:'));

    await cleanup(outDirName);
  });

  test('port test with separate dart launch', () async {
    const outDirName = 'tmp_dart_separate_launch';

    await runPortTest(
      outDirName: outDirName,
      separateDartLaunch: true,
    );

    await cleanup(outDirName);
  });

  test('python exception causes test failure', () async {
    const outDirName = 'tmp_python_fail';

    final stdoutContents = await runPortTest(
      outDirName: outDirName,
      pythonFail: true,
    );

    expect(stdoutContents, contains('FAIL=1'));

    await cleanup(outDirName);
  });
}
