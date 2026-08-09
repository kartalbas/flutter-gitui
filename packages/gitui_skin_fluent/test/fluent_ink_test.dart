// Guards the ink facet: that every Tone resolves under both brightnesses,
// that the separations and collapses the ink documents are real, that the
// git palette holds WCAG 2.1 AA (4.5:1 as text, the discipline #341 imposed
// on the Material palette) and the series holds 3:1 as a graphic on every
// paper this skin composites text over, and that the four metric maps keep
// their rungs distinct and ordered.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/fluent_ink.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';
import 'package:gitui_skin_fluent/src/fluent_theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours (SC 1.4.3 / 1.4.11).
double wcagContrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

/// Every opaque paper git ink is painted over: the solid background ramp,
/// the card flattened onto the page ground, and the hovered card - WinUI
/// composites the subtle hover fill over the card, so a hovered row is the
/// lightest dark surface text ever sits on.
List<Color> papers(FluentResources res) {
  final Color card = Color.alphaBlend(
    res.cardBackgroundFillColorDefault,
    res.solidBackgroundFillColorBase,
  );
  return <Color>[
    res.solidBackgroundFillColorBase,
    res.solidBackgroundFillColorSecondary,
    res.solidBackgroundFillColorTertiary,
    res.solidBackgroundFillColorQuarternary,
    card,
    Color.alphaBlend(res.subtleFillColorSecondary, card),
  ];
}

const List<FluentThemeData> themes = <FluentThemeData>[
  FluentThemeData.light(),
  FluentThemeData.dark(),
];

/// Every named tone the vocabulary declares.
const List<Tone> namedTones = <Tone>[
  Tone.neutral,
  Tone.muted,
  Tone.accent,
  Tone.onAccent,
  Tone.danger,
  Tone.warning,
  Tone.invalid,
  Tone.success,
  Tone.info,
  Tone.gitAdded,
  Tone.gitModified,
  Tone.gitDeleted,
  Tone.gitRenamed,
  Tone.gitUntracked,
  Tone.gitConflicted,
  Tone.gitIgnored,
  Tone.gitStaged,
];

void main() {
  test('every tone resolves to visible ink under both brightnesses', () {
    for (final FluentThemeData theme in themes) {
      for (final Tone tone in namedTones) {
        final Color ink = FluentInk.foreground(theme, tone);
        expect(
          ink.a,
          greaterThan(0),
          reason: '$tone resolved fully transparent (${theme.brightness})',
        );
      }
      for (int i = 0; i < FluentInk.seriesLength; i++) {
        expect(
          FluentInk.foreground(theme, Tone.series(i)).a,
          greaterThan(0),
          reason: 'series($i) resolved fully transparent (${theme.brightness})',
        );
      }
    }
  });

  test('the separations and collapses the ink documents are real', () {
    for (final FluentThemeData theme in themes) {
      final String label = '${theme.brightness}';
      // Fluent separates invalid from danger - the vocabulary's own proof
      // that invalid is a meaning, not a colour.
      expect(
        FluentInk.foreground(theme, Tone.invalid),
        isNot(FluentInk.foreground(theme, Tone.danger)),
        reason: 'invalid must not collapse onto danger ($label)',
      );
      // Fluent's own collapse: info is painted with the accent brush
      // (InfoBar's informational icon). Pinned so a drive-by "fix" that
      // invents an informational colour is caught as the invention it is.
      expect(
        FluentInk.foreground(theme, Tone.info),
        FluentInk.foreground(theme, Tone.accent),
        reason: 'info collapses onto the accent brush by WinUI rule ($label)',
      );
      // The two rendering collapses the git palette makes, same as Material.
      expect(
        FluentInk.foreground(theme, Tone.gitIgnored),
        FluentInk.foreground(theme, Tone.gitUntracked),
        reason: 'gitIgnored renders as gitUntracked ($label)',
      );
      expect(
        FluentInk.foreground(theme, Tone.gitStaged),
        FluentInk.foreground(theme, Tone.gitAdded),
        reason: 'gitStaged renders as gitAdded ($label)',
      );
    }
  });

  test('muted answers against the surface the text sits on', () {
    for (final FluentThemeData theme in themes) {
      final FluentResources res = theme.resources;
      // Nothing published, or the page's own foreground: the supporting fill.
      expect(FluentInk.mutedBeside(res, null), res.textFillColorSecondary);
      expect(
        FluentInk.mutedBeside(res, res.textFillColorPrimary),
        res.textFillColorSecondary,
      );
      // On an accent fill Fluent HAS the quieter on-accent word.
      expect(
        FluentInk.mutedBeside(res, res.textOnAccentFillColorPrimary),
        res.textOnAccentFillColorSecondary,
      );
      // Any other published foreground: muted collapses onto it.
      const Color published = Color(0xFF123456);
      expect(FluentInk.mutedBeside(res, published), published);
    }
  });

  test('git text tones hold WCAG AA 4.5:1 on every paper', () {
    for (final FluentThemeData theme in themes) {
      final FluentGitPalette git = FluentGitPalette.forBrightness(
        theme.brightness,
      );
      final Map<String, Color> roles = <String, Color>{
        'added': git.added,
        'modified': git.modified,
        'deleted': git.deleted,
        'renamed': git.renamed,
        'untracked': git.untracked,
        'conflict': git.conflict,
      };
      for (final Color paper in papers(theme.resources)) {
        roles.forEach((String name, Color color) {
          expect(
            wcagContrast(color, paper),
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${_hex(color)} < 4.5:1 on paper ${_hex(paper)} '
                '(${theme.brightness})',
          );
        });
      }
      // Filled tones: the black/white foreground the helper picks must
      // clear 4.5:1 on the solid role colour.
      roles.forEach((String name, Color color) {
        expect(
          wcagContrast(FluentInk.foregroundOn(color), color),
          greaterThanOrEqualTo(4.5),
          reason: 'foregroundOn(${_hex(color)}) < 4.5:1 on $name',
        );
      });
    }
  });

  test('the series holds 3:1 as a graphic on every paper and wraps', () {
    expect(FluentInk.seriesLength, 7);
    expect(FluentInk.seriesLight, hasLength(FluentInk.seriesLength));
    expect(FluentInk.seriesDark, hasLength(FluentInk.seriesLength));
    for (final FluentThemeData theme in themes) {
      for (int i = 0; i < FluentInk.seriesLength; i++) {
        final Color lane = FluentInk.series(theme.brightness, i);
        for (final Color paper in papers(theme.resources)) {
          expect(
            wcagContrast(lane, paper),
            greaterThanOrEqualTo(3.0),
            reason:
                'series($i) ${_hex(lane)} < 3:1 on paper ${_hex(paper)} '
                '(${theme.brightness})',
          );
        }
      }
      expect(
        FluentInk.series(theme.brightness, FluentInk.seriesLength),
        FluentInk.series(theme.brightness, 0),
        reason: 'the series indexes modulo its own length',
      );
    }
  });

  test('the distance vocabularies keep their rungs distinct and ordered', () {
    final List<double> gaps = Proximity.values.map(FluentSpacing.gap).toList();
    final List<double> insets = Inset.values.map(FluentSpacing.inset).toList();
    final List<double> glyphs = ControlScale.values
        .map(FluentSpacing.glyph)
        .toList();
    for (final List<double> ramp in <List<double>>[gaps, insets, glyphs]) {
      for (int i = 1; i < ramp.length; i++) {
        expect(
          ramp[i],
          greaterThan(ramp[i - 1]),
          reason: 'ramp $ramp must be strictly increasing',
        );
      }
    }
    expect(FluentSpacing.inset(Inset.none), 0);
  });

  test('depth is layer plus stroke, and only the overlay casts a shadow', () {
    for (final FluentThemeData theme in themes) {
      final FluentResources res = theme.resources;
      final FluentDepth flush = FluentInk.depth(theme, Elevation.flush);
      expect(flush.fill.a, 0);
      expect(flush.stroke.a, 0);
      expect(flush.shadowElevation, 0);

      final FluentDepth resting = FluentInk.depth(theme, Elevation.resting);
      expect(resting.fill, res.cardBackgroundFillColorDefault);
      expect(resting.stroke, res.cardStrokeColorDefault);
      expect(resting.shadowElevation, 0);

      final FluentDepth raised = FluentInk.depth(theme, Elevation.raised);
      expect(raised.fill, res.subtleFillColorSecondary);
      expect(raised.shadowElevation, 0);

      final FluentDepth overlay = FluentInk.depth(theme, Elevation.overlay);
      expect(overlay.stroke, res.surfaceStrokeColorFlyout);
      expect(overlay.shadowElevation, FluentMetrics.overlayShadowElevation);
      expect(
        overlay.shadows(FluentInk.shadowInk(theme.brightness)),
        hasLength(2),
        reason: 'the design-kit shadow is an ambient layer plus a key layer',
      );
      expect(
        resting.shadows(FluentInk.shadowInk(theme.brightness)),
        isEmpty,
        reason: 'a resting card casts no shadow in this language',
      );
      // Every rung stays distinguishable from its neighbour even with every
      // shadow at zero - the layer and the stroke carry the separation.
      expect(flush, isNot(resting));
      expect(resting, isNot(raised));
      expect(raised, isNot(overlay));
    }
  });
}
