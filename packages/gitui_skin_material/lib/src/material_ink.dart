/// The numbers, the colours and the type ramp this skin renders from.
///
/// This is the Material analogue of the blueprint's `blueprint_ink.dart`: the
/// one place a facet is allowed to learn a value, so that a number written
/// anywhere else in this package is visible in review as a number belonging to
/// nothing.
///
/// **Every value here is the application's own, moved.** The five spacing
/// rungs, the five corner rungs, the five glyph sizes, the six elevation rungs
/// and the git palette were `AppTheme.padding*`, `AppTheme.radius*`,
/// `AppTheme.icon*`, `AppTheme.elevationLevel*` and `GitSemanticColors` until
/// this extraction. They are copied rather than imported for one reason: a
/// skin package reaching back into `lib/` would invert the one dependency edge
/// the whole contract is built on, and the workspace-isolation gate makes that
/// a hard error. Numbers live on the skin's side of the line - that is the
/// whole of `docs/SKIN-CONTRACT.md` §1 - so this file is where they belong and
/// `AppTheme` is what eventually goes away.
library;

import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The lengths this design language measures in.
///
/// Named rungs rather than raw literals so that the design-system rules
/// (`avoid_hardcoded_spacing`, `avoid_hardcoded_radius`) keep meaning
/// something inside this package: a literal in a `SizedBox`, an `EdgeInsets`
/// or a `BorderRadius` is still a defect here, it is just that the constant it
/// must come from now lives in the skin instead of the application.
abstract final class MaterialMetrics {
  /// Touching. Two halves of one thing.
  static const double spaceXS = 4;

  /// Two parts of one statement.
  static const double spaceS = 8;

  /// Members of one group.
  static const double spaceM = 16;

  /// Two groups inside one region.
  static const double spaceL = 24;

  /// Two regions about different subjects.
  static const double spaceXL = 32;

  /// The smallest corner: an inline pill, a tint behind a count.
  static const double radiusXS = 2;

  /// The field corner. Text fields, dropdowns, inline surfaces.
  static const double radiusS = 4;

  /// The control corner (BTN-001, ICO-001, CHIP-*). Buttons, chips, menus.
  ///
  /// Material 3's own answer for a button is the stadium; 8 dp is this
  /// application's registered divergence from it, which is why the value is
  /// named here and asserted in `docs/deviation_register.yaml` rather than
  /// merely written down.
  static const double radiusM = 8;

  /// The surface corner. Cards and panels.
  static const double radiusL = 12;

  /// The largest corner. Dialogs and sheets.
  static const double radiusXL = 16;

  /// Non-interactive inline indicators.
  static const double iconXS = 12;

  /// Dense tree and list marks, small buttons, chips.
  static const double iconS = 16;

  /// Compact toolbar and secondary marks.
  static const double iconM = 20;

  /// Material 3's own default glyph size: buttons, navigation.
  static const double iconL = 24;

  /// Headers, emphasis, empty states.
  static const double iconXL = 32;

  /// Flat: rails, resting app bars.
  static const double elevationFlush = 0;

  /// Resting cards and panels.
  static const double elevationResting = 1;

  /// Menus and dropdown overlays.
  static const double elevationRaised = 3;

  /// Dialogs and floating actions.
  static const double elevationOverlay = 6;
}

/// How this skin turns the contract's two distance vocabularies into lengths.
///
/// The application declares the RELATIONSHIP and this decides the DISTANCE.
/// Five rungs map onto the five spacing rungs one for one, which is honest
/// about the lineage: [Proximity] has five values because
/// `AppTheme.paddingXS/S/M/L/XL` were the five steps this application actually
/// used, at 1,340 measured reads. Another language is not obliged to land on
/// five and registers the collapse if it does not.
abstract final class MaterialSpacing {
  /// The gap [proximity] asks for.
  static double gap(Proximity proximity) => switch (proximity) {
    Proximity.hairline => MaterialMetrics.spaceXS,
    Proximity.related => MaterialMetrics.spaceS,
    Proximity.grouped => MaterialMetrics.spaceM,
    Proximity.separate => MaterialMetrics.spaceL,
    Proximity.sectioned => MaterialMetrics.spaceXL,
  };

  /// How far a container's content sits from its own edge.
  static double inset(Inset inset) => switch (inset) {
    Inset.none => 0,
    Inset.tight => MaterialMetrics.spaceS,
    Inset.normal => MaterialMetrics.spaceM,
    Inset.roomy => MaterialMetrics.spaceL,
  };

  /// How far a surface stands off the one behind it.
  static double elevation(Elevation elevation) => switch (elevation) {
    Elevation.flush => MaterialMetrics.elevationFlush,
    Elevation.resting => MaterialMetrics.elevationResting,
    Elevation.raised => MaterialMetrics.elevationRaised,
    Elevation.overlay => MaterialMetrics.elevationOverlay,
  };

  /// How large a mark is at [scale].
  static double glyph(ControlScale scale) => switch (scale) {
    ControlScale.compact => MaterialMetrics.iconS,
    ControlScale.normal => MaterialMetrics.iconM,
    ControlScale.prominent => MaterialMetrics.iconL,
  };
}

/// How this skin turns a [Tone] into a colour.
///
/// Sixteen named tones plus the series, resolved against the ambient
/// `ColorScheme` where Material has a slot for the meaning and against this
/// skin's own git palette where it has none. "This file is staged" is not a
/// question any design language answers, which is exactly why [Tone] carries
/// it and why the answer is here.
abstract final class MaterialInk {
  /// The foreground colour [tone] means on an ordinary surface.
  static Color foreground(BuildContext context, Tone tone) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final MaterialGitPalette git = MaterialGitPalette.of(context);
    if (tone.seriesIndex != null) return series(tone.seriesIndex!);
    return switch (tone.name) {
      'neutral' => colors.onSurface,
      'muted' => colors.onSurfaceVariant,
      'accent' => colors.primary,
      'onAccent' => colors.onPrimary,
      'danger' => colors.error,
      // Warning and success are the git palette's, not the scheme's: Material
      // 3 has no warning or success role at all, and this application already
      // answered both with the git colours that carry the same meaning - a
      // modified file IS its warning colour.
      'warning' => git.modified,
      'success' => git.added,
      // Informational and accent land on the same role, and that is what the
      // application already renders: `BaseBadge` resolves both `primary` and
      // `info` to `colorScheme.primary`. Recorded rather than hidden - a
      // language with a distinct informational role would separate them.
      'info' => colors.primary,
      'gitAdded' => git.added,
      'gitModified' => git.modified,
      'gitDeleted' => git.deleted,
      'gitRenamed' => git.renamed,
      'gitUntracked' => git.untracked,
      'gitConflicted' => git.conflict,
      'gitIgnored' => git.untracked,
      'gitStaged' => git.added,
      _ => colors.onSurface,
    };
  }

  /// The nth colour of this skin's generated series.
  ///
  /// Twelve, and the LENGTH is as much this skin's decision as the palette is:
  /// that is why `controls.seriesPicker` has to exist, because once the skin
  /// owns both there is no legal way for the application to enumerate the
  /// swatches itself. The values are the ones the application duplicated
  /// across `project.dart`, `workspace.dart` and `quick_settings_menu.dart`,
  /// which the contract deletes by moving them here.
  static Color series(int index) => seriesPalette[index % seriesPalette.length];

  /// Every colour a `Tone.series` can name, in order.
  static const List<Color> seriesPalette = <Color>[
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
  ];

  /// Foreground for text painted on a solid tone: a filled success button, a
  /// chosen swatch.
  ///
  /// 0.179 is the luminance at which black and white text contrast equally;
  /// above it black reads better, below it white. Raw literals rather than
  /// `Colors.black`/`Colors.white`, because the design-system rule bans that
  /// class and the rule is right about it here too.
  static Color foregroundOn(Color background) =>
      background.computeLuminance() > 0.179
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}

/// The colours git state means, per brightness.
///
/// One fixed hex per role cannot satisfy WCAG 2.1 AA on both a near-white and
/// a near-black surface, so each role carries a light and a dark value and the
/// pair is chosen from the ambient brightness. The values are derived with HCT
/// tone mapping so that the worst case over every surface this skin paints
/// them on is at least 4.5:1 for text roles and 3:1 for the commit-graph
/// lanes; `test/conformance/a11y/git_colors_contrast_test.dart` asserts
/// exactly that and must be kept passing when any value changes.
@immutable
final class MaterialGitPalette {
  /// Declares one palette.
  const MaterialGitPalette({
    required this.added,
    required this.modified,
    required this.deleted,
    required this.renamed,
    required this.untracked,
    required this.conflict,
    required this.branchLocal,
    required this.branchRemote,
    required this.branchTag,
    required this.branchStash,
    required this.lanes,
  });

  /// Added files, staged success states.
  final Color added;

  /// Modified files, and warnings that are not errors.
  final Color modified;

  /// Deleted files, failed git output.
  final Color deleted;

  /// Renamed and copied files.
  final Color renamed;

  /// Untracked and ignored files.
  final Color untracked;

  /// Merge conflicts.
  final Color conflict;

  /// Local branches.
  final Color branchLocal;

  /// Remote branches.
  final Color branchRemote;

  /// Tags.
  final Color branchTag;

  /// Stashes.
  final Color branchStash;

  /// The commit-graph lane cycle. Lanes are 2 px lines, so these meet the 3:1
  /// non-text threshold rather than the 4.5:1 text threshold.
  final List<Color> lanes;

  /// The palette for the brightness [context] renders at.
  static MaterialGitPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The palette for light surfaces.
  static const MaterialGitPalette light = MaterialGitPalette(
    added: Color(0xFF006318),
    modified: Color(0xFF7D4800),
    deleted: Color(0xFFA70007),
    renamed: Color(0xFF005794),
    untracked: Color(0xFF555656),
    conflict: Color(0xFFA40040),
    branchLocal: Color(0xFF006318),
    branchRemote: Color(0xFF005794),
    branchTag: Color(0xFF7D4800),
    branchStash: Color(0xFF8C10A1),
    lanes: <Color>[
      Color(0xFF0082D9), // Blue
      Color(0xFF2C9136), // Green
      Color(0xFFB86C00), // Orange
      Color(0xFFAB47BC), // Purple
      Color(0xFF008C9B), // Cyan
      Color(0xFFE53A75), // Pink
      Color(0xFF608B2D), // Light green
      Color(0xFF5C6BC0), // Indigo
    ],
  );

  /// The palette for dark surfaces.
  static const MaterialGitPalette dark = MaterialGitPalette(
    added: Color(0xFF59BC5B),
    modified: Color(0xFFFF9800),
    deleted: Color(0xFFFF8272),
    renamed: Color(0xFF58ACFF),
    untracked: Color(0xFFA8A8A8),
    conflict: Color(0xFFFF7E98),
    branchLocal: Color(0xFF59BC5B),
    branchRemote: Color(0xFF58ACFF),
    branchTag: Color(0xFFFF9800),
    branchStash: Color(0xFFED76FD),
    lanes: <Color>[
      Color(0xFF2196F3), // Blue
      Color(0xFF4CAF50), // Green
      Color(0xFFFF9800), // Orange
      Color(0xFFAD49BE), // Purple
      Color(0xFF26C6DA), // Cyan
      Color(0xFFEC407A), // Pink
      Color(0xFF9CCC65), // Light green
      Color(0xFF5F6EC3), // Indigo
    ],
  );
}

/// How this skin turns the nine application text roles into Material's ramp.
///
/// Nine roles rather than Material's fifteen, and the collapse is deliberate:
/// a screen that names `bodyMedium` has picked Material's ramp for Fluent and
/// AppKit too. The mapping is stated once, here, so that the one place a role
/// changes size is a line in this file.
///
/// **This is the ramp only, and a facet must not call it directly.** It sits
/// beside the numbers, where the user's [SkinRequest] cannot be reached, so it
/// cannot answer the one role whose family the user chooses. `MaterialTypeResolution.styleOf`
/// in `material_theme.dart` is the door every facet uses: it is this mapping
/// plus the monospace family. Calling this one directly is exactly how the two
/// halves of `TextRole.code` came to disagree between the type facet and the
/// code surfaces.
abstract final class MaterialTypeScale {
  /// The ramp step [role] lands on under the ambient theme.
  static TextStyle? styleOf(BuildContext context, TextRole role) {
    final TextTheme text = Theme.of(context).textTheme;
    return switch (role) {
      TextRole.pageTitle => text.titleLarge,
      TextRole.sectionTitle => text.titleMedium,
      TextRole.itemTitle => text.titleSmall,
      TextRole.body => text.bodyMedium,
      TextRole.emphasis => text.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      TextRole.detail => text.bodySmall,
      TextRole.micro => text.labelSmall,
      TextRole.control => text.labelLarge,
      // Monospaced by definition, because alignment is meaning in a diff
      // rather than style. The step is all this can say: the FAMILY is the
      // user's own choice and arrives as `SkinRequest.monoFamily`, which is
      // not reachable from here, so `MaterialTypeResolution.styleOf` puts it
      // on top. The fallback below is only the floor for a build with no
      // request in the tree at all - it cannot take effect while a primary
      // family is set, which is why it is not a substitute for that door.
      TextRole.code => text.bodyMedium?.copyWith(
        fontFamilyFallback: const <String>['monospace'],
      ),
    };
  }
}
