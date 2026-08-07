// The shrink-only budget of test files that build their own application root
// (#249, P1).
//
// ## The failure this exists to prevent
//
// T2, the zero-and-extremes sweep (docs/SKIN-CONTRACT.md §3.4), runs this
// entire suite under `--dart-define=SKIN=blueprint` and reads the result as
// evidence about the application. A test file that constructs its own
// `MaterialApp` ignores that define completely: it renders Material, passes,
// and contributes a green tick to a run that was supposed to be measuring a
// different skin. The design names this exactly - "a false-confidence risk in
// the instrument itself is worse than no instrument" - and it is the reason
// pump_under_skin.dart exists.
//
// Re-rooting the files that do this is mechanical work, and it is P1's, not
// this test's. What this test does is stop the population from growing while
// that work is outstanding, and lock in every file that has been converted:
// the budget is the measured count, it may only shrink, and a run in which it
// could have shrunk but did not is also a failure. That second half is what
// makes it a ratchet rather than a ceiling - the same both-directions
// discipline docs/deviation_register.yaml already uses, where a registered
// entry that now conforms fails as stale.
//
// ## Scope
//
// This package's `test/` only. The Material skin's conformance suite
// (packages/gitui_skin_material/test/) is a different package with a different
// job: it renders *Material's* pixels on purpose and its goldens are that
// skin's baselines, so a `MaterialApp` there is the subject, not a leak. The
// design carves out exactly that exception.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// How many files under `test/` may still build their own application root.
///
/// Measured, not chosen: 46 when the funnel landed, 43 after the three files
/// re-rooted in the same commit (stashes, branches and tags keyboard tests).
/// Lower it whenever another file moves onto `pumpUnderSkin`; the test below
/// fails if it is not lowered, so the gain cannot be given back silently.
const int kOwnRootBudget = 43;

/// The file that is allowed to *build* the application root, because it is
/// the funnel every other file is being moved onto.
const String kTheFunnel = 'test/skin/pump_under_skin.dart';

/// This file, which names the root only in order to look for it and would
/// otherwise count itself as an offender.
const String kThisGate = 'test/skin/test_root_budget_test.dart';

/// What a test file must not construct for itself.
const String kApplicationRoot = 'MaterialApp(';

void main() {
  test(
    'the number of test files building their own application root only shrinks',
    () {
      final List<String> offenders = _filesBuildingTheirOwnRoot();

      expect(
        offenders.length,
        lessThanOrEqualTo(kOwnRootBudget),
        reason:
            'A test file under test/ builds its own $kApplicationRoot instead '
            'of going through pumpUnderSkin (test/skin/pump_under_skin.dart). '
            'Such a file renders Material whatever --dart-define=SKIN says, so '
            'it would report a pass in a blueprint run that never rendered a '
            'blueprint. The budget of $kOwnRootBudget is the count measured '
            'when the funnel landed and may only shrink.\n'
            'Files:\n${offenders.map((String f) => '  $f').join('\n')}',
      );

      expect(
        offenders.length,
        greaterThanOrEqualTo(kOwnRootBudget),
        reason:
            'Only ${offenders.length} files still build their own '
            '$kApplicationRoot, which is fewer than the budget of '
            '$kOwnRootBudget - so files have been re-rooted onto pumpUnderSkin '
            'without the budget following them down. Set kOwnRootBudget to '
            '${offenders.length} in the same commit, or the next file to '
            'regress will be waved through by the slack.',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('the funnel is still the funnel', () {
    final File funnel = File(_resolveFromPackageRoot(kTheFunnel));
    expect(
      funnel.existsSync(),
      isTrue,
      reason:
          '$kTheFunnel is the single place this package builds an application '
          'root; without it every re-rooted test has nowhere to go.',
    );
    expect(
      kApplicationRoot.allMatches(funnel.readAsStringSync()).length,
      1,
      reason:
          'The funnel must contain exactly one $kApplicationRoot. More than '
          'one means the root has been forked inside the funnel itself, which '
          'is the same leak one level down: at P2 only one of them would be '
          'replaced by the skin.',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}

/// Every file under `test/` that names [kApplicationRoot], except the funnel.
List<String> _filesBuildingTheirOwnRoot() {
  final Directory tests = Directory(_resolveFromPackageRoot('test'));
  final int rootLength = _resolveFromPackageRoot('').length;
  final List<String> found = <String>[];

  for (final FileSystemEntity entity in tests.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final String relative = entity.path
        .substring(rootLength)
        .replaceAll(r'\', '/');
    if (relative == kTheFunnel || relative == kThisGate) continue;
    if (entity.readAsStringSync().contains(kApplicationRoot)) {
      found.add(relative);
    }
  }
  found.sort();
  return found;
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
    final Directory parent = dir.parent;
    if (parent.path == dir.path) return relativePath;
    dir = parent;
  }
}
