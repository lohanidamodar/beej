---
name: beej-scaffolding
description: Scaffold a new Flutter app with the beej CLI — material_ui, Riverpod, go_router, localization, Appwrite or offline, and release tooling. Use when asked to create, scaffold, generate or start a new Flutter project, to add a beej spec file, or to work out which beej options a project needs.
---

# Scaffolding a Flutter app with beej

[beej](https://pub.dev/packages/beej) generates a complete, buildable Flutter
project in one command. It is opinionated: the stack below is fixed, and only
the parts that genuinely differ between apps are choices.

```sh
dart pub global activate beej
```

## Never guess the options

beej describes itself. Read that instead of inventing flag names or spec keys —
they change, and a wrong one fails late:

```sh
beej bricks              # every capability, and what triggers it
beej spec --schema       # JSON Schema for a spec file
beej spec --example      # an annotated example spec
beej create --help       # every flag
```

## Creating a project

```sh
beej create my_app --yes                 # every default, no prompts
beej create my_app --yes --dry-run       # print the plan, write nothing
beej create --spec app.yaml              # from a spec file
```

**Use `--dry-run` first.** It prints exactly which files would be written, for
free. For anything beyond a default app, confirm the plan before generating.

`--yes` is what makes beej usable without a TTY. Without it, beej prompts and
an agent will hang.

## Choosing a spec file over flags

For anything non-trivial, write `app.yaml` and use `--spec`. It is reviewable,
diffable and re-runnable, where a long flag line is none of those. Get its
shape from `beej spec --schema` rather than from memory.

## What is fixed, and what that costs

Every generated project uses **`package:material_ui`** — Material decoupled
from the Flutter SDK — and never `package:flutter/material.dart`. A generated
test fails the build if any file breaks that rule.

This is the single most important thing to know before choosing beej: if the
user wants plain Flutter Material, beej is the wrong tool. The assumption runs
through the templates, the tests and the docs, and is not a flag.

Also fixed: Riverpod 3 without code generation, a `core/` + `features/` layout,
`flutter gen-l10n` localization, and hand-written models. Do not add
`build_runner`, `freezed` or `json_serializable` to a generated project without
asking — that is a deliberate exclusion, not an oversight.

## After generating

The project explains itself. **Read `PROJECT.md` first** — it is the single
guide. `AGENTS.md` carries the shared working rails and points at it, and
`CLAUDE.md` is exactly `@AGENTS.md`, the import form Claude Code follows.
`PROJECT.md` has the scope rules, the conventions, the registries to extend,
and the traps specific to this stack.

The project also ships its own skills under `.claude/skills/` covering
`material-ui`, store readiness, app store optimization, mobile UI design and
screenshot generation. Those are more specific than this skill; prefer them
once you are working inside a generated project.

## Defaults belong to the user, not the project

```sh
beej config set org com.acme
```

Set once, not per project. Built-in defaults are deliberately neutral
(`com.example`, English only), so a generated project carries nothing personal
until the user configures it.

## Verifying a change to beej itself

If you are working on beej rather than using it, `dart test` is not enough:

```sh
dart run tool/verify_matrix.dart
```

That generates ten configurations and runs `flutter analyze` and `flutter test`
against each. A change can pass beej's unit tests and still produce a project
that does not compile, which is exactly what the matrix is for.
