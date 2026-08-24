# beej

**बीज** — plant a new PopupBits Flutter app.

A Dart CLI that generates a complete, buildable Flutter project with the stack
every PopupBits app has converged on, and the parts that genuinely differ as
explicit choices.

```sh
./tool/install.sh          # compiles and installs to ~/.local/bin/beej

beej config set org com.acme            # once, not per project
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
| `org` | reverse-DNS prefix | `com.example` |
| `locales` | `en` plus any of `ne` | `en` |
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

## Making it yours

beej ships neutral defaults — `com.example`, English only, no About URLs — so
it is useful to anyone. `beej config` is where you set yours once instead of
passing the same flags to every `create`:

```sh
beej config                    # show current settings and their file
beej config keys               # everything settable
beej config set org com.acme
beej config set locales en,ne
beej config set about.privacyPolicyUrl https://acme.com/{name-kebab}-privacy
beej config unset locales      # back to the built-in default
```

The file is `$XDG_CONFIG_HOME/beej/config.yaml` (`%APPDATA%\beej` on Windows),
overridable with `BEEJ_CONFIG`. It is **a spec file without a `name`**, so it
accepts exactly the same keys as `--spec` and is hand-editable.

About URLs accept `{name}` and `{name-kebab}`, expanded per project — which is
what makes a per-app privacy-policy URL storable as a one-time preference.

Anything you do not set is simply absent: an About row is generated only when
its value exists, because a row linking nowhere is worse than no row. beej
warns when no privacy-policy URL is configured, since both stores require one
before release.

Resolution order: **built-in defaults < config < spec file < flags.**

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

## Install

`tool/install.sh` compiles a standalone binary to `~/.local/bin/beej`.

Prefer it over `dart pub global activate --source path .`: a path activation
re-resolves dependencies on every invocation and prints "Resolving
dependencies..." to **stdout**, which corrupts the output any agent or script
is reading. It also starts in ~3s against the binary's ~4ms.

The binary is self-contained — templates are embedded, so it works from any
directory. The trade-off is that it does not track source edits, so re-run
`./tool/install.sh` after changing beej. It re-embeds templates first, so a
stale one cannot ship.

## Development

```sh
dart test                            # beej's own tests — seconds
dart run tool/verify_matrix.dart     # generate 10 configs, analyze + test each
dart run tool/verify_matrix.dart minimal --keep
dart run tool/embed_templates.dart   # after editing anything under templates/
```

Editing a template takes effect immediately when running from source —
`TemplateSource` prefers the directory and falls back to the embedded copy. A
test asserts the two agree, so a forgotten re-embed fails CI rather than
shipping stale templates in a binary.

The matrix is the real safety net. Mutually exclusive bricks can never coexist
in one project, so "the templates compile" is not achievable — proving the
*output* compiles is what keeps fifteen toggles from rotting.

Package versions live in one place: `lib/src/bricks/versions.dart`. Bump there,
then re-run the matrix.

## What a generated project depends on

One external repository: `popupbits/fastlane-plugin-play_publisher`, which is
public. The release workflow is written into the project rather than calling a
shared reusable workflow, so nothing in a generated repo depends on private
infrastructure.

## Known limitation

`designSystem: popup_bits_design` is rejected. That package pins
`material_ui: ^0.0.1` — the old one-line re-export shim — which cannot resolve
alongside the 1.x line beej generates against. Widening its constraint to
`^1.0.0` upstream is the fix; until then, `designSystem: local` generates
project-owned tokens.
