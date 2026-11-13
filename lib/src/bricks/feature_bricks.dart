import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import 'brick.dart';
import 'versions.dart';

/// Where the app keeps its own files: `appDataDirectory()`.
///
/// Its own brick because more than one feature needs it, and two bricks may
/// not both write the same file. The documents directory on Android and iOS,
/// the support directory on desktop, never the user's Documents folder.
class AppDataStorageBrick extends Brick {
  const AppDataStorageBrick();

  @override
  String get id => 'app_data_storage';

  @override
  String get summary =>
      'appDataDirectory(): app-private on mobile, the support dir on desktop';

  @override
  bool appliesTo(AppSpec spec) => spec.usesSqflite || spec.features.onboarding;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'storage/app_data_directory.dart.tmpl',
      'lib/core/storage/app_data_directory.dart',
    ),
    TemplateFile(
      'storage/app_data_directory_test.dart.tmpl',
      'test/app_data_directory_test.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted('path_provider', Versions.pathProvider),
  ];
}

/// A skippable welcome of a few pages, shown once on first launch.
class OnboardingBrick extends Brick {
  const OnboardingBrick();

  @override
  String get id => 'onboarding';

  @override
  String get summary =>
      'skippable first-launch onboarding, seen-flag in the app data dir';

  @override
  bool appliesTo(AppSpec spec) => spec.features.onboarding;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'onboarding/onboarding_store.dart.tmpl',
      'lib/features/onboarding/onboarding_store.dart',
    ),
    TemplateFile(
      'onboarding/onboarding_controller.dart.tmpl',
      'lib/features/onboarding/onboarding_controller.dart',
    ),
    TemplateFile(
      'onboarding/onboarding_gate.dart.tmpl',
      'lib/features/onboarding/onboarding_gate.dart',
    ),
    TemplateFile(
      'onboarding/onboarding_screen.dart.tmpl',
      'lib/features/onboarding/onboarding_screen.dart',
    ),
    TemplateFile(
      'onboarding/onboarding_test.dart.tmpl',
      'test/onboarding_test.dart',
    ),
  ];
}

/// Phosphor icons via `picons`.
///
/// No files of its own — the icon expressions are already baked into the
/// templates by the context. This brick exists to own the dependency and to
/// show up in `beej bricks` as the choice it is.
class PiconsBrick extends Brick {
  const PiconsBrick();

  @override
  String get id => 'picons';

  @override
  String get summary => 'Phosphor icons (PiconsRegular.*) in place of Material';

  @override
  bool appliesTo(AppSpec spec) => spec.usesPicons;

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'picons',
      Versions.picons,
      comment:
          'Phosphor icons. 3.x models PiconData as an extension type over '
          'IconData, so it survived IconData becoming a final class and call '
          'sites stay const.',
    ),
  ];
}

/// Play Core flexible in-app update, with the full snackbar state machine.
class InAppUpdateBrick extends Brick {
  const InAppUpdateBrick();

  @override
  String get id => 'in_app_update';

  @override
  String get summary =>
      'Play flexible in-app update, with the resume/stuck/install-ready flow';

  @override
  bool appliesTo(AppSpec spec) => spec.features.inAppUpdate;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'in_app_update/app_update_service.dart.tmpl',
      'lib/core/update/app_update_service.dart',
    ),
    TemplateFile(
      'in_app_update/update_listener.dart.tmpl',
      'lib/core/update/update_listener.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'in_app_update',
      Versions.inAppUpdate,
      comment:
          'Play Core flexible update. Flexible rather than immediate: an '
          'immediate update blocks behind a full-screen Play dialog until it '
          'finishes. Android-only; every method no-ops elsewhere.',
    ),
  ];
}

/// An `in_app_review` prompt, available from Settings.
class ReviewBrick extends Brick {
  const ReviewBrick();

  @override
  String get id => 'review';

  @override
  String get summary => 'in-app review prompt';

  @override
  bool appliesTo(AppSpec spec) => spec.features.review;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'review/review_prompt.dart.tmpl',
      'lib/core/util/review_prompt.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'in_app_review',
      Versions.inAppReview,
      comment:
          'Native review sheet. The store listing is still linked as a '
          'fallback: the platform silently ignores requestReview when it has '
          'shown one recently, so the explicit link is the only reliable path.',
    ),
  ];
}

/// Nepali (Bikram Sambat) date handling.
class NepaliDatesBrick extends Brick {
  const NepaliDatesBrick();

  @override
  String get id => 'nepali_dates';

  @override
  String get summary => 'Bikram Sambat dates and a BS date picker';

  @override
  bool appliesTo(AppSpec spec) => spec.features.nepaliDates;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'nepali_dates/nepali_date.dart.tmpl',
      'lib/core/util/nepali_date.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'nepali_utils',
      Versions.nepaliUtils,
      comment: 'BS/AD conversion, Nepali numerals and date formatting.',
    ),
    PubDep.hosted('nepali_date_picker', Versions.nepaliDatePicker),
  ];
}
