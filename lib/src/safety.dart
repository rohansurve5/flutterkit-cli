import 'dart:io';
import 'dart:math';

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

/// Windows device names. Windows maps these to devices in ANY folder, in any
/// case, with or without an extension (`CON`, `nul.dart`, `Aux.tar.gz`).
final RegExp _windowsReservedName = RegExp(
  r'^(con|prn|aux|nul|com[1-9\u00b9\u00b2\u00b3]|lpt[1-9\u00b9\u00b2\u00b3]|conin\$|conout\$)\s*(\..*)?$',
  caseSensitive: false,
);

/// Validates a server-supplied install [target] and returns the absolute path
/// it maps to inside [libDir].
///
/// Accepted: a relative path, optionally starting with `lib/`. Rejected: empty,
/// absolute (`/x`, `~/x`, `C:\x`), backslashes, control characters, any `..`
/// segment, a segment ending in a space or dot (Windows silently strips those,
/// so `.. ` would become `..`), a Windows reserved device name, or anything
/// that normalizes to [libDir] itself or outside it.
String resolveTarget(String target, String libDir) {
  CliException refuse(String why) =>
      CliException("Refusing unsafe file target '${safeText(target)}': $why.");

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
  for (final seg in segments) {
    if (seg.endsWith(' ') || seg.endsWith('.')) {
      throw refuse('a path segment ends in a space or dot (Windows strips it)');
    }
    if (_windowsReservedName.hasMatch(seg)) {
      throw refuse('"$seg" is a reserved device name on Windows');
    }
  }

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
  // lib/ itself must be a real folder: a lib/ symlink would send every file
  // wherever it points, outside this project.
  if (FileSystemEntity.isLinkSync(libAbs)) {
    throw CliException(
      "Refusing to write: '${p.relative(libAbs)}' is a symlink. FlutterKit only "
      'writes into a real lib/ folder — run it in the project the link points to.',
    );
  }
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

/// Writes [bytes] to [outPath] (inside [libDir]) without ever writing through an
/// existing file, hardlink or symlink, and with every check made BEFORE the
/// content is written:
///
///  1. check the destination (no symlink out of `lib/`, `lib/` not a link);
///  2. create a new, EMPTY temp file with a random name in the destination's
///     own folder and keep it open;
///  3. check where that temp file REALLY is. If its folder was swapped for a
///     link since step 1, nothing is written (at worst an empty temp file is
///     left behind) and the install is refused;
///  4. write the content through the handle opened in step 2 — the file that
///     was just verified to be inside `lib/` — and check its location again;
///  5. rename it over the destination. A rename replaces the directory entry,
///     so a hardlink's other names (or a link's target) are never modified.
///
/// [debugHook] is for tests only: called with 'beforeTemp', 'beforeWrite' and
/// 'beforeRename'.
void writeFileAtomically(
  String outPath,
  List<int> bytes,
  String libDir, {
  void Function(String stage)? debugHook,
}) {
  ensureNoSymlinkEscape(outPath, libDir);
  final dir = Directory(p.dirname(outPath))..createSync(recursive: true);
  ensureNoSymlinkEscape(outPath, libDir); // folders just created: check again
  debugHook?.call('beforeTemp');

  // A random 64-bit name: only this process ever creates a file with it.
  final tmp = File(p.join(dir.path, '.flutterkit-${_randomHex()}.tmp'));
  final raf = tmp.openSync(mode: FileMode.writeOnly); // creates it, empty
  var committed = false;
  try {
    debugHook?.call('beforeWrite');
    _ensureRealPathInsideLib(tmp.path, outPath, libDir);
    raf.writeFromSync(bytes);
    raf.flushSync();
    raf.closeSync();
    debugHook?.call('beforeRename');
    _ensureRealPathInsideLib(tmp.path, outPath, libDir);
    tmp.renameSync(outPath);
    committed = true;
  } finally {
    if (!committed) {
      try {
        raf.closeSync();
      } on FileSystemException {
        // already closed
      }
      _deleteTemp(tmp.path);
    }
  }
}

void _ensureRealPathInsideLib(String tmpPath, String outPath, String libDir) {
  CliException refuse() => CliException(
        "Refusing to write '${p.relative(outPath)}': its folder changed into a "
        'symlink while installing. Nothing was written there.',
      );
  final libReal =
      Directory(p.normalize(p.absolute(libDir))).resolveSymbolicLinksSync();
  final String real;
  try {
    real = File(tmpPath).resolveSymbolicLinksSync();
  } on FileSystemException {
    throw refuse();
  }
  if (!p.isWithin(libReal, real)) throw refuse();
}

/// Best effort: remove an unfinished temp file wherever it really ended up.
void _deleteTemp(String tmpPath) {
  try {
    File(File(tmpPath).resolveSymbolicLinksSync()).deleteSync();
  } on FileSystemException {
    // not found (its folder moved) — never mask the original error
  }
}

final Random _rng = Random.secure();
String _randomHex() =>
    List.generate(8, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();

/// ANSI/VT escape sequences: CSI (`ESC [ … final`), OSC (`ESC ] … BEL|ST`),
/// DCS/SOS/PM/APC strings, and two-byte `ESC x` sequences.
final RegExp _escapeSequence = RegExp(
  r'\x1b(?:\[[0-?]*[ -/]*[@-~]?|\][^\x07\x1b]*(?:\x07|\x1b\\)?|[PX^_][^\x1b]*(?:\x1b\\)?|.)?',
);

/// Control characters a terminal may act on: C0 (except optional `\n`), DEL,
/// C1, and Unicode bidi/direction overrides that can reorder what is shown.
final RegExp _controlChars = RegExp(
  '[\\x00-\\x09\\x0b-\\x1f\\x7f-\\x9f\\u061c\\u200e\\u200f\\u202a-\\u202e\\u2066-\\u2069]',
);

/// Server text made safe to print: escape sequences and control characters are
/// removed, so a screen name can't clear the screen, retitle the terminal, fake
/// coloured "verified" output or hide text. Newlines are kept only when
/// [keepNewlines] is true (multi-line error messages).
String safeText(String s, {bool keepNewlines = false}) {
  var out = s.replaceAll(_escapeSequence, '').replaceAll(_controlChars, '');
  if (!keepNewlines) out = out.replaceAll('\n', ' ');
  return out;
}
