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
///   * **Nothing the scene paints escapes the capture.** Ink is not painted
///     where its widget sits, so a scene can paint correctly and still be
///     missing from its own baseline; see `_expectInkIsCaptured`.
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

          _expectInkIsCaptured(tester, scene, captured);
        },
      );
    }
  }
}

/// Asserts that every ink-painting widget in [scene] paints into an ink layer
/// that lies *inside* the captured boundary.
///
/// An `Ink` decoration and an `InkWell`'s hover, focus and press layers are
/// not painted at the widget's own position in the paint order. They are
/// registered on the nearest ancestor `Material`, whose render object paints
/// every registered feature before it paints its own child subtree. So the ink
/// lands wherever that `Material` is — and if the nearest one is *above* the
/// `RepaintBoundary` the golden is captured from, the ink is not in the image
/// at all, and whatever the subtree paints in between covers it as well.
///
/// That is not hypothetical. `BaseListItem` paints its selection tile through
/// `Ink` (base_list_item.dart:311) because a `Container` would paint over the
/// hover and press layers. With no `Material` inside the boundary, the nearest
/// one was the harness `Scaffold`'s, and `base_list_item_states_dark.png`
/// contained zero pixels of `secondaryContainer` while its captions announced
/// a selected and a multi-selected row. The baseline was reviewed, committed
/// and compared by CI for as long as it existed, and it proved nothing about
/// the state it was named after.
///
/// The check walks up from each ink painter and requires a `Material` to be
/// met before the boundary is. It is deliberately expressed from the widget's
/// point of view rather than as "the harness has a Material", so it keeps
/// testing the property that matters if the harness is ever restructured.
void _expectInkIsCaptured(
  WidgetTester tester,
  GoldenScene scene,
  Finder captured,
) {
  final Element boundary = tester.element(captured);
  for (final Element element in collectAllElementsFrom(
    boundary,
    skipOffstage: false,
  )) {
    final Widget widget = element.widget;
    if (widget is! Ink && widget is! InkResponse) continue;

    bool reachedMaterialFirst = false;
    element.visitAncestorElements((Element ancestor) {
      if (ancestor.widget is Material) {
        reachedMaterialFirst = true;
        return false;
      }
      // The boundary itself, reached before any Material: the ink of this
      // widget is painted outside the image the golden is made of.
      return !identical(ancestor, boundary);
    });

    expect(
      reachedMaterialFirst,
      isTrue,
      reason:
          'Scene "${scene.name}" contains a ${widget.runtimeType} whose '
          'nearest ancestor Material lies outside the captured boundary, so '
          'its tile and its hover, focus and press layers paint into an ink '
          'layer the golden never sees. Give the boundary a Material of its '
          'own (see pumpGoldenScene) rather than moving the widget.',
    );
  }
}
