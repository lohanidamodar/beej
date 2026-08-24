import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'embedded_templates.g.dart';

/// Where beej reads its templates from.
///
/// Two implementations, because beej runs in two very different shapes:
///
///  * [DirectoryTemplateSource] — reads `templates/` off disk. Used during
///    development and from a `dart pub global activate` install, so editing a
///    template takes effect immediately with no regeneration step.
///  * [EmbeddedTemplateSource] — reads the map generated into
///    `embedded_templates.g.dart`. This is what makes `dart compile exe` work:
///    an AOT binary bundles only Dart code, `Isolate.resolvePackageUri`
///    returns null inside one, and there is no package directory to read.
abstract class TemplateSource {
  /// Read the template at [relativePath] (relative to `templates/`).
  String read(String relativePath);

  /// Whether [relativePath] exists. Used by the test that asserts every
  /// template a brick names is actually shipped.
  bool exists(String relativePath);

  /// Every template that ships, as paths relative to `templates/`, sorted.
  List<String> listAll();

  static TemplateSource? _cached;

  /// Locate the templates.
  ///
  /// Prefers the directory when one is genuinely beej's, so a template edit is
  /// live during development; falls back to the embedded copy otherwise. A
  /// test asserts the two agree, so a forgotten
  /// `dart run tool/embed_templates.dart` fails CI instead of silently
  /// shipping stale templates.
  static Future<TemplateSource> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;

    // Null in an AOT binary, which is the whole reason for the fallback.
    final libUri = await Isolate.resolvePackageUri(
      Uri.parse('package:beej/beej.dart'),
    );

    final candidates = <String>[
      if (libUri != null)
        p.join(p.dirname(p.dirname(libUri.toFilePath())), 'templates'),
      // Running from the package root during development.
      p.join(Directory.current.path, 'templates'),
    ];

    for (final candidate in candidates) {
      if (_looksLikeBeejTemplates(candidate)) {
        return _cached = DirectoryTemplateSource(Directory(candidate));
      }
    }

    return _cached = const EmbeddedTemplateSource();
  }

  /// Guard against picking up an unrelated `templates/` directory.
  ///
  /// The cwd candidate above is a development convenience; without this check
  /// a compiled beej run inside any project that happens to have a
  /// `templates/` folder would try to generate from it.
  static bool _looksLikeBeejTemplates(String path) =>
      File(p.join(path, 'base', 'lib', 'main.dart.tmpl')).existsSync();

  /// Drop the cached source. Tests only.
  static void resetCache() => _cached = null;
}

/// Reads templates from a directory on disk.
class DirectoryTemplateSource implements TemplateSource {
  DirectoryTemplateSource(this.root);

  /// The `templates/` directory.
  final Directory root;

  @override
  String read(String relativePath) {
    final file = File(p.join(root.path, relativePath));
    if (!file.existsSync()) {
      throw TemplateSourceException(
        'missing template "$relativePath" (expected at ${file.path})',
      );
    }
    return file.readAsStringSync();
  }

  @override
  bool exists(String relativePath) =>
      File(p.join(root.path, relativePath)).existsSync();

  @override
  List<String> listAll() =>
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: root.path).replaceAll(r'\', '/'))
          .toList()
        ..sort();
}

/// Reads templates from the generated map, so a compiled binary carries them.
class EmbeddedTemplateSource implements TemplateSource {
  const EmbeddedTemplateSource();

  @override
  String read(String relativePath) {
    final content = embeddedTemplates[relativePath];
    if (content == null) {
      throw TemplateSourceException(
        'missing template "$relativePath" in the embedded set. If it was just '
        'added, run: dart run tool/embed_templates.dart',
      );
    }
    return content;
  }

  @override
  bool exists(String relativePath) =>
      embeddedTemplates.containsKey(relativePath);

  @override
  List<String> listAll() => embeddedTemplates.keys.toList()..sort();
}

class TemplateSourceException implements Exception {
  TemplateSourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
