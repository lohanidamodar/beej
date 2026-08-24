# beej

**बीज** — plant a new PopupBits Flutter app.

A Dart CLI that generates a complete, buildable Flutter project with the stack
every PopupBits app has converged on, and the parts that genuinely differ as
explicit choices.

```sh
dart pub global activate --source path .

beej create tipot                       # interactive
beej create tipot --yes                 # take every default
beej create --spec app.yaml             # from a file
beej create tipot --yes --dry-run       # show the plan, write nothing
```

## What you always get

- **`material_ui`** — Material decoupled from the Flutter SDK. Nothing under
  `lib/` imports `package:flutter/material.dart`, and a generated test fails
  the build if that ever changes.
- **Riverpod 3**, no code generation.
- **Localization** in `lib/l10n/` — English and Nepali, actually translated.
- **Theming** from design tokens, with **working personalization**: accent
  colour, theme mode, language and text size, persisted and applied before the
  first frame.
- **The About module** — privacy policy, open-source licences, share, rate,
  more apps, contact support — wired into routes and the settings list.
- **Responsive helpers**, shared UI (`AsyncView`, `EmptyView`, `ErrorView`,
  `SectionLabel`, `context.toast`, `context.confirm`), and a `Launcher` for
  every hand-off to another app.
- **`PROJECT.md`** as the single guide, with `CLAUDE.md` and `AGENTS.md`
  pointing at it — scope, workflow, conventions, the responsive contract, a
  testing strategy and a done-checklist.
- **Agent tooling**: `.mcp.json` declaring the Dart MCP server (it ships inside
  the Dart SDK, so nothing to install) plus Appwrite's hosted server when that
  backend is on, and project-scoped skills under `.claude/skills/`. Turn it all
  off with `--no-agent-config`, or narrow it with `--skills=material-ui`.

## What you choose

| Option | Values | Default |
|---|---|---|
| `platforms` | android, ios, web, windows, macos, linux | all |
| `backend` | `appwrite`, `none` | `none` |
| `router` | `go_router`, `navigator` | `go_router` |
| `nav` | `tabs`, `drawer`, `tabs+drawer` | `tabs+drawer` |
| `database` | `sqflite`, `none` | `none` |
| `icons` | `picons`, `material` | `picons` |
| `features.inAppUpdate` | bool | true |
| `features.notifications` | bool | false |
| `features.nepaliDates` | bool | false |
| `features.review` | bool | true |
| `tooling.fastlane` | bool | true |
| `tooling.githubWorkflow` | bool | true |
| `tooling.screenshots` | bool | true |
| `agents.mcp` | bool | true |
| `agents.skills` | `all` / `none` / list | `all` |

`beej bricks` lists what each contributes.

## For agents

```sh
beej spec --schema     # JSON Schema for the spec file
beej spec --example    # annotated example
beej create --spec app.yaml --yes
```

Precedence is **flag > spec file > prompt > default**. `--yes` never prompts,
so it is safe in a script. `--dry-run` prints the resolved plan and writes
nothing.

## How it works

`flutter create` produces the platform folders, then **bricks** render template
files over that skeleton. Bricks are additive — a feature that is off simply
never contributes. Three registries in the generated app are the seams a
feature extends: `core/bootstrap.dart`, `core/router/routes.dart`, and
`features/settings/tiles.dart`.

## Development

```sh
dart test                            # beej's own tests — seconds
dart run tool/verify_matrix.dart     # generate 8 configs, analyze + test each
dart run tool/verify_matrix.dart minimal --keep
```

The matrix is the real safety net. Mutually exclusive bricks can never coexist
in one project, so "the templates compile" is not achievable — proving the
*output* compiles is what keeps fifteen toggles from rotting.

Package versions live in one place: `lib/src/bricks/versions.dart`. Bump there,
then re-run the matrix.

## Known limitation

`designSystem: popup_bits_design` is rejected. That package pins
`material_ui: ^0.0.1` — the old one-line re-export shim — which cannot resolve
alongside the 1.x line beej generates against. Widening its constraint to
`^1.0.0` upstream is the fix; until then, `designSystem: local` generates
project-owned tokens.
