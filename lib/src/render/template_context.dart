import '../bricks/versions.dart';
import '../spec/app_spec.dart';
import '../spec/enums.dart';
import '../spec/icon_defaults.dart';
import '../spec/nepali_labels.dart';

/// Build the mustache context for a spec.
///
/// Templates see booleans (`{{#appwrite}}`), strings (`{{appName}}`) and lists
/// (`{{#tabs}}`). Everything a template could need is computed here so no
/// template has to do arithmetic or string surgery — a template that needs a
/// new derived value gets it added here rather than inlining an expression.
Map<String, dynamic> buildContext(AppSpec spec) {
  final tabs = <Map<String, dynamic>>[
    for (var i = 0; i < spec.tabs.length; i++)
      {
        'id': spec.tabs[i].id,
        'pascalId': spec.tabs[i].pascalId,
        'label': spec.tabs[i].label,
        'icon': iconExpression(
          usePicons: spec.usesPicons,
          iconName: spec.tabs[i].icon,
        ),
        'l10nKey': spec.tabs[i].l10nKey,
        // Falls back to the English label when beej has no word for this id;
        // the ARB marks those so the developer can see what still needs doing.
        'neLabel': nepaliTabLabel(spec.tabs[i].id) ?? spec.tabs[i].label,
        'neTranslated': nepaliTabLabel(spec.tabs[i].id) != null,
        'index': i,
        'isFirst': i == 0,
        'isLast': i == spec.tabs.length - 1,
        'notLast': i != spec.tabs.length - 1,
      },
  ];

  return <String, dynamic>{
    // --- Identity ---
    'name': spec.name,
    'pascalName': spec.pascalName,
    'appName': spec.displayName,
    'description': spec.description,
    'org': spec.org,
    'applicationId': spec.applicationId,

    // --- Platforms ---
    'android': spec.hasAndroid,
    'ios': spec.hasIos,
    'web': spec.hasWeb,
    'desktop': spec.hasDesktop,
    'mobileOnly': !spec.hasWeb && !spec.hasDesktop,

    // --- Choices ---
    'appwrite': spec.usesAppwrite,
    'offline': !spec.usesAppwrite,
    'appwriteEndpoint': spec.appwrite?.endpoint ?? '',
    // The hosted MCP server only reaches Appwrite Cloud.
    'appwriteCloud':
        spec.appwrite?.endpoint.contains('cloud.appwrite.io') ?? false,
    'appwriteSelfHosted':
        spec.usesAppwrite &&
        !(spec.appwrite?.endpoint.contains('cloud.appwrite.io') ?? false),
    'appwriteProjectId': spec.appwrite?.projectId ?? '',
    'appwriteDatabaseId': spec.appwrite?.databaseId ?? '',

    'goRouter': spec.usesGoRouter,
    'navigator': !spec.usesGoRouter,

    'hasTabs': spec.navStyle.hasTabs,
    'hasDrawer': spec.navStyle.hasDrawer,
    'tabsOnly': spec.navStyle == NavStyle.tabs,
    'drawerOnly': spec.navStyle == NavStyle.drawer,
    'tabsAndDrawer': spec.navStyle == NavStyle.tabsAndDrawer,
    'tabs': tabs,
    'tabCount': spec.tabs.length,

    'sqflite': spec.usesSqflite,
    'hasDatabase': spec.database != DatabaseKind.none,

    'picons': spec.usesPicons,
    'materialIcons': !spec.usesPicons,
    'iconImport': spec.usesPicons ? "import 'package:picons/picons.dart';" : '',

    'sharedDesignSystem': spec.usesSharedDesignSystem,
    'localDesignSystem': !spec.usesSharedDesignSystem,

    // --- Features ---
    'inAppUpdate': spec.features.inAppUpdate,
    'notifications': spec.features.notifications,
    'nepaliDates': spec.features.nepaliDates,
    'review': spec.features.review,

    // --- Tooling ---
    'fastlane': spec.tooling.fastlane,
    'githubWorkflow': spec.tooling.githubWorkflow,
    'screenshots': spec.tooling.screenshots,
    'flutterVersion': Versions.flutterForCi,
    'mcp': spec.agents.mcp,
    // The Tooling section documents the MCP servers and the Android
    // CLI; with neither it would be an empty heading.
    'hasTooling': spec.agents.mcp || spec.hasAndroid,
    'hasSkills': spec.agents.skills.isNotEmpty,
    'skills': [
      for (final skill in spec.agents.skills) {'name': skill.wire},
    ],
    'signing': spec.keystore != null,
    'keystoreAlias': spec.keystore?.alias ?? '',
    'keystoreStorePassword': spec.keystore?.storePassword ?? '',
    'keystoreKeyPassword': spec.keystore?.keyPassword ?? '',
    'keystoreFile': 'keystore/${spec.name}.jks',

    // --- Localization ---
    'locales': [
      for (final locale in spec.locales)
        {'code': locale, 'isTemplate': locale == 'en'},
    ],
    'hasNepali': spec.locales.contains('ne'),
    'localeCodes': spec.locales.join(', '),

    // --- About ---
    // A tile is generated only when its value is set — a row linking nowhere
    // is worse than an absent row in a fresh project.
    'hasPrivacyPolicy': spec.about.hasPrivacyPolicy,
    'hasMoreApps': spec.about.hasMoreApps,
    'hasSupportEmail': spec.about.hasSupportEmail,
    // core/ui/feedback.dart is reached only from the More-apps tile
    // (toast) and the Appwrite sign-out tile (confirm).
    'tilesUseFeedback': spec.about.hasMoreApps || spec.usesAppwrite,
    'privacyPolicyUrl': spec.about.hasPrivacyPolicy
        ? spec.expandPlaceholders(spec.about.privacyPolicyUrl!)
        : '',
    'moreAppsUrl': spec.about.hasMoreApps
        ? spec.expandPlaceholders(spec.about.moreAppsUrl!)
        : '',
    'supportEmail': spec.about.supportEmail ?? '',
    'legalese': spec.about.legalese,

    // --- Icon constants used by generated chrome ---
    // Named explicitly per set: these are beej's own chrome, so there is a
    // correct icon in both vocabularies and nothing to guess.
    'iconSettings': _chrome(
      spec,
      picons: 'gear',
      material: 'settings_outlined',
    ),
    'iconAbout': _chrome(spec, picons: 'info', material: 'info_outline'),
    'iconPrivacy': _chrome(
      spec,
      picons: 'shieldCheck',
      material: 'privacy_tip_outlined',
    ),
    'iconLicense': _chrome(
      spec,
      picons: 'scroll',
      material: 'description_outlined',
    ),
    'iconShare': _chrome(
      spec,
      picons: 'shareNetwork',
      material: 'share_outlined',
    ),
    'iconRate': _chrome(spec, picons: 'star', material: 'star_outline'),
    'iconMoreApps': _chrome(
      spec,
      picons: 'appWindow',
      material: 'apps_outlined',
    ),
    'iconSupport': _chrome(spec, picons: 'envelope', material: 'mail_outline'),
    'iconAccent': _chrome(
      spec,
      picons: 'palette',
      material: 'palette_outlined',
    ),
    'iconTheme': _chrome(spec, picons: 'moon', material: 'dark_mode_outlined'),
    'iconLanguage': _chrome(spec, picons: 'translate', material: 'translate'),
    'iconTextSize': _chrome(spec, picons: 'textAa', material: 'format_size'),
    'iconAccount': _chrome(spec, picons: 'user', material: 'person_outline'),
    'iconSignOut': _chrome(
      spec,
      picons: 'signOut',
      material: 'logout_outlined',
    ),
  };
}

/// The Dart expression for a chrome icon that beej itself places, where the
/// correct constant is known in both icon sets.
String _chrome(
  AppSpec spec, {
  required String picons,
  required String material,
}) => spec.usesPicons ? 'PiconsRegular.$picons' : 'Icons.$material';
