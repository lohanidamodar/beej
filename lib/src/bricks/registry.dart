import 'backend_bricks.dart';
import 'base_brick.dart';
import 'brick.dart';
import 'feature_bricks.dart';
import 'router_bricks.dart';
import 'tooling_bricks.dart';

/// Every brick beej knows about, in the order they contribute.
///
/// Order matters only for presentation and for pubspec dependency order —
/// bricks never overwrite each other's files, and the planner raises a
/// [TemplateCollisionException] if two ever claim the same path.
const List<Brick> allBricks = <Brick>[
  BaseBrick(),
  GoRouterBrick(),
  NavigatorBrick(),
  AppwriteBrick(),
  SqfliteBrick(),
  PiconsBrick(),
  InAppUpdateBrick(),
  ReviewBrick(),
  NepaliDatesBrick(),
  NotificationsBrick(),
  AndroidBrick(),
  FastlaneBrick(),
  GithubWorkflowBrick(),
  ScreenshotsBrick(),
];
