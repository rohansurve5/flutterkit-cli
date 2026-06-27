import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../api_client.dart';
import '../cli_exception.dart';
import '../config.dart';
import '../runner.dart';

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
  final String description = 'Add a Pro screen to this project by slug.';

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
    final slug = rest.first.trim();

    final config = Config.load();
    if (config.licenseKey == null) {
      stderr.writeln('Not logged in. Run: flutterkit login <key>');
      return 1;
    }

    if (!File('pubspec.yaml').existsSync() && !force) {
      stderr.writeln(
        "This doesn't look like a Flutter project (no pubspec.yaml here).\n"
        'Run from your project root, or pass --force to proceed anyway.',
      );
      return 1;
    }

    final apiBase = resolveApiBase(globalResults?.option('api-base'), config);
    final api = ApiClient(apiBase: apiBase, licenseKey: config.licenseKey);

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

    var written = 0;
    for (final file in screen.files) {
      final relTarget = _normalizeTarget(file.target);
      final outPath = p.join('lib', relTarget);
      final outFile = File(outPath);

      if (outFile.existsSync() && !force) {
        if (!_confirmOverwrite(outPath)) {
          stdout.writeln('Skipped $outPath');
          continue;
        }
      }

      outFile.parent.createSync(recursive: true);
      if (file.encoding == 'base64') {
        outFile.writeAsBytesSync(base64.decode(file.content));
      } else {
        outFile.writeAsStringSync(file.content);
      }
      stdout.writeln('Wrote $outPath');
      written++;
    }

    stdout.writeln('Added ${screen.name} — $written '
        '${written == 1 ? 'file' : 'files'}');
    return 0;
  }

  /// Keeps targets inside `lib/`: strips a leading `lib/` and any leading
  /// slashes so a target can't escape the project tree.
  String _normalizeTarget(String target) {
    var t = target.replaceAll('\\', '/').trim();
    while (t.startsWith('/')) {
      t = t.substring(1);
    }
    if (t.startsWith('lib/')) t = t.substring(4);
    return p.normalize(t);
  }

  bool _confirmOverwrite(String path) {
    stdout.write('$path exists. Overwrite? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }
}
