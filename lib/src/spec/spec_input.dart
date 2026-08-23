import 'app_spec.dart';
import 'enums.dart';

/// A partially-specified configuration.
///
/// Three of these are layered to produce an [AppSpec]: defaults, then the spec
/// file, then command-line flags — each overriding the last. Every field is
/// nullable so "not mentioned" stays distinguishable from "explicitly set to
/// the default value", which is what makes the interactive prompts able to ask
/// only about what is genuinely unanswered.
class SpecInput {
  const SpecInput({
    this.name,
    this.displayName,
    this.description,
    this.org,
    this.platforms,
    this.backend,
    this.appwriteEndpoint,
    this.appwriteProjectId,
    this.appwriteDatabaseId,
    this.router,
    this.navStyle,
    this.tabs,
    this.database,
    this.locales,
    this.designSystem,
    this.icons,
    this.inAppUpdate,
    this.notifications,
    this.nepaliDates,
    this.review,
    this.privacyPolicyUrl,
    this.moreAppsUrl,
    this.supportEmail,
    this.legalese,
    this.fastlane,
    this.githubWorkflow,
    this.screenshots,
    this.keystoreAlias,
    this.keystoreStorePassword,
    this.keystoreKeyPassword,
    this.keystoreDname,
  });

  const SpecInput.empty() : this();

  final String? name;
  final String? displayName;
  final String? description;
  final String? org;
  final Set<TargetPlatform>? platforms;
  final Backend? backend;
  final String? appwriteEndpoint;
  final String? appwriteProjectId;
  final String? appwriteDatabaseId;
  final RouterKind? router;
  final NavStyle? navStyle;
  final List<TabSpec>? tabs;
  final DatabaseKind? database;
  final List<String>? locales;
  final DesignSystem? designSystem;
  final IconSet? icons;
  final bool? inAppUpdate;
  final bool? notifications;
  final bool? nepaliDates;
  final bool? review;
  final String? privacyPolicyUrl;
  final String? moreAppsUrl;
  final String? supportEmail;
  final String? legalese;
  final bool? fastlane;
  final bool? githubWorkflow;
  final bool? screenshots;
  final String? keystoreAlias;
  final String? keystoreStorePassword;
  final String? keystoreKeyPassword;
  final String? keystoreDname;

  /// True when any keystore field was supplied. Signing is generated only
  /// when the user actually asked for it.
  bool get hasAnyKeystoreField =>
      keystoreAlias != null ||
      keystoreStorePassword != null ||
      keystoreKeyPassword != null ||
      keystoreDname != null;

  /// Layer [other] on top of this one; [other]'s non-null fields win.
  SpecInput overriddenBy(SpecInput other) => SpecInput(
    name: other.name ?? name,
    displayName: other.displayName ?? displayName,
    description: other.description ?? description,
    org: other.org ?? org,
    platforms: other.platforms ?? platforms,
    backend: other.backend ?? backend,
    appwriteEndpoint: other.appwriteEndpoint ?? appwriteEndpoint,
    appwriteProjectId: other.appwriteProjectId ?? appwriteProjectId,
    appwriteDatabaseId: other.appwriteDatabaseId ?? appwriteDatabaseId,
    router: other.router ?? router,
    navStyle: other.navStyle ?? navStyle,
    tabs: other.tabs ?? tabs,
    database: other.database ?? database,
    locales: other.locales ?? locales,
    designSystem: other.designSystem ?? designSystem,
    icons: other.icons ?? icons,
    inAppUpdate: other.inAppUpdate ?? inAppUpdate,
    notifications: other.notifications ?? notifications,
    nepaliDates: other.nepaliDates ?? nepaliDates,
    review: other.review ?? review,
    privacyPolicyUrl: other.privacyPolicyUrl ?? privacyPolicyUrl,
    moreAppsUrl: other.moreAppsUrl ?? moreAppsUrl,
    supportEmail: other.supportEmail ?? supportEmail,
    legalese: other.legalese ?? legalese,
    fastlane: other.fastlane ?? fastlane,
    githubWorkflow: other.githubWorkflow ?? githubWorkflow,
    screenshots: other.screenshots ?? screenshots,
    keystoreAlias: other.keystoreAlias ?? keystoreAlias,
    keystoreStorePassword:
        other.keystoreStorePassword ?? keystoreStorePassword,
    keystoreKeyPassword: other.keystoreKeyPassword ?? keystoreKeyPassword,
    keystoreDname: other.keystoreDname ?? keystoreDname,
  );
}

/// Thrown when an input is missing something no default can supply.
class SpecResolutionException implements Exception {
  SpecResolutionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Every default in one place, so `beej spec --example` and the prompts and
/// the resolver cannot disagree about what "the default" is.
abstract final class SpecDefaults {
  static const org = 'com.popupbits';
  static const platforms = {
    TargetPlatform.android,
    TargetPlatform.ios,
    TargetPlatform.web,
    TargetPlatform.windows,
    TargetPlatform.macos,
    TargetPlatform.linux,
  };
  static const backend = Backend.none;
  static const appwriteEndpoint = 'https://cloud.appwrite.io/v1';
  static const router = RouterKind.goRouter;
  static const navStyle = NavStyle.tabsAndDrawer;
  static const database = DatabaseKind.none;
  static const locales = ['en', 'ne'];
  static const designSystem = DesignSystem.local;
  static const icons = IconSet.picons;
  static const inAppUpdate = true;
  static const notifications = false;
  static const nepaliDates = false;
  static const review = true;
  static const fastlane = true;
  static const githubWorkflow = true;
  static const screenshots = true;
  static const moreAppsUrl = 'https://www.popupbits.com/products';
  static const supportEmail = 'info@popupbits.com';
}

/// Collapse a layered [input] into a complete [AppSpec].
///
/// Does not validate — run [validateSpec] on the result. [year] is injected so
/// generated output is reproducible in tests.
AppSpec resolveSpec(SpecInput input, {required int year}) {
  final name = input.name;
  if (name == null || name.isEmpty) {
    throw SpecResolutionException(
      'no project name given — pass one as the first argument to '
      '`beej create`, or set `name:` in the spec file',
    );
  }

  final backend = input.backend ?? SpecDefaults.backend;
  final defaultAbout = AppSpec.defaultAbout(name, year);

  return AppSpec(
    name: name,
    displayName: input.displayName ?? _titleize(name),
    description: input.description ?? 'A ${_titleize(name)} app by PopupBits.',
    org: input.org ?? SpecDefaults.org,
    platforms: input.platforms ?? SpecDefaults.platforms,
    backend: backend,
    appwrite: backend == Backend.appwrite
        ? AppwriteConfig(
            endpoint: input.appwriteEndpoint ?? SpecDefaults.appwriteEndpoint,
            // The project and database conventionally share the app's name —
            // that is what every existing app does.
            projectId: input.appwriteProjectId ?? name,
            databaseId: input.appwriteDatabaseId ?? name,
          )
        : null,
    router: input.router ?? SpecDefaults.router,
    navStyle: input.navStyle ?? SpecDefaults.navStyle,
    tabs: input.tabs ?? AppSpec.defaultTabs,
    database: input.database ?? SpecDefaults.database,
    locales: input.locales ?? SpecDefaults.locales,
    designSystem: input.designSystem ?? SpecDefaults.designSystem,
    icons: input.icons ?? SpecDefaults.icons,
    features: Features(
      inAppUpdate: input.inAppUpdate ?? SpecDefaults.inAppUpdate,
      notifications: input.notifications ?? SpecDefaults.notifications,
      nepaliDates: input.nepaliDates ?? SpecDefaults.nepaliDates,
      review: input.review ?? SpecDefaults.review,
    ),
    about: AboutConfig(
      privacyPolicyUrl:
          input.privacyPolicyUrl ?? defaultAbout.privacyPolicyUrl,
      moreAppsUrl: input.moreAppsUrl ?? SpecDefaults.moreAppsUrl,
      supportEmail: input.supportEmail ?? SpecDefaults.supportEmail,
      legalese: input.legalese ?? defaultAbout.legalese,
    ),
    tooling: Tooling(
      fastlane: input.fastlane ?? SpecDefaults.fastlane,
      githubWorkflow: input.githubWorkflow ?? SpecDefaults.githubWorkflow,
      screenshots: input.screenshots ?? SpecDefaults.screenshots,
    ),
    keystore: input.hasAnyKeystoreField
        ? KeystoreConfig(
            alias: input.keystoreAlias ?? name,
            storePassword: input.keystoreStorePassword ?? '',
            keyPassword: input.keystoreKeyPassword ??
                input.keystoreStorePassword ??
                '',
            dname: input.keystoreDname,
          )
        : null,
  );
}

String _titleize(String name) => name
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
