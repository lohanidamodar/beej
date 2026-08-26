import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
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
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'screenshots/screenshot_helper.dart.tmpl',
      'integration_test/screenshot_helper.dart',
    ),
    TemplateFile(
      'screenshots/screenshot_test.dart.tmpl',
      'integration_test/screenshot_test.dart',
    ),
    TemplateFile(
      'screenshots/integration_test_driver.dart.tmpl',
      'test_driver/integration_test.dart',
    ),
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
