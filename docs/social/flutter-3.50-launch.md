# beej 1.3.0 — Flutter 3.50 launch posts

Drafts only. Nothing here has been posted; the person posts these.

**Links**

- `{PUB_LINK}` → https://pub.dev/packages/beej
- `{REPO_LINK}` → https://github.com/lohanidamodar/beej
- `{CHANGELOG_LINK}` → https://github.com/lohanidamodar/beej/blob/main/CHANGELOG.md

**What every post rests on** (from the 1.3.0 CHANGELOG; nothing below goes
past it)

- beej is a Dart CLI that generates a complete, buildable Flutter app:
  `material_ui`, Riverpod, routing, localization, theming, release tooling and
  agent config, with backend, database and the rest as explicit choices.
- 1.3.0 targets Flutter 3.50 / Dart 3.14. Generated apps declare
  `sdk: ^3.14.0` and `flutter: '>=3.50.0'`.
- New apps start on `material_ui`, AGP 9.3.1, Gradle 9.5.0 and minSdk 24, and
  a generated app analyzes clean on 3.50 — no deprecated APIs.
- Two 3.50 gotchas fixed: an `applicationIdSuffix` on the `profile` build type
  now breaks every Android build, and flutter_local_notifications 23 needs
  compileSdk 37.

**Wording notes**

- "Day one" is not used: Flutter 3.50 shipped on 2026-11-09 and beej 1.3.0
  followed in the same week. The posts say "release week".
- Generated apps use `material_ui` directly. They do not depend on
  `cupertino_ui` themselves (it arrives through packages that migrated to it),
  so the posts name `material_ui` only.

**Image** (shared by most posts) — there are no existing beej screenshots, so
two options:

- **A. Terminal capture:** `beej create tipot --yes` finishing, then
  `flutter analyze` printing "No issues found!", on Flutter 3.50.0.
- **B. Card:** dark background, "beej 1.3.0" top left, large
  "Flutter 3.50 ✓" centred, and one line under it: "material_ui · AGP 9.3 ·
  Gradle 9.5 · no deprecated APIs". 1200×675 for X/LinkedIn/Bluesky/Mastodon,
  1080×1080 for Instagram/Facebook.

---

## X / Twitter

> beej 1.3.0 is out: release-week support for Flutter 3.50.
>
> beej is a Dart CLI that generates a complete Flutter app. New apps now start on material_ui, AGP 9.3 and Gradle 9.5, and analyze clean with no deprecated APIs.
>
> {PUB_LINK}
>
> #Flutter #FlutterDev #Dart

- **Image:** B (1200×675).
- **Link:** `{PUB_LINK}`.

## LinkedIn

> Flutter 3.50 shipped this week, and beej 1.3.0 is updated for it.
>
> beej is an open-source Dart CLI that generates a complete, buildable Flutter app: material_ui, Riverpod, routing, localization, theming, release tooling and agent config, with the backend and database left as explicit choices. Its defaults came from thirteen production apps that had converged on one stack.
>
> What changes for a new app generated with 1.3.0:
>
> • It targets Flutter 3.50 / Dart 3.14 from the first commit.
> • It starts on material_ui, the Material library that now lives outside the SDK.
> • It takes 3.50's Android defaults: AGP 9.3.1, Gradle 9.5.0, minSdk 24.
> • It analyzes clean on 3.50, with no deprecated APIs.
>
> Two things in the upgrade are worth knowing about if you maintain a Flutter app yourself:
>
> 1. Flutter 3.50 copies your app's build types onto plugin library projects. If you set applicationIdSuffix on the profile build type, every Android build now fails with "Library projects cannot set applicationIdSuffix". Setting it through the Android variant API instead keeps it on the app alone.
> 2. flutter_local_notifications 23 compiles against Android SDK 37, one level above Flutter's default of 36, so apps using it need compileSdk 37.
>
> The full migration notes are in the changelog: {CHANGELOG_LINK}
>
> #Flutter #FlutterDev #Dart #MobileDevelopment #OpenSource

- **Image:** B (1200×675), or A if a real capture reads better.
- **Link:** `{CHANGELOG_LINK}` in the post; `{PUB_LINK}` as the first comment.

## Bluesky

> beej 1.3.0: updated for Flutter 3.50 in release week.
>
> beej is a Dart CLI that generates a complete Flutter app. New apps start on material_ui, AGP 9.3 and Gradle 9.5, and analyze clean with no deprecated APIs.
>
> {PUB_LINK}
>
> #Flutter #FlutterDev #Dart

- **Image:** B (1200×675), alt text: "Card reading beej 1.3.0, Flutter 3.50 ✓".
- **Link:** `{PUB_LINK}`.

## Threads

> Flutter 3.50 shipped this week, and beej 1.3.0 is ready for it.
>
> beej is a Dart CLI that generates a complete, buildable Flutter app: material_ui, Riverpod, routing, localization and release tooling.
>
> New apps now start on 3.50 with material_ui, AGP 9.3.1, Gradle 9.5.0 and minSdk 24, and analyze clean with no deprecated APIs.
>
> A gotcha I hit: an applicationIdSuffix on the profile build type now breaks every Android build on 3.50.
>
> {PUB_LINK}
>
> #Flutter #FlutterDev #Dart

- **Image:** B (1080×1080).
- **Link:** `{PUB_LINK}`.

## Mastodon

> beej 1.3.0 is out, updated for Flutter 3.50 in release week.
>
> beej is a Dart CLI that generates a complete, buildable Flutter app (material_ui, Riverpod, routing, localization, theming, release tooling).
>
> New apps start on Flutter 3.50 / Dart 3.14 with material_ui, AGP 9.3.1 and Gradle 9.5.0, and analyze clean with no deprecated APIs.
>
> Migration notes: {CHANGELOG_LINK}
>
> #Flutter #FlutterDev #Dart #OpenSource

- **Image:** B (1200×675), alt text: "Card reading beej 1.3.0, Flutter 3.50 ✓,
  material_ui, AGP 9.3, Gradle 9.5, no deprecated APIs".
- **Link:** `{CHANGELOG_LINK}`.

## Reddit (r/FlutterDev)

Check the subreddit's current self-promotion rules before posting. The post
leads with the migration notes; the tool comes up once, at the end, disclosed
as the author's own.

**Title:** Flutter 3.50 upgrade notes: two Android build breaks I hit, and what fixed them

**Body:**

> I've just moved a Flutter project generator onto 3.50, and while doing it I built every combination it generates (Android debug/profile/release, web, wasm and Windows). Most of it was smooth. Here are the things that weren't, in case they save someone an afternoon.
>
> **1. `applicationIdSuffix` on the `profile` build type now breaks every Android build**
>
> If your `android/app/build.gradle.kts` does something like this, so debug and profile builds install next to the store build:
>
> ```kotlin
> getByName("profile") {
>     applicationIdSuffix = ".dev"
> }
> ```
>
> on 3.50 the build fails during configuration with:
>
> ```
> A problem occurred configuring project ':device_info_plus'.
> > Library projects cannot set applicationIdSuffix. applicationIdSuffix is set to '.dev' in build type 'profile'.
> ```
>
> The cause is in the Flutter Gradle plugin: 3.50 copies each app build type that a plugin lacks onto the plugin's library project with `initWith`. Plugins have `debug` but no `profile`, so `profile` gets copied, suffix included, and AGP rejects it on a library. `debug` is fine, because the plugin already has one.
>
> What worked for me was setting the profile id through the variant API, which only touches the app's own variant:
>
> ```kotlin
> androidComponents {
>     onVariants(selector().withBuildType("profile")) { variant ->
>         variant.applicationId.set("com.example.myapp.dev")
>     }
> }
> ```
>
> `withBuildType` quietly matches nothing if the build type ever disappears, so I also added a `check(android.buildTypes.findByName("profile") != null)`. Otherwise a profile build could end up overwriting the store install without anyone noticing.
>
> **2. flutter_local_notifications 23 needs compileSdk 37**
>
> Flutter 3.50's default `compileSdk` is still 36. With flutter_local_notifications 23 the build stops and asks for 37. `compileSdk = maxOf(flutter.compileSdkVersion, 37)` fixes it and still follows Flutter's default once that goes higher.
>
> **3. Smaller things**
>
> - `flutter create` on 3.50 writes AGP 9.3.1, Gradle 9.5.0 and minSdk 24. Nothing I build needed changes for those.
> - flutter_web_auth_2 (pulled in by appwrite) and in_app_review still apply the Kotlin Gradle Plugin, so you'll see the "Future versions of Flutter will fail to build" warning. It's a warning for now, but worth tracking.
> - go_router 18, nepali_date_picker 8 and cupertino_icons 2 are majors, but each one is mainly the move onto `material_ui`/`cupertino_ui`. None of them needed code changes in my case. google_fonts 9 is the same kind of move. I held it back only because another package of mine still pins 8.
> - On Windows, keep your build path short. With a very long temp path, `impellerc` failed to write `ink_sparkle.frag` (MAX_PATH).
>
> Disclosure: the generator is my own open-source CLI, beej ({REPO_LINK}). These notes come from upgrading it, but none of the fixes above depend on it.

- **Flair:** "Discussion" or "Tooling", whichever the subreddit offers.
- **Image:** none. Reddit text posts read better without one.
- **Link:** `{REPO_LINK}`, once, in the disclosure line.

## Facebook

> beej 1.3.0 is out, updated for Flutter 3.50 the same week it shipped.
>
> beej is a free, open-source Dart command-line tool that generates a complete, buildable Flutter app: Material via material_ui, Riverpod, routing, localization, theming, release tooling and agent config, with backend and database as explicit choices.
>
> With 1.3.0, a new app starts on Flutter 3.50 / Dart 3.14, with 3.50's Android defaults (AGP 9.3.1, Gradle 9.5.0, minSdk 24), and analyzes clean with no deprecated APIs.
>
> Get it: {PUB_LINK}
>
> #Flutter #FlutterDev #Dart

- **Image:** B (1080×1080).
- **Link:** `{PUB_LINK}`.

## Instagram

**Caption:**

> Flutter 3.50 shipped this week. beej 1.3.0 is ready for it. ✓
>
> beej is a free Dart CLI that generates a complete Flutter app in one command. New apps now start on Flutter 3.50 with material_ui, AGP 9.3, Gradle 9.5 and no deprecated APIs.
>
> Link in bio.
>
> #Flutter #FlutterDev #Dart #MobileDev #OpenSource

**Image idea:** a two-slide carousel, both 1080×1080.

1. Card B: "Flutter 3.50 ✓", with "beej 1.3.0" in the corner.
2. Terminal capture A, cropped square: `beej create tipot --yes`, then
   `flutter analyze` printing "No issues found!".

- **Link:** `{PUB_LINK}` in the bio (Instagram captions don't link).

## YouTube (Shorts script, ~30 s)

Vertical 1080×1920, screen recording with voice-over.

| Time | On screen | Voice-over |
|---|---|---|
| 0–3 s | Text: "Flutter 3.50 shipped this week." | "Flutter 3.50 shipped this week." |
| 3–10 s | Terminal: `flutter --version` → 3.50.0, then `beej create tipot --yes` running | "beej is a Dart CLI that generates a complete Flutter app, and 1.3.0 is updated for 3.50." |
| 10–18 s | `pubspec.yaml` with `sdk: ^3.14.0` and `material_ui` highlighted, then `settings.gradle.kts` with AGP 9.3.1 | "New apps start on material_ui and the new Android defaults: AGP 9.3 and Gradle 9.5." |
| 18–25 s | `flutter analyze` → "No issues found!" | "And they analyze clean on 3.50, with no deprecated APIs." |
| 25–30 s | Card B, with the pub.dev URL underneath | "beej on pub.dev. Link in the description." |

- **Description:** "beej 1.3.0 is updated for Flutter 3.50 / Dart 3.14.
  {PUB_LINK} #Flutter #FlutterDev #Dart"
- **Link:** `{PUB_LINK}` in the description.
