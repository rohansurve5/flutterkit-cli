import 'dart:io';

import 'package:args/command_runner.dart';

import '../api_client.dart';
import '../cli_exception.dart';
import '../config.dart';
import '../runner.dart';

class LoginCommand extends Command<int> {
  @override
  final String name = 'login';

  @override
  final String description = 'Validate and save your license key.';

  @override
  String get invocation => 'flutterkit login <license-key>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      throw CliException(
        'Missing license key.\nUsage: flutterkit login <license-key>',
        exitCode: 64,
      );
    }
    final key = rest.first.trim();

    final config = Config.load();
    final apiBase = resolveApiBase(
      globalResults?.option('api-base'),
      config,
    );

    final api = ApiClient(apiBase: apiBase, licenseKey: key);
    try {
      final ok = await api.validateKey();
      if (!ok) {
        stderr.writeln('Invalid license key.');
        return 1;
      }
    } finally {
      api.close();
    }

    config.licenseKey = key;
    // Remember a non-default base so later commands hit the same endpoint.
    if (apiBase != Config.defaultApiBase) {
      config.apiBase = apiBase;
    }
    config.save();

    stdout.writeln('Logged in.');
    return 0;
  }
}
