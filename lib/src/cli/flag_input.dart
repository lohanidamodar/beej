import 'package:args/args.dart';

import '../spec/app_spec.dart';
import '../spec/enums.dart';
import '../spec/icon_defaults.dart';
import '../spec/spec_input.dart';
import '../spec/spec_parser.dart';

/// Declare every `beej create` flag.
///
/// Kept beside [readFlagInput] so a new option cannot be added to one without
/// the other going missing.
void addCreateFlags(ArgParser parser) {
  parser
    ..addOption(
      'spec',
      help: 'Read configuration from a YAML spec file.',
      valueHelp: 'app.yaml',
    )
    ..addOption(
      'out',
      help: 'Directory to create the project in. Defaults to the cwd.',
      valueHelp: 'path',
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Accept defaults for anything unspecified; never prompt.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Print the resolved plan and write nothing.',
    )
    ..addFlag(
      'no-pub',
      negatable: false,
      help: 'Skip `flutter pub get` and `gen-l10n` after generating.',
    )
    // --- Identity ---
    ..addOption(
      'org',
      help: 'Reverse-DNS org prefix.',
      valueHelp: 'com.popupbits',
    )
    ..addOption('display-name', help: 'Human-facing app name.')
    ..addOption('description', help: 'One-line description.')
    // --- Choices ---
    ..addOption(
      'platforms',
      help: 'Comma-separated, or "all" / "mobile".',
      valueHelp: 'android,ios,web',
    )
    ..addOption(
      'backend',
      allowed: Backend.values.map((v) => v.wire),
      help: 'Backend to wire up.',
    )
    ..addOption('appwrite-endpoint', valueHelp: 'https://cloud.appwrite.io/v1')
    ..addOption('appwrite-project')
    ..addOption('appwrite-database')
    ..addOption(
      'router',
      allowed: RouterKind.values.map((v) => v.wire),
      help: 'Routing approach.',
    )
    ..addOption(
      'nav',
      allowed: NavStyle.values.map((v) => v.wire),
      help: 'Navigation chrome.',
    )
    ..addOption(
      'tabs',
      help: 'Comma-separated destination ids. Settings is added automatically.',
      valueHelp: 'home,search',
    )
    ..addOption(
      'database',
      allowed: DatabaseKind.values.map((v) => v.wire),
      help: 'Local database.',
    )
    ..addOption('locales', help: 'Comma-separated.', valueHelp: 'en,ne')
    ..addOption(
      'design-system',
      allowed: DesignSystem.values.map((v) => v.wire),
      help: 'Where design tokens come from.',
    )
    ..addOption(
      'icons',
      allowed: IconSet.values.map((v) => v.wire),
      help: 'Icon set.',
    )
    // --- Features ---
    ..addFlag('in-app-update', help: 'Play flexible in-app update.')
    ..addFlag('notifications', help: 'Local notifications and time zones.')
    ..addFlag('nepali-dates', help: 'Bikram Sambat dates.')
    ..addFlag('review', help: 'In-app review prompt.')
    // --- Tooling ---
    ..addFlag('fastlane', help: 'fastlane lanes for Play and the App Store.')
    ..addFlag('github-workflow', help: 'GitHub Actions release workflow.')
    ..addFlag('screenshots', help: 'Store-screenshot integration test harness.')
    // --- Signing ---
    ..addOption(
      'keystore-alias',
      help: 'Generate a release keystore with this alias.',
    )
    ..addOption('keystore-password', help: 'Keystore password (min 6 chars).')
    ..addOption(
      'key-password',
      help: 'Key password. Defaults to the keystore one.',
    )
    ..addOption('keystore-dname', help: 'X.500 name passed to keytool.');
}

/// Read the flags that were actually supplied.
///
/// Only flags the user typed become non-null, so an untouched flag never
/// overrides a value from the spec file. `wasParsed` is what makes that
/// distinction possible — a bare `argResults.flag('review')` would report
/// `false` for "not mentioned" and silently beat `review: true` in the spec.
SpecInput readFlagInput(ArgResults results) {
  String? option(String name) =>
      results.wasParsed(name) ? results.option(name) : null;
  bool? flag(String name) =>
      results.wasParsed(name) ? results.flag(name) : null;

  final iconsValue = option('icons');
  final icons = iconsValue == null
      ? null
      : TargetPlatformParsers.iconSets[iconsValue];

  return SpecInput(
    displayName: option('display-name'),
    description: option('description'),
    org: option('org'),
    platforms: _parsePlatforms(option('platforms')),
    backend: _lookup(TargetPlatformParsers.backends, option('backend')),
    appwriteEndpoint: option('appwrite-endpoint'),
    appwriteProjectId: option('appwrite-project'),
    appwriteDatabaseId: option('appwrite-database'),
    router: _lookup(TargetPlatformParsers.routers, option('router')),
    navStyle: _lookup(TargetPlatformParsers.navStyles, option('nav')),
    tabs: _parseTabs(option('tabs'), icons),
    database: _lookup(TargetPlatformParsers.databases, option('database')),
    locales: _splitCsv(option('locales')),
    designSystem: _lookup(
      TargetPlatformParsers.designSystems,
      option('design-system'),
    ),
    icons: icons,
    inAppUpdate: flag('in-app-update'),
    notifications: flag('notifications'),
    nepaliDates: flag('nepali-dates'),
    review: flag('review'),
    fastlane: flag('fastlane'),
    githubWorkflow: flag('github-workflow'),
    screenshots: flag('screenshots'),
    keystoreAlias: option('keystore-alias'),
    keystoreStorePassword: option('keystore-password'),
    keystoreKeyPassword: option('key-password'),
    keystoreDname: option('keystore-dname'),
  );
}

T? _lookup<T>(Map<String, T> table, String? value) =>
    value == null ? null : table[value];

List<String>? _splitCsv(String? value) {
  if (value == null) return null;
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

Set<TargetPlatform>? _parsePlatforms(String? value) {
  if (value == null) return null;
  if (value == 'all') return TargetPlatform.values.toSet();
  if (value == 'mobile') return TargetPlatform.mobile;
  final names = _splitCsv(value)!;
  final result = <TargetPlatform>{};
  for (final name in names) {
    final platform = TargetPlatformParsers.platforms[name];
    if (platform == null) {
      throw FormatException(
        'unknown platform "$name" — expected some of '
        '${TargetPlatformParsers.platforms.keys.join(', ')}, or "all"/"mobile"',
      );
    }
    result.add(platform);
  }
  return result;
}

List<TabSpec>? _parseTabs(String? value, IconSet? icons) {
  final ids = _splitCsv(value);
  if (ids == null) return null;
  final useMaterial = icons == IconSet.material;
  return [
    for (final id in ids)
      TabSpec(
        id: id,
        label: titleizeTabId(id),
        icon: useMaterial ? defaultMaterialIcon(id) : defaultPiconsIcon(id),
      ),
  ];
}
