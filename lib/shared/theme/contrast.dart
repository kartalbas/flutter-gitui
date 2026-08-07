/// WCAG 2.1 contrast thresholds and the one rule the app uses to keep a
/// foreground readable on a container it did not choose.
///
/// This exists because of a defect class the component matrix kept producing:
/// a selected state swaps the container for a tonal colour and the label stays
/// on the role that was chosen against the *unselected* background. The git
/// palette had the same shape of bug before it became a brightness-aware
/// extension - a colour picked in one brightness and used in both - and the
/// answer here is the same one: derive the foreground from the background it
/// is actually painted on, and assert the pair.
///
/// `test/conformance/a11y/component_colors_contrast_test.dart` measures every
/// pair the Base components resolve, in both brightnesses, against these
/// thresholds.
library;

import 'package:flutter/material.dart';

import 'git_semantic_colors.dart';

/// SC 1.4.3, body text: 4.5 : 1 against its own background.
const double kWcagTextContrast = 4.5;

/// SC 1.4.11, non-text UI: 3 : 1 for glyphs, outlines and other graphics that
/// carry meaning.
const double kWcagNonTextContrast = 3.0;

/// WCAG 2.x contrast ratio between two **opaque** colours.
///
/// The same formula `git_colors_contrast_test.dart` uses; it lives here so the
/// application can apply the rule and the suites can assert it without either
/// side owning a private copy.
///
/// Opacity is a precondition rather than a detail. `Color.computeLuminance()`
/// reads the three channels and ignores the alpha channel completely, so a
/// 10 % tint measures as the fully saturated colour it was derived from - a
/// colour that is nowhere on screen. Flatten first with [flattenedOver]; the
/// assertion is here so a translucent argument fails loudly instead of
/// returning a number about a colour nobody painted.
double wcagContrast(Color a, Color b) {
  assert(
    a.a == 1.0 && b.a == 1.0,
    'wcagContrast measures opaque colours. computeLuminance() ignores alpha, '
    'so a translucent argument is measured as its own opaque colour rather '
    'than as what the compositor puts on screen. Flatten it over the colour '
    'painted behind it with flattenedOver() first.',
  );
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The opaque colour the user really sees when [color] is painted over [base]:
/// sRGB source-over, exactly what the compositor does.
///
/// This is the same helper `git_colors_contrast_test.dart` has always applied
/// before measuring the 12 % diff-row tint and the 15 % badge tint (`flattened`
/// there). It belongs on the application side too, because the application
/// paints translucent containers as well: `BaseCard.customBackgroundColor`
/// receives `primary` at 10 % from repository_card.dart and the workspace
/// colour at 10 % from workspace_card.dart.
Color flattenedOver(Color color, Color base) => Color.alphaBlend(color, base);

/// The foreground to paint on [background] over [backgroundBase], which is
/// [preferred] whenever that pair clears [minRatio] and otherwise the black or
/// white that does.
///
/// [preferred] is the Material 3 role for the pairing - `onSecondaryContainer`
/// on `secondaryContainer`, and so on. The fallback is not a second design
/// decision: it is [GitSemanticColors.foregroundOn], the rule the app already
/// uses to put a readable label on a solid semantic colour, and it only ever
/// takes over where the scheme's own on-role misses the threshold. In this
/// app's dark themes that happens on the selection containers, where
/// `onSecondaryContainer` reaches 4.45 : 1 - close enough to look designed and
/// still a failure.
///
/// [backgroundBase] is the opaque colour painted *behind* [background], and it
/// is required rather than optional because a caller that does not think about
/// it gets the wrong answer silently. A container may be translucent - the
/// repositories grid tints a selected card with `primary` at 10 % and the
/// workspaces grid with the workspace colour at 10 % - and judging such a tint
/// by its own channels inverts the result: `primary` is a pale lilac in the
/// dark theme, so the unflattened rule reads "light container" and returns
/// black, which is then painted on the near-black the tint actually composites
/// to. Pass the surface the container sits on; an opaque [background]
/// composites to itself, so naming it costs nothing there.
Color readableForeground({
  required Color preferred,
  required Color background,
  required Color backgroundBase,
  double minRatio = kWcagTextContrast,
}) {
  final Color painted = flattenedOver(background, backgroundBase);
  return wcagContrast(preferred, painted) >= minRatio
      ? preferred
      : GitSemanticColors.foregroundOn(painted);
}
