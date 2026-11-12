import 'dart:io';

import 'package:beej/src/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('beejVersion matches the pubspec version', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
    expect(beejVersion, pubspec['version']);
  });
}
