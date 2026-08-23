import 'dart:io';

import 'package:path/path.dart' as p;

import 'bricks/registry.dart';
import 'flutter/flutter_tool.dart';
import 'flutter/keystore.dart';
import 'render/file_plan.dart';
import 'render/planner.dart';
import 'render/template_source.dart';
import 'spec/app_spec.dart';
import 'spec/validation.dart';

/// Progress callback. The CLI renders these; tests ignore them.
typedef ProgressReporter = void Function(String message);

/// Thrown when generation cannot proceed. The message is user-facing.
class GenerationException implements Exception {
  GenerationException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message\n$detail';
}

class GenerationResult {
  const GenerationResult({
    required this.directory,
    required this.plan,
    required this.warnings,
    required this.skipped,
  });

  final String directory;
  final FilePlan plan;

  /// Non-fatal spec issues, worth showing after a successful run.
  final List<SpecIssue> warnings;

  /// Optional post-steps that did not run, with the reason.
  final List<String> skipped;
}

/// Turns a validated [AppSpec] into a project on disk.
class Generator {
  Generator({
    required this.source,
    FlutterTool? flutter,
    this.keystoreGenerator = const KeystoreGenerator(),
    this.reporter,
  }) : flutter = flutter ?? FlutterTool();

  final TemplateSource source;
  final FlutterTool flutter;
  final KeystoreGenerator keystoreGenerator;
  final ProgressReporter? reporter;

  void _report(String message) => reporter?.call(message);

  /// Compute the plan without touching the disk. Backs `--dry-run`.
  FilePlan planOnly(AppSpec spec) {
    _assertValid(spec);
    return Planner(source: source, bricks: allBricks).plan(spec);
  }

  /// Generate the project into [parentDirectory]`/`[spec.name].
  Future<GenerationResult> generate(
    AppSpec spec, {
    required String parentDirectory,
    bool runPubGet = true,
    bool runFormat = true,
  }) async {
    final issues = _assertValid(spec);
    final warnings = issues.where((i) => !i.isError).toList();

    final target = p.join(parentDirectory, spec.name);
    final targetDirectory = Directory(target);
    if (targetDirectory.existsSync() && targetDirectory.listSync().isNotEmpty) {
      throw GenerationException('"$target" already exists and is not empty');
    }

    // Plan before creating anything: a template typo should fail with nothing
    // written, not with a half-generated directory to clean up.
    final plan = Planner(source: source, bricks: allBricks).plan(spec);

    await _flutterCreate(spec, target);
    _applyPlan(plan, target);

    final skipped = <String>[];

    if (spec.keystore != null) {
      switch (await keystoreGenerator.generate(
        spec,
        projectDirectory: target,
      )) {
        case KeystoreCreated(:final path):
          _report('keystore at $path');
        case KeystoreSkipped(:final reason):
          skipped.add('keystore generation — $reason');
        case KeystoreFailed(:final output):
          skipped.add('keystore generation:\n$output');
      }
    }

    if (runPubGet) {
      await _pubGetAndL10n(target, skipped);
    } else {
      skipped.add('flutter pub get (skipped by request)');
    }
    if (runFormat && runPubGet) {
      final formatted = await flutter.format(target);
      if (!formatted.ok) skipped.add('dart format');
    }

    return GenerationResult(
      directory: target,
      plan: plan,
      warnings: warnings,
      skipped: skipped,
    );
  }

  List<SpecIssue> _assertValid(AppSpec spec) {
    final issues = validateSpec(spec);
    final errors = issues.where((i) => i.isError).toList();
    if (errors.isNotEmpty) {
      throw GenerationException(
        'the spec has ${errors.length} problem'
        '${errors.length == 1 ? '' : 's'}',
        detail: errors
            .map(
              (e) =>
                  '  • ${e.field}: ${e.message}'
                  '${e.hint == null ? '' : '\n    ${e.hint}'}',
            )
            .join('\n'),
      );
    }
    return issues;
  }

  Future<void> _flutterCreate(AppSpec spec, String target) async {
    _report('flutter create (${spec.flutterCreatePlatforms})');
    final result = await flutter.create(
      directory: target,
      projectName: spec.name,
      org: spec.org,
      platforms: spec.flutterCreatePlatforms,
      description: spec.description,
    );
    if (!result.ok) {
      throw GenerationException('flutter create failed', detail: result.output);
    }
  }

  void _applyPlan(FilePlan plan, String target) {
    for (final relative in plan.removals) {
      final file = File(p.join(target, relative));
      if (file.existsSync()) file.deleteSync();
    }

    for (final planned in plan.files) {
      final file = File(p.join(target, planned.path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(planned.content);
      if (planned.executable && !Platform.isWindows) {
        Process.runSync('chmod', ['+x', file.path]);
      }
    }
    _report('${plan.files.length} files written');
  }

  Future<void> _pubGetAndL10n(String target, List<String> skipped) async {
    _report('flutter pub get');
    final pubGet = await flutter.pubGet(target);
    if (!pubGet.ok) {
      throw GenerationException(
        'flutter pub get failed — the project was generated but will not '
        'build until this is resolved',
        detail: pubGet.output,
      );
    }

    // `generate: true` in pubspec.yaml runs gen-l10n during build, but the
    // analyzer needs AppLocalizations to exist *now* — otherwise a freshly
    // generated project shows errors in the editor before its first run.
    _report('flutter gen-l10n');
    final l10n = await flutter.genL10n(target);
    if (!l10n.ok) skipped.add('flutter gen-l10n:\n${l10n.output}');
  }
}
