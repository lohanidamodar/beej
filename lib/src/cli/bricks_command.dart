import 'dart:math';

import 'package:args/command_runner.dart';

import '../bricks/registry.dart';
import 'console.dart';

/// Width of the brick-id column, from the longest id there actually is.
///
/// Derived rather than fixed so that adding a brick with a longer name than
/// any before it cannot silently knock the two columns out of alignment.
final int brickIdWidth = allBricks.map((b) => b.id.length).reduce(max) + 1;

/// `beej bricks` — what beej can generate, and what turns each part on.
class BricksCommand extends Command<int> {
  BricksCommand({required this.console});

  final Console console;

  @override
  String get name => 'bricks';

  @override
  String get description => 'List the available bricks.';

  @override
  Future<int> run() async {
    console.heading('bricks');
    for (final brick in allBricks) {
      console
        ..line(
          '    ${console.bold(brick.id.padRight(brickIdWidth))} '
          '${brick.summary}',
        )
        ..line(
          '    ${' ' * brickIdWidth} ${console.dim(triggerFor(brick.id))}',
        );
    }
    console.line();
    return 0;
  }
}

/// What makes each brick apply, phrased as the spec key that controls it.
String triggerFor(String id) => switch (id) {
  'base' => 'always',
  'error_capture' => 'always',
  'theme_local' => 'designSystem: local',
  'theme_popup_bits' => 'designSystem: popup_bits_design',
  'go_router' => 'router: go_router',
  'navigator' => 'router: navigator',
  'picons' => 'icons: picons',
  'in_app_update' => 'features.inAppUpdate: true',
  'review' => 'features.review: true',
  'nepali_dates' => 'features.nepaliDates: true',
  'appwrite' => 'backend: appwrite',
  'sqflite' => 'database: sqflite',
  'notifications' => 'features.notifications: true',
  'onboarding' => 'features.onboarding: true',
  'app_data_storage' => 'database: sqflite or features.onboarding',
  'fastlane' => 'tooling.fastlane: true',
  'github_workflow' => 'tooling.githubWorkflow: true',
  'screenshots' => 'tooling.screenshots: true',
  'android' => 'android is a target platform',
  'platform_identity' => 'android or ios is a target platform',
  'agent_config' => 'agents.mcp or agents.skills (on by default)',
  'signing' => 'a signing block is present',
  _ => '',
};
