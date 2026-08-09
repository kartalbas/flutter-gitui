/// How this skin answers the contract's ink vocabularies: every [Tone], and
/// the lengths of [Proximity], [Inset], [Elevation] and [ControlScale].
///
/// This is the Fluent analogue of `material_ink.dart`: the one place a facet
/// is allowed to learn one of these values, so that a number written anywhere
/// else in this package is visible in review as a number belonging to
/// nothing. The colour ground it resolves against is NOT declared here - the
/// WinUI resource dictionary lives in `fluent_resources.dart` and the accent
/// swatch in `fluent_accent.dart`, both reached through [FluentThemeData] -
/// because a second copy of a dictionary is how two facets drift apart.
///
/// **No value here is invented, and every value names where it came from.**
/// Two sources are cited throughout:
///
///  * the published Fluent 2 / WinUI specification - the spacing and icon
///    ramps from the Fluent 2 design-token set
///    (<https://fluent2.microsoft.design>, `@fluentui/tokens`);
///  * the reference checkout fluent_ui@4.16.1 (commit `2da5649`), read at
///    `D:/repos/github/fluent_ui` and never compiled, vendored or shipped.
///    Paths in comments below are relative to its `lib/`.
///
/// A value with no such comment is a guess wearing a constant's clothes.
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'fluent_resources.dart';
import 'fluent_theme.dart';

/// The lengths this design language measures in.
///
/// Fluent 2 publishes a denser spacing ramp than Material's 4dp grid counted
/// out in eights: the token set steps 0 / 2 / 4 / 6 / 8 / 10 / 12 / 16 / 20 /
/// 24 / 32 (`spacingHorizontalNone..XXXL`, fluent2.microsoft.design layout
/// tokens, `@fluentui/tokens`). Only the rungs this skin's vocabularies land
/// on are named here; naming the whole ramp would be constants nobody reads.
/// Control-internal metrics (button padding, the in-button glyph) live in
/// `FluentGeometry`, beside the controls that own them.
abstract final class FluentMetrics {
  /// The densest inset that still reads: a code line, a blame row.
  ///
  /// Fluent 2 `spacingHorizontalXXS` = 2.
  static const double spaceXXS = 2;

  /// Touching. Two halves of one thing.
  ///
  /// Fluent 2 `spacingHorizontalXS` = 4.
  static const double spaceXS = 4;

  /// The nudge step between tight and ordinary.
  ///
  /// Fluent 2 `spacingHorizontalSNudge` = 6; also the reference's dense row
  /// rhythm - list tiles inset 6 vertically
  /// (fluent_ui src/controls/surfaces/list_tile.dart:8-12) and InfoBar
  /// actions pad 6 (src/controls/surfaces/info_bar.dart:628).
  static const double spaceSNudge = 6;

  /// Two parts of one statement.
  ///
  /// Fluent 2 `spacingHorizontalS` = 8.
  static const double spaceS = 8;

  /// Members of one group; the ordinary reading inset.
  ///
  /// Fluent 2 `spacingHorizontalM` = 12; the reference's list tile ends at 12
  /// (fluent_ui src/controls/surfaces/list_tile.dart:8-12).
  static const double spaceM = 12;

  /// Two groups inside one region.
  ///
  /// Fluent 2 `spacingHorizontalL` = 16.
  static const double spaceL = 16;

  /// Deliberately generous: a dialog body, a card interior.
  ///
  /// Fluent 2 `spacingHorizontalXL` = 20; the reference's ContentDialog pads
  /// its body and its action strip 20 on every side
  /// (fluent_ui src/controls/flyouts/content_dialog.dart:498,506).
  static const double spaceXL = 20;

  /// Two regions of a screen about different subjects.
  ///
  /// Fluent 2 `spacingHorizontalXXL` = 24. Fluent's largest ordinary rung -
  /// the ramp continues to 32 (`XXXL`) but the language reserves it for page
  /// gutters, so the fifth Proximity rung lands here rather than at
  /// Material's 32. A re-landing, not a collapse: all five rungs stay
  /// distinct.
  static const double spaceXXL = 24;

  /// Inline marks beside text: a breadcrumb chevron, a caption glyph.
  ///
  /// Fluent 2 icon ramp step 12 (fluent2.microsoft.design iconography;
  /// Fluent UI System Icons ship 12/16/20/24/28/32/48); the reference draws
  /// its breadcrumb bar's overflow glyph at 12
  /// (fluent_ui src/controls/navigation/breadcrumb_bar.dart:195).
  static const double glyphCompact = 12;

  /// The standard WinUI glyph: command bars, navigation, list marks.
  ///
  /// Fluent 2 icon ramp step 16; the reference's command bar
  /// (src/controls/surfaces/commandbar.dart:676) and navigation pane items
  /// (src/controls/navigation/navigation_view/pane_items.dart:323,346) both
  /// pin 16. The glyph INSIDE a button is 14 in the reference
  /// (`FluentGeometry.buttonIconSize`) - a control-internal metric, not a
  /// rung of this ramp.
  static const double glyphNormal = 16;

  /// Deliberately large: a header mark, an empty state's glyph.
  ///
  /// Fluent 2 icon ramp step 20; the reference draws its dropdown glyph
  /// (src/controls/inputs/dropdown_button.dart:303) and tree-view selection
  /// mark (src/controls/navigation/tree_view.dart:1537) at 20.
  static const double glyphProminent = 20;

  /// The shadow elevation of the one depth rung Fluent actually shadows.
  ///
  /// Flyouts and menus default to elevation 8 in the reference
  /// (fluent_ui src/controls/flyouts/flyout_content.dart:21,
  /// src/controls/flyouts/menu_flyout.dart:33). Every other rung of depth is
  /// drawn as a layer fill plus a 1px stroke - see [FluentInk.depth].
  static const double overlayShadowElevation = 8;
}

/// How this skin turns the contract's distance vocabularies into lengths.
///
/// The application declares the RELATIONSHIP and this decides the DISTANCE.
/// The five Proximity rungs and the five Inset rungs each land on five
/// distinct steps of Fluent 2's spacing ramp, so no rung collapses and no
/// deviation is owed - though the ramp is denser than Material's throughout,
/// which is exactly the divergence the vocabulary's own doc predicts.
abstract final class FluentSpacing {
  /// The gap [proximity] asks for.
  static double gap(Proximity proximity) => switch (proximity) {
    Proximity.hairline => FluentMetrics.spaceXS,
    Proximity.related => FluentMetrics.spaceS,
    Proximity.grouped => FluentMetrics.spaceM,
    Proximity.separate => FluentMetrics.spaceL,
    Proximity.sectioned => FluentMetrics.spaceXXL,
  };

  /// How far a container's content sits from its own edge.
  static double inset(Inset inset) => switch (inset) {
    Inset.none => 0,
    Inset.hairline => FluentMetrics.spaceXXS,
    Inset.tight => FluentMetrics.spaceSNudge,
    Inset.normal => FluentMetrics.spaceM,
    Inset.roomy => FluentMetrics.spaceXL,
  };

  /// How large a mark is at [scale].
  static double glyph(ControlScale scale) => switch (scale) {
    ControlScale.compact => FluentMetrics.glyphCompact,
    ControlScale.normal => FluentMetrics.glyphNormal,
    ControlScale.prominent => FluentMetrics.glyphProminent,
  };

  /// The shadow elevation a surface at [elevation] casts.
  ///
  /// Zero for everything below the overlay, because Fluent does not express
  /// resting or raised depth with shadows - it layers fills and strokes,
  /// which [FluentInk.depth] carries. Only the flyout tier casts one
  /// (fluent_ui src/controls/flyouts/flyout_content.dart:21).
  static double shadowElevation(Elevation elevation) => switch (elevation) {
    Elevation.flush || Elevation.resting || Elevation.raised => 0,
    Elevation.overlay => FluentMetrics.overlayShadowElevation,
  };
}

/// One resolved depth treatment: what a surface at some [Elevation] wears.
///
/// [fill] is a LAYER, not always an opaque paint: at `Elevation.raised` it is
/// the translucent hover fill and composites over whatever the resting
/// surface already painted, which is exactly how WinUI raises a row.
@immutable
final class FluentDepth {
  /// Declares one treatment.
  const FluentDepth({
    required this.fill,
    required this.stroke,
    required this.shadowElevation,
  });

  /// The surface's own paint, composited over what is behind it.
  final Color fill;

  /// The 1px outline. Fully transparent at `Elevation.flush`.
  final Color stroke;

  /// The shadow elevation, in the reference's units. Zero everywhere but the
  /// overlay.
  final double shadowElevation;

  /// The two shadow layers the reference derives from an elevation, verbatim
  /// from the FluentUI design kit
  /// (fluent_ui src/controls/surfaces/acrylic.dart:216-227, "taken from the
  /// official FluentUI design kit on Figma"): an ambient layer at 0.13 alpha
  /// (blur 0.9e, dy 0.4e) and a key layer at 0.11 alpha (blur 0.225e,
  /// dy 0.085e). [shadowInk] is [FluentInk.shadowInk] for the brightness in
  /// force. Empty when this treatment casts no shadow.
  List<BoxShadow> shadows(Color shadowInk) => shadowElevation == 0
      ? const <BoxShadow>[]
      : <BoxShadow>[
          BoxShadow(
            color: shadowInk.withValues(alpha: 0.13),
            blurRadius: 0.9 * shadowElevation,
            offset: Offset(0, 0.4 * shadowElevation),
          ),
          BoxShadow(
            color: shadowInk.withValues(alpha: 0.11),
            blurRadius: 0.225 * shadowElevation,
            offset: Offset(0, 0.085 * shadowElevation),
          ),
        ];

  @override
  bool operator ==(Object other) =>
      other is FluentDepth &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.shadowElevation == shadowElevation;

  @override
  int get hashCode => Object.hash(fill, stroke, shadowElevation);
}

/// The colours git state means under this skin, per brightness.
///
/// No design language has a resource for "this file is staged" - that is why
/// [Tone] carries the eight git tones at all - so these are the skin's OWN
/// palette, built from Fluent's published colour system rather than invented:
/// each value is a shade of a named `fluent_ui` accent swatch or a WinUI
/// system colour, and each comment says which.
///
/// The shade per brightness follows Fluent's own text-brush rule (dark shade
/// on light surfaces, light shade on dark - `AccentColor.defaultBrushFor`,
/// src/styles/color.dart:347-353) EXCEPT where that shade cannot hold WCAG
/// 2.1 AA 4.5:1 on every surface this skin paints text over (the solid
/// background ramp, the card, and the hovered card - the same discipline
/// #341 imposed on the Material palette, asserted by
/// `test/fluent_ink_test.dart`). Where the published swatch tops out below
/// that floor, the shade is extended with the swatch generator Fluent itself
/// ships (`toAccentColor`, lightestFactor 0.38,
/// src/styles/color.dart:394-412), seeded from the swatch's `lighter`
/// member; the two derived values say so on their line.
@immutable
final class FluentGitPalette {
  /// Declares one palette.
  const FluentGitPalette({
    required this.added,
    required this.modified,
    required this.deleted,
    required this.renamed,
    required this.untracked,
    required this.conflict,
  });

  /// Added files; also the colour of `Tone.gitStaged`.
  final Color added;

  /// Modified files.
  final Color modified;

  /// Deleted files.
  final Color deleted;

  /// Renamed and copied files.
  final Color renamed;

  /// Untracked files; also `Tone.gitIgnored`.
  final Color untracked;

  /// Merge conflicts.
  final Color conflict;

  /// The palette for light surfaces.
  static const FluentGitPalette light = FluentGitPalette(
    // green.dark (color.dart:190-198).
    added: Color(0xFF0E6F0E),
    // orange.darker (color.dart:126): orange.dark #D1540A only reaches
    // 4.2:1 on white, so the next Fluent shade down carries the role.
    modified: Color(0xFFAC4508),
    // SystemFillColorCritical light (color_resources.dart:350).
    deleted: Color(0xFFC42B1C),
    // blue.dark (color.dart:171) - the accent-as-text brush shade.
    renamed: Color(0xFF0066B4),
    // grey[130] (color.dart:93).
    untracked: Color(0xFF605E5C),
    // magenta.dark (color.dart:149).
    conflict: Color(0xFF90007E),
  );

  /// The palette for dark surfaces.
  static const FluentGitPalette dark = FluentGitPalette(
    // green.lighter (color.dart:196) reseeded through
    // toAccentColor().lightest: the published green swatch tops out at
    // #6AAD6A, 4.4:1 on the hovered dark card.
    added: Color(0xFF8FC28F),
    // orange.lighter (color.dart:130).
    modified: Color(0xFFF99154),
    // SystemFillColorCritical dark (color_resources.dart:263) - the red
    // swatch itself tops out at #F06B76, 4.0:1; this IS Fluent's
    // red-for-text on dark.
    deleted: Color(0xFFFF99A4),
    // blue.lightest (color.dart:175): blue.lighter #4CA0E0 is Fluent's dark
    // accent brush but reaches only 4.2:1 on the hovered dark card.
    renamed: Color(0xFF60ABE4),
    // grey[80] (color.dart:98).
    untracked: Color(0xFFB3B0AD),
    // magenta.lighter (color.dart:152) reseeded through
    // toAccentColor().lightest: the published magenta swatch tops out at
    // #D060C2, 3.5:1.
    conflict: Color(0xFFDE90D5),
  );

  /// The palette for [brightness].
  static FluentGitPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// How this skin turns a [Tone] into a colour, and an [Elevation] into a
/// depth treatment.
///
/// Seventeen named tones plus the series, resolved against Fluent's own
/// resource theory - text fills, the accent brush, the system colours - where
/// the language has a word for the meaning, and against [FluentGitPalette]
/// where it has none. The honest gaps and collapses, recorded rather than
/// hidden:
///
///  * `info` collapses onto the accent brush, and that is FLUENT'S collapse,
///    not this skin's: WinUI has an attention BACKGROUND
///    (`SystemFillColorAttentionBackground`) but no attention foreground,
///    and the reference paints the InfoBar's informational icon with the
///    accent (src/controls/surfaces/info_bar.dart:619-620).
///  * `invalid` and `danger` genuinely separate here, exactly as the
///    vocabulary predicted: the reference paints field validation with the
///    red swatch's brush (src/controls/form/form_row.dart:64,
///    src/controls/form/text_form_box.dart:234), not with
///    `SystemFillColorCritical`.
///  * `onAccent` maps directly: Fluent DOES have a paired on-accent concept
///    (`TextOnAccentFillColorPrimary`/`Secondary`), contrary to the
///    vocabulary doc's claim that only Material has one.
///  * `gitIgnored` renders as `gitUntracked`'s colour and `gitStaged` as
///    `gitAdded`'s - the same rendering collapse the Material skin makes.
abstract final class FluentInk {
  /// The foreground colour [tone] means on an ordinary surface under [theme].
  ///
  /// [ambientForeground] is for the one tone whose meaning is RELATIVE:
  /// pass `DefaultTextStyle.of(context).style.color` so that `muted` can
  /// answer against the surface the text actually sits on - see
  /// [mutedBeside]. Every other tone ignores it.
  static Color foreground(
    FluentThemeData theme,
    Tone tone, {
    Color? ambientForeground,
  }) {
    final FluentResources res = theme.resources;
    final FluentGitPalette git = FluentGitPalette.forBrightness(
      theme.brightness,
    );
    final int? index = tone.seriesIndex;
    if (index != null) return series(theme.brightness, index);
    return switch (tone.name) {
      'neutral' => res.textFillColorPrimary,
      'muted' => mutedBeside(res, ambientForeground),
      'accent' => theme.accent.defaultBrushFor(theme.brightness),
      'onAccent' => res.textOnAccentFillColorPrimary,
      'danger' => res.systemFillColorCritical,
      'warning' => res.systemFillColorCaution,
      'invalid' => invalidBrush(theme.brightness),
      'success' => res.systemFillColorSuccess,
      'info' => theme.accent.defaultBrushFor(theme.brightness),
      'gitAdded' => git.added,
      'gitModified' => git.modified,
      'gitDeleted' => git.deleted,
      'gitRenamed' => git.renamed,
      'gitUntracked' => git.untracked,
      'gitConflicted' => git.conflict,
      'gitIgnored' => git.untracked,
      'gitStaged' => git.added,
      _ => res.textFillColorPrimary,
    };
  }

  /// "Secondary to what it sits beside", resolved against the surface the
  /// text actually sits on rather than against the page.
  ///
  /// The same relative rule `MaterialInk._muted` earned the hard way, with
  /// one genuinely Fluent improvement: where the ambient foreground is the
  /// on-accent primary, Fluent HAS a quieter word for it -
  /// `TextOnAccentFillColorSecondary` - where Material had to collapse muted
  /// onto the container's one on-colour. Anywhere else that a surface has
  /// published its own foreground, muted collapses onto it, because the
  /// dictionary offers no quieter variant of an arbitrary published colour.
  static Color mutedBeside(
    FluentResources resources,
    Color? ambientForeground,
  ) {
    if (ambientForeground == null ||
        ambientForeground == resources.textFillColorPrimary) {
      return resources.textFillColorSecondary;
    }
    if (ambientForeground == resources.textOnAccentFillColorPrimary) {
      return resources.textOnAccentFillColorSecondary;
    }
    return ambientForeground;
  }

  /// The brush of a value that is missing or rejected.
  ///
  /// Fluent's field-validation colour: the red accent swatch resolved by the
  /// language's own brightness rule - `Colors.red.defaultBrushFor` at every
  /// validation site in the reference (src/controls/form/form_row.dart:64,
  /// src/controls/form/text_form_box.dart:234; swatch values
  /// src/styles/color.dart:135-143, rule src/styles/color.dart:347-353).
  /// Deliberately NOT `systemFillColorCritical`: that separation is the
  /// vocabulary's own proof that `invalid` is a meaning and not a colour.
  static Color invalidBrush(Brightness brightness) => switch (brightness) {
    // red.dark (color.dart:138).
    Brightness.light => const Color(0xFFB90D1C),
    // red.lighter (color.dart:141).
    Brightness.dark => const Color(0xFFEE5865),
  };

  /// How Fluent separates the four depth rungs.
  ///
  /// Not a shadow ramp: the vocabulary's own doc
  /// (`docs/SKIN-CONTRACT-MEMBERS.md` §10.1) predicts that Fluent expresses
  /// depth as layer plus stroke, and this is that answer made concrete.
  /// Only the overlay casts a shadow; resting is a card (fill + 1px stroke,
  /// fluent_ui src/controls/surfaces/card.dart:107-112); raised is the
  /// subtle hover layer WinUI composites OVER the resting surface
  /// (fluent_ui src/controls/buttons/theme.dart:376); flush is nothing.
  static FluentDepth depth(FluentThemeData theme, Elevation elevation) {
    final FluentResources res = theme.resources;
    return switch (elevation) {
      Elevation.flush => FluentDepth(
        fill: res.subtleFillColorTransparent,
        stroke: res.subtleFillColorTransparent,
        shadowElevation: 0,
      ),
      Elevation.resting => FluentDepth(
        fill: res.cardBackgroundFillColorDefault,
        stroke: res.cardStrokeColorDefault,
        shadowElevation: 0,
      ),
      Elevation.raised => FluentDepth(
        fill: res.subtleFillColorSecondary,
        stroke: res.cardStrokeColorDefault,
        shadowElevation: 0,
      ),
      Elevation.overlay => FluentDepth(
        fill: menuSurface(theme.brightness),
        stroke: res.surfaceStrokeColorFlyout,
        shadowElevation: FluentMetrics.overlayShadowElevation,
      ),
    };
  }

  /// The solid surface of a menu or flyout.
  ///
  /// Not a dictionary resource: the reference carries it as
  /// `FluentThemeData.menuColor` (fluent_ui src/styles/theme.dart:461,
  /// `#F9F9F9` light / `#2C2C2C` dark), the solid stand-in for acrylic that
  /// every flyout defaults to
  /// (src/controls/flyouts/flyout_content.dart:95).
  static Color menuSurface(Brightness brightness) => switch (brightness) {
    Brightness.light => const Color(0xFFF9F9F9),
    Brightness.dark => const Color(0xFF2C2C2C),
  };

  /// The ink a shadow is mixed from.
  ///
  /// Not a dictionary resource: the reference carries it as
  /// `FluentThemeData.shadowColor` (fluent_ui src/styles/theme.dart:455,
  /// black in light, `grey[130]` `#605E5C` in dark).
  static Color shadowInk(Brightness brightness) => switch (brightness) {
    Brightness.light => const Color(0xFF000000),
    Brightness.dark => const Color(0xFF605E5C),
  };

  /// How many members `Tone.series` has under this skin.
  ///
  /// Seven, and the length is as much this skin's decision as the palette:
  /// the source is the reference's own enumeration of its accent families
  /// (`Colors.accentColors`, src/styles/color.dart:228-239, eight members)
  /// MINUS yellow, because no shade of Fluent's yellow swatch holds even the
  /// 3:1 graphic threshold on this skin's light papers - the same reason the
  /// Material skin's light lane cycle carries no yellow.
  static const int seriesLength = 7;

  /// The nth colour of this skin's generated series, for [brightness].
  static Color series(Brightness brightness, int index) {
    final List<Color> palette = brightness == Brightness.dark
        ? seriesDark
        : seriesLight;
    return palette[index % palette.length];
  }

  /// The series on light surfaces: the `dark` shade of each family, which is
  /// Fluent's own light-theme brush shade (`AccentColor.defaultBrushFor`,
  /// src/styles/color.dart:347-353). Family order is the reference's
  /// `accentColors` order (src/styles/color.dart:228-239) with yellow
  /// removed.
  static const List<Color> seriesLight = <Color>[
    Color(0xFFD1540A), // orange.dark (color.dart:127)
    Color(0xFFB90D1C), // red.dark (color.dart:138)
    Color(0xFF90007E), // magenta.dark (color.dart:149)
    Color(0xFF644293), // purple.dark (color.dart:160)
    Color(0xFF0066B4), // blue.dark (color.dart:171)
    Color(0xFF00977D), // teal.dark (color.dart:182)
    Color(0xFF0E6F0E), // green.dark (color.dart:193)
  ];

  /// The series on dark surfaces: the `lightest` shade of each family.
  ///
  /// One step past Fluent's own dark brush shade (`lighter`), because
  /// magenta's `lighter` member sits at 2.98:1 on the hovered dark card - a
  /// hair under the 3:1 graphic threshold - and a series whose members obey
  /// two different shade rules would be two decisions wearing one name.
  static const List<Color> seriesDark = <Color>[
    Color(0xFFFA9E68), // orange.lightest (color.dart:131)
    Color(0xFFF06B76), // red.lightest (color.dart:142)
    Color(0xFFD060C2), // magenta.lightest (color.dart:153)
    Color(0xFFA890C9), // purple.lightest (color.dart:164)
    Color(0xFF60ABE4), // blue.lightest (color.dart:175)
    Color(0xFF60CFBC), // teal.lightest (color.dart:186)
    Color(0xFF6AAD6A), // green.lightest (color.dart:197)
  ];

  /// Foreground for text painted on a solid tone: a filled success button, a
  /// chosen series swatch.
  ///
  /// 0.179 is the luminance at which black and white text contrast equally;
  /// above it black reads better, below it white. The same arithmetic fact
  /// `MaterialInk.foregroundOn` uses - it is colour science, not a design
  /// value, which is why it may appear in two skins without either copying
  /// the other.
  static Color foregroundOn(Color background) =>
      background.computeLuminance() > 0.179
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}
