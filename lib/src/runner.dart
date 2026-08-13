import 'dart:io';

import 'package:args/command_runner.dart';

import 'commands/add_command.dart';
import 'commands/list_command.dart';
import 'config.dart';

const String version = '0.2.0';

/// Resolves the API base in priority order:
/// `--api-base` flag > `FLUTTERKIT_API_BASE` env > config `apiBase` > default.
String resolveApiBase(String? flagValue, Config config) {
  final fromFlag = (flagValue != null && flagValue.isNotEmpty) ? flagValue : null;
  final fromEnv = Platform.environment['FLUTTERKIT_API_BASE'];
  return fromFlag ??
      (fromEnv != null && fromEnv.isNotEmpty ? fromEnv : null) ??
      config.apiBase ??
      Config.defaultApiBase;
}

class FlutterkitRunner extends CommandRunner<int> {
  FlutterkitRunner()
      : super(
          'flutterkit',
          'Add free FlutterKit screens to your Flutter project.',
        ) {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the flutterkit version.',
      )
      ..addOption(
        'api-base',
        help: 'Override the API base URL '
            '(else \$FLUTTERKIT_API_BASE, config, or the default).',
        valueHelp: 'url',
      );

    addCommand(ListCommand());
    addCommand(AddCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    final results = parse(args);
    if (results.flag('version')) {
      stdout.writeln('flutterkit $version');
      return 0;
    }
    return await runCommand(results) ?? 0;
  }
}
