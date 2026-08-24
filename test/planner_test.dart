import 'dart:convert';

import 'package:beej/src/bricks/brick.dart';
import 'package:beej/src/bricks/registry.dart';
import 'package:beej/src/render/file_plan.dart';
import 'package:beej/src/render/planner.dart';
import 'package:beej/src/render/pub_dep.dart';
import 'package:beej/src/render/template_source.dart';
import 'package:beej/src/spec/app_spec.dart';
import 'package:beej/src/spec/enums.dart';
import 'package:beej/src/spec/spec_input.dart';
import 'package:test/test.dart';

AppSpec specOf(SpecInput input) => resolveSpec(input, year: 2026);

Future<FilePlan> planFor(SpecInput input) async {
  final source = await TemplateSource.resolve();
  return Planner(source: source, bricks: allBricks).plan(specOf(input));
}

/// Specs that between them activate every brick.
///
/// Both hygiene tests below walk this list, and one of them asserts the list
/// really does reach every brick — otherwise adding a brick with a template
/// nobody references would slip through unnoticed.
final coveringSpecs = <AppSpec>[
  specOf(const SpecInput(name: 'a1')),
  specOf(
    const SpecInput(
      name: 'a1',
      backend: Backend.appwrite,
      database: DatabaseKind.sqflite,
      notifications: true,
      nepaliDates: true,
      keystoreStorePassword: 'longenough',
    ),
  ),
  specOf(
    const SpecInput(
      name: 'a1',
      router: RouterKind.navigator,
      platforms: {TargetPlatform.android},
      icons: IconSet.material,
    ),
  ),
  specOf(const SpecInput(name: 'a1', designSystem: DesignSystem.popupBits)),
  specOf(const SpecInput(name: 'a1', locales: ['en'])),
  // Agent config off, so the brick's absence is covered as well as its
  // presence — an always-on brick hides bugs in the "off" path.
  specOf(const SpecInput(name: 'a1', agentConfig: false)),
];

/// Paths the plan writes, for readable set assertions.
Set<String> pathsOf(FilePlan plan) => plan.files.map((f) => f.path).toSet();

/// The rendered content of one planned file.
String contentOf(FilePlan plan, String path) =>
    plan.files.firstWhere((f) => f.path == path).content;

void main() {
  group('the default plan', () {
    late FilePlan plan;

    setUpAll(() async {
      plan = await planFor(const SpecInput(name: 'tipot'));
    });

    test('writes the app spine', () {
      expect(
        pathsOf(plan),
        containsAll([
          'pubspec.yaml',
          'lib/main.dart',
          'lib/core/app.dart',
          'lib/core/bootstrap.dart',
          'lib/core/router/router.dart',
          'lib/core/router/routes.dart',
          'lib/core/router/navigation.dart',
          'lib/core/theme/app_theme.dart',
          'lib/features/shell/app_shell.dart',
          'lib/features/settings/settings_screen.dart',
          'lib/features/settings/about_screen.dart',
        ]),
      );
    });

    test('writes both ARB files and the l10n config', () {
      expect(
        pathsOf(plan),
        containsAll([
          'lib/l10n/app_en.arb',
          'lib/l10n/app_ne.arb',
          'l10n.yaml',
        ]),
      );
    });

    test('points CLAUDE.md and AGENTS.md at one PROJECT.md', () {
      expect(
        pathsOf(plan),
        containsAll(['CLAUDE.md', 'AGENTS.md', 'PROJECT.md']),
      );
      expect(contentOf(plan, 'CLAUDE.md'), contains('PROJECT.md'));
      expect(contentOf(plan, 'AGENTS.md'), contains('PROJECT.md'));
    });

    test('removes the flutter create placeholder test', () {
      expect(plan.removals, contains('test/widget_test.dart'));
    });

    test('never depends on flutter_localizations', () {
      // material_ui exports GlobalMaterialLocalizations.delegates; depending on
      // the SDK package as well is how the frozen/modern types get mixed.
      expect(
        plan.dependencies.map((d) => d.name),
        isNot(contains('flutter_localizations')),
      );
    });

    test('depends on material_ui at 1.x, never the 0.0.1 shim', () {
      final materialUi = plan.dependencies.firstWhere(
        (d) => d.name == 'material_ui',
      );
      expect(materialUi.constraint, startsWith('^1.'));
    });
  });

  group('choices change the plan', () {
    test(
      'go_router and navigator write the same paths, different content',
      () async {
        final goRouter = await planFor(const SpecInput(name: 'a1'));
        final navigator = await planFor(
          const SpecInput(
            name: 'a1',
            router: RouterKind.navigator,
            platforms: {TargetPlatform.android},
          ),
        );

        // Same filenames: feature code is portable between the two.
        for (final path in [
          'lib/core/app.dart',
          'lib/core/router/router.dart',
          'lib/core/router/navigation.dart',
          'lib/features/shell/app_shell.dart',
        ]) {
          expect(pathsOf(goRouter), contains(path));
          expect(pathsOf(navigator), contains(path));
          expect(
            contentOf(goRouter, path),
            isNot(contentOf(navigator, path)),
            reason: '$path should differ between routers',
          );
        }

        expect(goRouter.dependencies.map((d) => d.name), contains('go_router'));
        expect(
          navigator.dependencies.map((d) => d.name),
          isNot(contains('go_router')),
        );
      },
    );

    test('appwrite adds the backend and auth, offline adds neither', () async {
      final offline = await planFor(const SpecInput(name: 'a1'));
      final appwrite = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );

      expect(
        pathsOf(appwrite),
        containsAll([
          'lib/core/appwrite/client.dart',
          'lib/core/appwrite/failures.dart',
          'lib/core/appwrite/base_repository.dart',
          'lib/features/auth/auth_controller.dart',
          'lib/features/auth/sign_in_screen.dart',
        ]),
      );
      expect(
        pathsOf(offline)
            .where((p) => p.contains('appwrite') || p.contains('auth')),
        isEmpty,
      );
    });

    test('appwrite carries its win32 dependency overrides', () async {
      final appwrite = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      final names = appwrite.dependencyOverrides.map((d) => d.name);
      expect(names, containsAll(['package_info_plus', 'device_info_plus']));
      // An override without a stated reason is the kind that outlives its cause.
      for (final override in appwrite.dependencyOverrides) {
        expect(override.comment, isNotNull);
      }
    });

    test('an offline app declares no overrides at all', () async {
      final offline = await planFor(const SpecInput(name: 'a1'));
      expect(offline.dependencyOverrides, isEmpty);
    });

    test('sqflite ships migrations and declares them as assets', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', database: DatabaseKind.sqflite),
      );
      expect(
        pathsOf(plan),
        containsAll([
          'lib/core/db/database.dart',
          'lib/core/db/migrations/migrations.dart',
          'lib/core/db/migrations/v1_initial.sql',
        ]),
      );
      // The .sql files load through rootBundle, so they must ship as assets
      // even though they sit under lib/.
      expect(plan.assetDirs, contains('lib/core/db/migrations/'));
    });

    test('web adds flutter_web_plugins and the path url strategy', () async {
      final withWeb = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.web},
        ),
      );
      final withoutWeb = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.android}),
      );

      expect(
        withWeb.dependencies.map((d) => d.name),
        contains('flutter_web_plugins'),
      );
      expect(
        contentOf(withWeb, 'lib/main.dart'),
        contains('usePathUrlStrategy'),
      );

      expect(
        withoutWeb.dependencies.map((d) => d.name),
        isNot(contains('flutter_web_plugins')),
      );
      expect(
        contentOf(withoutWeb, 'lib/main.dart'),
        isNot(contains('usePathUrlStrategy')),
      );
    });

    test('one feature screen is written per tab', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          tabs: [
            TabSpec(id: 'home', label: 'Home', icon: 'house'),
            TabSpec(id: 'my_stuff', label: 'My Stuff', icon: 'circle'),
          ],
        ),
      );
      expect(
        pathsOf(plan),
        containsAll([
          'lib/features/home/home_screen.dart',
          'lib/features/my_stuff/my_stuff_screen.dart',
        ]),
      );
      expect(
        contentOf(plan, 'lib/features/my_stuff/my_stuff_screen.dart'),
        contains('class MyStuffScreen'),
      );
    });

    test(
      'picons off means no picons dependency and no picons import',
      () async {
        final plan = await planFor(
          const SpecInput(name: 'a1', icons: IconSet.material),
        );
        expect(plan.dependencies.map((d) => d.name), isNot(contains('picons')));
        for (final file in plan.files) {
          expect(
            file.content,
            isNot(contains('package:picons/picons.dart')),
            reason: '${file.path} imports picons with the material icon set',
          );
        }
      },
    );

    test(
      'the Play listing gets a Nepali locale only when the app ships one',
      () async {
        final bilingual = await planFor(const SpecInput(name: 'a1'));
        final englishOnly = await planFor(
          const SpecInput(name: 'a1', locales: ['en']),
        );

        expect(
          pathsOf(bilingual),
          contains('android/fastlane/metadata/android/ne-NP/title.txt'),
        );
        // An empty locale folder makes upload_metadata publish blank strings.
        expect(pathsOf(englishOnly).where((p) => p.contains('ne-NP')), isEmpty);
      },
    );

    test('generated tooling points at repositories that exist', () async {
      // A URL in a template is never compiled or executed by any test, so a
      // wrong one is invisible until someone runs `bundle install` or a CI
      // workflow. This pins the two that generated projects depend on.
      final plan = await planFor(const SpecInput(name: 'a1'));

      expect(
        contentOf(plan, 'android/Gemfile'),
        contains('github.com/popupbits/fastlane-plugin-play_publisher'),
      );
      expect(
        contentOf(plan, '.github/workflows/android-release.yml'),
        contains(
          'popupbits/.github/.github/workflows/publish-to-play-store.yml',
        ),
      );
    });

    test('signing details produce a .env.android', () async {
      final unsigned = await planFor(const SpecInput(name: 'a1'));
      final signed = await planFor(
        const SpecInput(name: 'a1', keystoreStorePassword: 'longenough'),
      );
      expect(pathsOf(unsigned), isNot(contains('.env.android')));
      expect(pathsOf(signed), contains('.env.android'));
    });
  });

  group('rendering', () {
    test('substitutes identity everywhere it appears', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'mero_nepali',
          displayName: 'Mero Nepali',
          org: 'org.example',
        ),
      );
      final config = contentOf(plan, 'lib/core/config/app_config.dart');
      expect(config, contains("appName = 'Mero Nepali'"));
      expect(config, contains('org.example.mero_nepali'));

      expect(contentOf(plan, 'lib/main.dart'), contains('MeroNepaliApp'));
    });

    test('leaves no unrendered mustache tags behind', () async {
      // A leftover `{{tag}}` means a template referenced a context key that
      // was never added — the failure is silent in the generated file but
      // obvious here.
      for (final input in [
        const SpecInput(name: 'a1'),
        const SpecInput(
          name: 'a1',
          backend: Backend.appwrite,
          database: DatabaseKind.sqflite,
          notifications: true,
          nepaliDates: true,
        ),
        const SpecInput(
          name: 'a1',
          router: RouterKind.navigator,
          platforms: {TargetPlatform.android},
          icons: IconSet.material,
          navStyle: NavStyle.drawer,
        ),
      ]) {
        final plan = await planFor(input);
        for (final file in plan.files) {
          expect(
            file.content,
            isNot(matches(RegExp(r'\{\{[#/^]?\w'))),
            reason: 'unrendered mustache tag in ${file.path}',
          );
        }
      }
    });

    test('the GitHub workflow keeps its GitHub expressions intact', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final workflow = contentOf(plan, '.github/workflows/android-release.yml');
      // Rendered rather than copied, mustache would eat these.
      expect(workflow, contains(r'${{ inputs.release_type }}'));
    });

    test('the generated pubspec is valid YAML with quoted ranges', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          description: 'Has: a colon, which YAML would misread',
        ),
      );
      final pubspec = contentOf(plan, 'pubspec.yaml');
      expect(pubspec, contains('name: a1'));
      // A description containing ": " must be quoted or it becomes a mapping.
      expect(pubspec, contains('description: "Has: a colon'));
    });
  });

  group('agent tooling', () {
    test('a default project gets .mcp.json and every skill', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      expect(pathsOf(plan), contains('.mcp.json'));
      for (final skill in SkillKind.values) {
        expect(
          pathsOf(plan),
          contains('.claude/skills/${skill.wire}/SKILL.md'),
          reason: '${skill.wire} missing',
        );
      }
    });

    test('.mcp.json is valid JSON with appwrite off', () async {
      // The appwrite entry is comma-separated inside the object, so the
      // off-state is exactly where a trailing comma would break the file.
      final plan = await planFor(const SpecInput(name: 'a1'));
      final parsed =
          jsonDecode(contentOf(plan, '.mcp.json')) as Map<String, dynamic>;
      expect((parsed['mcpServers'] as Map).keys, ['dart']);
    });

    test('.mcp.json is valid JSON with appwrite on', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      final parsed =
          jsonDecode(contentOf(plan, '.mcp.json')) as Map<String, dynamic>;
      expect((parsed['mcpServers'] as Map).keys, ['dart', 'appwrite']);
      // Hosted + browser OAuth: no credential may be written into the repo.
      expect(contentOf(plan, '.mcp.json'), isNot(contains('key')));
    });

    test('skills can be narrowed', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', skills: [SkillKind.materialUi]),
      );
      expect(pathsOf(plan), contains('.claude/skills/material-ui/SKILL.md'));
      expect(
        pathsOf(plan).where((p) => p.contains('store-readiness')),
        isEmpty,
      );
    });

    test('agentConfig false removes both mcp and skills', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', agentConfig: false),
      );
      expect(pathsOf(plan), isNot(contains('.mcp.json')));
      expect(pathsOf(plan).where((p) => p.startsWith('.claude/')), isEmpty);
    });

    test('naming skills does not resurrect a disabled agent config', () async {
      // --no-agent-config should win outright rather than half-applying.
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          agentConfig: false,
          skills: [SkillKind.materialUi],
        ),
      );
      expect(pathsOf(plan).where((p) => p.startsWith('.claude/')), isEmpty);
    });

    test('every skill ships a SKILL.md with frontmatter', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      for (final skill in SkillKind.values) {
        final content = contentOf(
          plan,
          '.claude/skills/${skill.wire}/SKILL.md',
        );
        expect(content, startsWith('---\n'), reason: skill.wire);
        expect(content, contains('name: ${skill.wire}'), reason: skill.wire);
        expect(content, contains('description:'), reason: skill.wire);
      }
    });

    test('skills are copied verbatim, not rendered', () async {
      // They are general-purpose prose; binding them to one project's values
      // would make the copy wrong for the next project.
      final plan = await planFor(
        const SpecInput(name: 'a1', displayName: 'Zebra'),
      );
      final content = contentOf(
        plan,
        '.claude/skills/store-readiness/SKILL.md',
      );
      expect(content, isNot(contains('Zebra')));
    });
  });

  group('brick hygiene', () {
    test('the covering specs really do reach every brick', () {
      final reached = <String>{
        for (final spec in coveringSpecs)
          ...allBricks.where((b) => b.appliesTo(spec)).map((b) => b.id),
      };
      expect(
        allBricks.map((b) => b.id).toSet().difference(reached),
        isEmpty,
        reason: 'add a spec to coveringSpecs that activates these',
      );
    });

    test('every template a brick names actually ships', () async {
      final source = await TemplateSource.resolve();
      final missing = <String>[];
      for (final spec in coveringSpecs) {
        for (final brick in allBricks.where((b) => b.appliesTo(spec))) {
          for (final file in brick.files(spec)) {
            if (!source.exists(file.template)) {
              missing.add('${brick.id} -> ${file.template}');
            }
          }
        }
      }
      expect(missing, isEmpty);
    });

    test('no template ships that no brick references', () async {
      final source = await TemplateSource.resolve();
      final referenced = <String>{
        for (final spec in coveringSpecs)
          for (final brick in allBricks.where((b) => b.appliesTo(spec)))
            ...brick.files(spec).map((f) => f.template),
      };
      // An orphan is either a template someone forgot to wire up or a leftover
      // from a brick that was removed. Both are worth knowing about.
      expect(source.listAll().toSet().difference(referenced), isEmpty);
    });

    test('brick ids are unique', () {
      final ids = allBricks.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('two bricks writing the same path is a clean error', () async {
      final source = await TemplateSource.resolve();
      final colliding = [const _FakeBrick('one'), const _FakeBrick('two')];
      expect(
        () => Planner(
          source: source,
          bricks: colliding,
        ).plan(specOf(const SpecInput(name: 'a1'))),
        throwsA(
          isA<TemplateCollisionException>()
              .having((e) => e.path, 'path', 'collision.md')
              // Naming both sides is the whole point: the fix is to narrow
              // one of them, and you cannot do that without knowing which.
              .having((e) => e.firstBrick, 'firstBrick', 'one')
              .having((e) => e.secondBrick, 'secondBrick', 'two'),
        ),
      );
    });
  });
}

/// Two of these claim the same destination, to prove the planner notices.
class _FakeBrick extends Brick {
  const _FakeBrick(this.id);

  @override
  final String id;

  @override
  String get summary => 'fake';

  @override
  bool appliesTo(AppSpec spec) => true;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile('base/CLAUDE.md.tmpl', 'collision.md'),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => const [];
}
