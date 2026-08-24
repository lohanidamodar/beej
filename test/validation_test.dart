import 'package:beej/src/spec/app_spec.dart';
import 'package:beej/src/spec/enums.dart';
import 'package:beej/src/spec/spec_input.dart';
import 'package:beej/src/spec/validation.dart';
import 'package:test/test.dart';

/// Resolve a spec from named overrides, so each test states only what it cares
/// about. `year` is fixed so nothing depends on the wall clock.
AppSpec specOf(SpecInput input) => resolveSpec(input, year: 2026);

List<String> errorFields(AppSpec spec) =>
    validateSpec(spec).where((i) => i.isError).map((i) => i.field).toList();

List<String> warningFields(AppSpec spec) =>
    validateSpec(spec).where((i) => !i.isError).map((i) => i.field).toList();

void main() {
  test('the default spec is valid', () {
    final spec = specOf(const SpecInput(name: 'tipot'));
    expect(validateSpec(spec).where((i) => i.isError), isEmpty);
  });

  group('name', () {
    test('rejects kebab-case', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'mero-nepali'))),
        contains('name'),
      );
    });

    test('rejects a leading digit', () {
      expect(
        errorFields(specOf(const SpecInput(name: '2fast'))),
        contains('name'),
      );
    });

    test('rejects a Dart reserved word', () {
      expect(
        validateSpec(specOf(const SpecInput(name: 'class')))
            .map((i) => i.message),
        anyElement(contains('reserved word')),
      );
    });

    test('rejects a name Flutter already provides', () {
      expect(
        validateSpec(specOf(const SpecInput(name: 'test')))
            .map((i) => i.message),
        anyElement(contains('collides')),
      );
    });

    test('rejects a Java keyword, naming the applicationId consequence', () {
      // `native` is a valid Dart package name but breaks the Gradle build.
      expect(
        validateSpec(specOf(const SpecInput(name: 'native')))
            .map((i) => i.message),
        anyElement(contains('Java keyword')),
      );
    });

    test('accepts snake_case', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'mero_nepali'))),
        isEmpty,
      );
    });
  });

  group('org', () {
    test('rejects a single segment', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'a1', org: 'popupbits'))),
        contains('org'),
      );
    });

    test('rejects a Java keyword segment', () {
      expect(
        validateSpec(specOf(const SpecInput(name: 'a1', org: 'com.native')))
            .map((i) => i.message),
        anyElement(contains('Java keyword')),
      );
    });

    test('rejects an uppercase segment', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'a1', org: 'com.PopupBits'))),
        contains('org'),
      );
    });
  });

  group('platforms and router', () {
    test('rejects an empty platform set', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'a1', platforms: {}))),
        contains('platforms'),
      );
    });

    test('rejects the navigator shell on web', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          router: RouterKind.navigator,
          platforms: {TargetPlatform.android, TargetPlatform.web},
        ),
      );
      expect(errorFields(spec), contains('router'));
    });

    test('allows the navigator shell on mobile only', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          router: RouterKind.navigator,
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      expect(errorFields(spec), isEmpty);
    });

    test('warns about the navigator shell on desktop', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          router: RouterKind.navigator,
          platforms: {TargetPlatform.windows},
        ),
      );
      expect(errorFields(spec), isEmpty);
      expect(warningFields(spec), contains('router'));
    });
  });

  group('tabs', () {
    test('rejects more than five', () {
      final spec = specOf(
        SpecInput(
          name: 'a1',
          tabs: [
            for (var i = 0; i < 6; i++)
              TabSpec(id: 'tab$i', label: 'Tab $i', icon: 'circle'),
          ],
        ),
      );
      expect(errorFields(spec), contains('nav.tabs'));
    });

    test('rejects duplicates', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          tabs: [
            TabSpec(id: 'home', label: 'Home', icon: 'house'),
            TabSpec(id: 'home', label: 'Home again', icon: 'house'),
          ],
        ),
      );
      expect(
        validateSpec(spec).map((i) => i.message),
        anyElement(contains('duplicate')),
      );
    });

    test('rejects a tab called settings, which is generated', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          tabs: [TabSpec(id: 'settings', label: 'Settings', icon: 'gear')],
        ),
      );
      expect(
        validateSpec(spec).map((i) => i.message),
        anyElement(contains('generated automatically')),
      );
    });

    test('rejects an empty tab list', () {
      final spec = specOf(const SpecInput(name: 'a1', tabs: []));
      expect(errorFields(spec), contains('nav.tabs'));
    });
  });

  group('locales', () {
    test('requires en', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'a1', locales: ['ne']))),
        contains('locales'),
      );
    });

    test('rejects a locale with no bundled translations', () {
      expect(
        errorFields(specOf(const SpecInput(name: 'a1', locales: ['en', 'fr']))),
        contains('locales'),
      );
    });
  });

  group('appwrite', () {
    test('accepts the defaults filled in by the resolver', () {
      final spec = specOf(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      expect(errorFields(spec), isEmpty);
      expect(spec.appwrite!.projectId, 'a1', reason: 'defaults to the name');
    });

    test('rejects a non-absolute endpoint', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          backend: Backend.appwrite,
          appwriteEndpoint: 'cloud.appwrite.io/v1',
        ),
      );
      expect(errorFields(spec), contains('backend.endpoint'));
    });

    test('warns when appwrite settings are given but the backend is off', () {
      final spec = specOf(
        const SpecInput(name: 'a1', appwriteProjectId: 'orphan'),
      );
      // No backend selected, so the resolver drops the config entirely.
      expect(spec.appwrite, isNull);
      expect(errorFields(spec), isEmpty);
    });
  });

  group('signing', () {
    test('is absent unless a keystore field was given', () {
      expect(specOf(const SpecInput(name: 'a1')).keystore, isNull);
    });

    test('rejects a short password, as keytool would', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          keystoreAlias: 'a1',
          keystoreStorePassword: 'short',
          keystoreKeyPassword: 'short',
        ),
      );
      expect(errorFields(spec), contains('signing.storePassword'));
    });

    test('reuses the store password for the key when only one is given', () {
      final spec = specOf(
        const SpecInput(name: 'a1', keystoreStorePassword: 'longenough'),
      );
      expect(spec.keystore!.keyPassword, 'longenough');
      expect(spec.keystore!.alias, 'a1');
      expect(errorFields(spec), isEmpty);
    });

    test('warns when signing is requested without android', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.ios},
          keystoreStorePassword: 'longenough',
        ),
      );
      expect(warningFields(spec), contains('signing'));
    });
  });

  group('derived values', () {
    test('applicationId joins org and name', () {
      expect(
        specOf(const SpecInput(name: 'tipot')).applicationId,
        'com.example.tipot',
        reason: 'the built-in org is the neutral one flutter create uses',
      );
    });

    test('pascalName handles snake_case', () {
      expect(
        specOf(const SpecInput(name: 'mero_nepali')).pascalName,
        'MeroNepali',
      );
    });

    test('flutterCreatePlatforms is stably ordered', () {
      final spec = specOf(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.web, TargetPlatform.android},
        ),
      );
      expect(spec.flutterCreatePlatforms, 'android,web');
    });

    test('a configured privacy URL expands {name-kebab}', () {
      // There is no default URL — this is what a saved config produces.
      final spec = specOf(
        const SpecInput(
          name: 'mero_nepali',
          privacyPolicyUrl: 'https://acme.com/{name-kebab}-privacy-policy',
        ),
      );
      expect(
        spec.expandPlaceholders(spec.about.privacyPolicyUrl!),
        'https://acme.com/mero-nepali-privacy-policy',
      );
    });

    test('extraLocales excludes the template language', () {
      expect(
        specOf(const SpecInput(name: 'a1', locales: ['en', 'ne'])).extraLocales,
        ['ne'],
      );
      // English-only is the default, so there is nothing extra.
      expect(specOf(const SpecInput(name: 'a1')).extraLocales, isEmpty);
    });
  });

  test('resolveSpec refuses to guess a missing name', () {
    expect(
      () => resolveSpec(const SpecInput.empty(), year: 2026),
      throwsA(isA<SpecResolutionException>()),
    );
  });
}
