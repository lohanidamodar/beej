import 'dart:io';

import 'package:path/path.dart' as p;

import '../spec/spec_input.dart';
import '../spec/spec_parser.dart';

/// beej's own preferences: the defaults you do not want to retype.
///
/// The file is **a spec file with no `name`**, so it accepts exactly the same
/// keys as `--spec` and needs no second schema, parser or documentation. It
/// layers underneath a project's spec:
///
///   built-in defaults  <  user config  <  spec file  <  flags
///
/// This is what keeps beej usable by anyone while still letting one
/// organisation keep its own org id, About URLs and locales permanently.
class UserConfig {
  const UserConfig(this.file);

  final File file;

  /// `$XDG_CONFIG_HOME/beej/config.yaml`, or the platform equivalent.
  ///
  /// `BEEJ_CONFIG` overrides it outright, which is what tests use and what
  /// lets a machine keep more than one profile.
  static UserConfig locate() {
    final override = Platform.environment['BEEJ_CONFIG'];
    if (override != null && override.isNotEmpty) {
      return UserConfig(File(override));
    }

    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;

    final base = Platform.isWindows
        ? (Platform.environment['APPDATA'] ??
              p.join(home, 'AppData', 'Roaming'))
        : (Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config'));

    return UserConfig(File(p.join(base, 'beej', 'config.yaml')));
  }

  bool get exists => file.existsSync();

  String get path => file.path;

  /// Parse the config as a [SpecInput], or an empty one when absent.
  ///
  /// Throws [SpecParseException] on a malformed file — silently ignoring a
  /// broken config would mean quietly generating with the wrong org.
  SpecInput read() {
    if (!exists) return const SpecInput.empty();
    return parseSpecYaml(file.readAsStringSync(), source: path);
  }

  /// Raw text, for `beej config` to display and edit.
  String readRaw() => exists ? file.readAsStringSync() : '';

  void write(String contents) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
}

/// Keys `beej config set` accepts, mapped to where they live in the file.
///
/// Deliberately a subset: things that are genuinely per-person or
/// per-organisation. Per-project choices (name, platforms, backend) belong on
/// the command line, not in a preference that would silently apply everywhere.
const Map<String, List<String>> configurableKeys = <String, List<String>>{
  'org': ['org'],
  'locales': ['locales'],
  'icons': ['icons'],
  'designSystem': ['designSystem'],
  'router': ['router'],
  'database': ['database'],
  'about.privacyPolicyUrl': ['about', 'privacyPolicyUrl'],
  'about.moreAppsUrl': ['about', 'moreAppsUrl'],
  'about.supportEmail': ['about', 'supportEmail'],
  'about.legalese': ['about', 'legalese'],
  'tooling.fastlane': ['tooling', 'fastlane'],
  'tooling.githubWorkflow': ['tooling', 'githubWorkflow'],
  'tooling.screenshots': ['tooling', 'screenshots'],
  'agents.mcp': ['agents', 'mcp'],
  'agents.skills': ['agents', 'skills'],
  'features.inAppUpdate': ['features', 'inAppUpdate'],
  'features.notifications': ['features', 'notifications'],
  'features.nepaliDates': ['features', 'nepaliDates'],
  'features.review': ['features', 'review'],
};

/// Values that must be written as a YAML list rather than a scalar.
const Set<String> listValuedKeys = {'locales', 'agents.skills'};
