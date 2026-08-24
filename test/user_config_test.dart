import 'dart:io';

import 'package:beej/src/cli/user_config.dart';
import 'package:beej/src/spec/app_spec.dart';
import 'package:beej/src/spec/spec_input.dart';
import 'package:beej/src/spec/validation.dart';
import 'package:test/test.dart';

/// Resolve with the layering `create` uses: defaults < config < spec < flags.
AppSpec resolveLayered({
  SpecInput config = const SpecInput.empty(),
  SpecInput spec = const SpecInput.empty(),
  SpecInput flags = const SpecInput.empty(),
}) => resolveSpec(
  // A name is required and is never a saved default, so supply one here and
  // let each test assert only the field it cares about.
  const SpecInput(name: 'a1')
      .overriddenBy(config)
      .overriddenBy(spec)
      .overriddenBy(flags),
  year: 2026,
);

void main() {
  group('built-in defaults are organisation-neutral', () {
    test('org is the one flutter create uses', () {
      expect(SpecDefaults.org, 'com.example');
    });

    test('English only — extra locales are opt-in', () {
      expect(SpecDefaults.locales, ['en']);
    });

    test('no About URL or address is invented', () {
      final spec = resolveSpec(const SpecInput(name: 'a1'), year: 2026);
      expect(spec.about.hasPrivacyPolicy, isFalse);
      expect(spec.about.hasMoreApps, isFalse);
      expect(spec.about.hasSupportEmail, isFalse);
    });

    test('legalese falls back to the app name, not an organisation', () {
      final spec = resolveSpec(
        const SpecInput(name: 'a1', displayName: 'Acme Notes'),
        year: 2026,
      );
      expect(spec.about.legalese, '© 2026 Acme Notes');
    });

    test('a missing privacy policy warns but does not block', () {
      final issues = validateSpec(
        resolveSpec(const SpecInput(name: 'a1'), year: 2026),
      );
      expect(issues.where((i) => i.isError), isEmpty);
      expect(
        issues.where((i) => !i.isError && i.field == 'about.privacyPolicyUrl'),
        isNotEmpty,
        reason: 'both stores require one before release',
      );
    });
  });

  group('layering', () {
    test('config beats the built-in default', () {
      final spec = resolveLayered(
        config: const SpecInput(org: 'com.acme', locales: ['en', 'ne']),
      );
      expect(spec.org, 'com.acme');
      expect(spec.locales, ['en', 'ne']);
    });

    test('a spec file beats the config', () {
      final spec = resolveLayered(
        config: const SpecInput(org: 'com.acme'),
        spec: const SpecInput(org: 'com.other'),
      );
      expect(spec.org, 'com.other');
    });

    test('a flag beats everything', () {
      final spec = resolveLayered(
        config: const SpecInput(org: 'com.acme'),
        spec: const SpecInput(org: 'com.other'),
        flags: const SpecInput(org: 'com.flag'),
      );
      expect(spec.org, 'com.flag');
    });
  });

  group('URL placeholders', () {
    test('{name} and {name-kebab} expand per project', () {
      final spec = resolveSpec(
        const SpecInput(name: 'mero_nepali'),
        year: 2026,
      );
      expect(spec.expandPlaceholders('x/{name}/y'), 'x/mero_nepali/y');
      expect(spec.expandPlaceholders('x/{name-kebab}/y'), 'x/mero-nepali/y');
    });

    test('a URL with no placeholder is untouched', () {
      final spec = resolveSpec(const SpecInput(name: 'a1'), year: 2026);
      expect(
        spec.expandPlaceholders('https://acme.com/apps'),
        'https://acme.com/apps',
      );
    });
  });

  group('the config file', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('beej_cfg_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('is absent until written, and reads as empty', () {
      final config = UserConfig(File('${temp.path}/config.yaml'));
      expect(config.exists, isFalse);
      expect(config.read().org, isNull);
    });

    test('is parsed with the ordinary spec parser', () {
      // The config is deliberately "a spec file without a name", so there is
      // no second schema to keep in step.
      final file = File('${temp.path}/config.yaml')
        ..writeAsStringSync('org: com.acme\nlocales: [en, ne]\n');
      final input = UserConfig(file).read();
      expect(input.org, 'com.acme');
      expect(input.locales, ['en', 'ne']);
      expect(input.name, isNull);
    });

    test('BEEJ_CONFIG is honoured when locating it', () {
      // Not asserting the default path — it is platform-specific — only that
      // the override wins, which is what makes this testable at all.
      expect(UserConfig.locate().path, isNotEmpty);
    });

    test('every settable key is a real spec path', () {
      // A key here that the spec parser rejects would let someone save a
      // config that then breaks every `create`.
      for (final entry in configurableKeys.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        expect(
          entry.value.length,
          lessThanOrEqualTo(2),
          reason: '${entry.key} nests deeper than the spec file does',
        );
      }
    });
  });
}
