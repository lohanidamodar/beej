import 'package:beej/src/spec/enums.dart';
import 'package:beej/src/spec/spec_input.dart';
import 'package:beej/src/spec/spec_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseSpecYaml', () {
    test('an empty document yields an empty input', () {
      expect(parseSpecYaml('').name, isNull);
      expect(parseSpecYaml('# just a comment').name, isNull);
    });

    test('reads the scalar fields', () {
      final input = parseSpecYaml('''
name: tipot
displayName: Tipot
description: Notes and todos.
org: com.popupbits
''');
      expect(input.name, 'tipot');
      expect(input.displayName, 'Tipot');
      expect(input.description, 'Notes and todos.');
      expect(input.org, 'com.popupbits');
    });

    test('platforms accepts a list, "all", and "mobile"', () {
      expect(
        parseSpecYaml('platforms: [android, web]').platforms,
        {TargetPlatform.android, TargetPlatform.web},
      );
      expect(
        parseSpecYaml('platforms: all').platforms,
        TargetPlatform.values.toSet(),
      );
      expect(
        parseSpecYaml('platforms: mobile').platforms,
        {TargetPlatform.android, TargetPlatform.ios},
      );
    });

    test('rejects an unknown platform by name', () {
      expect(
        () => parseSpecYaml('platforms: [android, tizen]'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            contains('unknown platform "tizen"'),
          ),
        ),
      );
    });

    test('backend accepts the string shorthand', () {
      final input = parseSpecYaml('backend: appwrite');
      expect(input.backend, Backend.appwrite);
      expect(input.appwriteEndpoint, isNull);
    });

    test('backend accepts the full mapping', () {
      final input = parseSpecYaml('''
backend:
  kind: appwrite
  endpoint: https://appwrite.example.com/v1
  projectId: proj
  databaseId: db
''');
      expect(input.backend, Backend.appwrite);
      expect(input.appwriteEndpoint, 'https://appwrite.example.com/v1');
      expect(input.appwriteProjectId, 'proj');
      expect(input.appwriteDatabaseId, 'db');
    });

    test('tabs accept bare strings and infer label + picons icon', () {
      final tabs = parseSpecYaml('''
nav:
  tabs: [home, my_stuff]
''').tabs!;
      expect(tabs.map((t) => t.id), ['home', 'my_stuff']);
      expect(tabs[0].label, 'Home');
      expect(tabs[0].icon, 'house');
      expect(tabs[1].label, 'My Stuff');
      // Unknown id falls back to a neutral shape rather than a wrong guess.
      expect(tabs[1].icon, 'circle');
    });

    test('tabs accept full mappings and honour an explicit icon', () {
      final tabs = parseSpecYaml('''
nav:
  tabs:
    - id: feed
      label: Timeline
      icon: newspaper
''').tabs!;
      expect(tabs.single.id, 'feed');
      expect(tabs.single.label, 'Timeline');
      expect(tabs.single.icon, 'newspaper');
    });

    test('tab icons follow the chosen icon set', () {
      final tabs = parseSpecYaml('''
icons: material
nav:
  tabs: [search]
''').tabs!;
      expect(tabs.single.icon, 'search');
    });

    test('reads nested feature, about and tooling blocks', () {
      final input = parseSpecYaml('''
features:
  inAppUpdate: false
  notifications: true
about:
  supportEmail: hi@example.com
tooling:
  fastlane: false
''');
      expect(input.inAppUpdate, isFalse);
      expect(input.notifications, isTrue);
      expect(input.nepaliDates, isNull, reason: 'unmentioned stays unset');
      expect(input.supportEmail, 'hi@example.com');
      expect(input.fastlane, isFalse);
    });

    test('reads the signing block', () {
      final input = parseSpecYaml('''
signing:
  alias: tipot
  storePassword: hunter2ish
  keyPassword: hunter2ish
''');
      expect(input.keystoreAlias, 'tipot');
      expect(input.hasAnyKeystoreField, isTrue);
    });

    test('rejects an unknown top-level key and suggests the near miss', () {
      expect(
        () => parseSpecYaml('platform: android'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('unknown key "platform"'), contains('platforms')),
          ),
        ),
      );
    });

    test('rejects an unknown nested key', () {
      expect(
        () => parseSpecYaml('features:\n  inAppUpdates: true'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            contains('features.inAppUpdates'),
          ),
        ),
      );
    });

    test('rejects an unknown enum value listing the valid ones', () {
      expect(
        () => parseSpecYaml('router: auto_route'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('unknown router'), contains('go_router')),
          ),
        ),
      );
    });

    test('rejects a wrongly-typed scalar', () {
      expect(
        () => parseSpecYaml('features:\n  review: yes please'),
        throwsA(isA<SpecParseException>()),
      );
    });

    test('rejects malformed YAML with a readable message', () {
      expect(
        () => parseSpecYaml('name: [unclosed'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            contains('not valid YAML'),
          ),
        ),
      );
    });

    test('rejects a non-mapping document', () {
      expect(
        () => parseSpecYaml('- a\n- b'),
        throwsA(
          isA<SpecParseException>().having(
            (e) => e.message,
            'message',
            contains('mapping at the top level'),
          ),
        ),
      );
    });
  });

  group('SpecInput.overriddenBy', () {
    test('the later layer wins field by field', () {
      const base = SpecInput(name: 'a', org: 'com.a', router: RouterKind.navigator);
      const top = SpecInput(name: 'b');
      final merged = base.overriddenBy(top);
      expect(merged.name, 'b');
      expect(merged.org, 'com.a', reason: 'unset in the top layer');
      expect(merged.router, RouterKind.navigator);
    });

    test('an explicit false still overrides', () {
      const base = SpecInput(inAppUpdate: true);
      const top = SpecInput(inAppUpdate: false);
      expect(base.overriddenBy(top).inAppUpdate, isFalse);
    });
  });
}
