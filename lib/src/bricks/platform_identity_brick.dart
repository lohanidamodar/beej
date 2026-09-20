import '../render/file_patch.dart';
import '../spec/app_spec.dart';
import 'brick.dart';

/// Appended to the applicationId / bundle id of every build that is not the
/// store build.
const String devIdSuffix = '.dev';

/// Appended to the launcher label of those same builds, so two icons with the
/// same artwork are still tellable apart on one home screen.
const String devLabelSuffix = ' Dev';

/// How the app identifies itself to the OS: what the launcher calls it, and
/// which id it installs under.
///
/// Two things live here because they are the same edit to the same two files.
///
/// **The label.** `flutter create` writes the *package* name into
/// `android:label` and a title-cased version of it into `CFBundleDisplayName`,
/// so without this an app called "Mero Nepali" ships as `mero_nepali` on
/// Android and `Mero_nepali` on iOS. Both become `displayName`.
///
/// **The id.** With `features.devSuffix` on, debug and profile builds install
/// under `<applicationId>.dev`. Android and iOS both key "is this the same
/// app" off that id, so a different one means a debug build sits *beside* the
/// copy installed from the store instead of replacing it — you stop choosing
/// between testing a change and keeping your real data.
///
/// Release is deliberately untouched, and so are the places that name the
/// store build: `namespace` in `build.gradle.kts` (the R class package, not
/// the install id), `AppConfig.androidApplicationId` and `storeListingUrl`
/// (the `market://` link has to reach the published app), and fastlane's
/// `APP_IDENTIFIER`.
///
/// **Android and iOS only.** macOS has its own `Runner.xcodeproj` and an
/// `AppInfo.xcconfig` that would each need the same treatment, and Windows
/// and Linux have no store install to collide with in the first place. Left
/// out on purpose, not overlooked — add macOS here if a desktop build ever
/// ships to the Mac App Store.
class PlatformIdentityBrick extends Brick {
  const PlatformIdentityBrick();

  @override
  String get id => 'platform_identity';

  @override
  String get summary =>
      'Launcher label from displayName, and a .dev id for debug/profile builds';

  @override
  bool appliesTo(AppSpec spec) => spec.hasAndroid || spec.hasIos;

  @override
  List<FilePatch> patches(AppSpec spec) => [
    if (spec.hasAndroid) _androidManifest(),
    if (spec.hasIos) ..._ios(spec),
  ];

  /// Android's label is routed through a manifest placeholder so that
  /// `build.gradle.kts` — which beej owns outright — can vary it per build
  /// type. The manifest already uses `${applicationName}` the same way, so
  /// this is the idiom Flutter itself established here.
  FilePatch _androidManifest() => FilePatch(
    path: 'android/app/src/main/AndroidManifest.xml',
    description: r'android:label reads the ${appLabel} placeholder',
    edits: [
      ReplaceMatch(
        pattern: RegExp('android:label="[^"]*"'),
        replacement: r'android:label="${appLabel}"',
        describe: 'android:label attribute',
      ),
    ],
  );

  List<FilePatch> _ios(AppSpec spec) {
    final dev = spec.features.devSuffix;
    return [
      FilePatch(
        path: 'ios/Runner/Info.plist',
        description:
            r'CFBundleDisplayName reads the $(APP_DISPLAY_NAME) setting',
        edits: const [
          SetPlistString(
            key: 'CFBundleDisplayName',
            value: r'$(APP_DISPLAY_NAME)',
          ),
        ],
      ),
      FilePatch(
        path: 'ios/Runner.xcodeproj/project.pbxproj',
        description: dev
            ? 'display name and bundle id per build configuration'
            : 'display name per build configuration',
        edits: [
          // appleBundleId, not applicationId: Apple bans underscores, so
          // flutter create camel-cases the name for the bundle id. They
          // differ for every project whose name has an underscore in it.
          SetXcodeRunnerSettings(
            bundleIdentifier: spec.appleBundleId,
            byConfiguration: {
              'Debug': _iosSettings(spec, dev: dev),
              'Profile': _iosSettings(spec, dev: dev),
              'Release': {'APP_DISPLAY_NAME': spec.displayName},
              // PRODUCT_BUNDLE_IDENTIFIER is left as flutter create wrote it.
            },
          ),
        ],
      ),
    ];
  }

  Map<String, String> _iosSettings(AppSpec spec, {required bool dev}) => {
    'APP_DISPLAY_NAME': dev
        ? '${spec.displayName}$devLabelSuffix'
        : spec.displayName,
    if (dev) 'PRODUCT_BUNDLE_IDENTIFIER': '${spec.appleBundleId}$devIdSuffix',
  };
}
