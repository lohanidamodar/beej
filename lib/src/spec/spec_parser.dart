import 'package:yaml/yaml.dart';

import 'app_spec.dart';
import 'enums.dart';
import 'icon_defaults.dart';
import 'spec_input.dart';

/// Thrown when a spec file is structurally wrong — bad YAML, a key of the
/// wrong type, an unknown enum value. Semantic problems (a name that is a
/// Dart keyword, tabs that collide) are left to `validateSpec` so the user
/// sees all of them at once.
class SpecParseException implements Exception {
  SpecParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Keys beej understands at the top level. Anything else is a typo, and
/// silently ignoring it means a user's `platform:` (singular) never takes
/// effect and they cannot tell why.
const _knownTopLevelKeys = {
  'name',
  'displayName',
  'description',
  'org',
  'platforms',
  'backend',
  'router',
  'nav',
  'database',
  'locales',
  'designSystem',
  'icons',
  'features',
  'about',
  'tooling',
  'agents',
  'signing',
};

const _knownBackendKeys = {'kind', 'endpoint', 'projectId', 'databaseId'};
const _knownNavKeys = {'style', 'tabs'};
const _knownFeatureKeys = {
  'inAppUpdate',
  'notifications',
  'nepaliDates',
  'review',
};
const _knownAboutKeys = {
  'privacyPolicyUrl',
  'moreAppsUrl',
  'supportEmail',
  'legalese',
};
const _knownToolingKeys = {'fastlane', 'githubWorkflow', 'screenshots'};
const _knownAgentKeys = {'mcp', 'skills'};
const _knownSigningKeys = {'alias', 'storePassword', 'keyPassword', 'dname'};
const _knownTabKeys = {'id', 'label', 'icon'};

/// Parse a beej spec file into a partial input.
///
/// [source] is only used in error messages.
SpecInput parseSpecYaml(String yamlText, {String source = 'spec'}) {
  final dynamic doc;
  try {
    doc = loadYaml(yamlText);
  } on YamlException catch (e) {
    throw SpecParseException('$source is not valid YAML: ${e.message}');
  }

  if (doc == null) return const SpecInput.empty();
  if (doc is! Map) {
    throw SpecParseException('$source must be a YAML mapping at the top level');
  }

  _rejectUnknownKeys(doc, _knownTopLevelKeys, source, '');

  final backendMap = _mapOrNull(doc['backend'], 'backend', source);
  if (backendMap != null) {
    _rejectUnknownKeys(backendMap, _knownBackendKeys, source, 'backend.');
  }
  final navMap = _mapOrNull(doc['nav'], 'nav', source);
  if (navMap != null) {
    _rejectUnknownKeys(navMap, _knownNavKeys, source, 'nav.');
  }
  final featuresMap = _mapOrNull(doc['features'], 'features', source);
  if (featuresMap != null) {
    _rejectUnknownKeys(featuresMap, _knownFeatureKeys, source, 'features.');
  }
  final aboutMap = _mapOrNull(doc['about'], 'about', source);
  if (aboutMap != null) {
    _rejectUnknownKeys(aboutMap, _knownAboutKeys, source, 'about.');
  }
  final toolingMap = _mapOrNull(doc['tooling'], 'tooling', source);
  if (toolingMap != null) {
    _rejectUnknownKeys(toolingMap, _knownToolingKeys, source, 'tooling.');
  }
  final agentsMap = _mapOrNull(doc['agents'], 'agents', source);
  if (agentsMap != null) {
    _rejectUnknownKeys(agentsMap, _knownAgentKeys, source, 'agents.');
  }
  final signingMap = _mapOrNull(doc['signing'], 'signing', source);
  if (signingMap != null) {
    _rejectUnknownKeys(signingMap, _knownSigningKeys, source, 'signing.');
  }

  // `backend` accepts either a bare string (`backend: appwrite`) or a mapping
  // with connection details. The shorthand is what most specs will want.
  final Backend? backend;
  if (doc['backend'] is String) {
    backend = _enumValue(
      TargetPlatformParsers.backends,
      doc['backend'] as String,
      'backend',
      source,
    );
  } else if (backendMap != null) {
    backend = _enumValue(
      TargetPlatformParsers.backends,
      _stringOrNull(backendMap['kind'], 'backend.kind', source),
      'backend.kind',
      source,
    );
  } else {
    backend = null;
  }

  final icons = _enumValue(
    TargetPlatformParsers.iconSets,
    _stringOrNull(doc['icons'], 'icons', source),
    'icons',
    source,
  );

  return SpecInput(
    name: _stringOrNull(doc['name'], 'name', source),
    displayName: _stringOrNull(doc['displayName'], 'displayName', source),
    description: _stringOrNull(doc['description'], 'description', source),
    org: _stringOrNull(doc['org'], 'org', source),
    platforms: _parsePlatforms(doc['platforms'], source),
    backend: backend,
    appwriteEndpoint: _stringOrNull(
      backendMap?['endpoint'],
      'backend.endpoint',
      source,
    ),
    appwriteProjectId: _stringOrNull(
      backendMap?['projectId'],
      'backend.projectId',
      source,
    ),
    appwriteDatabaseId: _stringOrNull(
      backendMap?['databaseId'],
      'backend.databaseId',
      source,
    ),
    router: _enumValue(
      TargetPlatformParsers.routers,
      _stringOrNull(doc['router'], 'router', source),
      'router',
      source,
    ),
    navStyle: _enumValue(
      TargetPlatformParsers.navStyles,
      _stringOrNull(navMap?['style'], 'nav.style', source),
      'nav.style',
      source,
    ),
    tabs: _parseTabs(navMap?['tabs'], icons, source),
    database: _enumValue(
      TargetPlatformParsers.databases,
      _stringOrNull(doc['database'], 'database', source),
      'database',
      source,
    ),
    locales: _parseStringList(doc['locales'], 'locales', source),
    designSystem: _enumValue(
      TargetPlatformParsers.designSystems,
      _stringOrNull(doc['designSystem'], 'designSystem', source),
      'designSystem',
      source,
    ),
    icons: icons,
    inAppUpdate: _boolOrNull(
      featuresMap?['inAppUpdate'],
      'features.inAppUpdate',
      source,
    ),
    notifications: _boolOrNull(
      featuresMap?['notifications'],
      'features.notifications',
      source,
    ),
    nepaliDates: _boolOrNull(
      featuresMap?['nepaliDates'],
      'features.nepaliDates',
      source,
    ),
    review: _boolOrNull(featuresMap?['review'], 'features.review', source),
    privacyPolicyUrl: _stringOrNull(
      aboutMap?['privacyPolicyUrl'],
      'about.privacyPolicyUrl',
      source,
    ),
    moreAppsUrl: _stringOrNull(
      aboutMap?['moreAppsUrl'],
      'about.moreAppsUrl',
      source,
    ),
    supportEmail: _stringOrNull(
      aboutMap?['supportEmail'],
      'about.supportEmail',
      source,
    ),
    legalese: _stringOrNull(aboutMap?['legalese'], 'about.legalese', source),
    fastlane: _boolOrNull(toolingMap?['fastlane'], 'tooling.fastlane', source),
    githubWorkflow: _boolOrNull(
      toolingMap?['githubWorkflow'],
      'tooling.githubWorkflow',
      source,
    ),
    screenshots: _boolOrNull(
      toolingMap?['screenshots'],
      'tooling.screenshots',
      source,
    ),
    agentConfig: _boolOrNull(agentsMap?['mcp'], 'agents.mcp', source),
    skills: _parseSkills(agentsMap?['skills'], source),
    keystoreAlias: _stringOrNull(signingMap?['alias'], 'signing.alias', source),
    keystoreStorePassword: _stringOrNull(
      signingMap?['storePassword'],
      'signing.storePassword',
      source,
    ),
    keystoreKeyPassword: _stringOrNull(
      signingMap?['keyPassword'],
      'signing.keyPassword',
      source,
    ),
    keystoreDname: _stringOrNull(signingMap?['dname'], 'signing.dname', source),
  );
}

/// The enum wire-name tables, shared by the YAML parser and the flag parser so
/// `--router=go_router` and `router: go_router` accept exactly the same set.
abstract final class TargetPlatformParsers {
  static final platforms = {for (final v in TargetPlatform.values) v.wire: v};
  static final backends = {for (final v in Backend.values) v.wire: v};
  static final routers = {for (final v in RouterKind.values) v.wire: v};
  static final navStyles = {for (final v in NavStyle.values) v.wire: v};
  static final databases = {for (final v in DatabaseKind.values) v.wire: v};
  static final designSystems = {for (final v in DesignSystem.values) v.wire: v};
  static final iconSets = {for (final v in IconSet.values) v.wire: v};
}

Set<TargetPlatform>? _parsePlatforms(dynamic value, String source) {
  if (value == null) return null;
  // `platforms: all` is worth supporting: it is what most specs mean, and
  // spelling out six names invites one being forgotten.
  if (value is String && value == 'all') {
    return TargetPlatform.values.toSet();
  }
  if (value is String && value == 'mobile') return TargetPlatform.mobile;
  final list = _parseStringList(value, 'platforms', source);
  if (list == null) return null;
  final result = <TargetPlatform>{};
  for (final entry in list) {
    final platform = TargetPlatformParsers.platforms[entry];
    if (platform == null) {
      throw SpecParseException(
        '$source: unknown platform "$entry" — expected one of '
        '${TargetPlatformParsers.platforms.keys.join(', ')}, or "all"/"mobile"',
      );
    }
    result.add(platform);
  }
  return result;
}

List<TabSpec>? _parseTabs(dynamic value, IconSet? icons, String source) {
  if (value == null) return null;
  if (value is! List) {
    throw SpecParseException('$source: nav.tabs must be a list');
  }
  final useMaterial = icons == IconSet.material;
  final tabs = <TabSpec>[];
  for (final entry in value) {
    if (entry is String) {
      tabs.add(
        TabSpec(
          id: entry,
          label: titleizeTabId(entry),
          icon: useMaterial
              ? defaultMaterialIcon(entry)
              : defaultPiconsIcon(entry),
        ),
      );
      continue;
    }
    if (entry is! Map) {
      throw SpecParseException(
        '$source: each nav.tabs entry must be a string or a mapping with '
        'id/label/icon',
      );
    }
    _rejectUnknownKeys(entry, _knownTabKeys, source, 'nav.tabs[].');
    final id = _stringOrNull(entry['id'], 'nav.tabs[].id', source);
    if (id == null) {
      throw SpecParseException('$source: a nav.tabs entry is missing "id"');
    }
    final icon = _stringOrNull(entry['icon'], 'nav.tabs[].icon', source);
    tabs.add(
      TabSpec(
        id: id,
        label:
            _stringOrNull(entry['label'], 'nav.tabs[].label', source) ??
            titleizeTabId(id),
        icon:
            icon ??
            (useMaterial ? defaultMaterialIcon(id) : defaultPiconsIcon(id)),
      ),
    );
  }
  return tabs;
}

/// `agents.skills` accepts a list of names, or `none`/`all` as shorthands.
List<SkillKind>? _parseSkills(dynamic value, String source) {
  if (value == null) return null;
  if (value is String) {
    if (value == 'none') return const [];
    if (value == 'all') return SkillKind.values;
  }
  final names = _parseStringList(value, 'agents.skills', source);
  if (names == null) return null;
  final table = {for (final s in SkillKind.values) s.wire: s};
  final result = <SkillKind>[];
  for (final name in names) {
    final skill = table[name];
    if (skill == null) {
      throw SpecParseException(
        '$source: unknown skill "$name" — expected some of '
        '${table.keys.join(', ')}, or "all"/"none"',
      );
    }
    if (!result.contains(skill)) result.add(skill);
  }
  return result;
}

// --- Small typed readers -------------------------------------------------

Map? _mapOrNull(dynamic value, String field, String source) {
  if (value == null) return null;
  if (value is Map) return value;
  // A bare string backend is handled by the caller; anything else is wrong.
  if (field == 'backend' && value is String) return null;
  throw SpecParseException('$source: $field must be a mapping');
}

String? _stringOrNull(dynamic value, String field, String source) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  throw SpecParseException('$source: $field must be a string');
}

bool? _boolOrNull(dynamic value, String field, String source) {
  if (value == null) return null;
  if (value is bool) return value;
  throw SpecParseException('$source: $field must be true or false');
}

List<String>? _parseStringList(dynamic value, String field, String source) {
  if (value == null) return null;
  if (value is String) return [value];
  if (value is! List) {
    throw SpecParseException('$source: $field must be a list');
  }
  return [for (final entry in value) _stringOrNull(entry, '$field[]', source)!];
}

T? _enumValue<T>(
  Map<String, T> table,
  String? wire,
  String field,
  String source,
) {
  if (wire == null) return null;
  final value = table[wire];
  if (value == null) {
    throw SpecParseException(
      '$source: unknown $field "$wire" — expected one of '
      '${table.keys.join(', ')}',
    );
  }
  return value;
}

void _rejectUnknownKeys(
  Map map,
  Set<String> known,
  String source,
  String prefix,
) {
  for (final key in map.keys) {
    if (!known.contains(key)) {
      final suggestion = _closest(key.toString(), known);
      throw SpecParseException(
        '$source: unknown key "$prefix$key"'
        '${suggestion == null ? '' : ' — did you mean "$prefix$suggestion"?'}',
      );
    }
  }
}

/// Cheapest useful typo hint: a candidate within edit distance 2.
String? _closest(String input, Set<String> candidates) {
  String? best;
  var bestDistance = 3;
  for (final candidate in candidates) {
    final distance = _editDistance(
      input.toLowerCase(),
      candidate.toLowerCase(),
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = <int>[i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        current[j - 1] + 1,
        previous[j] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
