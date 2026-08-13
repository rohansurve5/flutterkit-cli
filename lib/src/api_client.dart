import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cli_exception.dart';

/// A single file returned by the endpoint for a screen.
class ScreenFile {
  ScreenFile({
    required this.target,
    required this.content,
    this.encoding = 'utf8',
  });

  /// Path relative to the project's `lib/` directory.
  final String target;
  final String content;

  /// How [content] is encoded: `'utf8'` (plain text, the default) or
  /// `'base64'` (binary, e.g. images/fonts). Defaults to `'utf8'` so older
  /// responses without an `encoding` field keep working.
  final String encoding;

  factory ScreenFile.fromJson(Map<String, dynamic> json) => ScreenFile(
        target: (json['target'] ?? '') as String,
        content: (json['content'] ?? '') as String,
        encoding: (json['encoding'] ?? 'utf8') as String,
      );
}

/// One screen as listed by `GET /api/pro/screens`.
class ScreenSummary {
  ScreenSummary({required this.slug, required this.name, required this.category});

  final String slug;
  final String name;
  final String category;

  factory ScreenSummary.fromJson(Map<String, dynamic> json) => ScreenSummary(
        slug: (json['slug'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        category: (json['category'] ?? '') as String,
      );
}

/// A screen plus its files, from `GET /api/pro/screens/<slug>/code`.
class ScreenCode {
  ScreenCode({required this.slug, required this.name, required this.files});

  final String slug;
  final String name;
  final List<ScreenFile> files;

  factory ScreenCode.fromJson(Map<String, dynamic> json) => ScreenCode(
        slug: (json['slug'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        files: ((json['files'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ScreenFile.fromJson)
            .toList(),
      );
}

/// Thin wrapper over the public FlutterKit screens endpoints.
///
/// FlutterKit is free: these are anonymous GETs. The client sends no
/// credentials — no key, no token, no account.
class ApiClient {
  ApiClient({required this.apiBase, http.Client? client})
      : _client = client ?? http.Client();

  final String apiBase;
  final http.Client _client;

  Map<String, String> get _headers => {'Accept': 'application/json'};

  Uri _uri(String path) => Uri.parse('${_trimBase(apiBase)}$path');

  static String _trimBase(String base) =>
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;

  Future<List<ScreenSummary>> listScreens() async {
    final res = await _get('/api/pro/screens');
    if (res.statusCode != 200) throw _serverError(res.statusCode);

    final body = _decode(res.body);
    final list = body is List ? body : (body is Map ? body['screens'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ScreenSummary.fromJson)
        .toList();
  }

  Future<ScreenCode> getScreenCode(String slug) async {
    final res = await _get('/api/pro/screens/$slug/code');
    switch (res.statusCode) {
      case 200:
        final body = _decode(res.body);
        if (body is! Map) throw _serverError(res.statusCode);
        return ScreenCode.fromJson(body.cast<String, dynamic>());
      case 404:
        throw CliException(
          "Screen '$slug' not found. Run `flutterkit list` to see available screens.",
        );
      default:
        throw _serverError(res.statusCode);
    }
  }

  Future<http.Response> _get(String path) async {
    try {
      return await _client.get(_uri(path), headers: _headers);
    } on SocketException {
      throw CliException('Couldn\'t reach the server, try again.');
    } on http.ClientException {
      throw CliException('Couldn\'t reach the server, try again.');
    } on HttpException {
      throw CliException('Couldn\'t reach the server, try again.');
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  CliException _serverError(int status) {
    if (status == 429) {
      return CliException('Too many requests — please try again later.');
    }
    if (status >= 500) {
      return CliException('Couldn\'t reach the server, try again.');
    }
    return CliException('Unexpected response from server (HTTP $status).');
  }

  void close() => _client.close();
}
