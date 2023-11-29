// Copyright (C) 2022-2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// cosim.dart
// Definitions for Cosim with ROHD
//
// 2022 January 9
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:rohd/rohd.dart';
// ignore: implementation_imports
import 'package:rohd/src/utilities/uniquifier.dart';
import 'package:rohd_cosim/rohd_cosim.dart';
import 'package:rohd_cosim/src/exceptions/unexpected_end_of_simulation.dart';
import 'package:synchronized/synchronized.dart';

enum _CosimMessageType { tickComplete, signalUpdate, end }

/// A message communicating information between ROHD and the cosimulation
/// process.
class _CosimMessage {
  /// The raw message received over the socket, unprocessed.
  final String rawMessage;

  /// The timestamp communicated by the cosimulation process.
  ///
  /// Note this is multiplied by `clk_ratio` in the connector relative
  /// to the time in ROHD simulation time.
  late final int time;

  /// The name of the signal being discussed.
  ///
  /// It may be `null` for messages not related to a specific signal.
  late final String? signalName;

  /// The value of the signal being discussed.
  ///
  /// It may be `null` for messages not related to a specific signal.
  late final LogicValue? signalValue;

  /// The type of message being communicated.
  late final _CosimMessageType cosimMessageType;

  _CosimMessage(this.rawMessage) {
    final splitMessage = rawMessage.split(':');

    time = int.parse(splitMessage[0].substring(1));

    final messageTypeString = splitMessage[1];
    if (messageTypeString == 'TICK_COMPLETE') {
      cosimMessageType = _CosimMessageType.tickComplete;
    } else if (messageTypeString == 'UPDATE') {
      cosimMessageType = _CosimMessageType.signalUpdate;
      final signalInfo = splitMessage[2].split('=');
      signalName = signalInfo[0];
      signalValue = LogicValue.ofString(signalInfo[1]);
    } else if (messageTypeString == 'END') {
      cosimMessageType = _CosimMessageType.end;
    }
  }

  /// An "END" message, indicating the end of the cosimulation.
  _CosimMessage.end() : this('@0:END');
}

/// When applied to a [ExternalSystemVerilogModule], will configure it so that
/// it can be cosimulated in a SystemVerilog simulator along with the ROHD
/// simulator.
mixin Cosim on ExternalSystemVerilogModule {
  /// A list of verilog source files to include in the build.
  ///
  /// The contents are put in a Makefile, so environment variables
  /// should use parentheses, like `$(MYENVVAR)`.
  List<String>? get verilogSources => null;

  /// A list of filelists (.f files) to pass to the compile stage.
  ///
  /// The contents are put in a Makefile, so environment variables
  /// should use parentheses, like `$(MYENVVAR)`.
  List<String>? get filelists => null;

  /// A list of additional arguments to pass to both compile phase
  /// of the SystemVerilog simulator.
  ///
  /// The contents are put in a Makefile, so environment variables
  /// should use parentheses, like `$(MYENVVAR)`.
  List<String>? get compileArgs => null;

  /// A list of additional arguments to pass to both compile and execute phase
  /// of the SystemVerilog simulation.
  ///
  /// The contents are put in a Makefile, so environment variables
  /// should use parentheses, like `$(MYENVVAR)`.
  List<String>? get extraArgs => null;

  /// The hierarchy from the SystemVerilog cosimulation top to reach this
  /// module.
  ///
  /// If no hierarchy is provided, it will assume it is located in a module
  /// directly below the top-level simulation hierachy with its (potentially
  /// uniquified) name. Override this `get`ter to set the hierarchy of the
  /// module to something else.
  String get cosimHierarchy => registreeName;

  /// Resets all context for cosimulation.
  ///
  /// Note that any [Cosim]s already built will need to be reregistered via
  /// [cosimRegister] (which is automatically called when [build] is called).
  static Future<void> reset() async {
    _registreeUniquifier = Uniquifier();
    _registrees.clear();
    try {
      await _socket
          ?.close()
          .then((_) => _socket?.destroy())
          .catchError(_socketErrorHandler);
    } on Exception {
      logger?.finest(
          'Failed to close and/or destroy socket during Cosim.reset()');
    }
    _enableLogger = false;
    _socket = null;
  }

  /// A generic handler for asynchronous errors triggered by socket
  /// interactions.
  static void _socketErrorHandler(Object error, StackTrace stackTrace) {
    logger?.info('Error occurred during socket operation: $error');
    logger?.finest('> Stack trace: \n$stackTrace');
  }

  /// A uniquifier that guarantees unique names of modules
  /// under a common top level wrapper.
  static Uniquifier _registreeUniquifier = Uniquifier();

  /// The unique instance name for this registree in cosimulation.
  ///
  /// Initialized during [build].
  String get registreeName => _registreeName;
  late String _registreeName;

  /// A collection of all registered [Cosim] modules.
  ///
  /// The keys are their [registreeName]s.
  static Map<String, Cosim> get registrees => UnmodifiableMapView(_registrees);
  static final Map<String, Cosim> _registrees = {};

  /// Registers the current [Cosim] module with the cosimulator
  /// for generation and cosimulation.  Only registered modules
  /// will be cosimulated.
  ///
  /// This is automatically called when [build] is called.
  void cosimRegister() {
    _registreeName = _registreeUniquifier.getUniqueName(initialName: name);
    _registrees[_registreeName] = this;
  }

  @override
  Future<void> build() async {
    cosimRegister();
    await super.build();
  }

  /// A logger for cosimulation-related activities.
  static final Logger _maskedLogger = Logger('cosim');

  /// An enablable logger (null if disabled) for Cosim related information.
  static Logger? get logger => _enableLogger ? _maskedLogger : null;

  /// A control switch to enable/disable log messages from cosimulation in the [Logger].
  static bool _enableLogger = false;

  /// Socket connection to the cosimulation process.
  ///
  /// This is set to null at the end of the simulation after disconnection.
  static Socket? _socket;

  /// A lock for preventing socket-related communication race conditions.
  static final Lock _socketLock = Lock();

  /// Starts the SystemVerilog simulation and connects it to the ROHD simulator.
  static Future<void> connectCosimulation(CosimConfig cosimConfig) async {
    _enableLogger = cosimConfig.enableLogging;

    final connection = await cosimConfig.connect();
    _socket = connection.socket;

    // catch errors if the socket shuts down
    // ignore: avoid_types_on_closure_parameters
    unawaited(_socket!.done.catchError((Object error) {
      logger?.info('Encountered error upon socket completion, '
          'shutting down cosim: $error');
      endCosim();
    }));

    _socket!.listen(
      (event) {
        _receive(utf8.decode(event));
      },
      onDone: () {
        logger?.info('Received "done" message over socket, shutting down...');
        endCosim();
      },
      cancelOnError: true,
      // ignore: avoid_types_on_closure_parameters
      onError: (Object err, StackTrace stackTrace) {
        logger?.info(
            'Encountered error while listening to socket, ending cosim: $err');
        logger?.info('> Stack trace: \n $stackTrace');
        endCosim();
      },
    );

    await _setupPortHandshakes(
      onEnd: connection.disconnect,
      throwOnUnexpectedEnd: cosimConfig.throwOnUnexpectedEnd,
    );

    Simulator.registerEndOfSimulationAction(() async {
      logger?.finer('Simulation ended... closing everything down.');

      try {
        await connection.disconnect();

        _send('END');

        await _socket!.flush().catchError(_socketErrorHandler);

        // leave some time for the END to get there
        await Future<void>.delayed(const Duration(seconds: 1));

        await _socket!.close().catchError(_socketErrorHandler);
        logger?.finer('Closed!');

        _socket!.destroy();
        _socket = null;

        logger?.finer('All done!');
      } on Exception {
        logger?.warning('Failed to gracefully close cosim connection.');
      }
    });
  }

  /// The name of a given input/output port for the cosimulation process.
  String _cosimSignalName(Logic port) {
    assert(port.parentModule! == this, 'Signal should be in this Cosim.');
    return '$registreeName.${port.name}';
  }

  /// Drives an input pin to the cosimulated SystemVerilog module.
  Future<void> _sendInput(Logic inputSignal, LogicValue newValue) async {
    assert(
        inputSignal.parentModule! == this, 'Signal should be in this Cosim.');

    if (inputSignal is LogicArray && inputSignal.numUnpackedDimensions > 0) {
      var idx = 0;
      for (final element in inputSignal.flattenedUnpacked) {
        await _socketLock.synchronized(() async {
          _send('DRIVE:'
              '${_cosimSignalName(inputSignal)}[$idx]:'
              '${newValue.getRange(
                    idx * element.width,
                    idx * element.width + element.width,
                  ).toString(includeWidth: false)}');
        });
        idx++;
      }
    } else {
      await _socketLock.synchronized(() async {
        _send('DRIVE:'
            '${_cosimSignalName(inputSignal)}:'
            '${newValue.toString(includeWidth: false)}');
      });
    }
  }

  /// Transmits all input values to cosim.
  ///
  /// Useful for setting up initial values.
  Future<void> _sendAllInputValues() async {
    for (final modInput in inputs.values) {
      if (modInput.width == 0) {
        continue;
      }
      await _sendInput(modInput, modInput.value);
    }
  }

  /// Keeps track of pre-tick input values per input.
  final Map<Logic, LogicValue> _inputToPreTickInputValuesMap = {};

  /// Keeps track of signals needing an update in post-tick.
  final Set<Logic> _inputsPendingPostUpdate = {};

  /// Keeps track of whether we need to do an update post-tick.
  bool _pendingPostUpdate = false;

  /// Sets up listeners on ports in both directions with cosimulation for
  /// all [_registrees].
  static Future<void> _setupPortHandshakes({
    required bool throwOnUnexpectedEnd,
    void Function()? onEnd,
  }) async {
    // first, start listening for things received!
    _receivedStream
        .where(
            (event) => event.cosimMessageType == _CosimMessageType.signalUpdate)
        .listen((event) {
      final signalNameSplit = event.signalName!.split('.');
      final registreeName = signalNameSplit[0];
      final portName = signalNameSplit[1];

      if (!_registrees.containsKey(registreeName)) {
        throw Exception('Did not find registered module named "$registreeName",'
            ' but received a message from the cosim process attempting to'
            ' drive this signal: "${event.signalName}"');
      }

      // handle case where there was an unpacked array (should end with ']')
      if (portName.endsWith(']')) {
        final splitPortName = portName.split(RegExp(r'[\[\]]'));
        final arrayName = splitPortName[0];
        final arrayIndex = int.parse(splitPortName[1]);
        (_registrees[registreeName]!.output(arrayName) as LogicArray)
            .flattenedUnpacked
            .toList()[arrayIndex]
            // ignore: unnecessary_null_checks
            .put(event.signalValue!);
      } else {
        // ignore: unnecessary_null_checks
        _registrees[registreeName]!.output(portName).put(event.signalValue!);
      }
    });

    _receivedStream
        .where((event) => event.cosimMessageType == _CosimMessageType.end)
        .listen((event) {
      logger?.info('Received an indication that the simulator has finished.');
      if (onEnd != null) {
        onEnd();
      }
      Simulator.endSimulation();
    });

    // set up initial values
    for (final registree in _registrees.values) {
      await registree._sendAllInputValues();
    }
    await _sendTick(throwOnUnexpectedEnd: throwOnUnexpectedEnd);

    for (final registree in _registrees.values) {
      // listen to every input of this module
      for (final modInput in registree.inputs.values) {
        if (modInput.width == 0) {
          // no need to listen to 0-bit signals, they won't be changing
          // (and won't exist in SV)
          continue;
        }

        modInput.glitch.listen((event) {
          // TODO(mkorbel1): test for clock divider bug, https://github.com/intel/rohd-cosim/issues/6

          if (Simulator.phase != SimulatorPhase.clkStable) {
            // if the change happens not when the clocks are stable,
            // immediately update the map
            registree._inputToPreTickInputValuesMap[modInput] = modInput.value;
          } else {
            // if this is during stable clocks, it's probably another flop
            // driving it, so hold onto it for later
            registree._inputsPendingPostUpdate.add(modInput);
            if (!registree._pendingPostUpdate) {
              Simulator.postTick.first.then((value) {
                // once the tick has completed, we can update the override maps
                for (final driverInput in registree._inputsPendingPostUpdate) {
                  registree._inputToPreTickInputValuesMap[driverInput] =
                      driverInput.value;
                }
                registree._inputsPendingPostUpdate.clear();
                registree._pendingPostUpdate = false;

                // send the updates right away, so they show up
                // at the current time!
                Simulator.injectAction(() async {
                  await _sendPendingUpdates(
                      throwOnUnexpectedEnd: throwOnUnexpectedEnd);
                });
              });
            }
            registree._pendingPostUpdate = true;
          }
        });
      }
    }

    // every time the Simulator time changes, tick the simulator forward
    var previousTime = Simulator.time;
    Simulator.preTick.listen((event) async {
      if (previousTime != Simulator.time) {
        await _sendTick(throwOnUnexpectedEnd: throwOnUnexpectedEnd);
        previousTime = Simulator.time;
      }
    });

    // every clkStable, drive everything pending into the cosimulator
    Simulator.clkStable.listen((event) {
      Simulator.injectAction(() async {
        await _sendPendingUpdates(throwOnUnexpectedEnd: throwOnUnexpectedEnd);
      });
    });
  }

  static Future<void> _sendPendingUpdates({
    required bool throwOnUnexpectedEnd,
  }) async {
    for (final registree in _registrees.values) {
      for (final updateEntry
          in registree._inputToPreTickInputValuesMap.entries) {
        final logic = updateEntry.key;
        final newValue = updateEntry.value;
        if (logic.width > 0) {
          await registree._sendInput(logic, newValue);
        }
      }
      registree._inputToPreTickInputValuesMap.clear();
    }

    // send a tick after driving so we get back updates
    await _sendTick(throwOnUnexpectedEnd: throwOnUnexpectedEnd);
  }

  /// Sends a "tick" to the SystemVerilog simulator to propagate
  /// signals to outputs.
  static Future<void> _sendTick({required bool throwOnUnexpectedEnd}) async {
    await _socketLock.synchronized(() async {
      _send('TICK:${Simulator.time}');
      // await _socket.flush(); // don't need to flush, just wait for reply
      final msg = await _receivedStream.firstWhere((element) =>
          element.cosimMessageType == _CosimMessageType.tickComplete ||
          element.cosimMessageType == _CosimMessageType.end);
      if (msg.cosimMessageType == _CosimMessageType.end) {
        logger?.fine('Tick interrupted by END.');

        if (throwOnUnexpectedEnd) {
          Simulator.throwException(
              UnexpectedEndOfSimulation('Unexpected end of cosimulation!'),
              StackTrace.current);
        }
      }
      logger?.finest('Received tick complete');
    });
  }

  /// Sends a message across to the cosimulation.
  static void _send(String message) {
    if (_socket == null) {
      return;
    }

    logger?.finest('Sending over socket: $message');

    try {
      _socket!.write('$message;');
    } on Exception catch (e) {
      logger?.warning('Failed to send cosim message over socket:'
          ' "$message" due to exception: "$e"');
    }
  }

  /// A stream of messages from cosimulation.
  static Stream<_CosimMessage> get _receivedStream =>
      _receivedStreamController.stream;

  /// The controller for [_receivedStream].
  static final StreamController<_CosimMessage> _receivedStreamController =
      StreamController.broadcast(sync: true);

  /// Passes an "END" message to [Cosim] as if it had been sent by the other
  /// simulator.  This is helpful in cases where the simulator dies unexpectedly
  /// without gracefully notifying [Cosim].
  static void endCosim() {
    _receivedStreamController.add(_CosimMessage.end());
  }

  /// Collects a message (or group of messages) from the cosimulation to be
  /// passed to [_receivedStream].
  static void _receive(String message) {
    logger?.finest('Received over socket: $message');
    for (final subMessage in message.split('\n')) {
      if (subMessage.isNotEmpty) {
        _receivedStreamController.add(_CosimMessage(subMessage));
      }
    }
  }

  /// The default name of the python module containing the connector.
  static const defaultPythonModuleName = 'cosim_test_module';

  /// Generates collateral for building and executing a cosimulation.
  ///
  /// Generated files will be dumped into [directory].
  ///
  /// If [enableLogging] is true, then the python connector will print
  /// debug messages.
  static void generateConnector(
      {String directory = './',
      String pythonModuleName = defaultPythonModuleName,
      bool enableLogging = false}) {
    Directory(directory).createSync(recursive: true);

    _createPythonFile(directory, pythonModuleName, _registrees, enableLogging);
  }

  static String _pythonHeader() {
    final packageConfigJson =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map;
    const pkgName = 'rohd_cosim';
    final pkgInfo = (packageConfigJson['packages'] as List).firstWhere(
        (element) => (element as Map<String, dynamic>)['name'] == pkgName);
    final pkgPath = (pkgInfo as Map<String, dynamic>)['rootUri'] as String;
    final uriIsRelative = pkgPath.startsWith('../');
    final uri = Uri(path: uriIsRelative ? pkgPath.substring(1) : pkgPath);
    final pythonPath =
        '${File(uri.toFilePath().replaceAll('file://', '')).absolute.path}/python/';

    return '''
# Generated by ROHD Cosim - www.github.com/intel/rohd-cosim
# Generation time: ${DateTime.now()}

import cocotb
import sys

sys.path.append('$pythonPath')
import rohd_connector

''';
  }

  /// Generates the python connector module file on the receiving end
  /// for cosimulation.
  static void _createPythonFile(String directory, String pythonModuleName,
      Map<String, Cosim> registrees, bool enableLogging) {
    final pythonFileContents = StringBuffer()
      ..write(_pythonHeader())
      ..write('''
@cocotb.test()
async def cosim_test(dut):
    connector = rohd_connector.RohdConnector(enable_logging = ${enableLogging ? 'True' : 'False'})
    connector.connect_to_socket()
    await setup_connections(dut, connector)
    
async def setup_connections(dut, connector : rohd_connector.RohdConnector):
''')
      ..write('    nameToSignalMap = {}\n');

    for (final registree in registrees.values) {
      pythonFileContents.write('    # ${registree.registreeName}\n');

      var cocoTbHier = 'dut';
      if (registree.cosimHierarchy.isNotEmpty) {
        cocoTbHier += '.${registree.cosimHierarchy}';
      }

      for (final outputEntry in registree.outputs.entries) {
        final outputName = outputEntry.key;
        final outputLogic = outputEntry.value;
        if (outputLogic.width == 0) {
          // no need to listen to 0-bit signals, they probably don't even exist
          continue;
        }
        if (outputLogic is LogicArray &&
            outputLogic.numUnpackedDimensions > 0) {
          for (var i = 0; i < outputLogic.flattenedUnpackedCount; i++) {
            pythonFileContents.write('    cocotb.start_soon( '
                'connector.listen_to_signal('
                "'${registree._cosimSignalName(outputLogic)}[$i]',"
                ' $cocoTbHier.$outputName[$i] '
                '))\n');
          }
        } else {
          pythonFileContents.write('    cocotb.start_soon( '
              'connector.listen_to_signal('
              "'${registree._cosimSignalName(outputLogic)}',"
              ' $cocoTbHier.$outputName '
              '))\n');
        }
      }
      for (final inputEntry in registree.inputs.entries) {
        final inputName = inputEntry.key;
        final inputLogic = inputEntry.value;
        if (inputLogic.width == 0) {
          // no need to drive 0-bit signals, they probably don't even exist
          continue;
        }

        if (inputLogic is LogicArray && inputLogic.numUnpackedDimensions > 0) {
          for (var i = 0; i < inputLogic.flattenedUnpackedCount; i++) {
            pythonFileContents.write('    nameToSignalMap[ '
                "'${registree._cosimSignalName(inputLogic)}[$i]' ] "
                '= $cocoTbHier.$inputName[$i]\n');
          }
        } else {
          pythonFileContents.write('    nameToSignalMap[ '
              "'${registree._cosimSignalName(inputLogic)}' ] "
              '= $cocoTbHier.$inputName\n');
        }
      }
    }
    pythonFileContents
        .write('    await connector.listen_for_stimulus(nameToSignalMap)\n');
    File('$directory/$pythonModuleName.py')
        .writeAsStringSync(pythonFileContents.toString());

    File('$directory/__init__.py').writeAsStringSync('');
  }
}

extension on LogicArray {
  /// Returns all unpacked dimensions as a flattened iterable.
  Iterable<Logic> get flattenedUnpacked {
    Iterable<Logic> flattenedElements = elements;
    for (var i = 0; i < numUnpackedDimensions - 1; i++) {
      flattenedElements = flattenedElements.map((e) => e.elements).flattened;
    }
    return flattenedElements;
  }

  /// Returns the number of elements in [flattenedUnpacked].
  int get flattenedUnpackedCount => numUnpackedDimensions == 0
      ? 0
      : dimensions.getRange(0, numUnpackedDimensions).fold(1, (a, b) => a * b);
}
