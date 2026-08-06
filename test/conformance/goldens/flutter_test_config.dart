/// Directory-scoped test configuration for test/conformance/goldens/.
///
/// flutter_test picks the NEAREST flutter_test_config.dart above a test file
/// and stops searching (flutter_test.dart library docs), so this comparator
/// applies ONLY to tests inside this directory. It replaces the default
/// exact-match LocalFileComparator with one that tolerates up to 0.5% of
/// pixels drifting, absorbing minor anti-aliasing differences without
/// letting real regressions through.
///
/// Golden baselines are rasterised on the Linux CI runner. Every golden test
/// in this directory must therefore carry BOTH guards:
///
/// ```dart
/// testWidgets(
///   'BaseButton golden (light)',
///   (WidgetTester tester) async { ... },
///   tags: <String>['golden'],
///   skip: !Platform.isLinux, // Baselines are Linux-rendered.
/// );
/// ```
///
/// Commands:
///   flutter test --tags golden test/conformance/goldens          (Linux)
///   flutter test --update-goldens --tags golden \
///       test/conformance/goldens                                 (Linux)
///   flutter test --exclude-tags golden        (everywhere, skips goldens)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraction of pixels (0..1) allowed to differ from the golden baseline.
const double _kMaxDiffFraction = 0.005;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final GoldenFileComparator defaultComparator = goldenFileComparator;
  if (defaultComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      // LocalFileComparator derives its base directory from the dirname of
      // the URI it is given, so resolve a synthetic file name inside the
      // existing basedir to inherit it unchanged.
      defaultComparator.basedir.resolve('synthetic_test.dart'),
    );
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final bool passed =
        result.passed || result.diffPercent <= _kMaxDiffFraction;
    if (passed) {
      result.dispose();
      return true;
    }
    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
