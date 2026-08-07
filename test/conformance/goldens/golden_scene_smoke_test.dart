/// Builds every golden scene on every platform, without comparing pixels.
///
/// The golden suites can only run where the baselines were rasterised (Linux),
/// so on Windows and macOS nothing would ever execute the scene code and a
/// scene that throws — a renamed constructor parameter, a widget that needs a
/// provider, a `Row` that overflows — would stay invisible until it reached
/// CI. This suite closes that gap: it walks the same registries the golden
/// tests walk, pumps every scene in both brightnesses, and asserts that the
/// frame came out clean.
///
/// It is therefore not a weaker copy of the golden suite but the half of it
/// that is portable. A golden answers "does it still look like this"; this
/// answers "does it still build, lay out and fit", which is the question a
/// developer on any platform needs answered before pushing.
///
/// Two things are asserted per scene:
///
///   * **No exception was raised during the frame.** `WidgetTester` records
///     framework errors instead of throwing them at the call site, and a
///     `RenderFlex` overflow is reported exactly that way, so
///     `takeException()` is what turns an overflowing toolbar into a failure
///     here. That is the breakage the screen scenes exist to catch, and this
///     suite catches it on every platform rather than only on Linux.
///   * **The scene painted something.** A scene whose builder silently
///     produced an empty box would generate a blank baseline that then
///     "passes" forever, so a zero-area capture is a failure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'component_scenes.dart';
import 'golden_scene.dart';
import 'screen_scenes.dart';

void main() {
  final List<GoldenScene> scenes = <GoldenScene>[
    ...componentGoldenScenes(),
    ...screenGoldenScenes(),
  ];

  test('every golden scene has a unique name', () {
    // Two scenes sharing a name would silently write to the same baseline,
    // so the second would be compared against the first one's picture.
    final Set<String> names = scenes
        .map((GoldenScene scene) => scene.name)
        .toSet();
    expect(
      names,
      hasLength(scenes.length),
      reason:
          'Scene names become golden file names; a duplicate would make two '
          'scenes share one baseline.',
    );
  });

  for (final GoldenScene scene in scenes) {
    for (final Brightness brightness in kGoldenBrightnesses) {
      testWidgets(
        '${scene.name} renders cleanly (${brightnessName(brightness)})',
        (WidgetTester tester) async {
          final Finder captured = await pumpGoldenScene(
            tester,
            scene,
            brightness: brightness,
          );

          expect(
            tester.takeException(),
            isNull,
            reason:
                'Scene "${scene.name}" raised a framework error while '
                'rendering in ${brightnessName(brightness)}. An overflowing '
                'Row reports itself this way, so this is where a control that '
                'outgrew its toolbar surfaces.',
          );

          expect(
            captured,
            findsOneWidget,
            reason:
                'Scene "${scene.name}" produced no capture boundary; the '
                'golden suite would have nothing to compare.',
          );
          final Size size = tester.getSize(captured);
          expect(
            size.width * size.height,
            greaterThan(0),
            reason:
                'Scene "${scene.name}" laid out to $size. A zero-area scene '
                'would produce a blank baseline that passes forever.',
          );
        },
      );
    }
  }
}
