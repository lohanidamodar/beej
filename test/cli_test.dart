import 'dart:convert';

import 'package:args/args.dart';
import 'package:beej/src/bricks/registry.dart';
import 'package:beej/src/cli/bricks_command.dart';
import 'package:beej/src/cli/flag_input.dart';
import 'package:beej/src/cli/spec_command.dart';
import 'package:beej/src/cli/spec_schema.dart';
import 'package:beej/src/spec/enums.dart';
import 'package:beej/src/spec/spec_parser.dart';
import 'package:test/test.dart';

ArgResults parseFlags(List<String> arguments) {
  final parser = ArgParser();
  addCreateFlags(parser);
  return parser.parse(arguments);
}

void main() {
  group('flags', () {
    test('an unmentioned flag stays unset, so a spec file still wins', () {
      // The bug this guards: reading `results.flag('review')` unconditionally
      // returns false for "not mentioned", which would silently override
      // `review: true` from the spec file.
      final input = readFlagInput(parseFlags(['tipot']));
      expect(input.review, isNull);
      expect(input.inAppUpdate, isNull);
      expect(input.fastlane, isNull);
    });

    test('an explicit negation is recorded as false', () {
      final input = readFlagInput(parseFlags(['--no-review']));
      expect(input.review, isFalse);
    });

    test('reads the choice options', () {
      final input = readFlagInput(
        parseFlags([
          '--backend',
          'appwrite',
          '--router',
          'navigator',
          '--nav',
          'drawer',
          '--database',
          'sqflite',
          '--icons',
          'material',
        ]),
      );
      expect(input.backend, Backend.appwrite);
      expect(input.router, RouterKind.navigator);
      expect(input.navStyle, NavStyle.drawer);
      expect(input.database, DatabaseKind.sqflite);
      expect(input.icons, IconSet.material);
    });

    test('platforms accepts a list, "all" and "mobile"', () {
      expect(
        readFlagInput(parseFlags(['--platforms', 'android,web'])).platforms,
        {TargetPlatform.android, TargetPlatform.web},
      );
      expect(
        readFlagInput(parseFlags(['--platforms', 'all'])).platforms,
        TargetPlatform.values.toSet(),
      );
      expect(readFlagInput(parseFlags(['--platforms', 'mobile'])).platforms, {
        TargetPlatform.android,
        TargetPlatform.ios,
      });
    });

    test('an unknown platform is rejected with the valid ones listed', () {
      expect(
        () => readFlagInput(parseFlags(['--platforms', 'tizen'])),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('tizen'), contains('android')),
          ),
        ),
      );
    });

    test('tabs pick icons matching the chosen set', () {
      final picons = readFlagInput(parseFlags(['--tabs', 'search'])).tabs!;
      expect(picons.single.icon, 'magnifyingGlass');

      final material = readFlagInput(
        parseFlags(['--tabs', 'search', '--icons', 'material']),
      ).tabs!;
      expect(material.single.icon, 'search');
    });

    test('an unknown enum value is rejected by the parser itself', () {
      expect(
        () => parseFlags(['--router', 'auto_route']),
        throwsA(isA<ArgParserException>()),
      );
    });
  });

  group('beej spec --schema', () {
    late Map<String, dynamic> schema;

    setUpAll(() {
      schema = jsonDecode(specJsonSchema()) as Map<String, dynamic>;
    });

    test('is valid JSON with the expected shape', () {
      expect(schema[r'$schema'], contains('json-schema.org'));
      expect(schema['additionalProperties'], isFalse);
    });

    test('describes every top-level spec key', () {
      final properties = (schema['properties'] as Map).keys.toSet();
      // Same set the YAML parser accepts. Drift here means an agent writes a
      // spec against the schema and the parser rejects it.
      expect(
        properties,
        containsAll([
          'name',
          'displayName',
          'description',
          'org',
          'platforms',
          'backend',
          'router',
          'nav',
          'database',
          'locales',
          'designSystem',
          'icons',
          'features',
          'about',
          'tooling',
          'signing',
        ]),
      );
    });

    test('enumerates the real values, not a hand-copied list', () {
      final router = (schema['properties'] as Map)['router'] as Map;
      expect(
        (router['enum'] as List).cast<String>(),
        RouterKind.values.map((v) => v.wire).toList(),
      );
    });
  });

  group('beej spec --example', () {
    test('parses cleanly through the real parser', () {
      // The example is the first thing anyone copies. If it does not parse,
      // that is the worst possible first impression.
      final input = parseSpecYaml(exampleSpec(), source: 'example');
      expect(input.name, 'tipot');
      expect(input.backend, Backend.appwrite);
      expect(input.router, RouterKind.goRouter);
      expect(input.tabs!.map((t) => t.id), ['home', 'notes']);
      expect(input.locales, ['en', 'ne']);
    });
  });

  group('beej bricks', () {
    test('every brick has an id, a summary and a stated trigger', () {
      for (final brick in allBricks) {
        expect(brick.id, isNotEmpty);
        expect(brick.summary, isNotEmpty);
        expect(
          triggerFor(brick.id),
          isNotEmpty,
          reason: '${brick.id} has no trigger description',
        );
      }
    });
  });
}
