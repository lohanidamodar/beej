/// Every package version beej generates, in one place.
///
/// Bumping a generated app's dependency means editing this file and re-running
/// `dart run tool/verify_matrix.dart`. Versions were verified against pub.dev
/// on 2026-08-23 for Flutter 3.47.1 / Dart 3.13.1.
library;

abstract final class Versions {
  /// The Dart SDK constraint written into generated pubspecs. Kept a minor
  /// behind the installed SDK so a project generated today still resolves on a
  /// slightly older machine.
  static const dartSdk = '^3.13.0';

  // --- Always present ---------------------------------------------------

  /// Material, decoupled from the Flutter SDK. 1.x is the real library;
  /// 0.0.1 was a one-line re-export shim, so never accept `^0.0.1` here.
  static const materialUi = '^1.0.1';
  static const cupertinoIcons = '^1.0.9';
  static const flutterRiverpod = '^3.4.2';
  static const googleFonts = '^8.2.1';
  static const sharedPreferences = '^2.5.5';
  static const packageInfoPlus = '^10.2.1';
  static const sharePlus = '^13.3.0';
  static const urlLauncher = '^6.3.2';
  static const intl = '^0.20.3';
  static const collection = '^1.19.1';

  // --- Choices ----------------------------------------------------------

  static const goRouter = '^17.5.0';
  static const appwrite = '^25.4.0';
  static const sqflite = '^2.4.3';
  static const sqfliteCommonFfi = '^2.4.2+1';
  static const path = '^1.9.1';
  static const pathProvider = '^2.1.6';
  static const picons = '^3.0.1';

  /// 5.0.0's break is Gradle-only (Flutter's built-in Kotlin); the Dart API is
  /// unchanged from the 4.2.x line the existing apps ship.
  static const inAppUpdate = '^5.0.0';
  static const inAppReview = '^2.0.12';

  static const flutterLocalNotifications = '^22.3.0';
  static const timezone = '^0.11.1';
  static const flutterTimezone = '^5.1.0';

  static const nepaliUtils = '^3.0.8';
  static const nepaliDatePicker = '^7.0.1';

  // --- Dev ---------------------------------------------------------------

  static const flutterLints = '^6.0.0';

  // --- Git dependencies ---------------------------------------------------

  static const popupBitsDesignUrl =
      'https://github.com/lohanidamodar/popup-bits-design-system.git';
  static const popupBitsDesignPath = 'packages/popup_bits_design';
}
