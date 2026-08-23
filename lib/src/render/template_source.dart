import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Reads template files from the beej package's `templates/` directory.
///
/// Resolution has to work three ways: from a source checkout (`dart run`),
/// from a global activation (`dart pub global activate`), and from tests. The
/// package URI is authoritative in the first two; the override exists for
/// tests that render from a fixture directory.
class TemplateSource {
  TemplateSource(this.root);

  /// The `templates/` directory.
  final Directory root;

  static TemplateSource? _cached;

  /// Locate the packaged templates.
  ///
  /// Throws [TemplateSourceException] rather than returning null: a beej
  /// install that cannot find its own templates is broken, and every caller
  /// would only rethrow.
  static Future<TemplateSource> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;

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
      final dir = Directory(candidate);
      if (dir.existsSync()) {
        return _cached = TemplateSource(dir);
      }
    }
    throw TemplateSourceException(
      'could not locate beej templates (looked in: ${candidates.join(', ')})',
    );
  }

  /// Read the template at [relativePath] (under `templates/`).
  String read(String relativePath) {
    final file = File(p.join(root.path, relativePath));
    if (!file.existsSync()) {
      throw TemplateSourceException(
        'missing template "$relativePath" (expected at ${file.path})',
      );
    }
    return file.readAsStringSync();
  }

  /// Whether [relativePath] exists. Used by tests that assert every template
  /// a brick names is actually shipped.
  bool exists(String relativePath) =>
      File(p.join(root.path, relativePath)).existsSync();

  /// Every template file that ships, as paths relative to `templates/`.
  List<String> listAll() =>
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: root.path).replaceAll(r'\', '/'))
          .toList()
        ..sort();
}

class TemplateSourceException implements Exception {
  TemplateSourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
