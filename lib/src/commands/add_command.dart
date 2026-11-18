import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../api_client.dart';
import '../cli_exception.dart';
import '../config.dart';
import '../runner.dart';
import '../safety.dart';

class AddCommand extends Command<int> {
  AddCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files and skip the Flutter-project check.',
    );
  }

  @override
  final String name = 'add';

  @override
  final String description = 'Add a screen to this project by slug.';

  @override
  String get invocation => 'flutterkit add <slug>';

  @override
  Future<int> run() async {
    final force = argResults!.flag('force');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw CliException(
        'Missing screen slug.\nUsage: flutterkit add <slug>',
        exitCode: 64,
      );
    }
    final slug = validateSlug(rest.first.trim());

    final config = Config.load();

    if (!File('pubspec.yaml').existsSync() && !force) {
      stderr.writeln(
        "This doesn't look like a Flutter project (no pubspec.yaml here).\n"
        'Run from your project root, or pass --force to proceed anyway.',
      );
      return 1;
    }

    final apiBase = resolveApiBase(globalResults?.option('api-base'), config);
    final api = ApiClient(apiBase: apiBase);

    final ScreenCode screen;
    try {
      screen = await api.getScreenCode(slug);
    } finally {
      api.close();
    }

    if (screen.files.isEmpty) {
      stdout.writeln('${screen.name} has no files to add.');
      return 0;
    }

    // Validate EVERY file before writing ANY: one unsafe target or bad
    // payload refuses the whole screen and nothing is written.
    final List<PlannedWrite> plan;
    try {
      plan = planWrites(screen.files, 'lib');
    } on CliException catch (e) {
      throw CliException('${e.message}\nNothing was written.',
          exitCode: e.exitCode);
    }

    var written = 0;
    for (final w in plan) {
      final shown = p.relative(w.path);
      final outFile = File(w.path);

      if (outFile.existsSync() && !force) {
        if (!_confirmOverwrite(shown)) {
          stdout.writeln('Skipped $shown');
          continue;
        }
      }

      // Re-check right before writing (the prompt above may have taken time).
      ensureNoSymlinkEscape(w.path, 'lib');
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(w.bytes);
      stdout.writeln('Wrote $shown');
      written++;
    }

    stdout.writeln('Added ${screen.name} — $written '
        '${written == 1 ? 'file' : 'files'}');
    return 0;
  }

  bool _confirmOverwrite(String path) {
    stdout.write('$path exists. Overwrite? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }
}

/// One validated file write: absolute [path] inside `lib/` and its [bytes].
class PlannedWrite {
  PlannedWrite(this.path, this.bytes);

  final String path;
  final List<int> bytes;
}

/// Validates every [files] entry (target inside [libDir], no symlink escape,
/// known encoding, decodable content) and returns the writes to perform.
/// Throws a [CliException] on the first problem — callers write nothing then.
List<PlannedWrite> planWrites(List<ScreenFile> files, String libDir) {
  final plan = <PlannedWrite>[];
  final seen = <String>{};
  for (final file in files) {
    final out = resolveTarget(file.target, libDir);
    ensureNoSymlinkEscape(out, libDir);
    if (!seen.add(out)) {
      throw CliException(
          "Refusing screen: target '${file.target}' appears twice.");
    }
    final List<int> bytes;
    switch (file.encoding) {
      case 'utf8':
        bytes = utf8.encode(file.content);
      case 'base64':
        try {
          bytes = base64.decode(file.content);
        } on FormatException {
          throw CliException(
              "Refusing screen: '${file.target}' has invalid base64 content.");
        }
      default:
        throw CliException(
          "Refusing screen: '${file.target}' has unknown encoding '${file.encoding}'.",
        );
    }
    plan.add(PlannedWrite(out, bytes));
  }
  return plan;
}
