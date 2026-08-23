import '../render/pub_dep.dart';
import '../spec/app_spec.dart';

/// One template to render, and where its output goes.
class TemplateFile {
  const TemplateFile(
    this.template,
    this.destination, {
    this.extraContext = const {},
    this.raw = false,
    this.executable = false,
  });

  /// Path under `templates/`, e.g. `base/lib/main.dart.tmpl`.
  final String template;

  /// Destination relative to the project root. Rendered through mustache too,
  /// so a path may contain `{{name}}` or a per-item value from [extraContext].
  final String destination;

  /// Values merged over the global context for this file only — how a brick
  /// emits one file per tab or per locale without a bespoke code path.
  final Map<String, dynamic> extraContext;

  /// Copy the template verbatim instead of rendering it. Needed for files
  /// whose content legitimately contains `{{` — GitHub workflow expressions
  /// (`${{ inputs.x }}`) are the reason this exists.
  final bool raw;

  /// Set the executable bit on the written file (shell scripts).
  final bool executable;
}

/// A cohesive unit of generated project: some files, some dependencies, and
/// the condition under which it applies.
///
/// Bricks are additive only. Nothing a brick contributes is ever removed to
/// turn a feature off — a feature that is off simply never contributes. That
/// is what keeps fifteen independent toggles tractable.
abstract class Brick {
  const Brick();

  /// Stable identifier, shown by `beej bricks` and in the generation summary.
  String get id;

  /// One line describing what this brick puts in the project.
  String get summary;

  /// Whether this brick contributes anything for [spec].
  bool appliesTo(AppSpec spec);

  /// Files this brick renders. Called only when [appliesTo] is true.
  List<TemplateFile> files(AppSpec spec) => const [];

  /// Runtime dependencies added to `pubspec.yaml`.
  List<PubDep> dependencies(AppSpec spec) => const [];

  /// Dev dependencies added to `pubspec.yaml`.
  List<PubDep> devDependencies(AppSpec spec) => const [];

  /// Asset directories this brick needs declared under `flutter: assets:`.
  List<String> assetDirs(AppSpec spec) => const [];

  /// Paths (relative to the project root) that `flutter create` produces and
  /// this brick wants gone — the counted exception to "additive only", used
  /// for the two placeholder files `flutter create` always writes.
  List<String> removes(AppSpec spec) => const [];
}
