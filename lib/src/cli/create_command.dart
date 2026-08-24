import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../bricks/registry.dart';
import '../generator.dart';
import '../render/template_source.dart';
import '../spec/app_spec.dart';
import '../spec/spec_input.dart';
import '../spec/spec_parser.dart';
import '../spec/validation.dart';
import 'console.dart';
import 'flag_input.dart';
import 'prompts.dart';
import 'user_config.dart';

/// `beej create <name>` — plant a new project.
class CreateCommand extends Command<int> {
  CreateCommand({required this.console, this.now}) {
    addCreateFlags(argParser);
  }

  final Console console;

  /// Injected in tests so generated copyright years are deterministic.
  final DateTime? now;

  @override
  String get name => 'create';

  @override
  String get description => 'Plant a new PopupBits Flutter app.';

  @override
  String get invocation => 'beej create <name> [options]';

  @override
  Future<int> run() async {
    final results = argResults!;

    // Layer: defaults (inside resolveSpec) < user config < spec file < flags.
    var input = const SpecInput.empty();

    final userConfig = UserConfig.locate();
    try {
      input = input.overriddenBy(userConfig.read());
    } on SpecParseException catch (e) {
      console
        ..error('your beej config is not valid, so nothing was generated:')
        ..line('  ${e.message}')
        ..line('  ${console.dim(userConfig.path)}');
      return 1;
    }

    final specPath = results.option('spec');
    if (specPath != null) {
      final file = File(specPath);
      if (!file.existsSync()) {
        console.error('no spec file at "$specPath"');
        return 1;
      }
      try {
        input = input.overriddenBy(
          parseSpecYaml(file.readAsStringSync(), source: specPath),
        );
      } on SpecParseException catch (e) {
        console.error(e.message);
        return 1;
      }
    }

    try {
      input = input.overriddenBy(readFlagInput(results));
    } on FormatException catch (e) {
      console.error(e.message);
      return 1;
    }

    // A positional name always wins: `beej create tipot --spec other.yaml`
    // reads as "that config, this name".
    if (results.rest.isNotEmpty) {
      if (results.rest.length > 1) {
        console.error('expected one project name, got ${results.rest.length}');
        return 1;
      }
      input = input.overriddenBy(SpecInput(name: results.rest.single));
    }

    final interactive = !results.flag('yes') && stdin.hasTerminal;
    if (interactive) {
      input = await promptForMissing(input, console: console);
    }

    final AppSpec spec;
    try {
      spec = resolveSpec(input, year: (now ?? DateTime.now()).year);
    } on SpecResolutionException catch (e) {
      console.error(e.message);
      return 1;
    }

    final issues = validateSpec(spec);
    final errors = issues.where((i) => i.isError).toList();
    if (errors.isNotEmpty) {
      console.error(
        'the spec has ${errors.length} problem${errors.length == 1 ? '' : 's'}:',
      );
      for (final issue in errors) {
        console.line('  • ${console.bold(issue.field)}: ${issue.message}');
        if (issue.hint != null) console.line('    ${console.dim(issue.hint!)}');
      }
      return 1;
    }

    final source = await TemplateSource.resolve();
    final outputDirectory = results.option('out') ?? Directory.current.path;
    final generator = Generator(
      source: source,
      reporter: results.flag('dry-run') ? null : console.step,
    );

    if (results.flag('dry-run')) {
      return _printPlan(generator, spec, outputDirectory);
    }

    _printHeader(spec);
    try {
      final result = await generator.generate(
        spec,
        parentDirectory: outputDirectory,
        runPubGet: !results.flag('no-pub'),
      );
      _printSummary(result, spec);
      return 0;
    } on GenerationException catch (e) {
      console.error(e.message);
      if (e.detail != null) console.line(e.detail!);
      return 1;
    }
  }

  void _printHeader(AppSpec spec) {
    console
      ..line()
      ..line('  ${console.green('seed')}  ${console.bold(spec.name)}')
      ..line('  ${console.dim('org')}   ${spec.applicationId}')
      ..line();
  }

  int _printPlan(Generator generator, AppSpec spec, String outputDirectory) {
    final plan = generator.planOnly(spec);
    console
      ..heading('${spec.name} — dry run')
      ..line();

    console.info(console.dim('bricks'));
    for (final entry in plan.fileCountByBrick.entries) {
      final brick = allBricks.firstWhere((b) => b.id == entry.key);
      console.line(
        '    ${entry.key.padRight(16)} ${entry.value.toString().padLeft(3)} '
        '${console.dim(brick.summary)}',
      );
    }

    console
      ..line()
      ..info(console.dim('files'));
    for (final file in plan.files) {
      console.line('    ${p.join(outputDirectory, spec.name, file.path)}');
    }
    if (plan.removals.isNotEmpty) {
      console
        ..line()
        ..info(console.dim('removed from the flutter create skeleton'));
      for (final removal in plan.removals) {
        console.line('    $removal');
      }
    }

    console
      ..line()
      ..info(
        '${plan.files.length} files, ${plan.dependencies.length} dependencies. '
        'Nothing written.',
      )
      ..line();
    return 0;
  }

  void _printSummary(GenerationResult result, AppSpec spec) {
    for (final warning in result.warnings) {
      console.warn('${warning.field}: ${warning.message}');
    }
    for (final skip in result.skipped) {
      console.warn('skipped $skip');
    }

    console
      ..line()
      ..line(
        '  ${console.green('Planted')} ${console.bold(result.directory)} — '
        '${result.plan.files.length} files.',
      )
      ..line()
      ..info(console.dim('next'))
      ..line('    cd ${p.relative(result.directory)}')
      ..line('    flutter run');

    if (spec.tooling.fastlane && spec.hasAndroid) {
      console.line(
        '    ${console.dim('# release setup: see PROJECT.md § Release')}',
      );
    }
    console.line();
  }
}
