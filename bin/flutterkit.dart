import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutterkit_cli/src/cli_exception.dart';
import 'package:flutterkit_cli/src/runner.dart';

Future<void> main(List<String> args) async {
  final runner = FlutterkitRunner();
  try {
    final code = await runner.run(args);
    exit(code);
  } on CliException catch (e) {
    stderr.writeln(e.message);
    exit(e.exitCode);
  } on UsageException catch (e) {
    // Bad flags / unknown command: print usage to stderr, exit 64.
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(64);
  } catch (e) {
    // Last-resort guard: never leak a Dart stack trace to the user.
    stderr.writeln('Something went wrong: $e');
    exit(1);
  }
}
