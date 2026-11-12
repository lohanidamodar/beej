/// Every package version beej generates, in one place.
///
/// Bumping a generated app's dependency means editing this file and re-running
/// `dart run tool/verify_matrix.dart`. Versions were verified against pub.dev
/// on 2026-11-12 for Flutter 3.50.0 / Dart 3.14.
library;

abstract final class Versions {
  /// The Dart SDK constraint written into generated pubspecs.
  ///
  /// Tracks the current stable line rather than trailing it: a new app starts
  /// on the toolchain it was generated with, and several of the packages
  /// below (google_fonts 9, nepali_date_picker 8) already need Dart 3.13+.
  static const dartSdk = '^3.14.0';

  /// The Flutter SDK floor written beside [dartSdk]. 3.50 is where
  /// `flutter create` started writing `material_ui` itself, and where it moved
  /// to AGP 9 and Gradle 9.
  static const flutterSdk = '>=3.50.0';

  /// Flutter version the generated release workflow builds with. Keep it in
  /// step with the toolchain the apps are developed against.
  static const flutterForCi = '3.50.0';

  // --- Always present ---------------------------------------------------

  /// Material, decoupled from the Flutter SDK. 1.x is the real library;
  /// 0.0.1 was a one-line re-export shim, so never accept `^0.0.1` here.
  static const materialUi = '^1.1.0';
  static const cupertinoIcons = '^2.0.0';
  static const flutterRiverpod = '^3.4.2';

  /// Lets a coding agent drive the running app over the VM service. Only the
  /// debug binding is installed, so a release build carries nothing of it.
  static const marionetteFlutter = '^0.7.0';

  /// Held on 8: popup_bits_design (the shared design system, a git
  /// dependency) pins `^8.2.1`, so 9 cannot resolve beside it. Move both
  /// together. 8.2.1 analyzes clean on Flutter 3.50.
  static const googleFonts = '^8.2.1';
  static const sharedPreferences = '^2.5.5';
  static const packageInfoPlus = '^10.2.1';

  static const sharePlus = '^13.3.0';
  static const urlLauncher = '^6.3.2';
  static const intl = '^0.20.3';
  static const collection = '^1.19.1';

  // --- Choices ----------------------------------------------------------

  static const goRouter = '^18.1.4';

  /// Held on 26: 27 targets Appwrite server 2.3 and drops `Account.listLogs`
  /// and `Client.setDevKey`. An SDK major has to match the server the apps
  /// talk to, so it moves with the backend, not with Flutter.
  static const appwrite = '^26.1.0';
  static const sqflite = '^2.4.3';
  static const sqfliteCommonFfi = '^2.4.2+1';
  static const path = '^1.9.1';
  static const pathProvider = '^2.1.6';
  static const picons = '^3.0.1';

  /// 5.0.0's break is Gradle-only (Flutter's built-in Kotlin); the Dart API is
  /// unchanged from the 4.2.x line the existing apps ship.
  static const inAppUpdate = '^5.0.0';
  static const inAppReview = '^2.0.12';

  static const flutterLocalNotifications = '^23.0.1';
  static const timezone = '^0.11.1';
  static const flutterTimezone = '^5.1.0';

  static const nepaliUtils = '^3.0.8';
  static const nepaliDatePicker = '^8.0.0';

  // --- Dev ---------------------------------------------------------------

  static const flutterLints = '^6.0.0';

  // --- Git dependencies ---------------------------------------------------

  static const popupBitsDesignUrl =
      'https://github.com/lohanidamodar/popup-bits-design-system.git';
  static const popupBitsDesignPath = 'packages/popup_bits_design';
}
