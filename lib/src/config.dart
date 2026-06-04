import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads and writes the buyer's config at `~/.flutterkit/config.json`.
///
/// The file holds only the user's own credentials — there are no shared
/// secrets baked into the CLI:
/// `{ "licenseKey": "...", "apiBase": "..." }`.
class Config {
  Config({this.licenseKey, this.apiBase});

  String? licenseKey;
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
  /// or unreadable/corrupt (so a bad file never crashes the CLI).
  static Config load() {
    final file = File(configPath);
    if (!file.existsSync()) return Config();
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return Config();
      return Config(
        licenseKey: raw['licenseKey'] as String?,
        apiBase: raw['apiBase'] as String?,
      );
    } catch (_) {
      return Config();
    }
  }

  /// Persists config, creating `~/.flutterkit` if needed and restricting the
  /// file to the current user (best effort; ignored where chmod is unavailable).
  void save() {
    final dir = Directory(configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final data = <String, String>{};
    if (licenseKey != null) data['licenseKey'] = licenseKey!;
    if (apiBase != null) data['apiBase'] = apiBase!;

    final file = File(configPath);
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
    _restrictPermissions(file);
  }

  void _restrictPermissions(File file) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', ['600', file.path]);
    } catch (_) {
      // Not fatal — the file is still written, just with default permissions.
    }
  }
}
