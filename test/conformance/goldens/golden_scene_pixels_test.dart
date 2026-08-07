/// Reads the pixels a golden scene actually produces, on every platform.
///
/// The golden suite in this directory compares whole images and can only run
/// on Linux, so on Windows and macOS it is skipped and on Linux it only says
/// "same as last time". Neither answers the question this suite exists for:
/// **is the state the scene is named after present in the picture at all?**
///
/// It went unanswered for the whole life of `base_list_item_states`. That
/// scene builds a selected row, a multi-selected row and a selected row in an
/// unfocused container, and its baseline contained no selection colour of any
/// kind — 92,084 samples of `surface` and not one of `secondaryContainer`.
/// The cause was not the component: `BaseListItem` paints its tile with `Ink`
/// (base_list_item.dart:311), ink is registered on the nearest ancestor
/// `Material`, and the harness had none inside the boundary it captures, so
/// the tile painted above the `Scaffold` instead — outside the image, and
/// under the backdrop. Both golden suites were green throughout, because a
/// baseline that has always been wrong matches itself perfectly.
///
/// So this suite asserts content rather than sameness, and that is why it is
/// neither tagged `golden` nor skipped off Linux. It compares solid fills by
/// exact RGB, never glyphs or anti-aliased edges, so it carries none of the
/// per-platform rasterisation differences that force the image baselines onto
/// one machine.
///
/// Each scene measurement is paired with the same component measured in the
/// arrangement a screen actually uses. That pairing is the point: when a
/// baseline is missing something, only the second measurement says whether
/// the application is missing it too, and it says so in pixels rather than by
/// reading the widget tree and reasoning about it.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_list_item.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'component_scenes.dart';
import 'golden_scene.dart';

/// A captured frame, kept as raw RGBA so a pixel can be read by coordinate.
class _Raster {
  const _Raster(this.pixels, this.width, this.height);

  final Uint8List pixels;

  /// Row stride in pixels. Read from the image rather than assumed, because
  /// the boundary's pixel ratio need not be one.
  final int width;
  final int height;

  /// The RGB of the pixel at ([x], [y]), alpha discarded: every colour this
  /// suite looks for is an opaque scheme role painted as a solid fill.
  int rgbAt(int x, int y) {
    final int offset = (y * width + x) * 4;
    return (pixels[offset] << 16) |
        (pixels[offset + 1] << 8) |
        pixels[offset + 2];
  }

  /// How many pixels on a [step]-spaced grid carry [rgb]. Sampling rather than
  /// counting every pixel keeps a full-image scan cheap while staying far too
  /// dense for a filled row to hide from it.
  int countMatching(int rgb, {int step = 2}) {
    int matches = 0;
    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        if (rgbAt(x, y) == rgb) matches++;
      }
    }
    return matches;
  }
}

/// Rasterises the boundary [finder] identifies.
///
/// `toImage` and `toByteData` are real asynchronous engine work, so they are
/// awaited inside [WidgetTester.runAsync]; awaiting them under the fake clock
/// leaves the test hanging at teardown instead of failing. The image is
/// disposed as soon as its bytes are copied out.
Future<_Raster> _rasterise(WidgetTester tester, Finder finder) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(finder);
  final _Raster? raster = await tester.runAsync<_Raster>(() async {
    final ui.Image image = await boundary.toImage();
    try {
      final ByteData bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return _Raster(
        Uint8List.fromList(bytes.buffer.asUint8List(0, bytes.lengthInBytes)),
        image.width,
        image.height,
      );
    } finally {
      image.dispose();
    }
  });
  return raster!;
}

int _rgbOf(Color color) => color.toARGB32() & 0xFFFFFF;

String _hex(int rgb) =>
    '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Fraction of the samples across the horizontal centre line of [row] that
/// carry [rgb].
///
/// A tile that is genuinely painted fills the row edge to edge, so its own
/// colour dominates this line; the leading glyphs and the trailing controls
/// are the only things that interrupt it.
double _centreLineCoverage(_Raster raster, Rect row, Offset origin, int rgb) {
  final int y = (row.center.dy - origin.dy).round().clamp(0, raster.height - 1);
  int samples = 0;
  int matches = 0;
  for (double fraction = 0.02; fraction < 1.0; fraction += 0.02) {
    final int x = (row.left - origin.dx + row.width * fraction).round().clamp(
      0,
      raster.width - 1,
    );
    samples++;
    if (raster.rgbAt(x, y) == rgb) matches++;
  }
  return matches / samples;
}

void main() {
  final GoldenScene listItemStates = componentGoldenScenes().firstWhere(
    (GoldenScene scene) => scene.name == 'base_list_item_states',
  );

  for (final Brightness brightness in kGoldenBrightnesses) {
    testWidgets('the selected rows of base_list_item_states are painted in the '
        'captured image (${brightnessName(brightness)})', (
      WidgetTester tester,
    ) async {
      final Finder captured = await pumpGoldenScene(
        tester,
        listItemStates,
        brightness: brightness,
      );
      final ColorScheme colors = Theme.of(
        tester.element(find.byType(BaseListItem).first),
      ).colorScheme;
      final int selected = _rgbOf(colors.secondaryContainer);
      final int multiSelected = _rgbOf(colors.tertiaryContainer);

      final _Raster raster = await _rasterise(tester, captured);
      final Offset origin = tester.getTopLeft(captured);

      // The scene's rows, in the order component_scenes.dart declares them.
      final Rect selectedRow = tester.getRect(find.byType(BaseListItem).at(1));
      final Rect multiSelectedRow = tester.getRect(
        find.byType(BaseListItem).at(2),
      );
      final Rect unfocusedRow = tester.getRect(find.byType(BaseListItem).at(3));

      // Presence first, because absence is the defect this guards: the
      // colour has to occur in the file at all. The threshold is a tile's
      // worth of pixels, so a stray anti-aliased match cannot satisfy it.
      expect(
        raster.countMatching(selected),
        greaterThan(1000),
        reason:
            'The captured image holds almost no ${_hex(selected)}, the '
            'secondaryContainer this scene paints two selected rows with. '
            'A selection painted through Ink lands on the nearest ancestor '
            'Material, so this is what it looks like when that Material is '
            'outside the boundary the golden is captured from.',
      );
      expect(
        raster.countMatching(multiSelected),
        greaterThan(1000),
        reason:
            'The captured image holds almost no ${_hex(multiSelected)}, the '
            'tertiaryContainer of the multi-selected row.',
      );

      // Then position, so the colour cannot merely be somewhere in the
      // image: each row must be filled by the tile its caption names.
      expect(
        _centreLineCoverage(raster, selectedRow, origin, selected),
        greaterThan(0.5),
        reason:
            'The selected row is not filled with ${_hex(selected)} along '
            'its centre line, so the row does not read as selected.',
      );
      expect(
        _centreLineCoverage(raster, multiSelectedRow, origin, multiSelected),
        greaterThan(0.5),
        reason:
            'The multi-selected row is not filled with '
            '${_hex(multiSelected)} along its centre line.',
      );
      expect(
        _centreLineCoverage(raster, unfocusedRow, origin, selected),
        greaterThan(0.5),
        reason:
            'A selection whose container has lost focus keeps its tinted '
            'tile and only drops the ring, so this row must still be filled '
            'with ${_hex(selected)}.',
      );

      // And finally that the states stay distinguishable from each other and
      // from a plain row, which is the whole claim the scene's captions make.
      final Rect defaultRow = tester.getRect(find.byType(BaseListItem).first);
      expect(
        _centreLineCoverage(raster, defaultRow, origin, selected),
        lessThan(0.05),
        reason:
            'The unselected row carries the selection colour, so selected '
            'and default rows are indistinguishable in the baseline.',
      );
      expect(
        selected,
        isNot(multiSelected),
        reason:
            'secondaryContainer and tertiaryContainer resolve to the same '
            'colour in ${brightnessName(brightness)}, so a selected and a '
            'multi-selected row cannot be told apart.',
      );
    });

    testWidgets('a selected row is painted the way a screen builds it '
        '(${brightnessName(brightness)})', (WidgetTester tester) async {
      // The control group for the test above, and the one that decides
      // whether a broken baseline is a broken application. It arranges the
      // component the way every screen does — a ListView in a Scaffold body,
      // no wrapper of its own — and measures the same colour in the same
      // way. When the two disagree, the harness is what differs, and the
      // component is exonerated by measurement rather than by argument.
      //
      // The capture boundary sits *outside* the MaterialApp on purpose.
      // Here the ink layer is the Scaffold's, so a boundary inside the
      // Scaffold would reproduce the harness defect instead of measuring
      // the application: it would exclude the very layer under test.
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const Key screen = ValueKey<String>('screen');
      late ColorScheme colors;
      await tester.pumpWidget(
        RepaintBoundary(
          key: screen,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme()
                : AppTheme.darkTheme(),
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  colors = Theme.of(context).colorScheme;
                  return ListView(
                    children: <Widget>[
                      BaseListItem(
                        content: const Text('lib/main.dart'),
                        onTap: () {},
                      ),
                      BaseListItem(
                        content: const Text('lib/app.dart'),
                        isSelected: true,
                        onTap: () {},
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await settleScene(tester);

      final _Raster raster = await _rasterise(tester, find.byKey(screen));
      final int selected = _rgbOf(colors.secondaryContainer);
      final Rect selectedRow = tester.getRect(find.byType(BaseListItem).at(1));

      expect(
        _centreLineCoverage(raster, selectedRow, Offset.zero, selected),
        greaterThan(0.5),
        reason:
            'A selected row does not paint ${_hex(selected)} on screen. '
            'That would make this a defect in the component rather than in '
            'the golden harness: a user could not see which row they are '
            'on, in the list component the whole application is built from.',
      );
    });
  }
}
