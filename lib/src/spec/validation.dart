import 'app_spec.dart';
import 'enums.dart';

/// How badly wrong something is.
enum IssueLevel { error, warning }

/// One problem found in a spec. [field] is the spec-file path (`nav.tabs`) so
/// the message can point at the exact key the user wrote.
class SpecIssue {
  const SpecIssue(this.level, this.field, this.message, {this.hint});

  final IssueLevel level;
  final String field;
  final String message;

  /// What to do about it, when that isn't obvious from [message].
  final String? hint;

  bool get isError => level == IssueLevel.error;

  @override
  String toString() =>
      '${level.name}: $field — $message${hint == null ? '' : ' ($hint)'}';
}

/// Dart reserved words that cannot be a package name.
const _dartReserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Package names that collide with something Flutter already provides.
const _reservedPackageNames = {
  'flutter',
  'flutter_test',
  'flutter_localizations',
  'test',
  'integration_test',
};

/// Java keywords. An Android `applicationId` segment that is one of these
/// fails the Gradle build with a confusing error, so reject it here instead.
const _javaKeywords = {
  'abstract',
  'assert',
  'boolean',
  'break',
  'byte',
  'case',
  'catch',
  'char',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'double',
  'else',
  'enum',
  'extends',
  'final',
  'finally',
  'float',
  'for',
  'goto',
  'if',
  'implements',
  'import',
  'instanceof',
  'int',
  'interface',
  'long',
  'native',
  'new',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'short',
  'static',
  'strictfp',
  'super',
  'switch',
  'synchronized',
  'this',
  'throw',
  'throws',
  'transient',
  'try',
  'void',
  'volatile',
  'while',
};

/// Locales beej ships real translations for. Adding one means adding an `.arb`
/// to the base brick, not just widening this set.
const supportedLocales = {'en', 'ne'};

final _packageNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');
final _segmentPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Check [spec] and return every problem found, errors and warnings together.
///
/// An empty list means the spec is safe to generate from. A list containing
/// any [IssueLevel.error] means generation must not proceed.
List<SpecIssue> validateSpec(AppSpec spec) {
  final issues = <SpecIssue>[];

  _validateName(spec, issues);
  _validateOrg(spec, issues);
  _validateDisplay(spec, issues);
  _validatePlatforms(spec, issues);
  _validateNavigation(spec, issues);
  _validateLocales(spec, issues);
  _validateBackend(spec, issues);
  _validateKeystore(spec, issues);
  _validateDesignSystem(spec, issues);
  _validateTooling(spec, issues);

  return issues;
}

void _validateName(AppSpec spec, List<SpecIssue> issues) {
  final name = spec.name;
  if (name.isEmpty) {
    issues.add(const SpecIssue(IssueLevel.error, 'name', 'must not be empty'));
    return;
  }
  if (!_packageNamePattern.hasMatch(name)) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'name',
        '"$name" is not a valid Dart package name',
        hint:
            'lowercase letters, digits and underscores; must start with a '
            'letter — e.g. mero_nepali',
      ),
    );
  }
  if (_dartReserved.contains(name)) {
    issues.add(
      SpecIssue(IssueLevel.error, 'name', '"$name" is a Dart reserved word'),
    );
  }
  if (_reservedPackageNames.contains(name)) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'name',
        '"$name" collides with a package Flutter provides',
      ),
    );
  }
  if (name.length > 64) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'name',
        'must be 64 characters or fewer',
      ),
    );
  }
}

void _validateOrg(AppSpec spec, List<SpecIssue> issues) {
  final org = spec.org;
  if (org.isEmpty) {
    issues.add(const SpecIssue(IssueLevel.error, 'org', 'must not be empty'));
    return;
  }
  final segments = org.split('.');
  if (segments.length < 2) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'org',
        '"$org" needs at least two reverse-DNS segments',
        hint: 'e.g. com.popupbits',
      ),
    );
  }
  for (final segment in segments) {
    if (!_segmentPattern.hasMatch(segment)) {
      issues.add(
        SpecIssue(
          IssueLevel.error,
          'org',
          'segment "$segment" is not a valid identifier',
          hint:
              'lowercase letters, digits and underscores; must start with a '
              'letter',
        ),
      );
    } else if (_javaKeywords.contains(segment)) {
      issues.add(
        SpecIssue(
          IssueLevel.error,
          'org',
          'segment "$segment" is a Java keyword and will break the Android build',
        ),
      );
    }
  }
  if (_javaKeywords.contains(spec.name)) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'name',
        '"${spec.name}" is a Java keyword, so the applicationId '
            '"${spec.applicationId}" will break the Android build',
      ),
    );
  }
}

void _validateDisplay(AppSpec spec, List<SpecIssue> issues) {
  if (spec.displayName.trim().isEmpty) {
    issues.add(
      const SpecIssue(IssueLevel.error, 'displayName', 'must not be empty'),
    );
  }
  if (spec.description.trim().isEmpty) {
    issues.add(
      const SpecIssue(
        IssueLevel.warning,
        'description',
        'is empty — it lands in pubspec.yaml and the store listing',
      ),
    );
  }
}

void _validatePlatforms(AppSpec spec, List<SpecIssue> issues) {
  if (spec.platforms.isEmpty) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'platforms',
        'at least one platform is required',
        hint: 'android, ios, web, windows, macos, linux',
      ),
    );
  }
}

void _validateNavigation(AppSpec spec, List<SpecIssue> issues) {
  // A Navigator shell has no URL strategy and no deep-link parsing, so a web
  // build would ship with unroutable URLs. go_router is the only web-safe
  // choice we generate.
  if (spec.router == RouterKind.navigator && spec.hasWeb) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'router',
        'the navigator shell cannot serve the web platform',
        hint: 'use router: go_router, or drop web from platforms',
      ),
    );
  }
  if (spec.router == RouterKind.navigator && spec.hasDesktop) {
    issues.add(
      const SpecIssue(
        IssueLevel.warning,
        'router',
        'the navigator shell targets mobile; desktop windows get no deep links',
        hint: 'go_router handles desktop better',
      ),
    );
  }

  final tabs = spec.tabs;
  if (tabs.isEmpty) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'nav.tabs',
        'at least one destination is required',
      ),
    );
  }
  // Settings is always appended as the final destination, so five declared
  // tabs already means six — one past what a NavigationBar reads well with.
  if (tabs.length > 5) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'nav.tabs',
        '${tabs.length} tabs is too many (max 5; Settings is added automatically)',
      ),
    );
  }
  final seen = <String>{};
  for (final tab in tabs) {
    if (!_packageNamePattern.hasMatch(tab.id)) {
      issues.add(
        SpecIssue(
          IssueLevel.error,
          'nav.tabs',
          'tab id "${tab.id}" is not a valid identifier',
          hint: 'lowercase letters, digits and underscores',
        ),
      );
    }
    if (tab.id == 'settings') {
      issues.add(
        const SpecIssue(
          IssueLevel.error,
          'nav.tabs',
          '"settings" is generated automatically — remove it from the tab list',
        ),
      );
    }
    if (!seen.add(tab.id)) {
      issues.add(
        SpecIssue(IssueLevel.error, 'nav.tabs', 'duplicate tab id "${tab.id}"'),
      );
    }
  }
}

void _validateLocales(AppSpec spec, List<SpecIssue> issues) {
  final locales = spec.locales;
  if (!locales.contains('en')) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'locales',
        'must include "en" — it is the ARB template language',
      ),
    );
  }
  final seen = <String>{};
  for (final locale in locales) {
    if (!supportedLocales.contains(locale)) {
      issues.add(
        SpecIssue(
          IssueLevel.error,
          'locales',
          'no translations bundled for "$locale"',
          hint: 'supported: ${(supportedLocales.toList()..sort()).join(', ')}',
        ),
      );
    }
    if (!seen.add(locale)) {
      issues.add(
        SpecIssue(IssueLevel.error, 'locales', 'duplicate locale "$locale"'),
      );
    }
  }
}

void _validateBackend(AppSpec spec, List<SpecIssue> issues) {
  if (spec.backend != Backend.appwrite) {
    if (spec.appwrite != null) {
      issues.add(
        const SpecIssue(
          IssueLevel.warning,
          'backend',
          'appwrite settings are present but backend is not appwrite — ignored',
        ),
      );
    }
    return;
  }

  final appwrite = spec.appwrite;
  if (appwrite == null) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'backend',
        'backend is appwrite but no connection details were given',
      ),
    );
    return;
  }
  final endpoint = Uri.tryParse(appwrite.endpoint);
  if (endpoint == null ||
      !endpoint.isAbsolute ||
      !endpoint.scheme.startsWith('http')) {
    issues.add(
      SpecIssue(
        IssueLevel.error,
        'backend.endpoint',
        '"${appwrite.endpoint}" is not an absolute http(s) URL',
        hint: 'e.g. https://cloud.appwrite.io/v1',
      ),
    );
  }
  if (appwrite.projectId.trim().isEmpty) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'backend.projectId',
        'must not be empty',
      ),
    );
  }
  if (appwrite.databaseId.trim().isEmpty) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'backend.databaseId',
        'must not be empty',
      ),
    );
  }
}

void _validateKeystore(AppSpec spec, List<SpecIssue> issues) {
  final keystore = spec.keystore;
  if (keystore == null) return;

  if (!spec.hasAndroid) {
    issues.add(
      const SpecIssue(
        IssueLevel.warning,
        'signing',
        'keystore details given but android is not a target platform — skipped',
      ),
    );
    return;
  }
  if (keystore.alias.trim().isEmpty) {
    issues.add(
      const SpecIssue(IssueLevel.error, 'signing.alias', 'must not be empty'),
    );
  }
  // keytool refuses anything shorter, and it does so only after prompting.
  if (keystore.storePassword.length < 6) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'signing.storePassword',
        'must be at least 6 characters (keytool requirement)',
      ),
    );
  }
  if (keystore.keyPassword.length < 6) {
    issues.add(
      const SpecIssue(
        IssueLevel.error,
        'signing.keyPassword',
        'must be at least 6 characters (keytool requirement)',
      ),
    );
  }
}

void _validateDesignSystem(AppSpec spec, List<SpecIssue> issues) {
  if (!spec.usesSharedDesignSystem) return;
  // popup_bits_design pins `material_ui: ^0.0.1` — the one-line re-export
  // shim — while beej generates against the real 1.x library. Those
  // constraints cannot co-resolve, so `pub get` would fail before a single
  // file compiled. Better to say why here than to hand over a broken project.
  issues.add(
    const SpecIssue(
      IssueLevel.error,
      'designSystem',
      'popup_bits_design pins material_ui ^0.0.1 and cannot resolve alongside '
          'the 1.x line beej generates against',
      hint:
          'use designSystem: local until popup-bits-design-system widens its '
          'material_ui constraint to ^1.0.0',
    ),
  );
}

void _validateTooling(AppSpec spec, List<SpecIssue> issues) {
  if (spec.tooling.githubWorkflow && !spec.hasAndroid) {
    issues.add(
      const SpecIssue(
        IssueLevel.warning,
        'tooling.githubWorkflow',
        'the release workflow publishes to Play, but android is not targeted',
      ),
    );
  }
  if (spec.features.inAppUpdate && !spec.hasAndroid) {
    issues.add(
      const SpecIssue(
        IssueLevel.warning,
        'features.inAppUpdate',
        'Play in-app update is Android-only; it will no-op everywhere else',
      ),
    );
  }
}
