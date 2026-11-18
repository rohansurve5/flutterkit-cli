import 'dart:io';

import 'package:args/command_runner.dart';

import 'commands/add_command.dart';
import 'commands/list_command.dart';
import 'config.dart';
import 'safety.dart';

const String version = '0.3.1';

/// Resolves the API base in priority order:
/// `--api-base` flag > `FLUTTERKIT_API_BASE` env > config `apiBase` > default,
/// then validates it with [validateApiBase] (only https://rohansurve.in, or
/// http://localhost / http://127.0.0.1 for development). A disallowed value
/// throws a [CliException] — it never silently falls back to another source.
String resolveApiBase(
  String? flagValue,
  Config config, {
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final fromEnv = env['FLUTTERKIT_API_BASE'];
  if (flagValue != null && flagValue.isNotEmpty) {
    return validateApiBase(flagValue, source: '--api-base');
  }
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return validateApiBase(fromEnv, source: 'FLUTTERKIT_API_BASE');
  }
  final fromConfig = config.apiBase;
  if (fromConfig != null && fromConfig.isNotEmpty) {
    return validateApiBase(fromConfig, source: Config.configPath);
  }
  return validateApiBase(Config.defaultApiBase, source: 'default');
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
