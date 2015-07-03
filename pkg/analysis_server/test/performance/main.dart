// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library server.performance;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'driver.dart';
import 'input_converter.dart';
import 'operation.dart';

/**
 * The amount of time to give the server to respond to a shutdown request
 * before forcibly terminating it.
 */
const Duration SHUTDOWN_TIMEOUT = const Duration(seconds: 25);

/**
 * Launch and interact with the analysis server.
 */
main(List<String> rawArgs) {
  Logger logger = new Logger('Performance Measurement Client');
  logger.onRecord.listen((LogRecord rec) {
    print(rec.message);
  });
  PerfArgs args = parseArgs(rawArgs);

  Driver driver = new Driver(logger);
  Stream<Operation> stream = openInput(args);
  StreamSubscription<Operation> subscription;
  subscription = stream.listen((Operation op) {
    Future future = driver.perform(op);
    if (future != null) {
      logger.log(Level.FINE, 'pausing operations for ${op.runtimeType}');
      subscription.pause(future.then((_) {
        logger.log(Level.FINE, 'resuming operations');
      }));
    }
  }, onDone: () {
    subscription.cancel();
    driver.stopServer(SHUTDOWN_TIMEOUT);
  }, onError: (e, s) {
    subscription.cancel();
    logger.log(Level.SEVERE, '$e\n$s');
    driver.stopServer(SHUTDOWN_TIMEOUT);
  });
  driver.runComplete.then((Results results) {
    results.printResults();
  }).whenComplete(() {
    return subscription.cancel();
  });
}

const HELP_CMDLINE_OPTION = 'help';
const INPUT_CMDLINE_OPTION = 'input';
const MAP_OPTION = 'map';
const TMP_SRC_DIR_OPTION = 'tmpSrcDir';
const VERBOSE_CMDLINE_OPTION = 'verbose';
const VERY_VERBOSE_CMDLINE_OPTION = 'vv';

/**
 * Open and return the input stream specifying how this client
 * should interact with the analysis server.
 */
Stream<Operation> openInput(PerfArgs args) {
  var logger = new Logger('openInput');
  Stream<List<int>> inputRaw;
  if (args.inputPath == 'stdin') {
    inputRaw = stdin;
  } else {
    inputRaw = new File(args.inputPath).openRead();
  }
  args.srcPathMap.forEach((oldPath, newPath) {
    logger.log(
        Level.INFO, 'mapping source path\n  from $oldPath\n  to   $newPath');
  });
  logger.log(Level.INFO, 'tmpSrcDir: ${args.tmpSrcDirPath}');
  return inputRaw
      .transform(SYSTEM_ENCODING.decoder)
      .transform(new LineSplitter())
      .transform(new InputConverter(args.tmpSrcDirPath, args.srcPathMap));
}

/**
 * Parse the command line arguments.
 */
PerfArgs parseArgs(List<String> rawArgs) {
  ArgParser parser = new ArgParser();

  parser.addOption(INPUT_CMDLINE_OPTION, abbr: 'i', help: '<filePath>\n'
      'The input file specifying how this client should interact with the server.\n'
      'If the input file name is "stdin", then the instructions are read from standard input.');
  parser.addOption(MAP_OPTION,
      abbr: 'm',
      allowMultiple: true,
      splitCommas: false,
      help: '<oldSrcPath>,<newSrcPath>\n'
      'This option defines a mapping from the original source directory <oldSrcPath>\n'
      'when the instrumentation or log file was generated\n'
      'to the target source directory <newSrcPath> used during performance testing.\n'
      'Multiple mappings can be specified.\n'
      'WARNING: The contents of the target directory will be modified');
  parser.addOption(TMP_SRC_DIR_OPTION, abbr: 't', help: '<dirPath>\n'
      'The temporary directory containing source used during performance measurement.\n'
      'WARNING: The contents of the target directory will be modified');
  parser.addFlag(VERBOSE_CMDLINE_OPTION,
      abbr: 'v', help: 'Verbose logging', negatable: false);
  parser.addFlag(VERY_VERBOSE_CMDLINE_OPTION,
      help: 'Extra verbose logging', negatable: false);
  parser.addFlag(HELP_CMDLINE_OPTION,
      abbr: 'h', help: 'Print this help information', negatable: false);

  ArgResults args;
  PerfArgs perfArgs = new PerfArgs();
  try {
    args = parser.parse(rawArgs);
  } on Exception catch (e) {
    print(e);
    printHelp(parser);
    exit(1);
  }

  bool showHelp = args[HELP_CMDLINE_OPTION] || args.rest.isNotEmpty;

  bool isMissing(key) => args[key] == null || args[key].isEmpty;

  perfArgs.inputPath = args[INPUT_CMDLINE_OPTION];
  if (isMissing(INPUT_CMDLINE_OPTION)) {
    print('missing $INPUT_CMDLINE_OPTION argument');
    showHelp = true;
  }

  perfArgs.srcPathMap = <String, String>{};
  for (String pair in args[MAP_OPTION]) {
    if (pair is String) {
      int index = pair.indexOf(',');
      if (index != -1 && pair.indexOf(',', index + 1) == -1) {
        String oldSrcPath = pair.substring(0, index);
        String newSrcPath = pair.substring(index + 1);
        if (new Directory(oldSrcPath).existsSync() &&
            new Directory(newSrcPath).existsSync()) {
          perfArgs.srcPathMap[oldSrcPath] = newSrcPath;
          continue;
        }
      }
    }
    print('must specifiy $MAP_OPTION <oldSrcPath>,<newSrcPath>');
    showHelp = true;
  }

  perfArgs.tmpSrcDirPath = args[TMP_SRC_DIR_OPTION];
  if (isMissing(TMP_SRC_DIR_OPTION)) {
    print('missing $TMP_SRC_DIR_OPTION argument');
    showHelp = true;
  }

  if (args[VERY_VERBOSE_CMDLINE_OPTION] || rawArgs.contains('-vv')) {
    Logger.root.level = Level.FINE;
  } else if (args[VERBOSE_CMDLINE_OPTION]) {
    Logger.root.level = Level.INFO;
  } else {
    Logger.root.level = Level.WARNING;
  }

  if (showHelp) {
    printHelp(parser);
    exit(1);
  }

  return perfArgs;
}

void printHelp(ArgParser parser) {
  print('');
  print('Launch and interact with the AnalysisServer');
  print('');
  print(parser.usage);
}

/**
 * The performance measurement arguments specified on the command line.
 */
class PerfArgs {

  /**
   * The file path of the instrumentation or log file 
   * used to drive performance measurement,
   * or 'stdin' if this information should be read from standard input.
   */
  String inputPath;

  /**
   * A mapping from the original source directory
   * when the instrumentation or log file was generated
   * to the target source directory used during performance testing.
   */
  Map<String, String> srcPathMap;

  /**
   * The temporary directory containing source used during performance measurement.
   */
  String tmpSrcDirPath;
}