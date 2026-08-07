// Guards WCAG 2.1 AA conformance of the git semantic palette: every role must
// hold 4.5:1 as text and every commit-graph lane 3:1 as a graphic against
// every surface the app paints them on, in every selectable scheme, in both
// modes. The old single-hex palette failed this as badly as 1.41:1; this test
// is what keeps the derived palette honest when themes or values change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours (SC 1.4.3 / 1.4.11).
double wcagContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The colour the user actually sees when [fg] is painted at [alpha] over the
/// opaque [base] (sRGB source-over, exactly what the compositor does).
Color flattened(Color fg, double alpha, Color base) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), base);

/// Every opaque surface role git colours are painted onto: scaffold, list
/// surfaces, and the BaseCard levels (normal surfaceContainerHigh, hover
/// surfaceContainerHighest — base_card.dart:109-112).
List<Color> plainSurfaces(ThemeData theme) => [
  theme.scaffoldBackgroundColor,
  theme.colorScheme.surface,
  theme.colorScheme.surfaceContainerLow,
  theme.colorScheme.surfaceContainer,
  theme.colorScheme.surfaceContainerHigh,
  theme.colorScheme.surfaceContainerHighest,
];

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

void main() {
  testWidgets('git semantic colours hold WCAG AA on every scheme and surface', (
    tester,
  ) async {
    for (final scheme in AppColorScheme.values) {
      for (final brightness in Brightness.values) {
        final isDark = brightness == Brightness.dark;
        final theme = isDark
            ? AppTheme.darkTheme(colorScheme: scheme)
            : AppTheme.lightTheme(colorScheme: scheme);
        final label = '${scheme.name}/${brightness.name}';

        final registered = theme.extension<GitSemanticColors>();
        expect(
          registered,
          isNotNull,
          reason: 'GitSemanticColors is not registered in the theme ($label)',
        );
        final colors = registered!;
        expect(
          colors,
          same(isDark ? GitSemanticColors.dark : GitSemanticColors.light),
          reason:
              'theme must carry the preset matching its brightness ($label)',
        );

        final textRoles = <String, Color>{
          'added': colors.added,
          'modified': colors.modified,
          'deleted': colors.deleted,
          'renamed': colors.renamed,
          'untracked': colors.untracked,
          'conflict': colors.conflict,
          'branchLocal': colors.branchLocal,
          'branchRemote': colors.branchRemote,
          'branchTag': colors.branchTag,
          'branchStash': colors.branchStash,
        };

        // 1) Text roles: 4.5:1 on every plain surface (SC 1.4.3).
        for (final surface in plainSurfaces(theme)) {
          textRoles.forEach((name, color) {
            expect(
              wcagContrast(color, surface),
              greaterThanOrEqualTo(4.5),
              reason:
                  '$name ${_hex(color)} < 4.5:1 on surface '
                  '${_hex(surface)} ($label)',
            );
          });
        }

        // 2) Diff rows paint the role at 12 % over the BaseCard surface and
        //    the role at 100 % as text on top of that tint
        //    (base_diff_viewer.dart _buildDiffLine). The text must clear
        //    4.5:1 against its own composited background.
        final diffBase = theme.colorScheme.surfaceContainerHigh;
        // 3) Tinted badges paint the role at 15 % over the hovered card
        //    (base_badge.dart) with the role as label colour on top.
        final chipBase = theme.colorScheme.surfaceContainerHighest;
        textRoles.forEach((name, color) {
          expect(
            wcagContrast(color, flattened(color, 0.12, diffBase)),
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${_hex(color)} < 4.5:1 on its own 12% diff tint '
                '($label)',
          );
          expect(
            wcagContrast(color, flattened(color, 0.15, chipBase)),
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${_hex(color)} < 4.5:1 on its own 15% badge tint '
                '($label)',
          );
          // 4) Filled buttons/badges: the black/white foreground the helper
          //    picks must clear 4.5:1 on the solid role colour.
          expect(
            wcagContrast(GitSemanticColors.foregroundOn(color), color),
            greaterThanOrEqualTo(4.5),
            reason: 'foregroundOn(${_hex(color)}) < 4.5:1 on $name ($label)',
          );
        });

        // 5) Commit-graph lanes are 2 px graphics: 3:1 (SC 1.4.11).
        expect(
          colors.laneColors,
          hasLength(8),
          reason: 'lane cycle length changed ($label)',
        );
        for (var i = 0; i < colors.laneColors.length; i++) {
          final lane = colors.laneColors[i];
          for (final surface in plainSurfaces(theme)) {
            expect(
              wcagContrast(lane, surface),
              greaterThanOrEqualTo(3.0),
              reason:
                  'lane $i ${_hex(lane)} < 3:1 on surface '
                  '${_hex(surface)} ($label)',
            );
          }
        }
      }
    }

    // Drain timers scheduled by google_fonts so teardown sees none pending.
    await tester.pump(const Duration(seconds: 30));
  });
}
