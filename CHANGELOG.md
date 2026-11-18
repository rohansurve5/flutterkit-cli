# Changelog

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
