import 'dart:io';

import 'package:args/command_runner.dart';

import '../config.dart';

class LogoutCommand extends Command<int> {
  @override
  final String name = 'logout';

  @override
  final String description = 'Clear your saved license key.';

  @override
  String get invocation => 'flutterkit logout';

  @override
  Future<int> run() async {
    final config = Config.load();
    if (config.licenseKey == null) {
      stdout.writeln('Not logged in.');
      return 0;
    }
    config.licenseKey = null;
    config.save();
    stdout.writeln('Logged out.');
    return 0;
  }
}
