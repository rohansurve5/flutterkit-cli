# flutterkit_cli

Add **FlutterKit** screens straight into your Flutter project. Pull a screen by
slug — the CLI fetches its files from the FlutterKit endpoint and writes them
into your `lib/`.

FlutterKit is **free**. There is no account, no sign-up, no key and no setup: on
a fresh machine, `flutterkit add <slug>` just works. The CLI sends no
credentials of any kind.

## Install

```sh
dart pub global activate --source git <public-repo-url>
```

Make sure `~/.pub-cache/bin` is on your `PATH` so the `flutterkit` command is
available.

## Commands

| Command | What it does |
| --- | --- |
| `flutterkit list` | List the screens available to add. |
| `flutterkit add <slug>` | Add a screen's files into `lib/`. |
| `flutterkit --help` / `--version` | Standard help / version. Per-command help via `flutterkit help <command>`. |

### `add` flags

- `--force` / `-f` — overwrite existing files without prompting and skip the
  "this doesn't look like a Flutter project" check.

## Config

No config file is required. If you want to point the CLI at a different
endpoint, you can optionally create `~/.flutterkit/config.json`:

```json
{ "apiBase": "..." }
```

## API base resolution

In priority order:

1. `--api-base <url>` flag
2. `FLUTTERKIT_API_BASE` environment variable
3. `apiBase` in config
4. Default: `https://rohansurve.in`

So the same binary can be pointed at a local endpoint for testing:

```sh
flutterkit --api-base http://localhost:3000 list
```

## Develop

```sh
dart pub get
dart analyze
dart run bin/flutterkit.dart --help
```
