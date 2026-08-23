import 'dart:io';

import 'package:io/ansi.dart' as ansi;

/// Terminal output for beej.
///
/// Colour is disabled automatically when stdout is not a terminal, so piping
/// to a file or a CI log produces clean text.
class Console {
  Console({IOSink? out, IOSink? err, bool? useColor})
    : _out = out ?? stdout,
      _err = err ?? stderr,
      _color = useColor ?? _detectColor();

  final IOSink _out;
  final IOSink _err;
  final bool _color;

  static bool _detectColor() {
    if (Platform.environment['NO_COLOR'] != null) return false;
    try {
      return stdout.hasTerminal;
    } catch (_) {
      return false;
    }
  }

  String _wrap(String text, ansi.AnsiCode code) =>
      _color ? code.wrap(text) ?? text : text;

  String dim(String text) => _wrap(text, ansi.darkGray);
  String bold(String text) => _wrap(text, ansi.styleBold);
  String green(String text) => _wrap(text, ansi.green);
  String yellow(String text) => _wrap(text, ansi.yellow);
  String red(String text) => _wrap(text, ansi.red);
  String cyan(String text) => _wrap(text, ansi.cyan);

  void line([String text = '']) => _out.writeln(text);

  void step(String text) => _out.writeln('  ${green('✓')} $text');

  void info(String text) => _out.writeln('  $text');

  void warn(String text) => _out.writeln('  ${yellow('!')} $text');

  void error(String text) => _err.writeln('${red('✗')} $text');

  void heading(String text) {
    _out
      ..writeln()
      ..writeln('  ${bold(text)}');
  }
}
