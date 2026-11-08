# Changelog

## Unreleased

### Desktop app data stays out of Documents

`database: sqflite` opened its file under `getApplicationDocumentsDirectory()`,
which on Android and iOS is app-private but on desktop is the user's real
Documents folder — so a Windows build dropped `<name>.db` into
`C:\Users\<user>\Documents`. Generated apps now get
`lib/core/storage/app_data_directory.dart`: desktop uses
`getApplicationSupportDirectory()` (`%APPDATA%\<org>\<name>` on Windows),
and Android, iOS and web keep exactly the path they had. A test pins the
choice for every platform. New apps have no old data, so there is no
migration step.

### Debug builds install beside the store build

Debug and profile builds now carry `<applicationId>.dev` and a ` Dev` launcher
label, so `flutter run` adds a second icon instead of replacing the copy
installed from the store. Testing a change no longer costs you the real app,
its data or its signed-in session. Release is untouched, and so is everything
that names the store build: the Gradle `namespace`, the `market://` rate link
and fastlane's `APP_IDENTIFIER`. Opt out with `--no-dev-suffix` or
`features.devSuffix: false`.

On iOS this had to go in `project.pbxproj` rather than an xcconfig, because
`flutter create` points **both** Profile and Release at `Release.xcconfig` — a
suffix defined there would have shipped to the App Store.

With `backend: appwrite`, beej now warns that the `.dev` id needs registering
as a second platform on the Appwrite project. Appwrite authorizes by bundle
id, so without it every call from a debug build fails on origin.

### The launcher label is the app's name

`flutter create` writes the *package* name into `android:label` and a
title-cased version of it into `CFBundleDisplayName`, and beej never corrected
it — so an app called "Mero Nepali" shipped as `mero_nepali` on Android and
`Mero_nepali` on iOS. Both now use `displayName`.

### Fixed: the iOS bundle id was wrong for any name with an underscore

Apple does not accept an underscore in a bundle identifier, so `flutter
create` camel-cases the project name for it: `mero_nepali` is
`com.example.mero_nepali` on Android but `com.example.meroNepali` on Apple.
beej had only one notion of an app id and used it for both, which meant the
generated `ios/fastlane/Appfile` and `Matchfile` addressed an app that does
not exist. `AppSpec.appleBundleId` now mirrors flutter_tools'
`createUTIIdentifier`, and everything on the Apple side uses it.

### Bricks can patch the platform tree

A brick can now declare anchored edits to files `flutter create` wrote, for
the few values that cannot be owned as whole files — `project.pbxproj` carries
generated UUIDs, and owning `AndroidManifest.xml` would mean re-shipping the
activity config on every Flutter release. Every edit asserts its anchor: if a
Flutter release changes one of those files, generation fails naming the file,
the anchor and the Flutter version, rather than quietly skipping the edit.
`--dry-run` lists patches alongside the files.

## 1.2.1

Fixes what 1.2.0 exposed. The skills CLI crawls a whole git repository for
`SKILL.md` files, so installing beej's own skill offered four more that are
templates for generated projects — including `material-ui`, which tells you
never to import `package:flutter/material.dart`. In an ordinary Flutter repo
that is not merely irrelevant, it is wrong.

Template skill files now carry `.tmpl` like every other template, so only
`beej-scaffolding` is discoverable. Generated projects are unchanged: they
still receive `SKILL.md` and its references under `.claude/skills/`.

## 1.2.0

### Ships its own agent skill

beej now carries `skills/beej-scaffolding/`, following the convention the
`skills` CLI reads. An agent in any repo can install it:

```sh
dart run skills@ add https://github.com/lohanidamodar/beej.git
```

It covers the machine-readable entry points (`beej bricks`, `beej spec
--schema`, `--dry-run`, `--yes`), and states up front that `material_ui` is a
fixed assumption rather than a flag — the thing worth knowing before choosing
beej at all.

Generated projects keep their committed `.claude/skills/`. They do not depend
on beej, so the CLI would never find those; and committed skills work offline
and can be edited per project. The two coexist — the CLI tracks what it manages
separately and leaves committed skills alone.

`PROJECT.md` now also points at `dart run skills@ get`, for pulling skills from
packages the app depends on as more of them ship skills.

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
