// Generates a representative set of configurations and proves each one
// builds: `flutter pub get`, `flutter analyze`, `flutter test`.
//
// This is beej's real safety net. Because mutually exclusive bricks can never
// coexist in one project, "the template directory compiles" is not achievable
// and not meaningful — proving the *output* compiles is. Without this, fifteen
// independent toggles rot silently: a change that suits the default config
// breaks the Navigator one, and nobody finds out until someone generates it.
//
//   dart run tool/verify_matrix.dart              # everything
//   dart run tool/verify_matrix.dart minimal web  # only the named cases
//   dart run tool/verify_matrix.dart --keep       # leave the output for inspection
//
// Each case runs a real `flutter create` plus a full pub solve, so the whole
// matrix takes a few minutes.

import 'dart:io';

import 'package:beej/src/flutter/flutter_tool.dart';
import 'package:beej/src/generator.dart';
import 'package:beej/src/render/template_source.dart';
import 'package:beej/src/spec/app_spec.dart';
import 'package:beej/src/spec/enums.dart';
import 'package:beej/src/spec/spec_input.dart';
import 'package:path/path.dart' as p;

/// One configuration to prove.
class MatrixCase {
  const MatrixCase(this.name, this.input, {required this.why});

  final String name;
  final SpecInput input;

  /// What this case is here to catch. A case without a distinct answer is a
  /// case that only costs time.
  final String why;
}

const _mobile = {TargetPlatform.android, TargetPlatform.ios};

final matrix = <MatrixCase>[
  MatrixCase(
    'minimal',
    const SpecInput(
      name: 'minimal_app',
      platforms: {TargetPlatform.android},
      router: RouterKind.navigator,
      navStyle: NavStyle.tabs,
      icons: IconSet.material,
      inAppUpdate: false,
      review: false,
      fastlane: false,
      githubWorkflow: false,
      screenshots: false,
      locales: ['en'],
    ),
    why: 'every optional brick off — catches base code that leans on one',
  ),
  MatrixCase(
    'default',
    const SpecInput(name: 'default_app'),
    why: 'exactly what `beej create <name> --yes` produces',
  ),
  MatrixCase(
    'appwrite_web',
    const SpecInput(
      name: 'appwrite_web_app',
      backend: Backend.appwrite,
      platforms: {TargetPlatform.android, TargetPlatform.web},
      navStyle: NavStyle.drawer,
    ),
    why: 'auth redirect + drawer-only shell + the web url strategy',
  ),
  MatrixCase(
    'everything',
    const SpecInput(
      name: 'everything_app',
      backend: Backend.appwrite,
      database: DatabaseKind.sqflite,
      notifications: true,
      nepaliDates: true,
      tabs: [
        TabSpec(id: 'home', label: 'Home', icon: 'house'),
        TabSpec(id: 'notes', label: 'Notes', icon: 'note'),
        TabSpec(id: 'search', label: 'Search', icon: 'magnifyingGlass'),
      ],
    ),
    why: 'every brick at once — catches collisions between them',
  ),
  MatrixCase(
    'sqflite_mobile',
    const SpecInput(
      name: 'sqflite_mobile_app',
      database: DatabaseKind.sqflite,
      platforms: _mobile,
      navStyle: NavStyle.tabs,
    ),
    why: 'sqflite without the desktop FFI branch',
  ),
  MatrixCase(
    'navigator_drawer',
    const SpecInput(
      name: 'navigator_drawer_app',
      router: RouterKind.navigator,
      navStyle: NavStyle.drawer,
      platforms: _mobile,
      notifications: true,
    ),
    why: 'the Navigator shell with a drawer, and desugaring in Gradle',
  ),
  MatrixCase(
    'web_only',
    const SpecInput(
      name: 'web_only_app',
      platforms: {TargetPlatform.web},
      navStyle: NavStyle.tabs,
      inAppUpdate: false,
      fastlane: false,
      githubWorkflow: false,
    ),
    why: 'no dart:io leaks, and no Android-only brick sneaking in',
  ),
  MatrixCase(
    'design_system',
    const SpecInput(
      name: 'design_system_app',
      designSystem: DesignSystem.popupBits,
      platforms: {TargetPlatform.android, TargetPlatform.web},
    ),
    // The only case that resolves a git dependency, so it also needs network.
    why: 'the shared popup_bits_design theme, which needs material_ui 1.x',
  ),
  MatrixCase(
    'no_agent_config',
    const SpecInput(
      name: 'no_agent_config_app',
      agentConfig: false,
      platforms: {TargetPlatform.android},
    ),
    why: 'the agent-tooling brick fully off, .mcp.json and skills absent',
  ),
  MatrixCase(
    'desktop',
    const SpecInput(
      name: 'desktop_app',
      platforms: {
        TargetPlatform.linux,
        TargetPlatform.macos,
        TargetPlatform.windows,
      },
      database: DatabaseKind.sqflite,
      inAppUpdate: false,
      fastlane: false,
      githubWorkflow: false,
    ),
    why: 'the sqflite FFI branch, and no mobile-only assumptions',
  ),
];

Future<void> main(List<String> arguments) async {
  final keep = arguments.contains('--keep');
  final selectors = arguments.where((a) => !a.startsWith('--')).toSet();
  final cases = selectors.isEmpty
      ? matrix
      : matrix.where((c) => selectors.contains(c.name)).toList();

  if (cases.isEmpty) {
    stderr.writeln(
      'no matching cases. Available: ${matrix.map((c) => c.name).join(', ')}',
    );
    // Returning a value from main does not set the process exit code, and a
    // matrix that reports failures while exiting 0 is worse than no matrix.
    exit(1);
  }

  final flutter = FlutterTool();
  final version = await flutter.version();
  if (version == null) {
    stderr.writeln('could not run flutter — set BEEJ_FLUTTER or fix PATH');
    exit(1);
  }

  final source = await TemplateSource.resolve();
  final workspace = Directory.systemTemp.createTempSync('beej_matrix_');
  stdout
    ..writeln('beej verification matrix')
    ..writeln('  $version')
    ..writeln('  workspace: ${workspace.path}')
    ..writeln('  ${cases.length} case(s)')
    ..writeln();

  final failures = <String>[];
  final stopwatch = Stopwatch()..start();

  for (final testCase in cases) {
    final caseWatch = Stopwatch()..start();
    stdout.write('  ${testCase.name.padRight(20)} ');

    final failure = await _run(
      testCase,
      source: source,
      flutter: flutter,
      workspace: workspace.path,
    );
    caseWatch.stop();
    final seconds = (caseWatch.elapsedMilliseconds / 1000).toStringAsFixed(1);

    if (failure == null) {
      stdout.writeln('ok    ${seconds}s   ${testCase.why}');
    } else {
      stdout.writeln('FAIL  ${seconds}s');
      failures.add('${testCase.name}\n$failure');
    }
  }

  stopwatch.stop();
  stdout
    ..writeln()
    ..writeln(
      '  ${cases.length - failures.length}/${cases.length} passed in '
      '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(0)}s',
    );

  if (failures.isNotEmpty) {
    stdout.writeln();
    for (final failure in failures) {
      stdout
        ..writeln('─' * 72)
        ..writeln(failure);
    }
  }

  if (keep) {
    stdout.writeln('\n  kept: ${workspace.path}');
  } else {
    workspace.deleteSync(recursive: true);
  }

  exit(failures.isEmpty ? 0 : 1);
}

/// Run one case. Returns null on success, or the failure output.
Future<String?> _run(
  MatrixCase testCase, {
  required TemplateSource source,
  required FlutterTool flutter,
  required String workspace,
}) async {
  final AppSpec spec;
  try {
    spec = resolveSpec(testCase.input, year: 2026);
  } on SpecResolutionException catch (e) {
    return 'spec did not resolve: $e';
  }

  final caseDirectory = p.join(workspace, testCase.name);
  Directory(caseDirectory).createSync(recursive: true);

  try {
    await Generator(source: source, flutter: flutter).generate(
      spec,
      parentDirectory: caseDirectory,
      // Formatting is cosmetic and costs a process per case.
      runFormat: false,
    );
  } on GenerationException catch (e) {
    return 'generation failed: ${e.message}\n${e.detail ?? ''}';
  }

  final projectDirectory = p.join(caseDirectory, spec.name);

  // --fatal-infos would also fail on upstream deprecations we deliberately
  // suppress, so the bar is the same one a developer sees: no errors, no
  // warnings. `flutter analyze` exits non-zero for both.
  final analyze = await flutter.analyze(projectDirectory);
  if (!analyze.ok) return 'flutter analyze:\n${analyze.output}';

  final test = await flutter.test(projectDirectory);
  if (!test.ok) return 'flutter test:\n${test.output}';

  return null;
}
