/// Pins the workspace-isolation gate in analysis_options.yaml (#383).
///
/// Pub workspace resolution makes every workspace member importable and
/// compilable from the app package even without a dependency edge; the
/// analyzer's only objection is `depend_on_referenced_packages`, which at its
/// default info severity does not fail `flutter analyze`. The gate escalates
/// it to error, so an import in `lib/` of a package absent from the app's
/// `dependencies` - a future skin package (#249), the lint plugin, any dev
/// dependency - is a hard stop in the blocking analysis step.
///
/// This test exists so the escalation cannot be dropped in passing: removing
/// or softening the `analyzer: errors:` entry fails the suite with the
/// invariant spelled out, instead of silently reopening the leak.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('depend_on_referenced_packages stays escalated to error severity', () {
    final file = File(_resolveFromPackageRoot('analysis_options.yaml'));
    expect(
      file.existsSync(),
      isTrue,
      reason: 'analysis_options.yaml not found at ${file.path}',
    );

    final options = loadYaml(file.readAsStringSync()) as YamlMap;
    final analyzer = options['analyzer'];
    final errors = analyzer is YamlMap ? analyzer['errors'] : null;
    final severity = errors is YamlMap
        ? errors['depend_on_referenced_packages']
        : null;

    expect(
      severity,
      'error',
      reason:
          'analysis_options.yaml must keep depend_on_referenced_packages '
          'at error severity. This is the workspace-isolation gate (#383): '
          'pub workspace resolution makes every workspace member '
          'importable from lib/ without a dependency edge, and only this '
          'escalation turns that leak into a failure of the blocking '
          '`flutter analyze` step. Without it, a #249 skin package would '
          'be silently reachable from the app.',
    );
  });
}

/// Resolves [relativePath] against the package root, walking up from the
/// current directory to the first pubspec.yaml (tests may run from a
/// subdirectory).
String _resolveFromPackageRoot(String relativePath) {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return '${dir.path}/$relativePath';
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return relativePath;
    }
    dir = parent;
  }
}
