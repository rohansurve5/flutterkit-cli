import 'dart:io';

import 'package:args/command_runner.dart';

import '../api_client.dart';
import '../config.dart';
import '../runner.dart';

class ListCommand extends Command<int> {
  @override
  final String name = 'list';

  @override
  final String description = 'List the screens available to your license.';

  @override
  String get invocation => 'flutterkit list';

  @override
  Future<int> run() async {
    final config = Config.load();
    final apiBase = resolveApiBase(globalResults?.option('api-base'), config);

    if (config.licenseKey == null) {
      stderr.writeln('Not logged in. Run: flutterkit login <key>');
      return 1;
    }

    final api = ApiClient(apiBase: apiBase, licenseKey: config.licenseKey);
    final List<ScreenSummary> screens;
    try {
      screens = await api.listScreens();
    } finally {
      api.close();
    }

    if (screens.isEmpty) {
      stdout.writeln('No screens available.');
      return 0;
    }

    _printTable(screens);
    return 0;
  }

  void _printTable(List<ScreenSummary> screens) {
    const slugHeader = 'SLUG';
    const nameHeader = 'NAME';
    const categoryHeader = 'CATEGORY';

    final slugWidth = [slugHeader.length, ...screens.map((s) => s.slug.length)]
        .reduce((a, b) => a > b ? a : b);
    final nameWidth = [nameHeader.length, ...screens.map((s) => s.name.length)]
        .reduce((a, b) => a > b ? a : b);

    stdout.writeln(
      '${slugHeader.padRight(slugWidth)}  ${nameHeader.padRight(nameWidth)}  $categoryHeader',
    );
    for (final s in screens) {
      stdout.writeln(
        '${s.slug.padRight(slugWidth)}  ${s.name.padRight(nameWidth)}  ${s.category}',
      );
    }
  }
}
