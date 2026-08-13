# Changelog

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
