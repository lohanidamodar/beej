import 'dart:io';

import 'package:path/path.dart' as p;

/// Runs the `flutter` executable.
///
/// beej shells out to `flutter create` rather than templating the platform
/// tree, so android/, ios/, web/ and the desktop runners are exactly what the
/// installed Flutter produces — including whatever changed in the last release.
class FlutterTool {
  FlutterTool({String? executable})
    : executable = executable ?? _defaultExecutable();

  final String executable;

  /// `BEEJ_FLUTTER` override first, then PATH.
  ///
  /// Windows needs the `.bat`; resolving it here means callers never think
  /// about it.
  static String _defaultExecutable() {
    final override = Platform.environment['BEEJ_FLUTTER'];
    if (override != null && override.isNotEmpty) return override;
    return Platform.isWindows ? 'flutter.bat' : 'flutter';
  }

  /// Whether the executable can be found and run.
  Future<FlutterVersion?> version() async {
    try {
      final result = await Process.run(executable, ['--version', '--machine']);
      if (result.exitCode != 0) return null;
      return FlutterVersion.parse(result.stdout.toString());
    } on ProcessException {
      return null;
    }
  }

  /// `flutter create` a skeleton at [directory].
  Future<ProcessRunResult> create({
    required String directory,
    required String projectName,
    required String org,
    required String platforms,
    required String description,
  }) {
    return _run([
      'create',
      '--project-name',
      projectName,
      '--org',
      org,
      '--platforms',
      platforms,
      '--description',
      description,
      // Kotlin and Swift are the current defaults, but naming them keeps a
      // generated project identical across Flutter versions that change them.
      '--android-language',
      'kotlin',
      '--ios-language',
      'swift',
      '--no-pub',
      directory,
    ]);
  }

  Future<ProcessRunResult> pubGet(String directory) =>
      _run(['pub', 'get'], workingDirectory: directory);

  Future<ProcessRunResult> genL10n(String directory) =>
      _run(['gen-l10n'], workingDirectory: directory);

  Future<ProcessRunResult> analyze(String directory) =>
      _run(['analyze'], workingDirectory: directory);

  Future<ProcessRunResult> test(String directory) =>
      _run(['test'], workingDirectory: directory);

  /// `dart format`, not `flutter format` — the latter was removed from the
  /// Flutter CLI. The dart executable sits beside flutter in the SDK, so it is
  /// resolved from the same place rather than assumed to be on PATH.
  Future<ProcessRunResult> format(String directory) async {
    final dart = _dartExecutable();
    try {
      final result = await Process.run(
        dart,
        ['format', p.join(directory, 'lib'), p.join(directory, 'test')],
        environment: const {'TERM': 'dumb'},
      );
      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      return ProcessRunResult(exitCode: 1, stdout: '', stderr: e.message);
    }
  }

  /// The `dart` next to this `flutter`, falling back to PATH.
  String _dartExecutable() {
    final resolved = _resolveOnPath(executable);
    if (resolved != null) {
      final sibling = p.join(
        p.dirname(resolved),
        Platform.isWindows ? 'dart.bat' : 'dart',
      );
      if (File(sibling).existsSync()) return sibling;
    }
    return Platform.isWindows ? 'dart.bat' : 'dart';
  }

  /// Absolute path of [command], or null when it is not on PATH.
  static String? _resolveOnPath(String command) {
    if (command.contains(Platform.pathSeparator)) return command;
    final which = Platform.isWindows ? 'where' : 'which';
    try {
      final result = Process.runSync(which, [command]);
      if (result.exitCode != 0) return null;
      final first = result.stdout.toString().split('\n').first.trim();
      return first.isEmpty ? null : first;
    } catch (_) {
      return null;
    }
  }

  Future<ProcessRunResult> _run(
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        // Flutter emits progress with ANSI control codes; without this the
        // captured output is unreadable in an error message.
        environment: const {'TERM': 'dumb'},
      );
      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (e) {
      throw FlutterNotFoundException(executable, e.message);
    }
  }
}

class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  /// Whichever stream carried the message, trimmed for display.
  String get output {
    final combined = '${stderr.trim()}\n${stdout.trim()}'.trim();
    return combined.isEmpty ? '(no output)' : combined;
  }
}

class FlutterVersion {
  const FlutterVersion({required this.flutter, required this.dart});

  final String flutter;
  final String dart;

  /// Pull the two versions out of `flutter --version --machine` JSON without
  /// a JSON dependency — the shape is stable and we want two strings.
  static FlutterVersion? parse(String machineOutput) {
    final flutter = RegExp(r'"frameworkVersion"\s*:\s*"([^"]+)"')
        .firstMatch(machineOutput);
    final dart = RegExp(r'"dartSdkVersion"\s*:\s*"([^"\s]+)')
        .firstMatch(machineOutput);
    if (flutter == null) return null;
    return FlutterVersion(
      flutter: flutter.group(1)!,
      dart: dart?.group(1) ?? 'unknown',
    );
  }

  @override
  String toString() => 'Flutter $flutter / Dart $dart';
}

class FlutterNotFoundException implements Exception {
  FlutterNotFoundException(this.executable, this.detail);

  final String executable;
  final String detail;

  @override
  String toString() =>
      'could not run "$executable" ($detail).\n'
      'Install Flutter and put it on PATH, or set BEEJ_FLUTTER to its path.';
}
