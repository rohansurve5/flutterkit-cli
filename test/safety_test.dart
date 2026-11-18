import 'dart:convert';
import 'dart:io';

import 'package:flutterkit_cli/src/api_client.dart';
import 'package:flutterkit_cli/src/cli_exception.dart';
import 'package:flutterkit_cli/src/commands/add_command.dart';
import 'package:flutterkit_cli/src/config.dart';
import 'package:flutterkit_cli/src/runner.dart';
import 'package:flutterkit_cli/src/safety.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final throwsCli = throwsA(isA<CliException>());

void main() {
  group('validateApiBase', () {
    test('allows production and local dev', () {
      expect(validateApiBase('https://rohansurve.in'), 'https://rohansurve.in');
      expect(
          validateApiBase('https://rohansurve.in/'), 'https://rohansurve.in');
      expect(validateApiBase('HTTPS://RohanSurve.in'), 'https://rohansurve.in');
      expect(validateApiBase('https://rohansurve.in:443'),
          'https://rohansurve.in');
      expect(validateApiBase('http://localhost'), 'http://localhost');
      expect(
          validateApiBase('http://localhost:3000/'), 'http://localhost:3000');
      expect(validateApiBase('http://127.0.0.1:8080'), 'http://127.0.0.1:8080');
    });

    const rejected = [
      'http://rohansurve.in', // plain http to production
      'https://rohansurve.in.evil.com', // look-alike suffix
      'https://evilrohansurve.in',
      'https://evil.com/rohansurve.in', // host in path
      'https://rohansurve.in@evil.com', // user-info trick
      'https://evil.com@rohansurve.in', // user-info on the real host
      'https://www.rohansurve.in', // not used by the CLI
      'https://rohansurve.in:8443',
      'https://rohansurve.in/api', // path
      'https://rohansurve.in?x=1',
      'https://rohansurve.in#x',
      'https://localhost:3000', // dev hosts are http only
      'http://localhost.evil.com',
      'http://127.0.0.2',
      'http://[::1]:3000',
      'ftp://rohansurve.in',
      'file:///etc/passwd',
      'javascript:alert(1)',
      'rohansurve.in',
      '//rohansurve.in',
      ' https://rohansurve.in',
      'https://rohansurve.in\\@evil.com',
      'https://rohansurve.in\n',
      '',
    ];
    for (final raw in rejected) {
      test('rejects ${jsonEncode(raw)}', () {
        expect(() => validateApiBase(raw), throwsCli);
      });
    }

    test('error message names the source and the allowed base', () {
      try {
        validateApiBase('https://evil.com', source: '--api-base');
        fail('should throw');
      } on CliException catch (e) {
        expect(e.message, contains('--api-base'));
        expect(e.message, contains('https://rohansurve.in'));
        expect(e.exitCode, isNot(0));
      }
    });
  });

  group('resolveApiBase', () {
    test('default is production', () {
      expect(resolveApiBase(null, Config(), environment: {}),
          'https://rohansurve.in');
    });
    test('flag, env and config are each validated (no silent fallback)', () {
      expect(
          () => resolveApiBase('https://evil.com', Config(), environment: {}),
          throwsCli);
      expect(
        () => resolveApiBase(null, Config(),
            environment: {'FLUTTERKIT_API_BASE': 'https://evil.com'}),
        throwsCli,
      );
      expect(
          () => resolveApiBase(null, Config(apiBase: 'https://evil.com'),
              environment: {}),
          throwsCli);
      // A bad env value is refused even when config holds a good one.
      expect(
        () => resolveApiBase(
          null,
          Config(apiBase: 'https://rohansurve.in'),
          environment: {'FLUTTERKIT_API_BASE': 'http://rohansurve.in'},
        ),
        throwsCli,
      );
    });
    test('priority: flag > env > config', () {
      expect(
        resolveApiBase(
          'http://localhost:1',
          Config(apiBase: 'http://localhost:3'),
          environment: {'FLUTTERKIT_API_BASE': 'http://localhost:2'},
        ),
        'http://localhost:1',
      );
      expect(
        resolveApiBase(null, Config(apiBase: 'http://localhost:3'),
            environment: {'FLUTTERKIT_API_BASE': 'http://localhost:2'}),
        'http://localhost:2',
      );
      expect(
          resolveApiBase(null, Config(apiBase: 'http://localhost:3'),
              environment: {}),
          'http://localhost:3');
    });
    test('ApiClient refuses a bad base even if constructed directly', () {
      expect(() => ApiClient(apiBase: 'https://evil.com'), throwsCli);
    });
  });

  group('validateSlug', () {
    test('accepts registry-style slugs', () {
      for (final s in ['wallet-splash', 'con_nav_search', 'a', 'A1-b_2']) {
        expect(validateSlug(s), s);
      }
    });
    test('rejects path tricks and junk', () {
      for (final s in [
        '',
        '..',
        '../admin',
        'a/b',
        '-x',
        '_x',
        'a b',
        'a%2Fb',
        'a?x',
        'x' * 101
      ]) {
        expect(() => validateSlug(s), throwsCli, reason: s);
      }
    });
  });

  group('resolveTarget', () {
    late String lib;
    setUp(() =>
        lib = p.join(Directory.systemTemp.createTempSync('fk-').path, 'lib'));

    test('maps relative and lib/-prefixed targets inside lib/', () {
      expect(resolveTarget('wallet_splash/a.dart', lib),
          p.join(lib, 'wallet_splash', 'a.dart'));
      expect(resolveTarget('lib/wallet_splash/a.dart', lib),
          p.join(lib, 'wallet_splash', 'a.dart'));
    });

    // Near misses of Windows device names / trailing-dot rules are fine.
    const okNames = [
      'console.dart',
      'com10.dart',
      'lpt.dart',
      'nul_screen.dart',
      'auxiliary/aux_screen.dart',
      'a.b/c.dart',
      's/.hidden',
    ];
    for (final t in okNames) {
      test('accepts ${jsonEncode(t)}', () {
        expect(p.isWithin(lib, resolveTarget(t, lib)), isTrue);
      });
    }

    const bad = [
      '',
      '../pubspec.yaml',
      'lib/../../.bashrc',
      'a/../../x',
      'a/..',
      '..',
      'a/../b.dart', // stays inside lib/, but any ".." is refused
      '/etc/passwd',
      '//etc/passwd',
      '~/.zshrc',
      '~',
      'C:/Windows/x',
      'c:x',
      'a\\..\\..\\x',
      '\\\\server\\share\\x',
      'a\u0000b',
      'a\nb',
      'lib',
      'lib/',
      '.',
      'lib/lib',
      // Windows strips trailing spaces/dots: '.. ' would act like '..' (#11).
      '.. /evil.dart',
      'a/.. /x',
      'a/... /x',
      'a./b.dart',
      'a /b.dart',
      'x.dart.',
      'x.dart ',
      'a/./b/c.ttf', // a '.' part ends in a dot too
      // Windows device names, any case, with or without extension (#11).
      'CON',
      'con.dart',
      's/NUL.txt',
      's/nul',
      'Aux.tar.gz',
      'prn.dart',
      'com1',
      'COM9.log',
      'lpt1.dart',
      'LPT9',
      'com\u00b9.dart',
      'conin\$',
      'CONOUT\$.txt',
      'con .dart',
    ];
    for (final t in bad) {
      test('rejects ${jsonEncode(t)}', () {
        expect(() => resolveTarget(t, lib), throwsCli);
      });
    }
  });

  group('symlink escape', () {
    late Directory root;
    late String lib;
    setUp(() {
      root = Directory.systemTemp.createTempSync('fk-link-');
      lib = p.join(root.path, 'lib');
      Directory(lib).createSync();
      Directory(p.join(root.path, 'outside')).createSync();
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('directory link inside lib pointing outside is refused', () {
      Link(p.join(lib, 'evil')).createSync(p.join(root.path, 'outside'));
      final out = resolveTarget('evil/x.dart', lib);
      expect(() => ensureNoSymlinkEscape(out, lib), throwsCli);
    });
    test('file link pointing outside is refused (incl. dangling)', () {
      Link(p.join(lib, 'a.dart'))
          .createSync(p.join(root.path, 'outside', 'a.dart'));
      expect(() => ensureNoSymlinkEscape(resolveTarget('a.dart', lib), lib),
          throwsCli);
    });
    test('link that stays inside lib is fine; new nested dirs are fine', () {
      Directory(p.join(lib, 'real')).createSync();
      Link(p.join(lib, 'alias')).createSync(p.join(lib, 'real'));
      ensureNoSymlinkEscape(resolveTarget('alias/x.dart', lib), lib);
      ensureNoSymlinkEscape(resolveTarget('new/deep/dir/x.dart', lib), lib);
    });
    test('lib itself being a symlink is refused (#13), wherever it points', () {
      final linkedRoot = Directory(p.join(root.path, 'proj'))..createSync();
      final l = p.join(linkedRoot.path, 'lib');
      Link(l).createSync(p.join(root.path, 'outside'));
      expect(() => ensureNoSymlinkEscape(resolveTarget('a/x.dart', l), l),
          throwsCli);
      // A dangling lib link is refused too (it would be created through).
      Link(l).deleteSync();
      Link(l).createSync(p.join(root.path, 'missing'));
      expect(() => ensureNoSymlinkEscape(resolveTarget('a/x.dart', l), l),
          throwsCli);
      expect(
          () => planWrites([ScreenFile(target: 'a/x.dart', content: 'x')], l),
          throwsCli);
      expect(Directory(p.join(root.path, 'outside')).listSync(), isEmpty);
    });
    test('the symlinked-lib error is one line saying what is wrong and the fix',
        () {
      final linkedRoot = Directory(p.join(root.path, 'proj2'))..createSync();
      final l = p.join(linkedRoot.path, 'lib');
      Link(l).createSync(p.join(root.path, 'outside'));
      try {
        ensureNoSymlinkEscape(resolveTarget('a/x.dart', l), l);
        fail('should refuse');
      } on CliException catch (e) {
        expect(e.message, isNot(contains('\n')));
        expect(e.message, contains('lib/ is a symlink'));
        expect(e.message, contains('replace the link with a real lib/ folder'));
      }
    });
  });

  group('planWrites (all-or-nothing)', () {
    late String lib;
    setUp(() => lib =
        p.join(Directory.systemTemp.createTempSync('fk-plan-').path, 'lib'));

    test('valid screen plans every file with decoded bytes', () {
      final plan = planWrites([
        ScreenFile(target: 'lib/s/s.dart', content: 'void main() {}'),
        ScreenFile(
            target: 's/fonts/f.ttf',
            content: base64.encode([0, 1, 0, 0]),
            encoding: 'base64'),
      ], lib);
      expect(plan.map((w) => w.path),
          [p.join(lib, 's', 's.dart'), p.join(lib, 's', 'fonts', 'f.ttf')]);
      expect(plan[1].bytes, [0, 1, 0, 0]);
    });
    test('one bad target (even last) refuses the whole screen', () {
      expect(
        () => planWrites([
          ScreenFile(target: 's/ok.dart', content: 'x'),
          ScreenFile(target: '../../evil.dart', content: 'x'),
        ], lib),
        throwsCli,
      );
      expect(Directory(lib).existsSync(), isFalse,
          reason: 'planning writes nothing');
    });
    test('bad base64, unknown encoding, duplicate target are refused', () {
      expect(
          () => planWrites(
              [ScreenFile(target: 'a.ttf', content: '%%%', encoding: 'base64')],
              lib),
          throwsCli);
      expect(
          () => planWrites(
              [ScreenFile(target: 'a.dart', content: 'x', encoding: 'gzip')],
              lib),
          throwsCli);
      expect(
        () => planWrites([
          ScreenFile(target: 'a.dart', content: 'x'),
          ScreenFile(target: 'lib/a.dart', content: 'y')
        ], lib),
        throwsCli,
      );
    });
  });

  test(
      'planWrites refuses a screen whose target goes through an escaping symlink',
      () {
    final root = Directory.systemTemp.createTempSync('fk-plan-link-');
    final lib = p.join(root.path, 'lib');
    Directory(lib).createSync();
    Directory(p.join(root.path, 'outside')).createSync();
    Link(p.join(lib, 'evil')).createSync(p.join(root.path, 'outside'));
    expect(
      () => planWrites([ScreenFile(target: 'evil/x.dart', content: 'x')], lib),
      throwsCli,
    );
    root.deleteSync(recursive: true);
  });

  group('ApiClient transport', () {
    test('never follows redirects and refuses 3xx', () async {
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response('', 302,
            headers: {'location': 'https://evil.com/code'});
      });
      final api = ApiClient(apiBase: 'https://rohansurve.in', client: client);
      await expectLater(
        api.getScreenCode('wallet-splash'),
        throwsA(isA<CliException>()
            .having((e) => e.message, 'message', contains('redirect'))),
      );
      expect(seen.followRedirects, isFalse);
      expect(seen.url.toString(),
          'https://rohansurve.in/api/pro/screens/wallet-splash/code');
    });
    test('refuses a bad slug before any request is sent', () async {
      var calls = 0;
      final api = ApiClient(
        apiBase: 'https://rohansurve.in',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(api.getScreenCode('../../admin'), throwsCli);
      expect(calls, 0);
    });
    test('200 still works', () async {
      final api = ApiClient(
        apiBase: 'http://localhost:3000',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'slug': 'a',
                'name': 'A',
                'files': [
                  {'target': 'lib/a/a.dart', 'content': 'x'}
                ]
              }),
              200,
            )),
      );
      final code = await api.getScreenCode('a');
      expect(code.files.single.target, 'lib/a/a.dart');
    });
  });

  group('writeFileAtomically (#14, #15)', () {
    late Directory root;
    late String lib;
    late String outside;
    setUp(() {
      root = Directory.systemTemp.createTempSync('fk-atomic-');
      lib = p.join(root.path, 'lib');
      outside = p.join(root.path, 'outside');
      Directory(p.join(lib, 's')).createSync(recursive: true);
      Directory(outside).createSync();
    });
    tearDown(() => root.deleteSync(recursive: true));

    List<String> tempFiles() => Directory(root.path)
        .listSync(recursive: true)
        .map((e) => p.basename(e.path))
        .where((n) => n.startsWith('.flutterkit-'))
        .toList();

    test('writes new files and replaces existing ones; no temp file left', () {
      final out = resolveTarget('s/new/a.dart', lib);
      writeFileAtomically(out, utf8.encode('one'), lib);
      writeFileAtomically(out, utf8.encode('two'), lib);
      expect(File(out).readAsStringSync(), 'two');
      expect(tempFiles(), isEmpty);
    });

    test('a hardlink to an outside file is replaced, never written through',
        () {
      final secret = File(p.join(outside, 'secret.txt'))
        ..writeAsStringSync('ORIGINAL');
      final out = resolveTarget('s/a.dart', lib);
      final r = Process.runSync('ln', [secret.path, out]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      writeFileAtomically(out, utf8.encode('NEW'), lib);
      expect(secret.readAsStringSync(), 'ORIGINAL');
      expect(File(out).readAsStringSync(), 'NEW');
    });

    test('a symlink inside lib is replaced by a regular file, not followed',
        () {
      final realFile = File(p.join(lib, 's', 'real.dart'))
        ..writeAsStringSync('REAL');
      final out = p.join(lib, 's', 'alias.dart');
      Link(out).createSync(realFile.path);
      writeFileAtomically(out, utf8.encode('NEW'), lib);
      expect(realFile.readAsStringSync(), 'REAL');
      expect(FileSystemEntity.isLinkSync(out), isFalse);
      expect(File(out).readAsStringSync(), 'NEW');
    });

    // Swap lib/s for a link to outside/ at each step after the check.
    void swapToLink() {
      Directory(p.join(lib, 's')).renameSync(p.join(lib, 's_real'));
      Link(p.join(lib, 's')).createSync(outside);
    }

    for (final stage in ['beforeTemp', 'beforeWrite', 'beforeRename']) {
      test(
          'folder swapped for a symlink at "$stage" → refused, nothing outside',
          () {
        final out = resolveTarget('s/a.dart', lib);
        expect(
          () => writeFileAtomically(out, utf8.encode('RACE'), lib,
              debugHook: (s) {
            if (s == stage) swapToLink();
          }),
          throwsCli,
        );
        // Never any content outside lib/ (an unfinished temp file is removed).
        expect(Directory(outside).listSync(), isEmpty,
            reason: 'no file (not even a temp file) may remain outside lib/');
      });
    }
  });

  group('safeText (#16)', () {
    test('removes ANSI/OSC sequences and control characters', () {
      const evil = '\x1b[2J\x1b[H\x1b]0;pwned\x07\x1b]8;;https://x\x1b\\'
          'Wallet\x1b[0m\x9b31m\u202eTXT\x00\x7f';
      final out = safeText(evil);
      expect(out, 'Wallet31mTXT');
      expect(
          out.runes.any((r) => r < 0x20 || (r >= 0x7f && r < 0xa0)), isFalse);
    });
    test('keeps ordinary text, emoji and accents; newlines only on request',
        () {
      expect(safeText('Café ₹ 🚀 — Fintech'), 'Café ₹ 🚀 — Fintech');
      expect(safeText('a\nb'), 'a b');
      expect(safeText('a\nb', keepNewlines: true), 'a\nb');
    });
    test('refusal messages quote targets without raw control characters', () {
      try {
        resolveTarget('a\x1b[2Jb', 'lib');
        fail('should refuse');
      } on CliException catch (e) {
        expect(e.message.contains('\x1b'), isFalse);
      }
    });
  });
}
