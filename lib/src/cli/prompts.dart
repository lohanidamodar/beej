import 'dart:io';

import '../spec/app_spec.dart';
import '../spec/enums.dart';
import '../spec/icon_defaults.dart';
import '../spec/spec_input.dart';
import 'console.dart';

/// Interactive prompts.
///
/// Hand-rolled against `dart:io` rather than pulled from a package: the two
/// candidates on pub were last published in 2021 and 2023, and the set of
/// controls needed here is three.
///
/// The rule throughout is that a prompt only appears for something still
/// unanswered. Anything supplied by a flag or a spec file is left alone, so
/// `--backend appwrite` never re-asks about the backend.
Future<SpecInput> promptForMissing(
  SpecInput input, {
  required Console console,
}) async {
  var result = input;

  console
    ..line()
    ..line('  ${console.bold('beej')} ${console.dim('— plant a Flutter app')}')
    ..line();

  if (result.name == null) {
    result = result.overriddenBy(
      SpecInput(name: _text(console, 'Project name', hint: 'snake_case')),
    );
  }

  if (result.displayName == null) {
    final suggested = _titleize(result.name ?? '');
    result = result.overriddenBy(
      SpecInput(
        displayName: _text(console, 'Display name', defaultValue: suggested),
      ),
    );
  }

  if (result.description == null) {
    result = result.overriddenBy(
      SpecInput(
        description: _text(
          console,
          'One-line description',
          defaultValue: 'A ${result.displayName} app by PopupBits.',
        ),
      ),
    );
  }

  if (result.org == null) {
    result = result.overriddenBy(
      SpecInput(
        org: _text(console, 'Org prefix', defaultValue: SpecDefaults.org),
      ),
    );
  }

  if (result.platforms == null) {
    final choice = _choose(console, 'Platforms', [
      _Choice('all', 'Every platform Flutter supports'),
      _Choice('mobile', 'Android and iOS'),
      _Choice('android', 'Android only'),
      _Choice('custom', 'Pick from a list'),
    ]);
    result = result.overriddenBy(
      SpecInput(platforms: _resolvePlatforms(console, choice)),
    );
  }

  if (result.backend == null) {
    final choice = _choose(console, 'Backend', [
      _Choice('none', 'Offline only — no network, no account'),
      _Choice('appwrite', 'Appwrite: auth, database, storage'),
    ]);
    result = result.overriddenBy(
      SpecInput(
        backend: choice == 'appwrite' ? Backend.appwrite : Backend.none,
      ),
    );
  }

  final platforms = result.platforms ?? SpecDefaults.platforms;
  if (result.router == null) {
    // With web in play there is only one workable answer, so state it rather
    // than offering a choice that validation would then reject.
    if (platforms.contains(TargetPlatform.web)) {
      console.info(
        console.dim('router: go_router (required for the web platform)'),
      );
      result = result.overriddenBy(
        const SpecInput(router: RouterKind.goRouter),
      );
    } else {
      final choice = _choose(console, 'Routing', [
        _Choice('go_router', 'go_router — deep links, URLs, nested shells'),
        _Choice('navigator', 'Navigator — simpler, mobile only'),
      ]);
      result = result.overriddenBy(
        SpecInput(
          router: choice == 'navigator'
              ? RouterKind.navigator
              : RouterKind.goRouter,
        ),
      );
    }
  }

  if (result.navStyle == null) {
    final choice = _choose(console, 'Navigation', [
      _Choice('tabs+drawer', 'Bottom tabs, plus a drawer for the long tail'),
      _Choice('tabs', 'Bottom tabs only (rail when wide)'),
      _Choice('drawer', 'Drawer only'),
    ]);
    result = result.overriddenBy(
      SpecInput(
        navStyle: NavStyle.values.firstWhere((n) => n.wire == choice),
      ),
    );
  }

  if (result.tabs == null) {
    final raw = _text(
      console,
      'Destinations (comma-separated; Settings is added for you)',
      defaultValue: 'home',
    );
    final useMaterial = result.icons == IconSet.material;
    result = result.overriddenBy(
      SpecInput(
        tabs: [
          for (final id in raw
              .split(',')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty))
            TabSpec(
              id: id,
              label: titleizeTabId(id),
              icon: useMaterial
                  ? defaultMaterialIcon(id)
                  : defaultPiconsIcon(id),
            ),
        ],
      ),
    );
  }

  if (result.database == null) {
    final choice = _choose(console, 'Local database', [
      _Choice('none', 'None — shared_preferences is always available'),
      _Choice('sqflite', 'sqflite with numbered SQL migrations'),
    ]);
    result = result.overriddenBy(
      SpecInput(
        database: choice == 'sqflite'
            ? DatabaseKind.sqflite
            : DatabaseKind.none,
      ),
    );
  }

  if (result.icons == null) {
    final choice = _choose(console, 'Icons', [
      _Choice('picons', 'Phosphor (picons) — used across PopupBits apps'),
      _Choice('material', 'Material icons'),
    ]);
    result = result.overriddenBy(
      SpecInput(
        icons: choice == 'material' ? IconSet.material : IconSet.picons,
      ),
    );
  }

  if (result.inAppUpdate == null && platforms.contains(TargetPlatform.android)) {
    result = result.overriddenBy(
      SpecInput(
        inAppUpdate: _confirm(console, 'Play in-app update?', defaultYes: true),
      ),
    );
  }

  if (result.notifications == null) {
    result = result.overriddenBy(
      SpecInput(
        notifications: _confirm(
          console,
          'Local notifications?',
          defaultYes: false,
        ),
      ),
    );
  }

  if (result.nepaliDates == null) {
    result = result.overriddenBy(
      SpecInput(
        nepaliDates: _confirm(
          console,
          'Bikram Sambat dates?',
          defaultYes: false,
        ),
      ),
    );
  }

  console.line();
  return result;
}

Set<TargetPlatform> _resolvePlatforms(Console console, String choice) {
  switch (choice) {
    case 'all':
      return TargetPlatform.values.toSet();
    case 'mobile':
      return TargetPlatform.mobile;
    case 'android':
      return {TargetPlatform.android};
  }
  final raw = _text(
    console,
    'Platforms (comma-separated)',
    defaultValue: 'android,ios',
  );
  final names = raw.split(',').map((s) => s.trim());
  return {
    for (final name in names)
      if (TargetPlatform.values.any((p) => p.wire == name))
        TargetPlatform.values.firstWhere((p) => p.wire == name),
  };
}

class _Choice {
  const _Choice(this.value, this.description);
  final String value;
  final String description;
}

/// A numbered single-select. The first entry is the default.
String _choose(Console console, String question, List<_Choice> choices) {
  console
    ..line()
    ..line('  ${console.bold(question)}');
  for (var i = 0; i < choices.length; i++) {
    final marker = i == 0 ? console.dim(' (default)') : '';
    console.line(
      '    ${console.cyan('${i + 1}')}. ${choices[i].value}$marker\n'
      '       ${console.dim(choices[i].description)}',
    );
  }
  while (true) {
    stdout.write('  ${console.dim('>')} ');
    final answer = stdin.readLineSync()?.trim() ?? '';
    if (answer.isEmpty) return choices.first.value;

    final index = int.tryParse(answer);
    if (index != null && index >= 1 && index <= choices.length) {
      return choices[index - 1].value;
    }
    // Accept the value itself too — muscle memory from the flags.
    for (final choice in choices) {
      if (choice.value == answer) return choice.value;
    }
    console.warn('pick 1–${choices.length}, or type the value');
  }
}

String _text(
  Console console,
  String question, {
  String? defaultValue,
  String? hint,
}) {
  final suffix = defaultValue == null
      ? (hint == null ? '' : console.dim(' ($hint)'))
      : console.dim(' [$defaultValue]');
  while (true) {
    console
      ..line()
      ..line('  ${console.bold(question)}$suffix');
    stdout.write('  ${console.dim('>')} ');
    final answer = stdin.readLineSync()?.trim() ?? '';
    if (answer.isNotEmpty) return answer;
    if (defaultValue != null) return defaultValue;
    console.warn('this one is required');
  }
}

bool _confirm(Console console, String question, {required bool defaultYes}) {
  final suffix = console.dim(defaultYes ? ' [Y/n]' : ' [y/N]');
  while (true) {
    console
      ..line()
      ..line('  ${console.bold(question)}$suffix');
    stdout.write('  ${console.dim('>')} ');
    final answer = (stdin.readLineSync() ?? '').trim().toLowerCase();
    if (answer.isEmpty) return defaultYes;
    if (answer == 'y' || answer == 'yes') return true;
    if (answer == 'n' || answer == 'no') return false;
    console.warn('answer y or n');
  }
}

String _titleize(String name) => name
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
