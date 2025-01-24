// Copyright (C) 2022-2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim_wrap_config.dart
// Definition for an automatic wrapped configuration of cosimulation.
//
// 2022 September 8
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:io';

import 'package:rohd_cosim/rohd_cosim.dart';

/// A selection of a type of SystemVerilog Simulator.
enum SystemVerilogSimulator {
  /// Icarus Verilog
  icarus,

  /// Synopsys VCS
  vcs,

  /// Verilator
  ///
  /// Known limitations to be aware of:
  /// - Verilator does not support invalid (`x`, `z`) values in the simulation.
  /// - Support for unpacked array ports is limited.
  verilator,
}

abstract class _SystemVerilogSimulatorWaveDumpConfiguration {
  static String vcsFsdbDump(
          {required String top, String fsdbName = 'novas.fsdb'}) =>
      '''
  initial begin
    \$display("Generating fsdb...");
    \$fsdbDumpvars(0, $top, "+all");
    \$fsdbDumpfile("$fsdbName");
  end
''';

  static String vcdDump({required String top, String vcdName = 'waves.vcd'}) =>
      '''
initial
 begin
    \$dumpfile("$vcdName");
    \$dumpvars(0,$top);
 end
''';
}

/// A cosimulation configuration for supplying the minimum information to
/// get a cosimulation running.
///
/// This is a good option if you do not already have a preferred build and/or
/// simulation environment for the RTL being cosimulated.
class CosimWrapConfig extends CosimProcessConfig {
  /// The simulator to use for cosimulation.
  final SystemVerilogSimulator systemVerilogSimulator;

  /// When set to true, will configure the SystemVerilog simulator to dump waves
  /// during simulation.
  final bool dumpWaves;

  /// A set of environment variables to be made visible to the process running
  /// the SystemVerilog simulator.
  final Map<String, String>? environment;

  /// Generates a SystemVerilog wrapper and a Makefile to be called by default.
  ///
  /// Generated files will be dumped into [directory].  Note that if your
  /// references in [Cosim]s to file paths are relative, they will need to
  /// account for the fact that they will be run from [directory].
  ///
  /// To dump waves from the SystemVerilog simulator, set [dumpWaves] to `true`.
  ///
  /// To pass environment variables to the process running the SystemVerilog
  /// simulator, place them in [environment].
  CosimWrapConfig(
    this.systemVerilogSimulator, {
    super.directory,
    super.enableLogging,
    this.dumpWaves = false,
    this.environment,
    super.throwOnUnexpectedEnd,
  }) {
    Cosim.generateConnector(directory: directory, enableLogging: enableLogging);

    String? dumpWavesString;
    if (dumpWaves) {
      if (systemVerilogSimulator == SystemVerilogSimulator.vcs) {
        dumpWavesString =
            _SystemVerilogSimulatorWaveDumpConfiguration.vcsFsdbDump(
                top: _wrapperName);
      } else if (systemVerilogSimulator == SystemVerilogSimulator.icarus ||
          systemVerilogSimulator == SystemVerilogSimulator.verilator) {
        dumpWavesString = _SystemVerilogSimulatorWaveDumpConfiguration.vcdDump(
            top: _wrapperName);
      } else {
        throw Exception('Not sure how to dump waves for simulator'
            ' "${systemVerilogSimulator.name}".');
      }
    }

    //TODO: cleanup run directory before running?

    _createSVWrapper(
      directory,
      Cosim.registrees,
      dumpWavesString: dumpWavesString,
    );
    _createMakefile(
      directory: directory,
      simulator: systemVerilogSimulator,
      registrees: Cosim.registrees,
      dumpWaves: dumpWaves,
    );
  }

  //TODO: look for VTop floating around in htop, left over processes

  @override
  Future<Process> startCosimProcess(String directory) => Process.start(
        'make',
        [
          '-C',
          directory,
          '-f',
          _cosimMakefileName,
        ],
        environment: environment,
      );

  /// The name to use for the SystemVerilog wrapper.
  static const _wrapperName = 'cosim_wrapper';

  /// Generates a SystemVerilog wrapper for all [registrees] to cosimulate
  /// in the same process.
  ///
  /// The [systemVerilogSimulator] will be used in the generated Makefile for
  /// building and simulation.
  static void _createSVWrapper(String directory, Map<String, Cosim> registrees,
      {String? dumpWavesString}) {
    final wrapperVerilog = [
      'module $_wrapperName();',
      ...registrees.entries
          .map((registreeEntry) => registreeEntry.value.instantiationVerilog(
                'dont_care',
                registreeEntry.key,
                {
                  ...registreeEntry.value.inputs,
                  ...registreeEntry.value.outputs,
                }.map((key, value) => MapEntry(key, '')),
              )),
      if (dumpWavesString != null) dumpWavesString,
      'endmodule'
    ].join('\n');
    File('$directory/$_wrapperName.sv').writeAsStringSync(wrapperVerilog);
  }

  /// The name of the Makefile that gets generated.
  static const _cosimMakefileName = 'Makefile.cosim';

  /// Generates a Makefile that can build and simulate the design
  /// for cosimulation.
  static void _createMakefile({
    required SystemVerilogSimulator simulator,
    required String directory,
    required Map<String, Cosim> registrees,
    required bool dumpWaves,
  }) {
    final verilogSources = Set.of(
        registrees.values.map((e) => e.verilogSources ?? []).expand((e) => e));
    final filelists = Set.of(
        registrees.values.map((e) => e.filelists ?? []).expand((e) => e));
    final extraArgs = Set.of(
        registrees.values.map((e) => e.extraArgs ?? []).expand((e) => e));
    final compileArgs = Set.of(
        registrees.values.map((e) => e.compileArgs ?? []).expand((e) => e));
    final makefileContents = [
      'SIM ?= ${simulator.name}',
      if (simulator == SystemVerilogSimulator.vcs)
        'CMD = vcs', // unsure why this is needed
      'TOPLEVEL_LANG ?= verilog',
      'VERILOG_SOURCES += \$(PWD)/$_wrapperName.sv',
      ...verilogSources.map((e) => 'VERILOG_SOURCES += $e\n'),
      ...filelists.map((e) => 'COMPILE_ARGS += -f $e\n'),
      ...extraArgs.map((e) => 'EXTRA_ARGS += $e\n'),
      ...compileArgs.map((e) => 'COMPILE_ARGS += $e\n'),
      if (dumpWaves && simulator == SystemVerilogSimulator.verilator)
        'EXTRA_ARGS += --trace',
      'TOPLEVEL = $_wrapperName',
      'MODULE = ${Cosim.defaultPythonModuleName}',
      r'include $(shell cocotb-config --makefiles)/Makefile.sim'
    ].join('\n');
    File('$directory/$_cosimMakefileName').writeAsStringSync(makefileContents);
  }
}
