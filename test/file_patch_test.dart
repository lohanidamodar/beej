import 'package:beej/src/render/file_patch.dart';
import 'package:test/test.dart';

/// The shape `flutter create` writes, trimmed to what the edits care about:
/// the two project-level configurations that carry no bundle id, the
/// RunnerTests ones that carry a *different* id, and the three Runner ones.
///
/// Written with `\n`; [crlf] converts it for the Windows case. Both matter:
/// `flutter create` writes CRLF on Windows and LF everywhere else, and the
/// same beej release has to patch projects on both.
const _pbxproj = '''
// !\$*UTF8*\$!
{
	archiveVersion = 1;
/* Begin XCBuildConfiguration section */
		97C147031CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				SDKROOT = iphoneos;
			};
			name = Debug;
		};
		331C8088294A63A400263BE5 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "\$(TEST_HOST)";
				PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot.RunnerTests;
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = Debug;
		};
		249021D4217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot;
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = Profile;
		};
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot;
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = Debug;
		};
		97C147071CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				INFOPLIST_FILE = Runner/Info.plist;
				PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot;
				PRODUCT_NAME = "\$(TARGET_NAME)";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */
}
''';

const _infoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>\$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Tipot</string>
	<key>CFBundleName</key>
	<string>tipot</string>
</dict>
</plist>
''';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="tipot"
        android:name="\${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''';

String crlf(String source) => source.replaceAll('\n', '\r\n');

/// The pbxproj edit as the platform_identity brick issues it.
SetXcodeRunnerSettings devSuffixEdit() => const SetXcodeRunnerSettings(
  bundleIdentifier: 'com.acme.tipot',
  byConfiguration: {
    'Debug': {
      'APP_DISPLAY_NAME': 'Tipot Dev',
      'PRODUCT_BUNDLE_IDENTIFIER': 'com.acme.tipot.dev',
    },
    'Profile': {
      'APP_DISPLAY_NAME': 'Tipot Dev',
      'PRODUCT_BUNDLE_IDENTIFIER': 'com.acme.tipot.dev',
    },
    'Release': {'APP_DISPLAY_NAME': 'Tipot'},
  },
);

/// The settings of one named build configuration, as `KEY = value;` lines.
///
/// Reads the result back structurally rather than by substring, so a value
/// landing in the wrong configuration cannot pass.
List<String> settingsOf(String pbxproj, String configuration, {String? id}) {
  final lines = pbxproj.replaceAll('\r\n', '\n').split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (!RegExp(r'^\t\t[0-9A-F]{24} /\* .* \*/ = \{$').hasMatch(lines[i])) {
      continue;
    }
    final end = lines.indexOf('\t\t};', i);
    final block = lines.sublist(i, end + 1);
    final matchesName = block.contains('\t\t\tname = $configuration;');
    final matchesTarget =
        id == null ||
        block.any((l) => l.contains('PRODUCT_BUNDLE_IDENTIFIER = $id;'));
    if (matchesName && matchesTarget) {
      return block
          .where((l) => RegExp(r'^\t\t\t\t[A-Za-z0-9_]+ = ').hasMatch(l))
          .map((l) => l.trim())
          .toList();
    }
  }
  return [];
}

void main() {
  group('SetXcodeRunnerSettings', () {
    test('suffixes debug and profile but never release', () {
      final result = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');

      expect(
        settingsOf(result, 'Debug', id: 'com.acme.tipot.dev'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot.dev;'),
      );
      expect(
        settingsOf(result, 'Profile', id: 'com.acme.tipot.dev'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot.dev;'),
      );
      // The one that gets uploaded. A suffix reaching it would be shipped.
      expect(
        settingsOf(result, 'Release', id: 'com.acme.tipot'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot;'),
      );
    });

    test('gives each configuration its own display name', () {
      final result = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');

      expect(
        settingsOf(result, 'Debug', id: 'com.acme.tipot.dev'),
        contains('APP_DISPLAY_NAME = "Tipot Dev";'),
      );
      expect(
        settingsOf(result, 'Release', id: 'com.acme.tipot'),
        contains('APP_DISPLAY_NAME = Tipot;'),
      );
    });

    test('inserts new settings in the alphabetical order Xcode keeps', () {
      final result = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');
      final settings = settingsOf(result, 'Release', id: 'com.acme.tipot');
      final keys = settings.map((s) => s.split(' = ').first).toList();

      expect(keys, orderedEquals([...keys]..sort()));
      expect(keys, contains('APP_DISPLAY_NAME'));
    });

    test('leaves the RunnerTests configuration alone', () {
      final result = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');

      expect(
        settingsOf(result, 'Debug', id: 'com.acme.tipot.RunnerTests'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot.RunnerTests;'),
      );
    });

    test('leaves the project-level configuration alone', () {
      final result = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');
      final project = settingsOf(result, 'Debug')
        ..removeWhere((s) => !s.startsWith('ALWAYS_SEARCH'));

      expect(project, isNotEmpty);
      expect(
        settingsOf(result, 'Debug').join(),
        isNot(contains('APP_DISPLAY_NAME')),
        reason:
            'the project-level block carries no bundle id, so it is not '
            'a Runner configuration',
      );
    });

    test('handles CRLF, which is what flutter create writes on Windows', () {
      final result = devSuffixEdit().apply(crlf(_pbxproj), 'project.pbxproj');

      expect(result, contains('\r\n'));
      expect(result.replaceAll('\r\n', '\n'), isNot(contains('\r')));
      expect(
        settingsOf(result, 'Debug', id: 'com.acme.tipot.dev'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.acme.tipot.dev;'),
      );
    });

    test('overwrites rather than duplicates a setting already present', () {
      const first = SetXcodeRunnerSettings(
        bundleIdentifier: 'com.acme.tipot',
        byConfiguration: {
          'Release': {'APP_DISPLAY_NAME': 'Tipot'},
        },
      );
      const again = SetXcodeRunnerSettings(
        bundleIdentifier: 'com.acme.tipot',
        byConfiguration: {
          'Release': {'APP_DISPLAY_NAME': 'Renamed'},
        },
      );

      final result = again.apply(
        first.apply(_pbxproj, 'project.pbxproj'),
        'project.pbxproj',
      );
      final names = settingsOf(
        result,
        'Release',
        id: 'com.acme.tipot',
      ).where((s) => s.startsWith('APP_DISPLAY_NAME'));

      expect(names, equals(['APP_DISPLAY_NAME = Renamed;']));
    });

    test('re-suffixing an already-suffixed project fails rather than '
        'double-suffixing', () {
      final once = devSuffixEdit().apply(_pbxproj, 'project.pbxproj');

      // Patches run once, against what flutter create just wrote. Running
      // them again is a bug in the caller, and `com.acme.tipot.dev.dev` is a
      // far worse outcome than a loud failure.
      expect(
        () => devSuffixEdit().apply(once, 'project.pbxproj'),
        throwsA(isA<PatchFailure>()),
      );
    });

    test('a bundle id it cannot find is a failure, not a no-op', () {
      const edit = SetXcodeRunnerSettings(
        bundleIdentifier: 'com.acme.renamed',
        byConfiguration: {
          'Debug': {'PRODUCT_BUNDLE_IDENTIFIER': 'com.acme.renamed.dev'},
        },
      );

      expect(
        () => edit.apply(_pbxproj, 'project.pbxproj'),
        throwsA(
          isA<PatchFailure>().having(
            (e) => e.message,
            'message',
            contains('com.acme.renamed'),
          ),
        ),
      );
    });

    test('a configuration Flutter stopped emitting is a failure', () {
      const edit = SetXcodeRunnerSettings(
        bundleIdentifier: 'com.acme.tipot',
        byConfiguration: {
          'Staging': {'PRODUCT_BUNDLE_IDENTIFIER': 'com.acme.tipot.dev'},
        },
      );

      expect(
        () => edit.apply(_pbxproj, 'project.pbxproj'),
        throwsA(
          isA<PatchFailure>().having(
            (e) => e.message,
            'message',
            contains('Staging'),
          ),
        ),
      );
    });
  });

  group('SetPlistString', () {
    const edit = SetPlistString(
      key: 'CFBundleDisplayName',
      value: r'$(APP_DISPLAY_NAME)',
    );

    test('replaces the value without caring what was there', () {
      final result = edit.apply(_infoPlist, 'Info.plist');

      expect(
        result,
        contains(
          '<key>CFBundleDisplayName</key>\n'
          '\t<string>\$(APP_DISPLAY_NAME)</string>',
        ),
      );
    });

    test('leaves the neighbouring keys untouched', () {
      final result = edit.apply(_infoPlist, 'Info.plist');

      expect(result, contains('<string>tipot</string>'));
      expect(result, contains(r'<string>$(DEVELOPMENT_LANGUAGE)</string>'));
    });

    test('handles CRLF', () {
      final result = edit.apply(crlf(_infoPlist), 'Info.plist');

      expect(result, contains(r'<string>$(APP_DISPLAY_NAME)</string>'));
      expect(result, contains('\r\n'));
    });

    test('escapes a display name containing markup characters', () {
      const amp = SetPlistString(key: 'CFBundleDisplayName', value: 'A & B');

      expect(
        amp.apply(_infoPlist, 'Info.plist'),
        contains('<string>A &amp; B</string>'),
      );
    });

    test('a key that is gone is a failure, not a no-op', () {
      const missing = SetPlistString(key: 'CFBundleAbsent', value: 'x');

      expect(
        () => missing.apply(_infoPlist, 'Info.plist'),
        throwsA(isA<PatchFailure>()),
      );
    });
  });

  group('ReplaceMatch', () {
    final edit = ReplaceMatch(
      pattern: RegExp('android:label="[^"]*"'),
      replacement: r'android:label="${appLabel}"',
      describe: 'android:label attribute',
    );

    test('routes the label through the placeholder', () {
      final result = edit.apply(_manifest, 'AndroidManifest.xml');

      expect(result, contains(r'android:label="${appLabel}"'));
      expect(result, isNot(contains('android:label="tipot"')));
    });

    test(r'does not treat $ in the replacement as a group reference', () {
      final result = edit.apply(_manifest, 'AndroidManifest.xml');

      expect(result, contains(r'${appLabel}'));
    });

    test('the wrong number of matches is a failure', () {
      expect(
        () => edit.apply('<manifest/>', 'AndroidManifest.xml'),
        throwsA(
          isA<PatchFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('android:label'), contains('found 0')),
          ),
        ),
      );
    });
  });

  group('FilePatch', () {
    test('applies its edits in order', () {
      final patch = FilePatch(
        path: 'Info.plist',
        description: 'display name',
        edits: [
          const SetPlistString(key: 'CFBundleDisplayName', value: 'One'),
          const SetPlistString(key: 'CFBundleDisplayName', value: 'Two'),
        ],
      );

      expect(patch.applyTo(_infoPlist), contains('<string>Two</string>'));
    });
  });
}
