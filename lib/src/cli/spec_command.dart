import 'package:args/command_runner.dart';

import '../spec/enums.dart';
import '../spec/spec_input.dart';
import 'console.dart';
import 'spec_schema.dart';

/// `beej spec` — machine-readable and human-readable views of the spec file.
///
/// `--schema` is the agent path: an agent can read it and write a valid spec
/// without guessing key names or enum values.
class SpecCommand extends Command<int> {
  SpecCommand({required this.console}) {
    argParser
      ..addFlag(
        'schema',
        negatable: false,
        help: 'Print the JSON Schema for a spec file.',
      )
      ..addFlag(
        'example',
        negatable: false,
        help: 'Print an annotated example spec.',
      );
  }

  final Console console;

  @override
  String get name => 'spec';

  @override
  String get description => 'Show the spec-file schema or an example.';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.flag('schema')) {
      console.line(specJsonSchema());
      return 0;
    }
    if (results.flag('example')) {
      console.line(exampleSpec());
      return 0;
    }
    console
      ..error('pass --schema or --example')
      ..line(argParser.usage);
    return 1;
  }
}

String exampleSpec() =>
    '''
# beej spec file. Every key is optional; anything omitted takes its default.
# Generate with: beej create --spec this-file.yaml

name: tipot                     # required (or pass it as the first argument)
displayName: Tipot
description: Notes and todos that stay out of the way.
org: ${SpecDefaults.org}

# A list, or "all" / "mobile".
platforms: [android, ios, web]

# "none", "appwrite", or a mapping with connection details.
backend:
  kind: appwrite
  endpoint: ${SpecDefaults.appwriteEndpoint}
  projectId: tipot              # defaults to `name`
  databaseId: tipot             # defaults to `name`

router: ${RouterKind.goRouter.wire}              # ${RouterKind.navigator.wire} is mobile-only

nav:
  style: ${NavStyle.tabsAndDrawer.wire}          # ${NavStyle.tabs.wire} | ${NavStyle.drawer.wire}
  # Bare strings get a titleised label and an inferred icon; a mapping with
  # id/label/icon overrides either. Settings is appended automatically.
  tabs:
    - home
    - id: notes
      label: Notes
      icon: note

database: ${DatabaseKind.none.wire}               # ${DatabaseKind.sqflite.wire}
locales: [en, ne]               # en is required — it is the ARB template
designSystem: ${DesignSystem.local.wire}
icons: ${IconSet.picons.wire}

features:
  inAppUpdate: true
  notifications: false
  nepaliDates: false
  review: true

# Every About value is optional — a tile is generated only when its value is
# set, because a row linking nowhere is worse than an absent row. These are
# usually saved once with `beej config set`, not repeated per project.
# URLs accept {name} and {name-kebab}, expanded per project.
about:
  privacyPolicyUrl: https://example.com/{name-kebab}-privacy-policy
  moreAppsUrl: https://example.com/apps
  supportEmail: hello@example.com
  legalese: (c) 2026 Example

tooling:
  fastlane: true
  githubWorkflow: true
  screenshots: true

# Tooling for coding agents working in the generated repo. On by default.
agents:
  mcp: true                     # writes .mcp.json (dart, + appwrite when on)
  # "all" (default), "none", or a list of:
  #   store-readiness, mobile-ui-design, material-ui
  skills: all

# Omit this block entirely to skip keystore generation.
# signing:
#   alias: tipot
#   storePassword: at-least-six-characters
#   keyPassword: at-least-six-characters
''';
