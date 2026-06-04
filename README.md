# flutterkit_cli

Deliver paid **FlutterKit Pro** screens straight into your Flutter project. Log
in once with your license key, then pull screens by slug — the CLI fetches the
screen's files from the FlutterKit endpoint and writes them into your `lib/`.

The CLI holds **no secrets**. The only credential it ever sends is your own
license key.

## Install

```sh
dart pub global activate --source git <public-repo-url>
```

Make sure `~/.pub-cache/bin` is on your `PATH` so the `flutterkit` command is
available.

## Commands

| Command | What it does |
| --- | --- |
| `flutterkit login <license-key>` | Validate your key and save it. |
| `flutterkit list` | List the screens available to your license. |
| `flutterkit add <slug>` | Add a screen's files into `lib/`. |
| `flutterkit logout` | Clear your saved key. |
| `flutterkit --help` / `--version` | Standard help / version. Per-command help via `flutterkit help <command>`. |

### `add` flags

- `--force` / `-f` — overwrite existing files without prompting and skip the
  "this doesn't look like a Flutter project" check.

## Config

Stored at `~/.flutterkit/config.json` (the file is created user-only, `chmod 600`):

```json
{ "licenseKey": "...", "apiBase": "..." }
```

## API base resolution

In priority order:

1. `--api-base <url>` flag
2. `FLUTTERKIT_API_BASE` environment variable
3. `apiBase` in config
4. Default: `https://rohansurve.in`

So the same binary can be pointed at a local endpoint for testing:

```sh
flutterkit --api-base http://localhost:3000 login <key>
```

## Develop

```sh
dart pub get
dart analyze
dart run bin/flutterkit.dart --help
```
