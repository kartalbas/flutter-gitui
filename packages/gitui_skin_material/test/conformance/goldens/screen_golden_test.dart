/// Golden baselines for the application's densest bars, at three widths each.
///
/// The reason these exist alongside the component baselines is spelled out in
/// screen_scenes.dart: a component golden cannot see that a control which grew
/// by 8 dp no longer fits the `Row` it shares with six others, because in
/// isolation the grown control looks correct. These scenes lay the real
/// toolbars out under real width constraints, so a size change shows up as
/// actions migrating into an overflow menu, a label ellipsizing earlier, or a
/// row that stops fitting.
///
/// Same platform guard and same generation procedure as
/// component_golden_test.dart — see that file's library comment.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_scene.dart';
import 'screen_scenes.dart';

void main() {
  for (final GoldenScene scene in screenGoldenScenes()) {
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
        // Baselines are Linux-rendered; see component_golden_test.dart.
        skip: !Platform.isLinux,
      );
    }
  }
}
