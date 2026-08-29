# Changelog

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
