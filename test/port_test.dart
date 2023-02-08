/// Copyright (C) 2022-2023 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// port_test.dart
/// Test where the python launches the dart, passing port over cli.
///
/// 2022 October 27
/// Author: Max Korbel <max.korbel@intel.com>
///

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:test/test.dart';

import 'port_stuff/port_launch.dart';

void main() async {
  const portStuffDir = './test/port_stuff/';
  String outDirPathOf(String outDirName) => '$portStuffDir/$outDirName/';

  tearDown(() async {
    await Simulator.reset();
    await Cosim.reset();
  });

  /// Returns stdout of process.
  Future<String> runPortTest({
    required String outDirName,
    bool fail = false,
    bool finish = false,
    bool enableLogging = false,
    bool failAsync = false,
    bool hang = false,
  }) async {
    final outDirPath = outDirPathOf(outDirName);
    final outDir = Directory(outDirPath);
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    final runEnv = {
      'OUT_DIR': outDirName,
      if (fail) 'DART_FAIL': '1',
      if (finish) 'EXTRA_ARGS': '-DDO_FINISH',
      if (failAsync) 'DART_FAIL_ASYNC': '1',
      if (hang) 'DART_HANG': '1',
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
        directory: outDirPath, enableLogging: enableLogging);

    final proc = await Process.start(
      './sim.sh',
      [],
      workingDirectory: portStuffDir,
      environment: runEnv,
    );

    final stdoutBuffer = StringBuffer();
    unawaited(proc.stdout.transform(utf8.decoder).forEach((msg) {
      stdoutBuffer.write(msg);
      // ignore: dead_code
      if (enableLogging) {
        print(msg);
      }
    }));

    final exitCode = await proc.exitCode;

    expect(exitCode, equals(0));

    return stdoutBuffer.toString();
  }

  test('port test normal', () async {
    final stdoutContents = await runPortTest(outDirName: 'tmp_normal');

    expect(stdoutContents, contains('PASS=1'));
  });

  test('port test dart fail', () async {
    const outDirName = 'tmp_dart_fail';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, fail: true);

    // if vvp is still sticking around, this test will time out

    // make sure exception occurred in dart
    final stderrLogContents =
        File('${outDirPathOf(outDirName)}/custom_test.stderr.log')
            .readAsStringSync();
    expect(stderrLogContents, contains('Failure intentionally injected'));

    // make sure error is communicated
    expect(stdoutContents, contains('ERROR:'));
  });

  test('port test with finish passes', () async {
    final stdoutContents =
        await runPortTest(outDirName: 'tmp_finish', finish: true);

    expect(stdoutContents, contains('detected a failure from cocotb'));
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
  });

  test('port test dart hang timeout', () async {
    const outDirName = 'tmp_dart_hang';

    final stdoutContents =
        await runPortTest(outDirName: outDirName, hang: true);

    // if vvp is still sticking around, this test will time out

    // make sure error is communicated
    expect(stdoutContents, contains('ERROR:'));
  });
}
