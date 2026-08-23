import 'pub_dep.dart';

/// One file the generator will write.
class PlannedFile {
  const PlannedFile({
    required this.path,
    required this.content,
    required this.brickId,
    this.executable = false,
  });

  /// Relative to the project root, always with forward slashes.
  final String path;
  final String content;

  /// Which brick produced it — shown in `--dry-run` and used to explain a
  /// collision between two bricks claiming the same path.
  final String brickId;

  final bool executable;
}

/// The complete set of changes for one generation, computed before anything
/// touches the disk.
///
/// Planning fully up front is what makes `--dry-run` honest and what lets a
/// path collision between two bricks be a clean error instead of a silent
/// last-writer-wins.
class FilePlan {
  const FilePlan({
    required this.files,
    required this.removals,
    required this.dependencies,
    required this.devDependencies,
    required this.dependencyOverrides,
    required this.assetDirs,
    required this.activeBrickIds,
  });

  final List<PlannedFile> files;

  /// Paths `flutter create` wrote that should not survive.
  final List<String> removals;

  final List<PubDep> dependencies;
  final List<PubDep> devDependencies;
  final List<PubDep> dependencyOverrides;
  final List<String> assetDirs;
  final List<String> activeBrickIds;

  /// File counts per brick, in brick order — the generation summary.
  Map<String, int> get fileCountByBrick {
    final counts = <String, int>{};
    for (final id in activeBrickIds) {
      counts[id] = 0;
    }
    for (final file in files) {
      counts[file.brickId] = (counts[file.brickId] ?? 0) + 1;
    }
    counts.removeWhere((_, count) => count == 0);
    return counts;
  }
}

/// Two bricks claimed the same destination path.
///
/// Always a bug in the brick definitions rather than in user input, so it
/// names both bricks and fails loudly instead of picking a winner.
class TemplateCollisionException implements Exception {
  TemplateCollisionException(this.path, this.firstBrick, this.secondBrick);

  final String path;
  final String firstBrick;
  final String secondBrick;

  @override
  String toString() =>
      'bricks "$firstBrick" and "$secondBrick" both write "$path" — '
      'one of them must be narrowed';
}
