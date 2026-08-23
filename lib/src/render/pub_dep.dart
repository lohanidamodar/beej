/// One entry in the generated `pubspec.yaml`.
///
/// The pubspec is assembled from these rather than rendered from a template
/// with fifteen nested conditionals. Each dependency travels with the comment
/// explaining why it is there, which is the house style across the apps and
/// the thing that decays fastest when pubspecs are hand-merged.
class PubDep {
  const PubDep(
    this.name, {
    this.constraint,
    this.sdk,
    this.gitUrl,
    this.gitPath,
    this.gitRef,
    this.comment,
  });

  /// A dependency on a version from pub.dev.
  const PubDep.hosted(String name, String constraint, {String? comment})
      : this(name, constraint: constraint, comment: comment);

  /// A dependency provided by the Flutter SDK (`sdk: flutter`).
  const PubDep.flutterSdk(String name, {String? comment})
      : this(name, sdk: 'flutter', comment: comment);

  /// A dependency pulled from a git repository.
  const PubDep.git(
    String name, {
    required String url,
    String? path,
    String? ref,
    String? comment,
  }) : this(name, gitUrl: url, gitPath: path, gitRef: ref, comment: comment);

  final String name;
  final String? constraint;
  final String? sdk;
  final String? gitUrl;
  final String? gitPath;
  final String? gitRef;

  /// Why this dependency exists. Rendered above the entry, wrapped to 76
  /// columns. Multi-paragraph comments may contain newlines.
  final String? comment;

  bool get isSdk => sdk != null;
  bool get isGit => gitUrl != null;
}
