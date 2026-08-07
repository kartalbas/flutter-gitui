/// Pins the two halves of the workspace-isolation gate (#383, #249 P1).
///
/// **Half one — the application cannot reach into a package it does not
/// depend on.** Pub workspace resolution makes every workspace member
/// importable and compilable from the app package even without a dependency
/// edge; the analyzer's only objection is `depend_on_referenced_packages`,
/// which at its default info severity does not fail `flutter analyze`. The
/// gate escalates it to error, so an import in `lib/` of a package absent from
/// the app's `dependencies` - the lint plugin, any dev dependency - is a hard
/// stop in the blocking analysis step.
///
/// That escalation is what lets the two skin packages be **dev** dependencies
/// and no more. `test/skin/pump_under_skin.dart` has to construct a
/// `BlueprintSkin` to run the zero-and-extremes sweep over the real screens,
/// so the edge has to exist somewhere; putting it in `dev_dependencies` gives
/// `test/` the package and leaves `lib/` unable to name it. Measured, not
/// assumed: a probe import of `package:gitui_skin_blueprint/…` in a `lib/`
/// file reports `depend_on_referenced_packages` as an **error**. The third
/// test below pins the arrangement so it cannot drift before P2.
///
/// **Half two — the contract cannot NAME a design language.**
/// `gitui_skin_api` imports `package:flutter/widgets.dart` and nothing else
/// from Flutter, so a Material-*named* type - `ThemeExtension`, `InputBorder`,
/// `PopupMenuEntry`, `ThemeData`, `ButtonStyle`, `Icons`, `Colors` - cannot
/// appear in a signature, because it would not resolve. That fact is worth
/// exactly as much as its enforcement: the day somebody adds
/// `import 'package:flutter/material.dart'` to make one member easier to
/// write, the contract silently stops being design-language-free while every
/// test in the repository still passes. So it is a test, not a convention.
///
/// **What this gate does NOT prove, said here so nobody relies on it.** It is
/// not the spine rule. `package:flutter/widgets.dart` exports `Color` (through
/// `dart:ui`), `EdgeInsets`, `TextStyle`, `ShapeBorder`, `IconData`,
/// `BoxDecoration`, `BorderRadius`, `Curve` and the entire `WidgetState`
/// family, and `Duration` is `dart:core` - so `final Color tint;` on a spec
/// changes no import and passes everything below. The rule that fails on that
/// is `no_value_in_contract` in `lint_rules/flutter_gitui_lint`, and it runs
/// in the blocking `dart run custom_lint` step. The two guards are
/// complementary; neither replaces the other.
///
/// The proof is a closure argument rather than a spot check, which is why
/// there are two tests and not one. The first fails on a literal
/// `package:flutter/material.dart` directive and names the file and line. The
/// second fails on *any* package import other than `package:flutter/widgets.dart`
/// and the package's own libraries - and that is what makes the first
/// exhaustive, because a second hop is then impossible: there is no third
/// package whose libraries could re-export Material into the contract, and
/// `package:flutter/widgets.dart` exports no Material symbol (that is a
/// property of the SDK, not of this repository).
///
/// Every test here exists so that an invariant cannot be dropped in passing:
/// softening the `analyzer: errors:` entry, promoting a skin package into the
/// application's own dependencies, or letting a design language into the
/// contract package each fail the suite with the invariant spelled out instead
/// of silently reopening the leak.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The one library the contract package may import from Flutter. Everything
/// the contract needs - `Widget`, `BuildContext`, `Brightness`, `FormField`,
/// `showGeneralDialog`, `RawMenuAnchor` - is exported from here; nothing
/// Material is.
const String _kOnlyLegalFlutterImport = 'package:flutter/widgets.dart';

/// The import that must never resolve inside a contract or blueprint package,
/// named on its own because it is the one the design is written against and a
/// failure should say so in the words of the design.
const String _kBannedDesignLanguageImport = 'package:flutter/material.dart';

/// One package that must stay free of every design language.
class _DesignLanguageFreePackage {
  const _DesignLanguageFreePackage({
    required this.name,
    required this.why,
    this.mayAlsoReach = const <String>[],
  });

  final String name;

  /// Printed on failure, in the words of the design.
  final String why;

  /// Other `package:` prefixes this one may import, beyond
  /// [_kOnlyLegalFlutterImport] and its own libraries.
  ///
  /// Every entry has to be a package this same test already pins, or the
  /// closure argument breaks: a package that may reach an unpinned third
  /// package can reach Material through it.
  final List<String> mayAlsoReach;
}

/// The packages that must stay free of every design language.
///
/// `gitui_skin_blueprint` is listed whether or not it is in the tree: the
/// blueprint is the second half of P1 and carries the identical rule
/// (SKIN-CONTRACT.md §2, "the blueprint's *build* is an assertion"), so listing
/// it means the day it lands it is already covered rather than depending on
/// somebody remembering to extend this file. Until then its tests report as
/// skipped with that reason, which is visible in the run output - the one thing
/// a gate for an absent directory must never do is pass quietly.
const List<_DesignLanguageFreePackage> _kDesignLanguageFreePackages =
    <_DesignLanguageFreePackage>[
      _DesignLanguageFreePackage(
        name: 'gitui_skin_api',
        why:
            'the skin contract: if Material is reachable here, a contract '
            'member can name a Material type and "no design lives in the '
            'code" stops being a compile-time fact',
      ),
      _DesignLanguageFreePackage(
        name: 'gitui_skin_blueprint',
        why:
            'the blueprint skin: its build IS the assertion that the contract '
            'needs no Material, so a Material import here makes the instrument '
            'that measures the programme part of what it measures',
        // The one package the design gives it (SKIN-CONTRACT.md §2:
        // "gitui_skin_blueprint/ depends on: gitui_skin_api, flutter (widgets
        // only)"). It does not weaken the closure, because gitui_skin_api is
        // held to the same rule by the tests above.
        mayAlsoReach: <String>['package:gitui_skin_api/'],
      ),
    ];

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

  test('main.dart is the only file in lib/ that names a skin package', () {
    // The inverse of what this test asserted before P2, and deliberately so.
    // Until P2 the skin packages were dev dependencies and the absence of the
    // edge was the guarantee; from P2 the application genuinely renders
    // through a skin, so the edge has to exist and the guarantee moves to
    // where it belongs - `main.dart` registers the languages and installs the
    // scope, and NOTHING ELSE in lib/ learns a skin package's name. That is
    // the property SKIN-CONTRACT.md §2.1 calls "what the contract guarantees",
    // and it is what a fourth skin would otherwise quietly break.
    final YamlMap pubspec =
        loadYaml(
              File(_resolveFromPackageRoot('pubspec.yaml')).readAsStringSync(),
            )
            as YamlMap;
    final Object? dependencies = pubspec['dependencies'];

    for (final String package in <String>[
      'gitui_skin_api',
      'gitui_skin_blueprint',
      'gitui_skin_material',
    ]) {
      expect(
        dependencies is YamlMap ? dependencies.containsKey(package) : false,
        isTrue,
        reason:
            '$package has to be in the application\'s `dependencies` from P2 '
            'on: lib/main.dart registers the design languages and installs '
            'SkinScope over the application, and lib/shared/components/ '
            'renders through the contract. A dev dependency would leave those '
            'imports failing `depend_on_referenced_packages` at error '
            'severity, which is the workspace-isolation gate above.',
      );
    }

    // The two SKIN packages - not the contract, which every component names -
    // may be written in exactly one file. `gitui_skin_api` is deliberately
    // absent from this list: reaching the active language through `SkinScope`
    // is what every façade is supposed to do.
    final List<_Directive> offenders =
        _directivesUnder(Directory(_resolveFromPackageRoot('lib')))
            .where(
              (_Directive d) =>
                  d.uri.startsWith('package:gitui_skin_material/') ||
                  d.uri.startsWith('package:gitui_skin_blueprint/'),
            )
            .where((_Directive d) => d.file != 'lib/main.dart')
            .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'A file other than lib/main.dart names a skin package. "Plugin" on '
          'a desktop AOT build reduces to one pubspec dependency and one '
          'register() call, and the property that actually matters is that no '
          'other file changes per skin - so a second file naming a design '
          'language is the leak, whatever it uses it for. '
          'Offending directives:\n${_describe(offenders)}',
    );
  });

  for (final _DesignLanguageFreePackage entry in _kDesignLanguageFreePackages) {
    final String package = entry.name;
    final String why = entry.why;
    final Directory sources = Directory(
      _resolveFromPackageRoot('packages/$package/lib'),
    );

    // A package that is not in the tree yet reports as skipped, naming
    // itself, rather than passing on an empty file list.
    final Object skip = sources.existsSync()
        ? false
        : 'packages/$package does not exist yet; the rule applies the moment '
              'it does';

    test(
      '$package does not resolve $_kBannedDesignLanguageImport',
      () {
        final List<_Directive> offenders = _directivesUnder(sources)
            .where((_Directive d) => d.uri.startsWith('package:flutter/'))
            .where((_Directive d) => d.uri != _kOnlyLegalFlutterImport)
            .toList();

        expect(
          offenders,
          isEmpty,
          reason:
              'packages/$package must import $_kOnlyLegalFlutterImport and '
              'nothing else from Flutter - $why. '
              'Offending directives:\n${_describe(offenders)}',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
      skip: skip,
    );

    final List<String> reachable = <String>[
      _kOnlyLegalFlutterImport,
      'package:$package/',
      ...entry.mayAlsoReach,
    ];

    test(
      '$package imports nothing but ${reachable.join(', ')}',
      () {
        // Relative imports stay inside the package by construction, and
        // `dart:` libraries carry no design language, so the closure that has
        // to be checked is exactly the `package:` one.
        final List<_Directive> offenders = _directivesUnder(sources)
            .where((_Directive d) => d.uri.startsWith('package:'))
            .where(
              (_Directive d) => !reachable.any(
                (String allowed) =>
                    d.uri == allowed || d.uri.startsWith(allowed),
              ),
            )
            .toList();

        expect(
          offenders,
          isEmpty,
          reason:
              'packages/$package may only reach ${reachable.join(', ')}. This '
              'is what makes the Material ban above exhaustive rather than a '
              'spot check: every package in the import closure is held to this '
              'same rule, so there is nothing that could re-export a design '
              'language into $package behind its back. '
              'Offending directives:\n${_describe(offenders)}',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
      skip: skip,
    );
  }
}

/// One `import` or `export` directive, with where it was written.
class _Directive {
  const _Directive({required this.uri, required this.file, required this.line});

  final String uri;

  /// Slash-separated and relative to the package root, so a failure message
  /// reads the same on every platform.
  final String file;
  final int line;

  @override
  String toString() => '$file:$line  $uri';
}

String _describe(List<_Directive> directives) =>
    directives.map((_Directive d) => '  $d').join('\n');

/// Every `import` and `export` URI written in the Dart sources under
/// [directory], newest-first order irrelevant.
///
/// Deliberately a source scan rather than an analyzer session: the property
/// being pinned is *textual reachability*, the scan needs no resolution and no
/// package config, and it runs in milliseconds inside the ordinary
/// `flutter test` run where a developer will actually see it fail.
List<_Directive> _directivesUnder(Directory directory) {
  final List<_Directive> found = <_Directive>[];
  if (!directory.existsSync()) return found;

  final String root = _resolveFromPackageRoot('');
  for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final String relative = entity.path
        .substring(root.length)
        .replaceAll(r'\', '/');
    final List<String> lines = _withoutBlockComments(
      entity.readAsStringSync(),
    ).split('\n');

    for (int index = 0; index < lines.length; index++) {
      // Anchored at column zero: a Dart directive is top-level, and
      // `dart format` - itself a gate on this repository - never indents one.
      // Anchoring is what keeps a doc comment quoting an import out of the
      // result, and stripping block comments first keeps a commented-out one
      // out too.
      final RegExpMatch? match = _kDirective.firstMatch(lines[index]);
      if (match == null) continue;
      found.add(
        _Directive(uri: match.group(2)!, file: relative, line: index + 1),
      );
    }
  }
  return found;
}

final RegExp _kDirective = RegExp('''^(import|export)\\s+['"]([^'"]+)['"]''');

/// Removes `/* ... */` comments, replacing each with the same number of
/// newlines so the reported line numbers stay the source's own.
String _withoutBlockComments(String source) => source.replaceAllMapped(
  RegExp(r'/\*.*?\*/', dotAll: true),
  (Match m) => '\n' * '\n'.allMatches(m.group(0)!).length,
);

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
