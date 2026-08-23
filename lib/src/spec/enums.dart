/// The closed sets of choices a spec can express.
///
/// Every enum here carries the wire name used in the spec file and on the
/// command line, so parsing and error messages share one source of truth.
library;

/// A target platform, matching the names `flutter create --platforms` accepts.
enum TargetPlatform {
  android,
  ios,
  web,
  windows,
  macos,
  linux;

  static const desktop = {
    TargetPlatform.windows,
    TargetPlatform.macos,
    TargetPlatform.linux,
  };
  static const mobile = {TargetPlatform.android, TargetPlatform.ios};

  String get wire => name;
}

enum Backend {
  appwrite,
  none;

  String get wire => name;
}

enum RouterKind {
  goRouter('go_router'),
  navigator('navigator');

  const RouterKind(this.wire);
  final String wire;
}

enum NavStyle {
  tabs('tabs'),
  drawer('drawer'),
  tabsAndDrawer('tabs+drawer');

  const NavStyle(this.wire);
  final String wire;

  bool get hasTabs => this != NavStyle.drawer;
  bool get hasDrawer => this != NavStyle.tabs;
}

enum DatabaseKind {
  sqflite('sqflite'),
  none('none');

  const DatabaseKind(this.wire);
  final String wire;
}

enum DesignSystem {
  /// The shared `popup_bits_design` package, pulled from git.
  popupBits('popup_bits_design'),

  /// Tokens generated into the project, owned by the project.
  local('local');

  const DesignSystem(this.wire);
  final String wire;
}

enum IconSet {
  picons('picons'),
  material('material');

  const IconSet(this.wire);
  final String wire;
}

/// Look up an enum value by its wire name, or return null.
T? enumFromWire<T>(List<T> values, String? wire, String Function(T) toWire) {
  if (wire == null) return null;
  for (final v in values) {
    if (toWire(v) == wire) return v;
  }
  return null;
}
