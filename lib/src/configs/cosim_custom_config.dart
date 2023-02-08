/// Copyright (C) 2022 Intel Corporation
/// SPDX-License-Identifier: BSD-3-Clause
///
/// cosim_custom_config.dart
/// Definition for custom configuration of cosimulation.
///
/// 2022 September 8
/// Author: Max Korbel <max.korbel@intel.com>
///

import 'dart:io';

import 'package:rohd_cosim/rohd_cosim.dart';

/// A cosimulation configuration which is intended for use when you already
/// have a custom build and/or simulation setup created and wish to cosimulate
/// using that rather than an auto-generated one.
class CosimCustomConfig extends CosimProcessConfig {
  /// A provided custom function for launching the cosimulation process.
  final Future<Process> Function(String directory) _startCosimProcess;

  /// A custom configuration for running cosimulation.
  ///
  /// Generated files will be placed in [directory], which is a *relative* path.
  ///
  /// [_startCosimProcess] should begin a simulation with all necessary
  /// configuration and setup for cosimulation.  It must print to `stdout` so
  /// that ROHD Cosim can find the proper port to connect to, communicated from
  /// the connector.
  CosimCustomConfig(
    this._startCosimProcess, {
    super.directory,
    super.enableLogging,
    super.throwOnUnexpectedEnd,
  }) {
    Cosim.generateConnector(directory: directory, enableLogging: enableLogging);
    _createReadme();
  }

  void _createReadme() {
    const readmeContents = '''
For ROHD Cosim to properly connect to a custom configuration of build, the connector must
be launched from the SystemVerilog simulator.

ROHD uses cocotb and its GPI libraries to connect to a variety of simulators.  Follow the
instructions at this link for your favorite simulator for build & sim options that need to be included:
https://docs.cocotb.org/en/stable/custom_flows.html

When your simulation launches, you should ensure the following environment variables are set:
```
MODULE = <python module path to cosim_test_module>
TOPLEVEL_LANG = verilog
TOPLEVEL = <name of top-level module in your built Verilog>
```

Include the following plusarg in your simulation command-line:
```
+define+COCOTB_SIM=1
```

The custom process *must* forward `stdout` from the simulation process, or at least a portion of it,
so that ROHD Cosim can find the proper port to connect to, communicated from the connector.
''';
    File('$directory/README.md').writeAsStringSync(readmeContents);
  }

  @override
  Future<Process> startCosimProcess(String directory) =>
      _startCosimProcess(directory);
}
