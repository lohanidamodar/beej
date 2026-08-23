import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import '../spec/icon_defaults.dart';
import 'brick.dart';
import 'versions.dart';

/// Everything every generated app gets, regardless of the choices made.
///
/// If something is here it is not a choice — the app, its theme, its
/// localization, its settings and its About module are the same shape in every
/// PopupBits app on purpose.
class BaseBrick extends Brick {
  const BaseBrick();

  @override
  String get id => 'base';

  @override
  String get summary =>
      'app shell, theme + accent/theme/language/text-size settings, '
      'localization, About module, shared UI, docs';

  @override
  bool appliesTo(AppSpec spec) => true;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    // --- Entry point and wiring ---
    const TemplateFile('base/lib/main.dart.tmpl', 'lib/main.dart'),
    const TemplateFile(
      'base/lib/core/bootstrap.dart.tmpl',
      'lib/core/bootstrap.dart',
    ),
    const TemplateFile(
      'base/lib/core/config/app_config.dart.tmpl',
      'lib/core/config/app_config.dart',
    ),
    const TemplateFile(
      'base/lib/core/router/routes.dart.tmpl',
      'lib/core/router/routes.dart',
    ),

    // --- Settings ---
    const TemplateFile(
      'base/lib/core/settings/app_settings.dart.tmpl',
      'lib/core/settings/app_settings.dart',
    ),
    const TemplateFile(
      'base/lib/core/settings/settings_controller.dart.tmpl',
      'lib/core/settings/settings_controller.dart',
    ),

    // --- Theme ---
    const TemplateFile(
      'base/lib/core/theme/tokens.dart.tmpl',
      'lib/core/theme/tokens.dart',
    ),
    const TemplateFile(
      'base/lib/core/theme/accent.dart.tmpl',
      'lib/core/theme/accent.dart',
    ),
    const TemplateFile(
      'base/lib/core/theme/app_theme.dart.tmpl',
      'lib/core/theme/app_theme.dart',
    ),
    const TemplateFile(
      'base/lib/core/theme/google_fonts_text_theme.dart.tmpl',
      'lib/core/theme/google_fonts_text_theme.dart',
    ),

    // --- Shared UI and utilities ---
    const TemplateFile(
      'base/lib/core/ui/views.dart.tmpl',
      'lib/core/ui/views.dart',
    ),
    const TemplateFile(
      'base/lib/core/ui/async_view.dart.tmpl',
      'lib/core/ui/async_view.dart',
    ),
    const TemplateFile(
      'base/lib/core/ui/feedback.dart.tmpl',
      'lib/core/ui/feedback.dart',
    ),
    const TemplateFile(
      'base/lib/core/util/responsive.dart.tmpl',
      'lib/core/util/responsive.dart',
    ),
    const TemplateFile(
      'base/lib/core/util/launcher.dart.tmpl',
      'lib/core/util/launcher.dart',
    ),

    // --- Localization: one ARB per chosen locale ---
    for (final locale in spec.locales)
      TemplateFile(
        'base/lib/l10n/app_$locale.arb.tmpl',
        'lib/l10n/app_$locale.arb',
      ),
    const TemplateFile('base/l10n.yaml.tmpl', 'l10n.yaml'),

    // --- Settings and About screens ---
    const TemplateFile(
      'base/lib/features/settings/settings_screen.dart.tmpl',
      'lib/features/settings/settings_screen.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/about_screen.dart.tmpl',
      'lib/features/settings/about_screen.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/tiles.dart.tmpl',
      'lib/features/settings/tiles.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/widgets/accent_tile.dart.tmpl',
      'lib/features/settings/widgets/accent_tile.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/widgets/theme_mode_tile.dart.tmpl',
      'lib/features/settings/widgets/theme_mode_tile.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/widgets/language_tile.dart.tmpl',
      'lib/features/settings/widgets/language_tile.dart',
    ),
    const TemplateFile(
      'base/lib/features/settings/widgets/text_scale_tile.dart.tmpl',
      'lib/features/settings/widgets/text_scale_tile.dart',
    ),

    // --- One placeholder screen per declared tab ---
    for (final tab in spec.tabs)
      TemplateFile(
        'base/lib/features/feature_screen.dart.tmpl',
        'lib/features/${tab.id}/${tab.id}_screen.dart',
        extraContext: {
          'id': tab.id,
          'pascalId': tab.pascalId,
          'label': tab.label,
          'l10nKey': tab.l10nKey,
          'icon': iconExpression(
            usePicons: spec.usesPicons,
            iconName: tab.icon,
          ),
        },
      ),

    // --- Project files ---
    const TemplateFile('base/analysis_options.yaml.tmpl', 'analysis_options.yaml'),
    const TemplateFile('base/gitignore.tmpl', '.gitignore'),
    const TemplateFile('base/README.md.tmpl', 'README.md'),
    const TemplateFile('base/PROJECT.md.tmpl', 'PROJECT.md'),
    const TemplateFile('base/CLAUDE.md.tmpl', 'CLAUDE.md'),
    const TemplateFile('base/AGENTS.md.tmpl', 'AGENTS.md'),

    // --- Tests ---
    const TemplateFile(
      'base/test/no_frozen_material_test.dart.tmpl',
      'test/no_frozen_material_test.dart',
    ),
    const TemplateFile(
      'base/test/app_smoke_test.dart.tmpl',
      'test/app_smoke_test.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    const PubDep.flutterSdk('flutter'),

    PubDep.hosted(
      'material_ui',
      Versions.materialUi,
      comment:
          'Material, decoupled from the Flutter SDK. Every file under lib/ '
          'imports this instead of package:flutter/material.dart — the two '
          'define same-named, mutually incompatible types, and '
          'test/no_frozen_material_test.dart enforces the rule.\n'
          '\n'
          'This is also why flutter_localizations is absent: material_ui '
          'exports GlobalMaterialLocalizations.delegates, covering Flutter, '
          'Material and Cupertino strings.',
    ),
    PubDep.hosted(
      'cupertino_icons',
      Versions.cupertinoIcons,
      comment:
          'Adaptive Material widgets emit IconData with the CupertinoIcons '
          'font family on iOS. Without this the tree-shaker warns and those '
          'glyphs render as missing-character boxes.',
    ),
    PubDep.hosted('flutter_riverpod', Versions.flutterRiverpod),
    PubDep.hosted(
      'google_fonts',
      Versions.googleFonts,
      comment:
          'Use googleFontsTextTheme() from core/theme/, never '
          'GoogleFonts.xTextTheme() — the latter returns a frozen-Material '
          'TextTheme that material_ui ThemeData rejects.',
    ),
    PubDep.hosted('intl', Versions.intl),
    PubDep.hosted(
      'shared_preferences',
      Versions.sharedPreferences,
      comment: 'Backs the persisted user settings (accent, theme, language, '
          'text size), loaded during bootstrap before the first frame.',
    ),
    PubDep.hosted(
      'package_info_plus',
      Versions.packageInfoPlus,
      comment:
          'Reads the installed version for the About screen, so what is shown '
          'can never drift from what shipped.',
    ),
    PubDep.hosted('share_plus', Versions.sharePlus),
    PubDep.hosted('url_launcher', Versions.urlLauncher),
    if (spec.hasWeb)
      const PubDep.flutterSdk(
        'flutter_web_plugins',
        comment: 'usePathUrlStrategy(), for hash-free URLs on the web.',
      ),
  ];

  @override
  List<PubDep> devDependencies(AppSpec spec) => [
    const PubDep.flutterSdk('flutter_test'),
    PubDep.hosted('flutter_lints', Versions.flutterLints),
  ];

  @override
  List<String> removes(AppSpec spec) => const [
    // `flutter create` writes a counter demo and its test. Both are replaced
    // by real files; leaving the test behind would fail on the first run.
    'test/widget_test.dart',
  ];
}
