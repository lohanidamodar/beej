import '../spec/app_spec.dart';
import '../spec/enums.dart';
import 'brick.dart';

/// Tooling for the coding agents that will work in the generated repo.
///
/// Two pieces, both project-scoped so they travel with the code rather than
/// living in one developer's machine configuration:
///
///  * `.mcp.json` — the Dart MCP server (which ships inside the Dart SDK, so
///    there is nothing to install), plus Appwrite's hosted server when that
///    backend is on. The Appwrite server authenticates in the browser, so no
///    credential is written into the repo.
///  * `.claude/skills/` — vendored copies of the skills relevant to a Flutter
///    app. Copies rather than references: a generated repo has to work when
///    opened on its own, by a teammate or a CI agent with none of this user's
///    personal configuration.
class AgentConfigBrick extends Brick {
  const AgentConfigBrick();

  @override
  String get id => 'agent_config';

  @override
  String get summary =>
      'MCP servers (dart, appwrite) and project-scoped agent skills';

  @override
  bool appliesTo(AppSpec spec) => !spec.agents.isEmpty;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    if (spec.agents.mcp) ...[
      const TemplateFile('agents/mcp.json.tmpl', '.mcp.json'),
      const TemplateFile('agents/mcp_readme.md.tmpl', 'docs/agent-tooling.md'),
    ],
    if (spec.agents.skills.isNotEmpty)
      const TemplateFile('skills/README.md.tmpl', '.claude/skills/README.md'),
    // Skills are copied verbatim: they are prose, and rendering them would
    // both risk mangling code samples and pointlessly bind a general-purpose
    // skill to one project's values.
    for (final skill in spec.agents.skills)
      ...skillFiles(skill).map(
        (relative) => TemplateFile(
          '${skill.templateDir}/$relative',
          '.claude/skills/${skill.wire}/$relative',
          raw: true,
        ),
      ),
  ];

  /// Files each skill ships, relative to its own directory.
  ///
  /// Listed explicitly rather than globbed so that the "every template a brick
  /// names actually ships" test can catch a skill file that goes missing.
  static List<String> skillFiles(SkillKind skill) => switch (skill) {
    SkillKind.storeReadiness => const [
      'SKILL.md',
      'references/apple.md',
      'references/play.md',
      'references/flutter-audit.md',
    ],
    SkillKind.mobileUiDesign => const ['SKILL.md', 'references/flutter.md'],
    SkillKind.materialUi => const ['SKILL.md'],
    SkillKind.moksha => const ['SKILL.md'],
    SkillKind.appStoreOptimization => const [
      'SKILL.md',
      'references/apple.md',
      'references/play.md',
    ],
  };
}
