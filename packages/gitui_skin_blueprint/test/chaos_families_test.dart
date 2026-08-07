/// T5, the chaos pair, at the level P1 can execute it.
///
/// `docs/SKIN-CONTRACT.md` §3.7 asks for two families and states precisely why
/// two: the original single chaotic skin varied ink AND metrics together, which
/// displaces a leak's pixels between seeds, so nothing is invariant, the zero
/// threshold is met, and the check goes green on a clean application and a
/// maximally leaky one alike. "A green test measuring nothing is the worst
/// failure a test instrument can have."
///
/// The repair is the whole of what these tests hold: **each family freezes
/// exactly what the other varies.** That property is what makes the eventual
/// pixel comparison mean something, and it is a property of the instrument
/// rather than of any scene - so it can be pinned here, now, without an image
/// comparator and without a Linux runner.
///
/// What is NOT here, said plainly: the pixel diff itself. Capturing a frame and
/// comparing two renders is the runner that `--tags blueprint-pixels` carries
/// on Linux CI (§5.9), and this repository's 68 goldens are skipped on Windows
/// for the same reason. What P1 owes is the instrument the runner needs, and
/// what these tests prove is that the instrument varies what it says it varies.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';

void main() {
  group('the chroma family varies ink and freezes metrics', () {
    test('two seeds give four distinct colours', () {
      final BlueprintVocabulary one = BlueprintVocabulary.chromaChaos(1);
      final BlueprintVocabulary two = BlueprintVocabulary.chromaChaos(2);

      expect(
        <Color>{one.paper, one.ink, two.paper, two.ink}.length,
        4,
        reason:
            'The chroma family compares two renders with each other. Any '
            'colour the two seeds share is a colour that would look invariant '
            'and be reported as the application\'s - a false positive built '
            'into the instrument.',
      );
    });

    test('seed 0 is a pair of colours rather than black on black', () {
      final BlueprintVocabulary zero = BlueprintVocabulary.chromaChaos(0);
      expect(zero.paper, isNot(zero.ink));
    });

    test('every metric is frozen at the resting value', () {
      for (final int seed in <int>[0, 1, 2, 7, 41]) {
        final BlueprintVocabulary chaos = BlueprintVocabulary.chromaChaos(seed);
        expect(chaos.strokeScale, BlueprintVocabulary.standard.strokeScale);
        expect(chaos.extentScale, BlueprintVocabulary.standard.extentScale);
        for (final Emphasis emphasis in Emphasis.values) {
          expect(
            chaos.stroke(emphasis),
            BlueprintVocabulary.standard.stroke(emphasis),
            reason:
                'A chroma seed that moved a stroke would displace the pixels '
                'it is supposed to be comparing in place, which is exactly '
                'the vacuity the two-family split repairs.',
          );
        }
        for (final ControlScale scale in ControlScale.values) {
          expect(
            chaos.extent(scale),
            BlueprintVocabulary.standard.extent(scale),
          );
        }
      }
    });

    test('the distance is frozen too', () {
      const BlueprintSkin one = BlueprintSkin.chromaChaos(seed: 1);
      const BlueprintSkin two = BlueprintSkin.chromaChaos(seed: 2);
      expect(one.distance, two.distance);
    });
  });

  group('the metric family varies metrics and freezes ink', () {
    test('two seeds give two different geometries', () {
      final BlueprintVocabulary one = BlueprintVocabulary.metricChaos(1);
      final BlueprintVocabulary two = BlueprintVocabulary.metricChaos(2);

      expect(one.stroke(Emphasis.primary), isNot(two.stroke(Emphasis.primary)));
      expect(
        one.extent(ControlScale.normal),
        isNot(two.extent(ControlScale.normal)),
      );
      expect(
        const BlueprintSkin.metricChaos(seed: 1).layout,
        isNotNull,
        reason: 'The facets resolve, which is what carries the varied rungs.',
      );
    });

    test('the gaps move between seeds as well as the strokes', () {
      final Set<double> gaps = <double>{
        for (final int seed in <int>[1, 2, 3])
          _gapUnder(BlueprintSkin.metricChaos(seed: seed)),
      };
      expect(
        gaps.length,
        3,
        reason:
            'A family that varied strokes while leaving every gap identical '
            'would leave most of the screen exactly where it was, and "did '
            'not move" is this family\'s word for "the application decided '
            'this".',
      );
    });

    test('both colours are frozen at paper and ink', () {
      for (final int seed in <int>[0, 1, 2, 7, 41]) {
        final BlueprintVocabulary chaos = BlueprintVocabulary.metricChaos(seed);
        expect(chaos.paper, BlueprintInk.standardPaper);
        expect(chaos.ink, BlueprintInk.standardInk);
      }
    });

    test('no seed produces a stroke thinner than a physical pixel', () {
      for (int seed = 0; seed < 32; seed++) {
        expect(
          BlueprintVocabulary.metricChaos(seed).stroke(Emphasis.quiet),
          greaterThanOrEqualTo(1),
        );
      }
    });
  });

  group('what neither family varies', () {
    test('ring counts and the link dash carry information, so they stand', () {
      for (final Elevation elevation in Elevation.values) {
        expect(
          BlueprintGeometry.rings(elevation),
          BlueprintGeometry.rings(elevation),
        );
      }
      expect(BlueprintGeometry.dashed(Emphasis.link), isTrue);
      expect(BlueprintGeometry.dashed(Emphasis.quiet), isFalse);
    });
  });

  group('the family reaches what the skin actually paints', () {
    testWidgets('a chroma seed changes the colour the outline is drawn in', (
      WidgetTester tester,
    ) async {
      final List<Color> inks = <Color>[];
      for (final int seed in <int>[1, 2]) {
        await tester.pumpWidget(
          _under(
            BlueprintSkin.chromaChaos(seed: seed),
            Builder(
              builder: (BuildContext context) {
                inks.add(BlueprintInk.ink(context));
                return const BlueprintBox(child: SizedBox.square(dimension: 8));
              },
            ),
          ),
        );
      }
      expect(
        inks,
        hasLength(2),
        reason: 'Both seeds rendered, so both reached the primitive.',
      );
      expect(
        inks.first,
        isNot(inks.last),
        reason:
            'The vocabulary is installed by chrome.wrapRoot and read out of '
            'the tree by every primitive, so a family that did not reach here '
            'would vary nothing that is ever painted.',
      );
    });

    testWidgets('a metric seed changes the box the control is drawn in', (
      WidgetTester tester,
    ) async {
      final List<double> extents = <double>[];
      for (final int seed in <int>[1, 2]) {
        await tester.pumpWidget(
          _under(
            BlueprintSkin.metricChaos(seed: seed),
            Builder(
              builder: (BuildContext context) {
                extents.add(
                  BlueprintGeometry.extent(context, ControlScale.normal),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
      expect(extents.first, isNot(extents.last));
    });

    testWidgets('the resting instrument is still paper and ink', (
      WidgetTester tester,
    ) async {
      late Color paper;
      late Color ink;
      await tester.pumpWidget(
        _under(
          const BlueprintSkin(),
          Builder(
            builder: (BuildContext context) {
              paper = BlueprintInk.paper(context);
              ink = BlueprintInk.ink(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(paper, BlueprintInk.standardPaper);
      expect(ink, BlueprintInk.standardInk);
      expect(
        ink.b,
        1.0,
        reason:
            'The census invariant is exact arithmetic because paper and ink '
            'share a saturated blue channel. A resting instrument that lost '
            'that would turn every antialiased glyph into a reported leak.',
      );
    });
  });
}

/// What one rung resolves to under [skin].
///
/// Read off the distance object the skin hands its facets, because that is the
/// thing the family varies; every `Proximity` and every `Inset` in the package
/// resolves through it and through nothing else.
double _gapUnder(BlueprintSkin skin) =>
    (skin.chrome as BlueprintChrome).distance.gap(Proximity.grouped);

/// A root that installs [skin] the way the application root does: the fence,
/// the scope, and the skin's own root treatment over the application.
Widget _under(BlueprintSkin skin, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: SkinScope.install(
    skin: skin,
    request: const SkinRequest(
      brightness: Brightness.light,
      accentSeed: 0,
      textScale: 1,
      animationScale: 0,
      monoFamily: 'monospace',
      uiFamily: 'sans-serif',
    ),
    dialogKeyboardHost:
        (BuildContext context, DialogSpec spec, Widget surface) => surface,
    app: ContentPort(Align(alignment: Alignment.topLeft, child: child)),
  ),
);
