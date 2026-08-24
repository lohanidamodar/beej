import 'dart:io';

import 'package:beej/src/render/embedded_templates.g.dart';
import 'package:beej/src/render/template_source.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The embedded templates must match `templates/` exactly.
///
/// They are what a compiled binary ships, and nothing else would notice them
/// going stale: development reads the directory, so a forgotten
/// `dart run tool/embed_templates.dart` would only surface as a released
/// binary generating last week's templates.
void main() {
  final root = Directory('templates');

  List<String> onDisk() =>
      root
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: root.path).replaceAll(r'\', '/'))
          .toList()
        ..sort();

  test('the embedded set covers exactly the templates directory', () {
    final disk = onDisk().toSet();
    final embedded = embeddedTemplates.keys.toSet();

    expect(
      disk.difference(embedded),
      isEmpty,
      reason:
          'templates missing from the embedded set — run: '
          'dart run tool/embed_templates.dart',
    );
    expect(
      embedded.difference(disk),
      isEmpty,
      reason:
          'embedded templates no longer on disk — run: '
          'dart run tool/embed_templates.dart',
    );
  });

  test('every embedded template matches its file byte for byte', () {
    final stale = <String>[];
    for (final relative in onDisk()) {
      final actual = File(p.join(root.path, relative)).readAsStringSync();
      if (embeddedTemplates[relative] != actual) stale.add(relative);
    }
    expect(
      stale,
      isEmpty,
      reason:
          'stale embedded content — run: '
          'dart run tool/embed_templates.dart',
    );
  });

  test('escaping survives the characters that would break a Dart literal', () {
    // Templates carry mustache `$`-free Dart, but also Nepali text, em-dashes,
    // backslashes in regexes and both quote styles. If any of those were
    // mis-escaped the generated file would not compile — but a subtly wrong
    // *value* would compile and generate corrupt projects, so assert content.
    final nepali = embeddedTemplates['base/lib/l10n/app_ne.arb.tmpl'];
    expect(nepali, isNotNull);
    expect(nepali, contains('सेटिङ'));

    final guard =
        embeddedTemplates['base/test/no_frozen_material_test.dart.tmpl'];
    expect(guard, isNotNull);
    expect(guard, contains(r"RegExp(r'import|export')"));
  });

  test('the embedded source can stand in for the directory', () {
    const embedded = EmbeddedTemplateSource();
    final directory = DirectoryTemplateSource(root);

    for (final relative in onDisk()) {
      expect(embedded.exists(relative), isTrue, reason: relative);
      expect(
        embedded.read(relative),
        directory.read(relative),
        reason: relative,
      );
    }
    expect(embedded.listAll(), directory.listAll());
  });

  test('a missing template names the fix', () {
    expect(
      () => const EmbeddedTemplateSource().read('nope/missing.tmpl'),
      throwsA(
        isA<TemplateSourceException>().having(
          (e) => e.message,
          'message',
          contains('embed_templates.dart'),
        ),
      ),
    );
  });
}
