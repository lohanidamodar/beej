import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import '../spec/store_locales.dart';
import 'brick.dart';
import 'versions.dart';

/// The Android Gradle config: release signing with a debug fallback, and
/// core-library desugaring when something needs it.
class AndroidBrick extends Brick {
  const AndroidBrick();

  @override
  String get id => 'android';

  @override
  String get summary =>
      'Gradle release signing (key.properties, debug fallback) and desugaring';

  @override
  bool appliesTo(AppSpec spec) => spec.hasAndroid;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    // Owned outright rather than patched. `flutter create` writes a
    // ~50-line file with a TODO where the signing config belongs; replacing
    // it is more predictable than editing around that TODO.
    const TemplateFile(
      'android/build.gradle.kts.tmpl',
      'android/app/build.gradle.kts',
    ),
    const TemplateFile(
      'android/key.properties.example.tmpl',
      'android/key.properties.example',
    ),
    // Written only when the spec carried keystore details — otherwise the
    // example above is the whole story.
    if (spec.keystore != null)
      const TemplateFile('android/env.android.tmpl', '.env.android'),
  ];
}

/// fastlane lanes and store metadata for Play and the App Store.
class FastlaneBrick extends Brick {
  const FastlaneBrick();

  @override
  String get id => 'fastlane';

  @override
  String get summary => 'fastlane lanes and store metadata for Play and iOS';

  @override
  bool appliesTo(AppSpec spec) =>
      spec.tooling.fastlane && (spec.hasAndroid || spec.hasIos);

  @override
  List<TemplateFile> files(AppSpec spec) => [
    if (spec.hasAndroid) ...[
      const TemplateFile(
        'fastlane/android/Fastfile.tmpl',
        'android/fastlane/Fastfile',
      ),
      const TemplateFile(
        'fastlane/android/Appfile.tmpl',
        'android/fastlane/Appfile',
      ),
      const TemplateFile('fastlane/android/Gemfile.tmpl', 'android/Gemfile'),
      // Play metadata, one directory per listing locale. `ne-NP` is only
      // created when the app actually ships Nepali — an empty locale folder
      // makes `upload_metadata` publish blank strings.
      for (final locale in _playLocales(spec)) ...[
        TemplateFile(
          'fastlane/android/title.txt.tmpl',
          'android/fastlane/metadata/android/$locale/title.txt',
        ),
        TemplateFile(
          'fastlane/android/short_description.txt.tmpl',
          'android/fastlane/metadata/android/$locale/short_description.txt',
        ),
        TemplateFile(
          'fastlane/android/full_description.txt.tmpl',
          'android/fastlane/metadata/android/$locale/full_description.txt',
        ),
        TemplateFile(
          'fastlane/android/video.txt.tmpl',
          'android/fastlane/metadata/android/$locale/video.txt',
        ),
        // supply reads changelogs/<versionCode>.txt and falls back to
        // default.txt. With neither, a release publishes to Play with an
        // empty "What's new".
        TemplateFile(
          'fastlane/android/changelog_default.txt.tmpl',
          'android/fastlane/metadata/android/$locale/changelogs/default.txt',
        ),
      ],
    ],
    if (spec.hasIos) ...[
      // App Store listing copy, in the repo for the same reason the Play copy
      // is: so it is reviewed rather than pasted into a web form.
      //
      // One directory per App Store language, which is not the same set as
      // Play's — see `appStoreLanguage`. An app that ships Nepali still has an
      // English-only App Store listing, because Apple has no Nepali.
      for (final language in _appStoreLocales(spec)) ...[
        TemplateFile(
          'fastlane/ios/metadata/name.txt.tmpl',
          'ios/fastlane/metadata/$language/name.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/subtitle.txt.tmpl',
          'ios/fastlane/metadata/$language/subtitle.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/description.txt.tmpl',
          'ios/fastlane/metadata/$language/description.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/keywords.txt.tmpl',
          'ios/fastlane/metadata/$language/keywords.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/promotional_text.txt.tmpl',
          'ios/fastlane/metadata/$language/promotional_text.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/release_notes.txt.tmpl',
          'ios/fastlane/metadata/$language/release_notes.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/support_url.txt.tmpl',
          'ios/fastlane/metadata/$language/support_url.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/marketing_url.txt.tmpl',
          'ios/fastlane/metadata/$language/marketing_url.txt',
        ),
        TemplateFile(
          'fastlane/ios/metadata/privacy_url.txt.tmpl',
          'ios/fastlane/metadata/$language/privacy_url.txt',
        ),
      ],
      // Not localised: one copyright line for the whole app.
      const TemplateFile(
        'fastlane/ios/metadata/copyright.txt.tmpl',
        'ios/fastlane/metadata/copyright.txt',
      ),
      const TemplateFile(
        'fastlane/ios/metadata/README.md.tmpl',
        'ios/fastlane/metadata/README.md',
      ),
      const TemplateFile('fastlane/ios/Fastfile.tmpl', 'ios/fastlane/Fastfile'),
      const TemplateFile('fastlane/ios/Appfile.tmpl', 'ios/fastlane/Appfile'),
      const TemplateFile(
        'fastlane/ios/Matchfile.tmpl',
        'ios/fastlane/Matchfile',
      ),
      const TemplateFile('fastlane/ios/Gemfile.tmpl', 'ios/Gemfile'),
    ],
  ];

  /// Play listing locales, derived from the app's own locales.
  static List<String> _playLocales(AppSpec spec) => [
    'en-US',
    if (spec.locales.contains('ne')) 'ne-NP',
  ];

  /// App Store listing languages. Not the same set as [_playLocales]: Apple
  /// accepts a fixed list that has no Nepali, and a directory it does not
  /// recognise is rejected by `deliver`.
  static List<String> _appStoreLocales(AppSpec spec) => [
    for (final locale in spec.locales)
      if (appStoreLanguage(locale) != null) appStoreLanguage(locale)!,
  ];
}

/// The GitHub Actions release workflow.
class GithubWorkflowBrick extends Brick {
  const GithubWorkflowBrick();

  @override
  String get id => 'github_workflow';

  @override
  String get summary =>
      'GitHub Actions: CI on every push, plus a self-contained release workflow';

  // Note the missing `hasAndroid`: CI is worth having on a web-only or
  // desktop-only app too. Only the release half is Android-specific.
  @override
  bool appliesTo(AppSpec spec) => spec.tooling.githubWorkflow;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    // Analyze and test on push and pull request. Unconditional, because
    // every generated project has tests, and tests that never run are
    // guarantees on paper only.
    const TemplateFile('github/ci.yml.tmpl', '.github/workflows/ci.yml'),
    if (spec.hasAndroid)
      // `<% %>` delimiters, because the file is full of `${{ … }}` GitHub
      // expressions that the default `{{ }}` would try to interpolate and
      // then fail on. Rendering it rather than copying it raw is what lets
      // the Appwrite bits be conditional.
      const TemplateFile(
        'github/android-release.yml.tmpl',
        '.github/workflows/android-release.yml',
        delimiters: '<% %>',
      ),
  ];
}

/// The store-screenshot integration-test harness.
class ScreenshotsBrick extends Brick {
  const ScreenshotsBrick();

  @override
  String get id => 'screenshots';

  @override
  String get summary =>
      'integration_test screenshot harness feeding the fastlane upload lane';

  @override
  bool appliesTo(AppSpec spec) => spec.tooling.screenshots;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    const TemplateFile(
      'screenshots/screenshot_helper.dart.tmpl',
      'integration_test/screenshot_helper.dart',
    ),
    const TemplateFile(
      'screenshots/screenshot_test.dart.tmpl',
      'integration_test/screenshot_test.dart',
    ),
    const TemplateFile(
      'screenshots/integration_test_driver.dart.tmpl',
      'test_driver/integration_test.dart',
    ),

    // How the captures are framed: device bezel, background and the headline
    // under each one. Committed, so listing design is reviewed like code.
    const TemplateFile(
      'screenshots/Framefile.json.tmpl',
      'fastlane/screenshots/Framefile.json',
    ),
    const TemplateFile(
      'screenshots/README.md.tmpl',
      'fastlane/screenshots/README.md',
    ),
    const TemplateFile(
      'screenshots/title.strings.tmpl',
      'fastlane/screenshots/en-US/title.strings',
    ),
    if (spec.locales.contains('ne'))
      const TemplateFile(
        'screenshots/title_ne.strings.tmpl',
        'fastlane/screenshots/ne-NP/title.strings',
      ),

    // The capture workflows. Manual only — they rewrite the repository.
    if (spec.tooling.githubWorkflow) ...[
      // Shared, so Play and the App Store are framed by the same code and
      // come out looking like the same app.
      const TemplateFile(
        'github/frame-screenshots-action.yml.tmpl',
        '.github/actions/frame-screenshots/action.yml',
        raw: true,
      ),
      if (spec.hasAndroid)
        const TemplateFile(
          'github/screenshots-android.yml.tmpl',
          '.github/workflows/screenshots-android.yml',
          delimiters: '<% %>',
        ),
      if (spec.hasIos)
        const TemplateFile(
          'github/screenshots-ios.yml.tmpl',
          '.github/workflows/screenshots-ios.yml',
          delimiters: '<% %>',
        ),
    ],
  ];

  @override
  List<PubDep> devDependencies(AppSpec spec) => const [
    PubDep.flutterSdk(
      'integration_test',
      comment: 'Drives the store-screenshot capture. See PROJECT.md.',
    ),
  ];
}

/// Local notifications with correct time-zone handling.
class NotificationsBrick extends Brick {
  const NotificationsBrick();

  @override
  String get id => 'notifications';

  @override
  String get summary => 'local notifications with zoned scheduling';

  @override
  bool appliesTo(AppSpec spec) => spec.features.notifications;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'notifications/notification_service.dart.tmpl',
      'lib/core/notifications/notification_service.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'flutter_local_notifications',
      Versions.flutterLocalNotifications,
    ),
    PubDep.hosted(
      'timezone',
      Versions.timezone,
      comment:
          'Zoned scheduling. Together with flutter_timezone this is what makes '
          'a 9am reminder stay at 9am across a DST change.',
    ),
    PubDep.hosted('flutter_timezone', Versions.flutterTimezone),
  ];
}
