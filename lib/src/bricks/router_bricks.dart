import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import 'brick.dart';
import 'versions.dart';

/// go_router: a `StatefulShellRoute` with one branch per destination.
///
/// Handles deep links and browser URLs, so it is the only choice offered when
/// web is a target.
class GoRouterBrick extends Brick {
  const GoRouterBrick();

  @override
  String get id => 'go_router';

  @override
  String get summary =>
      'go_router with a StatefulShellRoute, the app root, and the nav shell';

  @override
  bool appliesTo(AppSpec spec) => spec.usesGoRouter;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile('router/go_router/app.dart.tmpl', 'lib/core/app.dart'),
    TemplateFile(
      'router/go_router/router.dart.tmpl',
      'lib/core/router/router.dart',
    ),
    TemplateFile(
      'router/go_router/navigation.dart.tmpl',
      'lib/core/router/navigation.dart',
    ),
    TemplateFile(
      'router/go_router/app_shell.dart.tmpl',
      'lib/features/shell/app_shell.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.hosted('go_router', Versions.goRouter),
  ];
}

/// The Navigator shell: an `IndexedStack` plus named routes.
///
/// Simpler than go_router and enough for a mobile-only app. It has no URL
/// strategy, which is why the web platform is rejected with it.
class NavigatorBrick extends Brick {
  const NavigatorBrick();

  @override
  String get id => 'navigator';

  @override
  String get summary =>
      'Navigator with named routes, an IndexedStack shell, and the app root';

  @override
  bool appliesTo(AppSpec spec) => !spec.usesGoRouter;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile('router/navigator/app.dart.tmpl', 'lib/core/app.dart'),
    TemplateFile(
      'router/navigator/router.dart.tmpl',
      'lib/core/router/router.dart',
    ),
    TemplateFile(
      'router/navigator/navigation.dart.tmpl',
      'lib/core/router/navigation.dart',
    ),
    TemplateFile(
      'router/navigator/app_shell.dart.tmpl',
      'lib/features/shell/app_shell.dart',
    ),
  ];
}
