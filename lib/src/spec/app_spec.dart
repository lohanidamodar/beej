import 'enums.dart';

/// Appwrite connection details. Only present when [AppSpec.backend] is
/// [Backend.appwrite].
class AppwriteConfig {
  const AppwriteConfig({
    required this.endpoint,
    required this.projectId,
    required this.databaseId,
  });

  final String endpoint;
  final String projectId;
  final String databaseId;
}

/// One primary navigation destination.
class TabSpec {
  const TabSpec({required this.id, required this.label, required this.icon});

  /// snake_case; becomes the route path (`/home`) and the feature folder.
  final String id;

  /// The l10n key suffix and the English label seeded into `app_en.arb`.
  final String label;

  /// Icon constant name, resolved against the chosen icon set.
  final String icon;

  /// `home` -> `Home`, `my_stuff` -> `MyStuff`.
  String get pascalId => id
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join();

  /// The l10n key for this tab's label, e.g. `navHome`.
  String get l10nKey => 'nav$pascalId';
}

/// Optional feature bricks, each a plain on/off.
class Features {
  const Features({
    this.inAppUpdate = true,
    this.notifications = false,
    this.nepaliDates = false,
    this.review = true,
  });

  /// Play Core flexible in-app update, plus the snackbar state machine.
  final bool inAppUpdate;

  /// `flutter_local_notifications` + `timezone` + `flutter_timezone`.
  final bool notifications;

  /// `nepali_utils` + `nepali_date_picker` and a BS/AD date helper.
  final bool nepaliDates;

  /// An `in_app_review` prompt, offered from Settings.
  final bool review;
}

/// URLs and strings the About module renders.
///
/// Every URL is optional. A fresh project has no privacy policy page and no
/// products page yet, and a row linking nowhere is worse than no row — so a
/// tile is only generated when its value is set. Fill these in permanently
/// via `beej config` rather than per project.
class AboutConfig {
  const AboutConfig({
    this.privacyPolicyUrl,
    this.moreAppsUrl,
    this.supportEmail,
    required this.legalese,
  });

  /// Every store refuses to publish without one, so beej warns when it is
  /// missing — but does not invent a URL that would 404.
  final String? privacyPolicyUrl;

  final String? moreAppsUrl;
  final String? supportEmail;

  /// Shown on the About screen and passed to `showLicensePage`.
  final String legalese;

  bool get hasPrivacyPolicy => (privacyPolicyUrl ?? '').isNotEmpty;
  bool get hasMoreApps => (moreAppsUrl ?? '').isNotEmpty;
  bool get hasSupportEmail => (supportEmail ?? '').isNotEmpty;
}

/// Tooling for the coding agents that will work in the generated repo.
class AgentConfig {
  const AgentConfig({this.mcp = true, this.skills = const []});

  /// Write `.mcp.json` declaring the Dart MCP server (and Appwrite's, when
  /// that backend is on).
  final bool mcp;

  /// Skills copied into `.claude/skills/`.
  final List<SkillKind> skills;

  bool get isEmpty => !mcp && skills.isEmpty;
}

/// Repo-level scaffolding that is not app code.
class Tooling {
  const Tooling({
    this.fastlane = true,
    this.githubWorkflow = true,
    this.screenshots = true,
  });

  final bool fastlane;
  final bool githubWorkflow;
  final bool screenshots;
}

/// Release-signing details. When present, beej generates the keystore.
class KeystoreConfig {
  const KeystoreConfig({
    required this.alias,
    required this.storePassword,
    required this.keyPassword,
    this.dname,
    this.validityDays = 10000,
  });

  final String alias;
  final String storePassword;
  final String keyPassword;

  /// X.500 distinguished name passed to keytool. Defaults are filled in from
  /// the app's display name when omitted.
  final String? dname;
  final int validityDays;
}

/// A fully resolved, validated project configuration.
///
/// Construction never validates — build one with the parser or the defaults
/// below, then run it through `validateSpec`. Keeping validation out of the
/// constructor lets the CLI collect *every* problem and report them together
/// rather than throwing on the first.
class AppSpec {
  const AppSpec({
    required this.name,
    required this.displayName,
    required this.description,
    required this.org,
    required this.platforms,
    required this.backend,
    required this.appwrite,
    required this.router,
    required this.navStyle,
    required this.tabs,
    required this.database,
    required this.locales,
    required this.designSystem,
    required this.icons,
    required this.features,
    required this.about,
    required this.tooling,
    required this.agents,
    required this.keystore,
  });

  /// Dart package name; also the `flutter create --project-name`.
  final String name;

  /// Human-facing name shown in the UI and store listings.
  final String displayName;
  final String description;

  /// Reverse-DNS organisation prefix, e.g. `com.example`.
  final String org;

  final Set<TargetPlatform> platforms;
  final Backend backend;
  final AppwriteConfig? appwrite;
  final RouterKind router;
  final NavStyle navStyle;
  final List<TabSpec> tabs;
  final DatabaseKind database;

  /// BCP-47 language codes. Always contains `en`.
  final List<String> locales;

  final DesignSystem designSystem;
  final IconSet icons;
  final Features features;
  final AboutConfig about;
  final Tooling tooling;
  final AgentConfig agents;
  final KeystoreConfig? keystore;

  // --- Derived values -------------------------------------------------

  /// Android applicationId / iOS bundle id.
  String get applicationId => '$org.$name';

  /// `tipot` -> `Tipot`, `mero_nepali` -> `MeroNepali`. Used as the class
  /// prefix throughout the generated code (`TipotApp`, `TipotTokens`).
  String get pascalName => name
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join();

  bool get hasWeb => platforms.contains(TargetPlatform.web);
  bool get hasAndroid => platforms.contains(TargetPlatform.android);
  bool get hasIos => platforms.contains(TargetPlatform.ios);
  bool get hasDesktop => platforms.any(TargetPlatform.desktop.contains);
  bool get usesAppwrite => backend == Backend.appwrite;
  bool get usesGoRouter => router == RouterKind.goRouter;
  bool get usesSqflite => database == DatabaseKind.sqflite;
  bool get usesPicons => icons == IconSet.picons;
  bool get usesSharedDesignSystem => designSystem == DesignSystem.popupBits;

  /// Locales other than the template language, used to seed extra `.arb`s.
  List<String> get extraLocales =>
      locales.where((l) => l != 'en').toList(growable: false);

  /// The `--platforms` value for `flutter create`, in a stable order so
  /// generated projects are reproducible.
  String get flutterCreatePlatforms => TargetPlatform.values
      .where(platforms.contains)
      .map((p) => p.wire)
      .join(',');

  /// `my_app` -> `my-app`, for URLs.
  String get kebabName => name.replaceAll('_', '-');

  /// Expand `{name}` and `{name-kebab}` in a configured URL.
  ///
  /// A saved default like
  /// `https://example.com/contact/{name-kebab}-privacy-policy` is what makes
  /// a per-app URL storable as a one-time preference.
  String expandPlaceholders(String template) =>
      template.replaceAll('{name}', name).replaceAll('{name-kebab}', kebabName);

  /// The single default tab used when none are specified.
  static const defaultTabs = <TabSpec>[
    TabSpec(id: 'home', label: 'Home', icon: 'house'),
  ];

  AppSpec copyWith({
    String? name,
    String? displayName,
    String? description,
    String? org,
    Set<TargetPlatform>? platforms,
    Backend? backend,
    AppwriteConfig? appwrite,
    RouterKind? router,
    NavStyle? navStyle,
    List<TabSpec>? tabs,
    DatabaseKind? database,
    List<String>? locales,
    DesignSystem? designSystem,
    IconSet? icons,
    Features? features,
    AboutConfig? about,
    Tooling? tooling,
    AgentConfig? agents,
    KeystoreConfig? keystore,
  }) {
    return AppSpec(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      org: org ?? this.org,
      platforms: platforms ?? this.platforms,
      backend: backend ?? this.backend,
      appwrite: appwrite ?? this.appwrite,
      router: router ?? this.router,
      navStyle: navStyle ?? this.navStyle,
      tabs: tabs ?? this.tabs,
      database: database ?? this.database,
      locales: locales ?? this.locales,
      designSystem: designSystem ?? this.designSystem,
      icons: icons ?? this.icons,
      features: features ?? this.features,
      about: about ?? this.about,
      tooling: tooling ?? this.tooling,
      agents: agents ?? this.agents,
      keystore: keystore ?? this.keystore,
    );
  }
}
