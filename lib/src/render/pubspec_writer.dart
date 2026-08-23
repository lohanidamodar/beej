import '../bricks/versions.dart';
import '../spec/app_spec.dart';
import 'pub_dep.dart';

/// Renders `pubspec.yaml` from collected dependencies.
///
/// beej owns the whole file rather than patching what `flutter create` wrote:
/// YAML surgery on a generated file is more fragile than writing it outright,
/// and owning it is what lets every dependency carry its rationale comment.
String writePubspec({
  required AppSpec spec,
  required List<PubDep> dependencies,
  required List<PubDep> devDependencies,
  required List<PubDep> dependencyOverrides,
  required List<String> assetDirs,
  required bool generateL10n,
}) {
  final buffer = StringBuffer()
    ..writeln('name: ${spec.name}')
    ..writeln('description: ${_scalar(spec.description)}')
    // Every PopupBits app is private; publishing would be an accident.
    ..writeln("publish_to: 'none'")
    ..writeln('version: 1.0.0+1')
    ..writeln()
    ..writeln('environment:')
    ..writeln('  sdk: ${Versions.dartSdk}')
    ..writeln()
    ..writeln('dependencies:');

  _writeDeps(buffer, dependencies);

  buffer
    ..writeln()
    ..writeln('dev_dependencies:');
  _writeDeps(buffer, devDependencies);

  if (dependencyOverrides.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        '# Overrides constraints declared by other packages. Each entry',
      )
      ..writeln(
        '# explains why it is safe for the API surface actually used.',
      )
      ..writeln('dependency_overrides:');
    _writeDeps(buffer, dependencyOverrides);
  }

  buffer
    ..writeln()
    ..writeln('flutter:')
    ..writeln('  uses-material-design: true');

  if (generateL10n) {
    buffer
      ..writeln()
      ..writeln('  # Runs `gen-l10n` as part of `flutter build`/`run`, so the')
      ..writeln('  # generated AppLocalizations never lags behind the .arb files.')
      ..writeln('  generate: true');
  }

  if (assetDirs.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('  assets:');
    for (final dir in assetDirs) {
      buffer.writeln('    - $dir');
    }
  }

  return buffer.toString();
}

void _writeDeps(StringBuffer buffer, List<PubDep> deps) {
  var first = true;
  for (final dep in deps) {
    if (dep.comment != null) {
      // A blank line before a commented entry, so comment blocks read as
      // belonging to the entry below rather than the one above.
      if (!first) buffer.writeln();
      for (final line in _wrapComment(dep.comment!, indent: '  ')) {
        buffer.writeln(line);
      }
    }
    first = false;

    if (dep.isSdk) {
      buffer
        ..writeln('  ${dep.name}:')
        ..writeln('    sdk: ${dep.sdk}');
    } else if (dep.isGit) {
      buffer
        ..writeln('  ${dep.name}:')
        ..writeln('    git:')
        ..writeln('      url: ${dep.gitUrl}');
      if (dep.gitRef != null) buffer.writeln('      ref: ${dep.gitRef}');
      if (dep.gitPath != null) buffer.writeln('      path: ${dep.gitPath}');
    } else {
      buffer.writeln('  ${dep.name}: ${_constraint(dep.constraint!)}');
    }
  }
}

/// Wrap [text] to 76 columns as `#` comment lines. Existing newlines are
/// respected as paragraph breaks so a two-part rationale stays two parts.
List<String> _wrapComment(String text, {required String indent}) {
  const width = 76;
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    if (paragraph.trim().isEmpty) {
      lines.add('$indent#');
      continue;
    }
    final words = paragraph.trim().split(RegExp(r'\s+'));
    var current = StringBuffer();
    for (final word in words) {
      final candidateLength =
          indent.length + 2 + current.length + (current.isEmpty ? 0 : 1) + word.length;
      if (current.isNotEmpty && candidateLength > width) {
        lines.add('$indent# $current');
        current = StringBuffer(word);
      } else {
        if (current.isNotEmpty) current.write(' ');
        current.write(word);
      }
    }
    if (current.isNotEmpty) lines.add('$indent# $current');
  }
  return lines;
}

/// Quote a version constraint when YAML would misread it.
///
/// A range like `>=9.0.0 <11.0.0` is a plain scalar containing a space and a
/// leading `>`, which YAML reads as a folded block. Carets are safe bare.
String _constraint(String value) {
  final needsQuotes = value.contains(' ') ||
      value.startsWith('>') ||
      value.startsWith('<') ||
      value.startsWith('=');
  return needsQuotes ? "'$value'" : value;
}

/// Quote a YAML scalar when it needs it. Descriptions routinely contain a
/// colon, which would otherwise turn the line into a nested mapping.
String _scalar(String value) {
  final needsQuotes = value.contains(': ') ||
      value.contains('#') ||
      value.startsWith(RegExp(r'[\[\]{}>|*&!%@`"' r"']")) ||
      value.trim() != value;
  if (!needsQuotes) return value;
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
