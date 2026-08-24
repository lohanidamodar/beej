import 'package:mustache_template/mustache_template.dart';

import '../bricks/brick.dart';
import '../spec/app_spec.dart';
import 'file_plan.dart';
import 'pub_dep.dart';
import 'pubspec_writer.dart';
import 'template_context.dart';
import 'template_source.dart';

/// Turns a spec plus a brick list into a complete [FilePlan].
///
/// Nothing here touches the filesystem except reading templates, so planning
/// is fully testable and `--dry-run` exercises the same code path as a real
/// generation.
class Planner {
  Planner({required this.source, required this.bricks});

  final TemplateSource source;
  final List<Brick> bricks;

  FilePlan plan(AppSpec spec) {
    final context = buildContext(spec);
    final active = bricks.where((b) => b.appliesTo(spec)).toList();

    final files = <PlannedFile>[];
    final claimedBy = <String, String>{};
    final removals = <String>{};
    final dependencies = <PubDep>[];
    final devDependencies = <PubDep>[];
    final dependencyOverrides = <PubDep>[];
    final assetDirs = <String>{};

    for (final brick in active) {
      for (final templateFile in brick.files(spec)) {
        final fileContext = templateFile.extraContext.isEmpty
            ? context
            : {...context, ...templateFile.extraContext};

        final destination = _renderString(
          templateFile.destination,
          fileContext,
          'destination of ${templateFile.template}',
        );

        final existing = claimedBy[destination];
        if (existing != null) {
          throw TemplateCollisionException(destination, existing, brick.id);
        }
        claimedBy[destination] = brick.id;

        final raw = source.read(templateFile.template);
        final content = templateFile.raw
            ? raw
            : _renderString(
                raw,
                fileContext,
                templateFile.template,
                delimiters: templateFile.delimiters,
              );

        files.add(
          PlannedFile(
            path: destination,
            content: content,
            brickId: brick.id,
            executable: templateFile.executable,
          ),
        );
      }

      removals.addAll(brick.removes(spec));
      dependencies.addAll(brick.dependencies(spec));
      devDependencies.addAll(brick.devDependencies(spec));
      dependencyOverrides.addAll(brick.dependencyOverrides(spec));
      assetDirs.addAll(brick.assetDirs(spec));
    }

    // The pubspec is assembled from what the bricks asked for, not rendered
    // from a template, so it always matches the file plan exactly.
    final pubspec = writePubspec(
      spec: spec,
      dependencies: _dedupe(dependencies),
      devDependencies: _dedupe(devDependencies),
      dependencyOverrides: _dedupe(dependencyOverrides),
      assetDirs: assetDirs.toList()..sort(),
      generateL10n: true,
    );
    files.add(
      PlannedFile(path: 'pubspec.yaml', content: pubspec, brickId: 'base'),
    );

    files.sort((a, b) => a.path.compareTo(b.path));

    return FilePlan(
      files: files,
      removals: removals.toList()..sort(),
      dependencies: _dedupe(dependencies),
      devDependencies: _dedupe(devDependencies),
      dependencyOverrides: _dedupe(dependencyOverrides),
      assetDirs: assetDirs.toList()..sort(),
      activeBrickIds: active.map((b) => b.id).toList(),
    );
  }

  String _renderString(
    String template,
    Map<String, dynamic> context,
    String what, {
    String delimiters = '{{ }}',
  }) {
    try {
      // htmlEscapeValues off because we generate Dart, YAML and Gradle — HTML
      // escaping would turn an apostrophe in a description into `&#39;`.
      // lenient off so a typo'd `{{tabss}}` fails the build instead of
      // silently rendering an empty string into someone's source file.
      return Template(
        template,
        htmlEscapeValues: false,
        lenient: false,
        name: what,
        delimiters: delimiters,
      ).renderString(context);
    } on TemplateException catch (e) {
      throw RenderException('$what: ${e.message}');
    }
  }

  /// First declaration of a package wins. Bricks declare what they need
  /// without checking whether another brick already asked for it; `path` and
  /// `package_info_plus` are each wanted by several.
  static List<PubDep> _dedupe(List<PubDep> deps) {
    final seen = <String>{};
    final result = <PubDep>[];
    for (final dep in deps) {
      if (seen.add(dep.name)) result.add(dep);
    }
    return result;
  }
}

class RenderException implements Exception {
  RenderException(this.message);
  final String message;
  @override
  String toString() => message;
}
