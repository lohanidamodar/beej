import 'package:args/command_runner.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../spec/spec_parser.dart';
import 'console.dart';
import 'user_config.dart';

/// `beej config` — the defaults you do not want to retype.
///
/// beej ships neutral defaults (`com.example`, English only, no About URLs) so
/// it is usable by anyone. This is where one person or organisation makes it
/// theirs, once, instead of passing the same flags to every `create`.
///
/// Dispatches on `rest` rather than declaring subcommands: package:args
/// refuses a bare invocation when a command has subcommands, and plain
/// `beej config` should show the config rather than print a usage error.
class ConfigCommand extends Command<int> {
  ConfigCommand({required this.console});

  final Console console;

  @override
  String get name => 'config';

  @override
  String get description => "Show or change beej's own defaults.";

  @override
  String get invocation =>
      'beej config [set <key> <value> | unset <key> | keys | path]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) return _show();

    return switch (rest.first) {
      'set' => _set(rest.skip(1).toList()),
      'unset' => _unset(rest.skip(1).toList()),
      'keys' => _keys(),
      'path' => _path(),
      final unknown => _unknown(unknown),
    };
  }

  int _unknown(String what) {
    console
      ..error('unknown config command "$what"')
      ..line(usage);
    return 1;
  }

  int _path() {
    console.line(UserConfig.locate().path);
    return 0;
  }

  int _show() {
    final config = UserConfig.locate();

    console
      ..heading('config')
      ..info(console.dim(config.path))
      ..line();

    if (!config.exists) {
      console
        ..info('No config yet — everything uses the built-in defaults.')
        ..line()
        ..info(console.dim('for example:'))
        ..line('    beej config set org com.acme')
        ..line('    beej config set locales en,ne')
        ..line(
          '    beej config set about.privacyPolicyUrl '
          'https://acme.com/{name-kebab}-privacy',
        )
        ..line()
        ..info(console.dim('`beej config keys` lists everything settable.'))
        ..line();
      return 0;
    }

    // Parse as well as print, so an unreadable config is reported here rather
    // than at the start of an unrelated `create`.
    try {
      config.read();
    } on SpecParseException catch (e) {
      console
        ..error('the config file is not valid:')
        ..line('  ${e.message}');
      return 1;
    }

    for (final line in config.readRaw().trimRight().split('\n')) {
      console.line('    $line');
    }
    console.line();
    return 0;
  }

  int _set(List<String> args) {
    if (args.length != 2) {
      console
        ..error('expected a key and a value')
        ..line('  beej config set <key> <value>');
      return 1;
    }
    final [key, value] = args;

    final path = configurableKeys[key];
    if (path == null) {
      console
        ..error('"$key" is not a settable key')
        ..line('  run `beej config keys` to see the list');
      return 1;
    }

    final config = UserConfig.locate();
    final existing = config.readRaw();

    // A new or comment-only file parses to null, and yaml_edit cannot add a
    // key to a scalar. Seeding with a real block-style key makes the root a
    // mapping — and keeps block style, which `{}` would not — and the seed is
    // removed before writing.
    const seedKey = '_beej_seed';
    final startsEmpty = existing.trim().isEmpty;
    final editor = YamlEditor(startsEmpty ? '$seedKey: true\n' : existing);

    // A list-valued key given as `a,b` becomes a real YAML list, so the config
    // stays valid input for the ordinary spec parser.
    final Object parsed = listValuedKeys.contains(key)
        ? value
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList()
        : _scalar(value);

    // Create any missing parent mapping before writing into it.
    for (var depth = 1; depth < path.length; depth++) {
      final parent = path.sublist(0, depth);
      try {
        editor.parseAt(parent);
      } catch (_) {
        editor.update(parent, <String, Object>{});
      }
    }
    editor.update(path, parsed);
    if (startsEmpty) editor.remove([seedKey]);

    final header = startsEmpty
        ? '# beej defaults. The same keys as a --spec file, minus `name`.\n'
              '# Hand-editable; `beej config set` rewrites it in place.\n'
        : '';
    final updated = header + editor.toString();
    // Round-trip through the real parser: a config beej cannot read is worse
    // than no config, and this is the moment to catch it.
    try {
      parseSpecYaml(updated, source: config.path);
    } on SpecParseException catch (e) {
      console
        ..error(
          'that would make the config unreadable, so nothing was written:',
        )
        ..line('  ${e.message}');
      return 1;
    }

    config.write(updated);
    console
      ..line()
      ..step('$key = $value')
      ..info(console.dim(config.path))
      ..line();
    return 0;
  }

  int _unset(List<String> args) {
    if (args.length != 1) {
      console
        ..error('expected one key')
        ..line('  beej config unset <key>');
      return 1;
    }
    final key = args.single;

    final path = configurableKeys[key];
    if (path == null) {
      console.error('"$key" is not a settable key');
      return 1;
    }

    final config = UserConfig.locate();
    if (!config.exists) {
      console.warn('no config file at ${config.path}');
      return 0;
    }

    final editor = YamlEditor(config.readRaw());
    try {
      editor.remove(path);
    } catch (_) {
      console.warn('"$key" was not set');
      return 0;
    }

    config.write(editor.toString());
    console
      ..line()
      ..step('unset $key')
      ..line();
    return 0;
  }

  int _keys() {
    console.heading('settable keys');
    for (final key in configurableKeys.keys) {
      final note = listValuedKeys.contains(key)
          ? console.dim('  (comma-separated)')
          : '';
      console.line('    $key$note');
    }
    console
      ..line()
      ..info(
        console.dim(
          'About URLs accept {name} and {name-kebab}, expanded per project.',
        ),
      )
      ..line();
    return 0;
  }

  /// Turn a command-line string into the YAML type it looks like, so
  /// `beej config set agents.mcp false` stores a boolean rather than "false".
  static Object _scalar(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    return value;
  }
}
