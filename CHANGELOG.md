# Changelog

## 0.3.1

Security hardening (no new features).

- `add` refuses a file target with a path part that ends in a space or dot
  (Windows strips those, so `.. ` would act like `..`), or that is a Windows
  device name: `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9` (also
  `COM¹²³`/`LPT¹²³`, `CONIN$`, `CONOUT$`), in any case, with or without an
  extension. A `.` path part is refused too.
- **Behaviour change:** `add` refuses to run when `lib/` itself is a symlink
  (0.3.0 allowed it), because every file would land wherever the link points.
  Run it in the project the link points to.
- Each file is written to a new temporary file in its own folder, its real
  location is checked, and it is then renamed into place. An existing
  hardlink is no longer overwritten in place (its other names keep their
  content), and a folder swapped for a symlink during the install is caught
  instead of written through.
- Screen names, categories and other server text are printed with ANSI/VT
  escape sequences and control characters removed.

## 0.3.0

- **Breaking:** the API base (from `--api-base`, `FLUTTERKIT_API_BASE` or the
  config `apiBase`) must be exactly `https://rohansurve.in`, or
  `http://localhost[:port]` / `http://127.0.0.1[:port]` for development. Any
  other value is refused with a clear error and exit code 64 — no silent
  fallback.
- `add` now refuses file targets that contain `..`, are absolute (`/`, `~`,
  drive letters), use backslashes or control characters, resolve outside
  `lib/`, or would write through a symlink that leads outside `lib/`. All files
  are validated (including base64 decoding and encoding) before any is written,
  so an unsafe screen writes nothing.
- Slugs are validated before any request (same pattern as the website).
- HTTP redirects are no longer followed; a 3xx response is reported as an error.

## 0.2.0

- **FlutterKit is now free.** The CLI requires no account, key or credential of
  any kind, and works on a fresh machine with no config file.
- Removed the `login` and `logout` commands.
- `list` and `add` now call the public endpoints anonymously — no
  `Authorization` header is ever sent.
- Config at `~/.flutterkit/config.json` is optional and holds only `apiBase`.

## 0.1.0

- Initial release.
- `login`, `list`, `add`, `logout` commands.
- Config at `~/.flutterkit/config.json` (user-only permissions).
- API base resolution: `--api-base` > `FLUTTERKIT_API_BASE` > config > `https://rohansurve.in`.
