# Changelog

## 1.1.0

### Appwrite 26.1.0

Generated projects were pinned to `^25.4.0`, which cannot resolve into 26.x.
The only breaking change in 26.0.0 is `Execution.functionId` splitting into
`resourceId`/`resourceType` — the Functions API, which these templates do not
touch. TablesDB, Account and Client are unchanged.

### Two dependency overrides removed

Appwrite 25 capped `package_info_plus` below 10 and `device_info_plus` below
13, which dragged in the win32 ^5 cluster and collided with `share_plus` 13's
win32 ^6. Two `dependency_overrides` were the way out. 26.x widened both caps,
so the cause is gone and the overrides go with it — a generated Appwrite app
now resolves to the same versions on its own.

Generated projects still start at `version: 1.0.0+1`; that is independent of
beej's own version.

## 1.0.0

Published from CI, and the first release the automated workflow produced.

No functional change from 0.1.0 — the version signals that the CLI surface
(`create`, `spec`, `bricks`, `config`), the spec-file schema and the generated
project layout are ones to depend on, and that breaking them means a major
bump.

## 0.1.0

First release.

Generates a complete, buildable Flutter project from one command, with the
parts that genuinely differ left as explicit choices.

### Always generated

- `material_ui` (Material decoupled from the Flutter SDK), Riverpod 3 without
  code generation, and a fixed `lib/` layout of `core/` and `features/`
- Theming with live personalization — accent, theme mode, language, text size
- Localization through `flutter gen-l10n`, and an About module wired into
  routes and settings
- Crash and error capture across all three routes an error can take out of a
  Flutter app, with a Diagnostics screen
- Responsive helpers, shared UI, and a `Launcher` for hand-offs to other apps
- `PROJECT.md` as the single guide for humans and agents, with `CLAUDE.md` and
  `AGENTS.md` pointing at it
- Agent skills under `.claude/skills/` and an `.mcp.json`
- CI that runs `flutter analyze` and `flutter test` on every push

### Choices

Platforms, backend (Appwrite or offline), router (`go_router` or Navigator),
navigation chrome, local database, icon set, design system, locales, and the
optional features — in-app update, notifications, Bikram Sambat dates, review
prompts.

### Release tooling

fastlane lanes and store metadata for Play and the App Store, a self-contained
Android release workflow, and screenshot workflows that capture on a matching
emulator or simulator, render with
[moksha](https://github.com/lohanidamodar/moksha), and open a pull request.

### Verification

`dart run tool/verify_matrix.dart` generates ten configurations and runs
`flutter analyze` and `flutter test` against each, so a change that breaks one
combination fails before release.
