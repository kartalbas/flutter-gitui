/// The scene model every golden in this directory is built from.
///
/// A *scene* is one deterministic arrangement of components, rendered once
/// per brightness. Keeping the arrangement in a registry rather than inline
/// in a `testWidgets` body buys three things that matter for a suite whose
/// baselines can only be produced on one platform:
///
///   * **The golden test and the smoke test iterate the same list.** The
///     golden test can only run on Linux (see below), so on a Windows or
///     macOS machine nothing would ever execute it and a scene that throws
///     while building would stay invisible until CI. `golden_scene_smoke_test`
///     builds every scene in this registry on every platform and asserts it
///     renders without an exception and without an overflow, so a broken
///     scene fails locally, in the normal `flutter test` run.
///   * **The set of images is reviewable as a list**, not as a pattern spread
///     across several test files.
///   * **A scene can declare how its state is driven** (hover, focus, press)
///     next to the widget it drives, instead of duplicating the driver in
///     both the golden and the smoke suite.
///
/// ## Why the goldens are Linux-only
///
/// Glyph rasterisation, subpixel positioning and the exact anti-aliasing of a
/// rounded corner differ per platform, so a PNG produced on Windows never
/// matches one produced on the Ubuntu CI runner — the difference is real, it
/// is simply not a difference anybody chose. The baselines are therefore
/// generated on Linux and every golden test carries `skip: !Platform.isLinux`
/// so a Windows developer running plain `flutter test` sees the goldens
/// skipped rather than falsely red. The smoke suite carries no such guard,
/// which is what keeps the scenes honest everywhere.
///
/// ## Why the pumping here does not use `pumpAndSettle`
///
/// `pumpAndSettle` runs frames until none is scheduled, which never happens
/// while an indefinite animation is on screen — the loading button's
/// `CircularProgressIndicator` is exactly that, and settling it would hang the
/// test rather than fail it. Scenes are advanced by a *fixed* number of frames
/// over a fixed elapsed time instead, which both terminates and is
/// deterministic: an indefinite animation is captured at a known phase, so its
/// golden is reproducible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../support/conformance_harness.dart';

/// Drives a scene into a non-resting state (hovered, focused, pressed) after
/// it has been pumped. Returning normally means the state is on screen and
/// the frame may be captured.
typedef SceneDriver = Future<void> Function(WidgetTester tester);

/// One arrangement of components, captured as one image per brightness.
@immutable
class GoldenScene {
  const GoldenScene({
    required this.name,
    required this.build,
    this.width,
    this.height,
    this.drive,
  });

  /// File-name stem of the baseline, without brightness or extension. The
  /// golden lands at `images/<name>_<light|dark>.png`.
  final String name;

  /// Builds the arrangement. It receives a context below the themed
  /// `MaterialApp`, so it may read `Theme.of(context)` and the app's
  /// `GitSemanticColors` extension.
  final WidgetBuilder build;

  /// Fixed logical width, when the scene must be laid out under a constraint
  /// rather than at its intrinsic size. A toolbar only overflows under a
  /// constraint, so every screen-level scene sets this.
  final double? width;

  /// Fixed logical height, same reasoning as [width].
  final double? height;

  /// Optional state driver; see [SceneDriver].
  final SceneDriver? drive;
}

/// Identifies the repaint boundary the golden is captured from, so the image
/// is exactly the scene and not the 1280x800 surface it is centred in.
const Key kGoldenSceneKey = ValueKey<String>('golden-scene');

/// Logical surface every scene is laid out in.
///
/// This is a canvas, not a claim about window size: the golden is captured
/// from the scene's own repaint boundary, so the surface only has to be large
/// enough that no scene is squeezed by it. It is deliberately larger than the
/// 1280x800 the rest of the conformance suite measures at, because a screen
/// scene stacks the same bar at three widths and the widest of those is itself
/// a full content column. The width a scene is *tested* at is the one it
/// declares in [GoldenScene.width]; anything the surface contributed would be
/// an accident of the harness rather than a property of the layout.
const Size kGoldenSurface = Size(1600, 1600);

/// Padding around a scene, so a shadow or a focus ring is not clipped by the
/// repaint boundary's edge.
const double kGoldenScenePadding = 24.0;

/// Pumps [scene] under the application's real theme at [brightness] and
/// returns the finder the golden must be matched against.
///
/// The scene is wrapped in a `RepaintBoundary` painted with the theme's
/// `surface` role: without an opaque backdrop the captured PNG would carry
/// transparent pixels wherever the scene does not paint, and a light and a
/// dark baseline would then be indistinguishable in the parts that matter
/// least and impossible to review in the parts that matter most.
///
/// ## Why the backdrop is followed by a `Material`
///
/// An `Ink` decoration and an `InkWell`'s hover, focus and press layers are
/// not painted where the widget sits. They are registered on the nearest
/// ancestor `Material`, whose `_RenderInkFeatures` paints every registered
/// feature first and its own child subtree afterwards. So an ink feature
/// always lands *below* everything drawn between that `Material` and the
/// widget that produced it.
///
/// Without the `Material` below, the nearest ancestor was the `Scaffold`'s,
/// which sits *above* this `RepaintBoundary`. That had two consequences and
/// each on its own is fatal to a baseline: the ink painted outside the
/// boundary the golden is captured from, so it was never in the image at all,
/// and the opaque backdrop below — painted by this subtree, therefore later —
/// covered it. `BaseListItem` paints its selection tile through `Ink`
/// (base_list_item.dart:311), so `base_list_item_states_dark.png` contained
/// zero pixels of `secondaryContainer` while its captions promised a selected
/// and a multi-selected row; measured on the committed baseline, 92,084
/// samples of `surface` and none of the selection colour.
///
/// Placing a `Material` here fixes both at once: the ink layer is now inside
/// the captured boundary, and it paints after the backdrop and before the
/// content. It is `MaterialType.transparency` so it contributes no background
/// of its own — the backdrop stays the single `ColoredBox` it always was, and
/// the only thing this adds to a baseline is ink that was previously lost.
/// The relative order of the tile and the state layers is untouched, because
/// both still register on one and the same ink layer in the same order: the
/// `Ink` decoration at mount, a hover or press layer when it happens, which is
/// later and therefore on top. That ordering is what
/// `base_list_item_conformance_test.dart` asserts, and it is the reason the
/// component may not go back to a `Container`.
Future<Finder> pumpGoldenScene(
  WidgetTester tester,
  GoldenScene scene, {
  required Brightness brightness,
}) async {
  // No test may reach the network for a font: the app bundles every family it
  // uses under assets/google_fonts/ (pubspec.yaml) and `flutter test` serves
  // those assets, so google_fonts resolves them locally and deterministically.
  GoogleFonts.config.allowRuntimeFetching = false;

  tester.view.physicalSize = kGoldenSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Several container components read localized strings for their built-in
      // affordances (BaseListItem's overflow-menu tooltip, BaseTextField's
      // clear button), so the delegates are always supplied; without them a
      // scene would fail on a null AppLocalizations instead of on a visual
      // difference.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme()
          : AppTheme.darkTheme(),
      // The skin, installed where `main.dart` installs it: beneath the single
      // application root and above everything it builds. A `Base*` component
      // that renders through a contract member reaches its design language
      // here, and `chrome.wrapRoot` installs the theme this file already asked
      // `AppTheme` for - so a baseline is unchanged by the installation itself
      // and moves only where a component's own rendering moved.
      builder: (BuildContext context, Widget? built) =>
          underSkin(built ?? const SizedBox.shrink(), brightness),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: kGoldenSceneKey,
            child: Builder(
              builder: (BuildContext context) {
                final ColorScheme colors = Theme.of(context).colorScheme;
                return ColoredBox(
                  color: colors.surface,
                  child: Material(
                    // Transparency, so this Material is only an ink layer and
                    // never a second backdrop; see the doc comment above.
                    // `golden_scene_smoke_test` asserts every scene's ink
                    // reaches an ink layer inside the boundary, so removing
                    // this fails there rather than silently emptying an image.
                    type: MaterialType.transparency,
                    child: Builder(
                      // A context below the Material, so a scene that reads
                      // `Material.of` resolves to the layer its ink is
                      // actually captured in.
                      builder: (BuildContext context) {
                        Widget content = Padding(
                          padding: const EdgeInsets.all(kGoldenScenePadding),
                          child: scene.build(context),
                        );
                        if (scene.width != null || scene.height != null) {
                          content = SizedBox(
                            width: scene.width,
                            height: scene.height,
                            child: content,
                          );
                        }
                        return content;
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  await settleScene(tester);
  if (scene.drive != null) {
    await scene.drive!(tester);
    await settleScene(tester);
  }
  return find.byKey(kGoldenSceneKey);
}

/// Advances a scene by a fixed, terminating amount of time.
///
/// See the library comment: `pumpAndSettle` cannot be used because an
/// indefinite animation never settles. Four frames spread over 400 ms are
/// enough for every finite transition the Base layer plays (the longest is the
/// 300 ms panel expansion, `AppTheme` animation durations) while capturing an
/// indefinite one at a fixed phase.
Future<void> settleScene(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 200));
}

/// The relative path of the baseline for [scene] at [brightness].
///
/// Baselines live in a nested `images/` directory so the test sources and the
/// PNGs stay separable in a diff and in a review; `matchesGoldenFile`
/// resolves a relative path against the directory of the test file.
String goldenPath(GoldenScene scene, Brightness brightness) {
  final String suffix = brightness == Brightness.light ? 'light' : 'dark';
  return 'images/${scene.name}_$suffix.png';
}

/// Both brightnesses, in the order the baselines are generated and reviewed.
const List<Brightness> kGoldenBrightnesses = <Brightness>[
  Brightness.light,
  Brightness.dark,
];

/// Human-readable name of [brightness], used in test names.
String brightnessName(Brightness brightness) =>
    brightness == Brightness.light ? 'light' : 'dark';
