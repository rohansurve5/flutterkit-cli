import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli_exception.dart';

/// Guards that keep the CLI talking only to FlutterKit and writing only inside
/// the project's `lib/` directory. Everything the server sends is treated as
/// untrusted input.

/// The only production API base the CLI will talk to.
const String productionApiBase = 'https://rohansurve.in';

/// Hosts allowed over plain `http://` (any port) for local development.
const Set<String> devHosts = {'localhost', '127.0.0.1'};

/// Same rule as the website's code route: lowercase words joined by `-`/`_`.
final RegExp slugPattern =
    RegExp(r'^[a-z0-9][a-z0-9_-]{0,99}$', caseSensitive: false);

/// Validates an API base and returns it without a trailing slash.
///
/// Allowed: exactly `https://rohansurve.in` (optional trailing `/`), or
/// `http://localhost[:port]` / `http://127.0.0.1[:port]` for development.
/// Everything else (other hosts, look-alike hosts, user-info tricks, paths,
/// queries, other schemes, plain http to production) throws a [CliException].
/// [source] names where the value came from, for the error message.
String validateApiBase(String raw, {String source = 'config'}) {
  CliException refuse(String why) => CliException(
        "Refusing API base '$raw' (from $source): $why.\n"
        'Only $productionApiBase is allowed '
        '(or http://localhost / http://127.0.0.1 for development).',
        exitCode: 64,
      );

  if (raw.isEmpty) throw refuse('empty value');
  if (raw.contains(RegExp(r'[\s\\\x00-\x1f\x7f]'))) {
    throw refuse('contains whitespace, a backslash or a control character');
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw refuse('not an absolute URL');
  }
  if (uri.userInfo.isNotEmpty) throw refuse('user-info (`@`) is not allowed');
  if (uri.hasQuery || uri.hasFragment) {
    throw refuse('query strings and fragments are not allowed');
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    throw refuse('a path is not allowed');
  }

  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'https' && host == 'rohansurve.in') {
    if (uri.hasPort && uri.port != 443) {
      throw refuse('a custom port is not allowed');
    }
    return productionApiBase;
  }
  if (scheme == 'http' && devHosts.contains(host)) {
    return uri.hasPort ? 'http://$host:${uri.port}' : 'http://$host';
  }
  if (scheme == 'http' && host == 'rohansurve.in') {
    throw refuse('plain http is not allowed — use https');
  }
  throw refuse('host or scheme is not allowed');
}

/// Throws unless [slug] matches [slugPattern] (so it can't alter the URL path).
String validateSlug(String slug) {
  if (!slugPattern.hasMatch(slug)) {
    throw CliException(
      "Invalid screen slug '$slug'. Slugs use letters, digits, '-' and '_' "
      '(e.g. wallet-splash).',
      exitCode: 64,
    );
  }
  return slug;
}

/// Validates a server-supplied install [target] and returns the absolute path
/// it maps to inside [libDir].
///
/// Accepted: a relative path, optionally starting with `lib/`. Rejected: empty,
/// absolute (`/x`, `~/x`, `C:\x`), backslashes, control characters, any `..`
/// segment, or anything that normalizes to [libDir] itself or outside it.
String resolveTarget(String target, String libDir) {
  CliException refuse(String why) =>
      CliException("Refusing unsafe file target '$target': $why.");

  if (target.isEmpty) throw refuse('empty path');
  if (target.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    throw refuse('contains a control character');
  }
  if (target.contains('\\')) throw refuse('backslashes are not allowed');
  if (target.startsWith('/') ||
      target.startsWith('~') ||
      RegExp(r'^[A-Za-z]:').hasMatch(target) ||
      p.posix.isAbsolute(target) ||
      p.windows.isAbsolute(target)) {
    throw refuse('absolute paths are not allowed');
  }
  final segments = target.split('/');
  if (segments.contains('..')) throw refuse('".." is not allowed');

  var rel = target;
  if (rel.startsWith('lib/')) rel = rel.substring(4);
  rel = p.posix.normalize(rel);
  if (rel.isEmpty || rel == '.' || rel == 'lib') {
    throw refuse('does not name a file inside lib/');
  }

  final libAbs = p.normalize(p.absolute(libDir));
  final out = p.normalize(p.join(libAbs, rel));
  if (!p.isWithin(libAbs, out)) {
    throw refuse('resolves outside lib/');
  }
  return out;
}

/// Throws if writing [outPath] would follow a symlink out of [libDir]: the
/// nearest existing ancestor of [outPath] (and [outPath] itself, if it is a
/// link) must resolve to a location inside the real `lib/`.
void ensureNoSymlinkEscape(String outPath, String libDir) {
  final libAbs = p.normalize(p.absolute(libDir));
  // lib/ will be created fresh, so there are no links to follow.
  if (!Directory(libAbs).existsSync()) return;
  final libReal = Directory(libAbs).resolveSymbolicLinksSync();

  bool inside(String real) => real == libReal || p.isWithin(libReal, real);
  CliException refuse() => CliException(
        "Refusing to write '${p.relative(outPath)}': a symlink points outside lib/.",
      );

  if (FileSystemEntity.isLinkSync(outPath)) {
    final String real;
    try {
      real = File(outPath).resolveSymbolicLinksSync();
    } on FileSystemException {
      throw refuse(); // dangling link: never write through it
    }
    if (!inside(real)) throw refuse();
  }

  var dir = p.dirname(outPath);
  while (!FileSystemEntity.isDirectorySync(dir) &&
      !FileSystemEntity.isLinkSync(dir) &&
      p.isWithin(libAbs, dir)) {
    dir = p.dirname(dir);
  }
  final String real;
  try {
    real = Directory(dir).resolveSymbolicLinksSync();
  } on FileSystemException {
    throw refuse();
  }
  if (!inside(real)) throw refuse();
}
