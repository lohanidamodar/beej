import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import 'brick.dart';
import 'versions.dart';

/// Appwrite: client wrapper, typed failures, a generic repository, and email
/// auth wired into the router.
class AppwriteBrick extends Brick {
  const AppwriteBrick();

  @override
  String get id => 'appwrite';

  @override
  String get summary =>
      'Appwrite client, typed failures, CollectionRepository, and email auth';

  @override
  bool appliesTo(AppSpec spec) => spec.usesAppwrite;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile('appwrite/client.dart.tmpl', 'lib/core/appwrite/client.dart'),
    TemplateFile(
      'appwrite/failures.dart.tmpl',
      'lib/core/appwrite/failures.dart',
    ),
    TemplateFile(
      'appwrite/base_repository.dart.tmpl',
      'lib/core/appwrite/base_repository.dart',
    ),
    TemplateFile(
      'appwrite/auth_controller.dart.tmpl',
      'lib/features/auth/auth_controller.dart',
    ),
    TemplateFile(
      'appwrite/auth_validators.dart.tmpl',
      'lib/features/auth/auth_validators.dart',
    ),
    TemplateFile(
      'appwrite/sign_in_screen.dart.tmpl',
      'lib/features/auth/sign_in_screen.dart',
    ),
    TemplateFile(
      'appwrite/sign_up_screen.dart.tmpl',
      'lib/features/auth/sign_up_screen.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted(
      'appwrite',
      Versions.appwrite,
      comment:
          'Appwrite SDK. 1.8+ exposes the data API as TablesDB, so collection '
          'ids are passed as tableId and document ids as rowId.',
    ),
  ];

  // Appwrite caps package_info_plus below 10, and that older line pins
  // win32 ^5.5.3 — which collides with share_plus 13's win32 ^6. Something has
  // to give, and forcing the win32-6 cluster is the safe direction: Appwrite
  // touches only `PackageInfo.fromPlatform()` and `DeviceInfoPlugin()`, both
  // unchanged across these majors. (win32 itself is Windows-desktop-only, so
  // there is no Android or iOS runtime impact either way.)
  @override
  List<PubDep> dependencyOverrides(AppSpec spec) => [
    PubDep.hosted(
      'package_info_plus',
      Versions.packageInfoPlus,
      comment:
          'Appwrite caps this below 10, which drags in the win32 ^5 cluster '
          'and conflicts with share_plus 13. Appwrite only calls the stable '
          'PackageInfo.fromPlatform(), so 10.x is safe.',
    ),
    PubDep.hosted(
      'device_info_plus',
      Versions.deviceInfoPlus,
      comment:
          'Same win32 cluster. Appwrite only constructs DeviceInfoPlugin(), '
          'unchanged across these majors.',
    ),
  ];
}

/// sqflite with numbered SQL migrations.
class SqfliteBrick extends Brick {
  const SqfliteBrick();

  @override
  String get id => 'sqflite';

  @override
  String get summary => 'sqflite database with numbered SQL migrations';

  @override
  bool appliesTo(AppSpec spec) => spec.usesSqflite;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile('sqflite/database.dart.tmpl', 'lib/core/db/database.dart'),
    TemplateFile(
      'sqflite/migrations.dart.tmpl',
      'lib/core/db/migrations/migrations.dart',
    ),
    TemplateFile(
      'sqflite/v1_initial.sql.tmpl',
      'lib/core/db/migrations/v1_initial.sql',
    ),
    TemplateFile('sqflite/database_test.dart.tmpl', 'test/database_test.dart'),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted('sqflite', Versions.sqflite),
    if (spec.hasDesktop)
      PubDep.hosted(
        'sqflite_common_ffi',
        Versions.sqfliteCommonFfi,
        comment:
            'Desktop ships no bundled SQLite; this supplies one over FFI. '
            'Registered only on desktop platforms at runtime.',
      ),
    PubDep.hosted('path', Versions.path),
    PubDep.hosted('path_provider', Versions.pathProvider),
  ];

  @override
  List<PubDep> devDependencies(AppSpec spec) => [
    // Needed even on mobile-only apps: `flutter test` runs on the host, which
    // has no bundled SQLite, and test/database_test.dart is what catches a
    // malformed migration before a device does.
    if (!spec.hasDesktop)
      PubDep.hosted('sqflite_common_ffi', Versions.sqfliteCommonFfi),
  ];

  /// The `.sql` files are loaded through `rootBundle`, so they have to ship as
  /// assets even though they live under `lib/`.
  @override
  List<String> assetDirs(AppSpec spec) => const ['lib/core/db/migrations/'];
}
