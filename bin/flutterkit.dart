import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutterkit_cli/src/cli_exception.dart';
import 'package:flutterkit_cli/src/runner.dart';
import 'package:flutterkit_cli/src/safety.dart';

Future<void> main(List<String> args) async {
  final runner = FlutterkitRunner();
  try {
    final code = await runner.run(args);
    exit(code);
  } on CliException catch (e) {
    // Messages can quote server text; never let it reach the terminal raw.
    stderr.writeln(safeText(e.message, keepNewlines: true));
    exit(e.exitCode);
  } on UsageException catch (e) {
    // Bad flags / unknown command: print usage to stderr, exit 64.
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(64);
  } catch (e) {
    // Last-resort guard: never leak a Dart stack trace to the user.
    stderr.writeln(safeText('Something went wrong: $e', keepNewlines: true));
    exit(1);
  }
}
