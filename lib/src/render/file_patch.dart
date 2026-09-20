/// Surgical edits to files that `flutter create` produced.
///
/// beej writes most of a project outright, but deliberately leaves the
/// platform tree to `flutter create` so that whatever changed in the last
/// Flutter release lands for free. The few values beej must still control
/// there — the launcher label, the bundle id per build configuration — cannot
/// be expressed as whole files: `project.pbxproj` carries generated UUIDs, and
/// owning `AndroidManifest.xml` would mean re-shipping the activity config
/// every time Flutter changes it. So they are expressed as anchored edits
/// instead.
///
/// **Every edit asserts what it expects to find.** A Flutter release that
/// rewrites one of these files fails generation, naming the file and the
/// anchor, rather than quietly producing a project the edit never reached. A
/// silently skipped bundle-id edit means a debug build that overwrites the
/// tester's store install, which is the exact failure the edit exists to
/// prevent — so it must never be able to fail quietly.
library;

/// One file to edit, and the edits to make to it.
class FilePatch {
  const FilePatch({
    required this.path,
    required this.description,
    required this.edits,
  });

  /// Relative to the project root, always with forward slashes.
  final String path;

  /// One line for `--dry-run`, phrased as what changes rather than how.
  final String description;

  final List<PatchEdit> edits;

  /// Apply every edit in order. Throws [PatchFailure] if any anchor is
  /// missing or matches a different number of times than expected.
  ///
  /// Not idempotent, deliberately. A patch runs once, against what
  /// `flutter create` just wrote; applying one twice fails rather than
  /// quietly producing `com.acme.app.dev.dev`.
  String applyTo(String content) {
    var result = content;
    for (final edit in edits) {
      result = edit.apply(result, path);
    }
    return result;
  }
}

/// An anchor did not match what the edit required.
///
/// Always fatal. The message names the file and what was expected, because
/// the likely cause is a Flutter release changing a generated file and the
/// fix is to re-anchor the edit in beej.
class PatchFailure implements Exception {
  PatchFailure(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

sealed class PatchEdit {
  const PatchEdit();

  /// Returns the edited content, or throws [PatchFailure].
  String apply(String content, String path);
}

/// Replace every match of [pattern], asserting how many there are.
///
/// The count is the assertion: an `android:label` attribute that suddenly
/// appears twice, or not at all, means the file is not the one this edit was
/// written against.
final class ReplaceMatch extends PatchEdit {
  const ReplaceMatch({
    required this.pattern,
    required this.replacement,
    required this.describe,
    this.expected = 1,
  });

  final RegExp pattern;

  /// Used literally — Dart's [String.replaceAll] does no `$1` substitution.
  final String replacement;

  /// What the pattern is looking for, for the failure message.
  final String describe;

  final int expected;

  @override
  String apply(String content, String path) {
    final count = pattern.allMatches(content).length;
    if (count != expected) {
      throw PatchFailure(path, 'expected $expected $describe, found $count');
    }
    return content.replaceAll(pattern, replacement);
  }
}

/// Set the `<string>` value of a top-level plist key.
///
/// Anchors on the key rather than the old value: `flutter create` derives the
/// display name through its own `titleCaseProjectName` transform, and
/// reimplementing that here would be one more thing to keep in step with
/// Flutter for no gain.
final class SetPlistString extends PatchEdit {
  const SetPlistString({required this.key, required this.value});

  final String key;
  final String value;

  @override
  String apply(String content, String path) {
    final pattern = RegExp(
      '(<key>${RegExp.escape(key)}</key>\\s*<string>)([^<]*)(</string>)',
    );
    final matches = pattern.allMatches(content).toList();
    if (matches.length != 1) {
      throw PatchFailure(
        path,
        'expected exactly one <key>$key</key> with a <string> value, '
        'found ${matches.length}',
      );
    }
    final match = matches.single;
    return content.replaceRange(
      match.start,
      match.end,
      '${match.group(1)}${_escapeXml(value)}${match.group(3)}',
    );
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Set build settings on the Runner target's build configurations in
/// `ios/Runner.xcodeproj/project.pbxproj`.
///
/// This has to happen in the pbxproj rather than in an xcconfig, which would
/// otherwise be the tidier home: `flutter create` points **both** the Profile
/// and the Release configuration at `Release.xcconfig`, so a value defined
/// there cannot distinguish a profile build from the store build, and a `.dev`
/// suffix would leak into what gets uploaded. The three `XCBuildConfiguration`
/// blocks are the only place the two differ.
///
/// The Runner blocks are identified by carrying [bundleIdentifier] exactly.
/// The RunnerTests blocks carry `<id>.RunnerTests` and the two project-level
/// blocks carry no bundle id at all, so both are left alone.
final class SetXcodeRunnerSettings extends PatchEdit {
  const SetXcodeRunnerSettings({
    required this.bundleIdentifier,
    required this.byConfiguration,
  });

  /// The unsuffixed id `flutter create --org` wrote.
  final String bundleIdentifier;

  /// Build configuration name (`Debug`, `Profile`, `Release`) to the settings
  /// to set on it. Every named configuration must be found exactly once.
  final Map<String, Map<String, String>> byConfiguration;

  static final _blockStart = RegExp(r'^\t\t[0-9A-Fa-f]{24} /\* .* \*/ = \{$');
  static final _configName = RegExp(r'^\t\t\tname = (\w+);$');
  static final _settingLine = RegExp(r'^\t\t\t\t([A-Za-z0-9_]+) = ');

  @override
  String apply(String content, String path) {
    // `flutter create` writes CRLF on Windows and LF elsewhere, and the same
    // beej release has to patch both.
    final eol = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(eol);
    final seen = <String>[];

    var i = 0;
    while (i < lines.length) {
      if (!_blockStart.hasMatch(lines[i])) {
        i++;
        continue;
      }
      final end = lines.indexOf('\t\t};', i);
      if (end == -1) break;

      final block = lines.sublist(i, end + 1);
      final name = _runnerConfigurationName(block);
      if (name != null && byConfiguration.containsKey(name)) {
        if (seen.contains(name)) {
          throw PatchFailure(
            path,
            'the Runner target has more than one "$name" build configuration '
            'carrying "$bundleIdentifier"',
          );
        }
        seen.add(name);
        lines.replaceRange(
          i,
          end + 1,
          _withSettings(block, byConfiguration[name]!, path),
        );
      }
      i = end + 1;
    }

    final missing = byConfiguration.keys.where((c) => !seen.contains(c));
    if (missing.isNotEmpty) {
      throw PatchFailure(
        path,
        'no Runner build configuration named ${missing.join(", ")} carrying '
        'PRODUCT_BUNDLE_IDENTIFIER = $bundleIdentifier',
      );
    }
    return lines.join(eol);
  }

  /// The configuration name, when [block] is a Runner `XCBuildConfiguration`.
  String? _runnerConfigurationName(List<String> block) {
    if (!block.contains('\t\t\tisa = XCBuildConfiguration;')) return null;
    if (!block.contains(
      '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $bundleIdentifier;',
    )) {
      return null;
    }
    for (final line in block) {
      final match = _configName.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// [block] with [settings] set, replacing a key already present and
  /// otherwise inserting it in the alphabetical order Xcode keeps.
  List<String> _withSettings(
    List<String> block,
    Map<String, String> settings,
    String path,
  ) {
    final lines = [...block];

    for (final entry in settings.entries) {
      // Recomputed per entry: inserting a line shifts everything after it.
      final start = lines.indexOf('\t\t\tbuildSettings = {');
      if (start == -1) {
        throw PatchFailure(
          path,
          'a Runner build configuration has no buildSettings block',
        );
      }
      final end = lines.indexOf('\t\t\t};', start);
      if (end == -1) {
        throw PatchFailure(path, 'a Runner buildSettings block is not closed');
      }

      final rendered = '\t\t\t\t${entry.key} = ${_value(entry.value)};';
      final existing = lines.indexWhere(
        (l) => _settingLine.firstMatch(l)?.group(1) == entry.key,
        start,
      );
      if (existing != -1 && existing < end) {
        lines[existing] = rendered;
        continue;
      }
      var at = end;
      for (var i = start + 1; i < end; i++) {
        final key = _settingLine.firstMatch(lines[i])?.group(1);
        if (key != null && key.compareTo(entry.key) > 0) {
          at = i;
          break;
        }
      }
      lines.insert(at, rendered);
    }
    return lines;
  }

  /// pbxproj quotes any value that is not a bare token. `com.acme.app.dev`
  /// stays bare; `Mero Nepali Dev` gets quotes.
  static String _value(String value) =>
      RegExp(r'^[A-Za-z0-9_.$()/-]+$').hasMatch(value) ? value : '"$value"';
}
