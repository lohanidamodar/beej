import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beej/src/cli/bricks_command.dart';
import 'package:beej/src/cli/config_command.dart';
import 'package:beej/src/cli/console.dart';
import 'package:beej/src/cli/create_command.dart';
import 'package:beej/src/cli/spec_command.dart';
import 'package:beej/src/render/template_source.dart';

const String beejVersion = '0.1.0';

Future<void> main(List<String> arguments) async {
  final console = Console();

  final runner = CommandRunner<int>('beej', 'Plant a new Flutter app.')
    ..argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the beej version.',
    )
    ..addCommand(CreateCommand(console: console))
    ..addCommand(ConfigCommand(console: console))
    ..addCommand(SpecCommand(console: console))
    ..addCommand(BricksCommand(console: console));

  try {
    final topLevel = runner.argParser.parse(arguments);
    if (topLevel.flag('version')) {
      console.line('beej $beejVersion');
      exit(0);
    }
  } on FormatException {
    // Fall through: the runner below reports it with proper usage text.
  }

  try {
    exit(await runner.run(arguments) ?? 0);
  } on UsageException catch (e) {
    console
      ..error(e.message)
      ..line(e.usage);
    exit(64);
  } on TemplateSourceException catch (e) {
    console.error(e.message);
    exit(70);
  }
}
