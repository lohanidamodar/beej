import 'package:args/command_runner.dart';

import '../bricks/registry.dart';
import 'console.dart';

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
        ..line('    ${console.bold(brick.id.padRight(16))} ${brick.summary}')
        ..line('    ${' ' * 16} ${console.dim(triggerFor(brick.id))}');
    }
    console.line();
    return 0;
  }
}

/// What makes each brick apply, phrased as the spec key that controls it.
String triggerFor(String id) => switch (id) {
      'base' => 'always',
      'go_router' => 'router: go_router',
      'navigator' => 'router: navigator',
      'picons' => 'icons: picons',
      'in_app_update' => 'features.inAppUpdate: true',
      'review' => 'features.review: true',
      'nepali_dates' => 'features.nepaliDates: true',
      'appwrite' => 'backend: appwrite',
      'sqflite' => 'database: sqflite',
      'notifications' => 'features.notifications: true',
      'fastlane' => 'tooling.fastlane: true',
      'github_workflow' => 'tooling.githubWorkflow: true',
      'screenshots' => 'tooling.screenshots: true',
      'signing' => 'a signing block is present',
      _ => '',
    };
