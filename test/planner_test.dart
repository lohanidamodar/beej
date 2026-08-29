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
  specOf(const SpecInput(name: 'a1', locales: ['en', 'ne'])),
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

    test('writes an ARB per locale and the l10n config', () async {
      // English only by default; Nepali and anything else are opt-in.
      expect(pathsOf(plan), containsAll(['lib/l10n/app_en.arb', 'l10n.yaml']));
      expect(pathsOf(plan), isNot(contains('lib/l10n/app_ne.arb')));

      final bilingual = await planFor(
        const SpecInput(name: 'a1', locales: ['en', 'ne']),
      );
      expect(pathsOf(bilingual), contains('lib/l10n/app_ne.arb'));
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
        final bilingual = await planFor(
          const SpecInput(name: 'a1', locales: ['en', 'ne']),
        );
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

    test('the Gemfile points at a repository that exists', () async {
      // A URL in a template is never compiled or executed by any test, so a
      // wrong one stays invisible until someone runs `bundle install`. This is
      // the one external repository a generated project still needs.
      final plan = await planFor(const SpecInput(name: 'a1'));
      expect(
        contentOf(plan, 'android/Gemfile'),
        contains('github.com/popupbits/fastlane-plugin-play_publisher'),
      );
    });

    test('the release workflow is self-contained', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final workflow = contentOf(plan, '.github/workflows/android-release.yml');

      // No `uses:` of a reusable workflow — a private one makes the pipeline
      // unrunnable for anyone who cannot read that repository.
      expect(workflow, isNot(contains('popupbits/.github')));
      expect(workflow, isNot(contains('workflow_call')));
      expect(workflow, contains('bundle exec fastlane'));

      // The `<% %>` delimiters exist so these survive rendering.
      expect(workflow, contains(r'${{ inputs.release_type }}'));
      expect(workflow, contains(r'${{ secrets.ANDROID_KEYSTORE_BASE64 }}'));
      expect(workflow, isNot(contains('<%')));
    });

    test(
      'the workflow carries appwrite secrets only when appwrite is on',
      () async {
        final offline = await planFor(const SpecInput(name: 'a1'));
        final appwrite = await planFor(
          const SpecInput(name: 'a1', backend: Backend.appwrite),
        );
        const path = '.github/workflows/android-release.yml';

        expect(contentOf(appwrite, path), contains('APPWRITE_ENDPOINT'));
        expect(contentOf(offline, path), isNot(contains('APPWRITE')));
      },
    );

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
          // ARB files are rendered with `<% %>`, because an ICU plural is
          // written `other{{count} items}` and that `{{` would otherwise be
          // read as a mustache tag. Check for the delimiters the file was
          // actually rendered with.
          final isArb = file.path.endsWith('.arb');
          final leftover = isArb
              ? RegExp(r'<%[#/^]?\w')
              : RegExp(r'\{\{[#/^]?\w');
          expect(
            file.content,
            isNot(matches(leftover)),
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

    test('CI runs analyze and test on push, for every platform', () async {
      for (final platforms in [
        {TargetPlatform.android},
        {TargetPlatform.web},
      ]) {
        final plan = await planFor(SpecInput(name: 'a1', platforms: platforms));
        final ci = contentOf(plan, '.github/workflows/ci.yml');
        expect(ci, contains('flutter analyze'));
        expect(ci, contains('flutter test'));
        // Release is manual-dispatch only; CI is what has to fire on push.
        expect(ci, contains('push:'));
        expect(ci, contains('pull_request:'));
      }
    });

    test(
      'a web-only project gets CI but no Android release workflow',
      () async {
        final plan = await planFor(
          const SpecInput(name: 'a1', platforms: {TargetPlatform.web}),
        );
        final paths = plan.files.map((f) => f.path);
        expect(paths, contains('.github/workflows/ci.yml'));
        expect(paths, isNot(contains('.github/workflows/android-release.yml')));
      },
    );

    test('Play metadata carries a changelog fallback per locale', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', locales: ['en', 'ne']),
      );
      final paths = plan.files.map((f) => f.path);
      // supply falls back to default.txt when no file matches the
      // versionCode. Without it a release ships with empty release notes.
      expect(
        paths,
        contains(
          'android/fastlane/metadata/android/en-US/changelogs/default.txt',
        ),
      );
      expect(
        paths,
        contains(
          'android/fastlane/metadata/android/ne-NP/changelogs/default.txt',
        ),
      );
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

  group('the run-on-a-device rule', () {
    const path = 'PROJECT.md';

    test('appears in the workflow, the testing section and the checklist', () async {
      final guide = contentOf(await planFor(const SpecInput(name: 'a1')), path);
      // Three places, because an agent reads for "what does done mean" in
      // different spots depending on the task.
      expect(guide, contains('Analysis is not proof'));
      expect(guide, contains('`flutter run`'));
      expect(guide, contains('flutter devices'));
      expect(guide, contains('Ran on a device or emulator'));
      // The escape hatch has to be explicit, or the rule quietly becomes a lie.
      expect(guide, contains('If you genuinely cannot run it'));
    });

    test('never points at a Tooling section that was not generated', () async {
      // No MCP and no Android means no Tooling section; a cross-reference to
      // it would be a dangling pointer in the shipped guide.
      final guide = contentOf(
        await planFor(
          const SpecInput(
            name: 'a1',
            platforms: {TargetPlatform.web},
            agentConfig: false,
          ),
        ),
        path,
      );
      expect(guide, isNot(contains('Tooling — use it when it is there')));
      expect(guide, isNot(contains('Dart MCP')));
      expect(guide, isNot(contains('android emulator')));
      // The rule itself survives regardless.
      expect(guide, contains('Analysis is not proof'));
    });
  });

  group('the store skills', () {
    test('ships both, and they answer different questions', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));

      final readiness = contentOf(
        plan,
        '.claude/skills/store-readiness/SKILL.md',
      );
      final aso = contentOf(
        plan,
        '.claude/skills/app-store-optimization/SKILL.md',
      );

      // Acceptance vs performance. If these ever converge, one of them has
      // drifted into the other's job.
      expect(readiness, contains('readiness'));
      expect(aso, contains('found'));
      expect(
        aso,
        contains('store-readiness'),
        reason: 'ASO should point at the audit skill rather than repeat it',
      );

      // Per-store references, because the two stores need opposite advice.
      expect(
        pathsOf(plan),
        containsAll([
          '.claude/skills/app-store-optimization/references/apple.md',
          '.claude/skills/app-store-optimization/references/play.md',
        ]),
      );
    });

    test('ASO knows where this project keeps its Play listing', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final play = contentOf(
        plan,
        '.claude/skills/app-store-optimization/references/play.md',
      );
      // The path the fastlane brick actually writes.
      expect(play, contains('android/fastlane/metadata/android/'));
      expect(play, contains('short_description.txt'));
    });
  });

  group('the Appwrite MCP server', () {
    const doc = 'docs/agent-tooling.md';

    test('is the hosted one, with no credential in the repo', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      final config = contentOf(plan, '.mcp.json');
      expect(config, contains('https://mcp.appwrite.io/'));
      expect(config, contains('"type": "http"'));
      // Browser OAuth is the whole reason this file is safe to commit.
      expect(config.toLowerCase(), isNot(contains('api_key')));
      expect(config.toLowerCase(), isNot(contains('secret')));
    });

    test('says nothing about self-hosting when pointed at Cloud', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      expect(
        contentOf(plan, doc),
        isNot(contains('does not point at Appwrite Cloud')),
      );
    });

    test(
      'warns when the endpoint is not Cloud, since hosted cannot reach it',
      () async {
        final plan = await planFor(
          const SpecInput(
            name: 'a1',
            backend: Backend.appwrite,
            appwriteEndpoint: 'https://appwrite.internal.example.com/v1',
          ),
        );
        final guide = contentOf(plan, doc);
        expect(guide, contains('does not point at Appwrite Cloud'));
        expect(guide, contains('uvx mcp-server-appwrite'));
        expect(guide, contains('https://appwrite.internal.example.com/v1'));
        expect(guide, contains('Do not commit that API key'));
      },
    );
  });

  group('the PROJECT.md tooling section', () {
    const path = 'PROJECT.md';

    test('names the Dart MCP and the Android CLI when both apply', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.android}),
      );
      final guide = contentOf(plan, path);
      expect(guide, contains('Dart / Flutter MCP'));
      expect(guide, contains('Android CLI'));
      expect(guide, contains('android screen capture'));
    });

    test('drops the Android CLI when android is not a target', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.web}),
      );
      final guide = contentOf(plan, path);
      expect(guide, contains('Dart / Flutter MCP'));
      expect(guide, isNot(contains('Android CLI')));
    });

    test('omits the whole section when there is no tool to name', () async {
      // Neither MCP nor Android — an empty heading would be worse than none.
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.web},
          agentConfig: false,
        ),
      );
      final guide = contentOf(plan, path);
      expect(guide, isNot(contains('Tooling — use it when it is there')));
      expect(guide, isNot(contains('Android CLI')));
      // The rest of the guide is unaffected.
      expect(guide, contains('Before you call it done'));
    });
  });
  group('error capture', () {
    test('every project captures errors, whatever else it chose', () async {
      for (final input in [
        const SpecInput(name: 'a1'),
        const SpecInput(name: 'a1', router: RouterKind.navigator),
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      ]) {
        final plan = await planFor(input);
        final paths = plan.files.map((f) => f.path);
        expect(paths, contains('lib/core/error/error_logger.dart'));
        expect(paths, contains('lib/core/error/error_record.dart'));
        expect(
          paths,
          contains('lib/features/settings/diagnostics_screen.dart'),
        );
        expect(paths, contains('test/error_logger_test.dart'));
      }
    });

    test('main installs the handlers before it does anything else', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final main = contentOf(plan, 'lib/main.dart');
      // Order matters: a failure during startup is exactly the one worth
      // catching, and it happens before runApp.
      expect(
        main.indexOf('ErrorLogger.instance.install()'),
        lessThan(main.indexOf('WidgetsFlutterBinding.ensureInitialized()')),
      );
      expect(main, contains('ErrorLogger.runGuarded'));
    });

    test('bootstrap records its own failed steps', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final bootstrap = contentOf(plan, 'lib/core/bootstrap.dart');
      expect(bootstrap, contains('ErrorLogger.instance.attachStorage'));
      expect(bootstrap, contains("source: 'bootstrap'"));
    });

    test('only an Appwrite project gets the remote sink', () async {
      final offline = await planFor(const SpecInput(name: 'a1'));
      expect(
        offline.files.map((f) => f.path),
        isNot(contains('lib/core/error/appwrite_error_sink.dart')),
      );

      final backed = await planFor(
        const SpecInput(name: 'a1', backend: Backend.appwrite),
      );
      expect(
        backed.files.map((f) => f.path),
        contains('lib/core/error/appwrite_error_sink.dart'),
      );
      // Generated, but deliberately not wired up: sending error data off the
      // device is a privacy decision, not a default.
      expect(
        contentOf(backed, 'lib/main.dart'),
        contains('ErrorLogger.instance.attachSink(AppwriteErrorSink('),
      );
    });

    test('the diagnostics route is reachable under both routers', () async {
      for (final router in RouterKind.values) {
        final plan = await planFor(SpecInput(name: 'a1', router: router));
        expect(
          contentOf(plan, 'lib/core/router/routes.dart'),
          contains('diagnostics'),
        );
        expect(
          contentOf(plan, 'lib/core/router/router.dart'),
          contains('DiagnosticsScreen'),
        );
      }
    });
  });
  group('screenshot workflows', () {
    test('both are manual only — they rewrite listing images', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      for (final path in [
        '.github/workflows/screenshots-android.yml',
        '.github/workflows/screenshots-ios.yml',
      ]) {
        final workflow = contentOf(plan, path);
        expect(workflow, contains('workflow_dispatch'));
        expect(workflow, isNot(contains('\n  push:')));
        expect(workflow, isNot(contains('\n  pull_request:')));
      }
    });

    test('they open a PR rather than pushing to the branch', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      for (final path in [
        '.github/workflows/screenshots-android.yml',
        '.github/workflows/screenshots-ios.yml',
      ]) {
        final workflow = contentOf(plan, path);
        expect(workflow, contains('open-screenshot-pr'));
        // Opening a PR needs both; it also means neither workflow has to
        // push to a protected branch.
        expect(workflow, contains('pull-requests: write'));
        expect(workflow, contains('contents: write'));
      }
      expect(
        contentOf(plan, '.github/actions/open-screenshot-pr/action.yml'),
        contains('gh pr create'),
      );
    });

    test('only iOS gets a macOS runner', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      // Ubuntu with KVM is 2-3x faster and much cheaper. Only the iOS
      // simulator genuinely needs a Mac.
      expect(
        contentOf(plan, '.github/workflows/screenshots-android.yml'),
        contains('runs-on: ubuntu-latest'),
      );
      expect(
        contentOf(plan, '.github/workflows/screenshots-ios.yml'),
        contains('runs-on: macos-latest'),
      );
    });

    test('every device family a store has a slot for is covered', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      final android = contentOf(
        plan,
        '.github/workflows/screenshots-android.yml',
      );
      expect(android, contains('android-phone-screenshot'));
      expect(android, contains('android-tablet-screenshot'));

      final ios = contentOf(plan, '.github/workflows/screenshots-ios.yml');
      // The sizes App Store Connect requires for new submissions.
      expect(ios, contains('iphone-screenshot'));
      expect(ios, contains('ios-6.9'));
      expect(ios, contains('ipad-screenshot'));
      expect(ios, contains('ipad-13'));
    });

    test('the iOS workflow is absent without an iOS target', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.android}),
      );
      final paths = pathsOf(plan);
      expect(paths, contains('.github/workflows/screenshots-android.yml'));
      expect(paths, isNot(contains('.github/workflows/screenshots-ios.yml')));
    });

    test('GitHub expressions survive rendering', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      expect(
        contentOf(plan, '.github/workflows/screenshots-android.yml'),
        contains(r'${{ inputs.locale }}'),
      );
    });

    test('each store offers only the locales it accepts', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
          locales: ['en', 'ne'],
        ),
      );
      expect(
        contentOf(plan, '.github/workflows/screenshots-android.yml'),
        contains('ne-NP'),
      );
      // App Store Connect has no Nepali.
      expect(
        contentOf(plan, '.github/workflows/screenshots-ios.yml'),
        isNot(contains('ne-NP')),
      );
    });

    test('one copy file feeds every store and family', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          tabs: [
            TabSpec(id: 'home', label: 'Home', icon: 'house'),
            TabSpec(id: 'notes', label: 'Notes', icon: 'note'),
          ],
        ),
      );
      final decoded = jsonDecode(
        contentOf(plan, 'screenshots/headlines.json'),
      ) as Map<String, dynamic>;
      final ids = [
        for (final scene in decoded['scenes'] as List)
          (scene as Map)['id'] as String,
      ];
      // Scene ids tie the capture filenames to the copy.
      expect(ids, ['home', 'notes', 'settings']);

      // Cycled across the set, so a listing is not a contact sheet.
      expect(decoded['layouts'], isA<List>());
      expect(decoded['layouts'], isNotEmpty);
    });

    test('a font is named per locale, not assumed', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', locales: ['en', 'ne']),
      );
      final decoded = jsonDecode(
        contentOf(plan, 'screenshots/headlines.json'),
      ) as Map<String, dynamic>;
      final fonts = decoded['fonts'] as Map<String, dynamic>;

      // Coverage is per script: a font that sets an English headline draws a
      // Devanagari one as nothing at all, in a perfectly valid file.
      expect(fonts['default'], isNotNull);
      expect(fonts['ne-NP'], contains('Devanagari'));
    });

    test('rendering is pinned to a moksha ref', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final action = contentOf(
        plan,
        '.github/actions/moksha-render/action.yml',
      );
      // A checkout, not a dependency — so a change in moksha cannot silently
      // alter this app's listing.
      expect(action, contains('moksha-ref'));
      expect(action, contains('lohanidamodar/moksha'));
    });

    test('the job builder and the skill ship with the copy file', () async {
      final plan = await planFor(const SpecInput(name: 'a1'));
      final paths = pathsOf(plan);
      expect(paths, contains('screenshots/headlines.json'));
      expect(paths, contains('tool/screenshot_job.dart'));
      expect(paths, contains('.claude/skills/moksha/SKILL.md'));
    });

    test('the copy file ships even without CI', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', githubWorkflow: false),
      );
      final paths = pathsOf(plan);
      expect(paths, contains('screenshots/headlines.json'));
      expect(
        paths,
        isNot(contains('.github/workflows/screenshots-android.yml')),
      );
    });
  });

  group('App Store metadata', () {
    test('the listing lives in the repo, like the Play one', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      final paths = pathsOf(plan);
      expect(
        paths,
        containsAll([
          'ios/fastlane/metadata/en-US/name.txt',
          'ios/fastlane/metadata/en-US/description.txt',
          'ios/fastlane/metadata/en-US/keywords.txt',
          'ios/fastlane/metadata/en-US/release_notes.txt',
          // Not localised: one line for the whole app.
          'ios/fastlane/metadata/copyright.txt',
        ]),
      );
    });

    test('none of it appears without an iOS target', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.android}),
      );
      expect(
        pathsOf(plan).where((p) => p.startsWith('ios/fastlane/metadata')),
        isEmpty,
      );
    });

    test(
      'Apple gets no Nepali listing even when the app ships Nepali',
      () async {
        final plan = await planFor(
          const SpecInput(
            name: 'a1',
            platforms: {TargetPlatform.android, TargetPlatform.ios},
            locales: ['en', 'ne'],
          ),
        );
        final paths = pathsOf(plan);

        // Play is the permissive one and does get a Nepali listing.
        expect(
          paths,
          contains('android/fastlane/metadata/android/ne-NP/title.txt'),
        );
        // App Store Connect has no Nepali — fastlane's ALL_LANGUAGES, generated
        // from Apple's own list, carries hi, bn-BD and ur-PK but not ne. A
        // directory Apple does not recognise is rejected on upload.
        expect(paths, contains('ios/fastlane/metadata/en-US/name.txt'));
        expect(
          paths.where((p) => p.startsWith('ios/fastlane/metadata/ne')),
          isEmpty,
        );
      },
    );

    test(
      'the iOS screenshot workflow offers only App Store languages',
      () async {
        final plan = await planFor(
          const SpecInput(
            name: 'a1',
            platforms: {TargetPlatform.android, TargetPlatform.ios},
            locales: ['en', 'ne'],
          ),
        );
        final ios = contentOf(plan, '.github/workflows/screenshots-ios.yml');
        final android = contentOf(
          plan,
          '.github/workflows/screenshots-android.yml',
        );

        // The two stores take different locale sets; offering ne-NP for iOS
        // would capture into a directory deliver refuses.
        expect(android, contains('ne-NP'));
        expect(ios, isNot(contains('ne-NP')));
        expect(ios, contains('en-US'));
      },
    );

    test('the subtitle ships empty, because it is uploaded verbatim', () async {
      final plan = await planFor(
        const SpecInput(name: 'a1', platforms: {TargetPlatform.ios}),
      );
      // 30 characters, no room for a placeholder, and an over-length one is a
      // hard rejection. Empty reads as "not set"; a plausible default uploads.
      expect(
        contentOf(plan, 'ios/fastlane/metadata/en-US/subtitle.txt').trim(),
        isEmpty,
      );
    });
  });

  group('workflow hygiene', () {
    test('every workflow checks out with a supported action version', () async {
      final plan = await planFor(
        const SpecInput(
          name: 'a1',
          platforms: {TargetPlatform.android, TargetPlatform.ios},
        ),
      );
      final workflows = plan.files.where(
        (f) => f.path.startsWith('.github/workflows/'),
      );
      expect(workflows, isNotEmpty);
      for (final workflow in workflows) {
        // v4 runs on Node 20, which GitHub has deprecated.
        expect(
          workflow.content,
          isNot(contains('actions/checkout@v4')),
          reason: '${workflow.path} still pins the Node 20 checkout',
        );
        expect(workflow.content, contains('actions/checkout@v7'));
      }
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
