import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Optional CLI preferences read from `~/.flutterkit/config.json`.
///
/// FlutterKit is free and needs no credentials, so this file is entirely
/// optional — a fresh install works with no config at all. The only key it
/// understands is an alternate endpoint:
/// `{ "apiBase": "..." }`.
class Config {
  Config({this.apiBase});

  String? apiBase;

  /// Default API base used when nothing else is configured.
  static const String defaultApiBase = 'https://rohansurve.in';

  /// `~/.flutterkit` (honours `$HOME`, falls back to `$USERPROFILE` on Windows).
  static String get configDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return p.join(home, '.flutterkit');
  }

  static String get configPath => p.join(configDir, 'config.json');

  /// Loads config from disk. Returns an empty [Config] if the file is missing
  /// or unreadable/corrupt (so neither a bad file nor no file ever stops the
  /// CLI).
  static Config load() {
    final file = File(configPath);
    if (!file.existsSync()) return Config();
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return Config();
      return Config(apiBase: raw['apiBase'] as String?);
    } catch (_) {
      return Config();
    }
  }
}
