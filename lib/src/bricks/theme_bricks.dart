import '../render/pub_dep.dart';
import '../spec/app_spec.dart';
import 'brick.dart';
import 'versions.dart';

/// Theme built from tokens the project owns.
///
/// The default. Nothing to keep in sync with another repo, and the tokens are
/// there to be edited.
class LocalThemeBrick extends Brick {
  const LocalThemeBrick();

  @override
  String get id => 'theme_local';

  @override
  String get summary => 'ThemeData built from the project\'s own tokens';

  @override
  bool appliesTo(AppSpec spec) => !spec.usesSharedDesignSystem;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'base/lib/core/theme/app_theme.dart.tmpl',
      'lib/core/theme/app_theme.dart',
    ),
  ];
}

/// Theme built from the shared `popup_bits_design` package.
///
/// The design system owns typography, shape and the component themes; the
/// generated `AppTheme` only picks an archetype and feeds it the accent the
/// user chose in Settings.
class SharedThemeBrick extends Brick {
  const SharedThemeBrick();

  @override
  String get id => 'theme_popup_bits';

  @override
  String get summary =>
      'ThemeData from the shared popup_bits_design package (archetypes)';

  @override
  bool appliesTo(AppSpec spec) => spec.usesSharedDesignSystem;

  @override
  List<TemplateFile> files(AppSpec spec) => const [
    TemplateFile(
      'design_system/app_theme.dart.tmpl',
      'lib/core/theme/app_theme.dart',
    ),
  ];

  @override
  List<PubDep> dependencies(AppSpec spec) => [
    PubDep.git(
      'popup_bits_design',
      url: Versions.popupBitsDesignUrl,
      path: Versions.popupBitsDesignPath,
      comment:
          'Shared design tokens, archetypes and the ThemeData builder. '
          'Requires material_ui 1.x — versions before 0.2.0 pinned the '
          '0.0.1 shim and cannot resolve here.',
    ),
  ];
}
