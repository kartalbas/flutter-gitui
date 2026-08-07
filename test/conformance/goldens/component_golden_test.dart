/// Golden baselines for every `Base*` component, in both brightnesses.
///
/// These are the images the design system is measured against visually. The
/// numeric conformance suite under test/conformance/components/ asserts that a
/// corner is 8 dp and a disabled foreground is `onSurface` at 38%; these
/// baselines assert that the *result* of all those numbers together has not
/// moved. The two answer different questions, and a change that slips past one
/// is usually caught by the other: a numeric suite cannot see a shadow, an
/// overlapping glyph or an icon that started painting in the wrong slot, and a
/// golden cannot say which token caused a diff.
///
/// ## Platform guard
///
/// Baselines are rasterised on the Ubuntu CI runner. Glyph rasterisation and
/// anti-aliasing differ per platform, so a PNG produced on Windows or macOS
/// can never match one produced on Linux — the difference is real but nobody
/// chose it. Every test here therefore carries `skip: !Platform.isLinux`, so
/// a developer on another platform running plain `flutter test` sees these
/// skipped rather than failing for a reason they cannot act on.
///
/// The scenes are still built on every platform: `golden_scene_smoke_test.dart`
/// walks the same registry and asserts each scene renders without an exception
/// and without an overflow. Skipping the comparison never means skipping the
/// code path.
///
/// ## Generating and updating baselines
///
/// Never from a developer machine, and never from a bot. Run the
/// `Goldens` workflow (.github/workflows/goldens.yml) with `workflow_dispatch`;
/// it regenerates the PNGs on the same Ubuntu image CI compares on and uploads
/// them as an artifact for a human to inspect and commit. A job that pushed
/// regenerated goldens automatically would turn every visual regression into a
/// silent commit, which is exactly the failure this suite exists to prevent.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'component_scenes.dart';
import 'golden_scene.dart';

void main() {
  for (final GoldenScene scene in componentGoldenScenes()) {
    for (final Brightness brightness in kGoldenBrightnesses) {
      testWidgets(
        '${scene.name} matches its golden (${brightnessName(brightness)})',
        (WidgetTester tester) async {
          final Finder captured = await pumpGoldenScene(
            tester,
            scene,
            brightness: brightness,
          );
          await expectLater(
            captured,
            matchesGoldenFile(goldenPath(scene, brightness)),
          );
        },
        tags: const <String>['golden'],
        // Baselines are Linux-rendered; see the library comment.
        skip: !Platform.isLinux,
      );
    }
  }
}
