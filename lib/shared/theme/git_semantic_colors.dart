import 'package:flutter/material.dart';

/// Brightness-aware semantic colours for git state.
///
/// **A resolution table with a known end date, not a design.** What a git state
/// MEANS is now said with the eight `Tone.git*` members, and the skin answers
/// them - `MaterialInk.foreground` resolves `Tone.gitAdded` and its seven
/// siblings out of `MaterialGitPalette`, which carries these same values on the
/// skin's side of the seam. This extension survives beside that only for the
/// sites that still need a raw `Color` in hand: the surface FILLS, the tints
/// and the borders which have no way to name a tone, because the contract
/// deliberately exposes no application-side tone-to-colour door (no facet
/// returns a `Color`, and `no_value_in_contract` is what keeps it that way).
/// `FileStatusType.colorOf` beside `FileStatusType.toneOf` is the same pairing
/// one layer down, with the same end date: both go when those surfaces become
/// `SkinSurfaces` members and take their fills with them.
///
/// The four branch roles (`branchLocal`, `branchRemote`, `branchTag`,
/// `branchStash`) are gone: they had no reader left in the application and no
/// `Tone.git*` counterpart to become, so they were eight hex values naming
/// nothing. [laneColors] has no counterpart either and is NOT deletable - the
/// commit graph reads it - because `Tone.series` is one series and this is a
/// second, independent one. See the conversion notes for #249.
///
/// One fixed hex per role cannot satisfy WCAG 2.1 AA on both a near-white and
/// a near-black surface, so each role carries a light and a dark value and the
/// theme registers the preset matching its brightness. Values are derived from
/// the previous palette's hues with HCT tone mapping so that the worst-case
/// contrast over every surface the app paints them on (all ten selectable
/// schemes; scaffold through surfaceContainerHighest; the 12 % diff-row tint;
/// the 15 % badge tint) is at least 4.5:1 for text roles and 3:1 for the
/// commit-graph lanes.
/// `packages/gitui_skin_material/test/conformance/a11y/git_colors_contrast_test.dart`
/// asserts exactly that and must be kept passing when any value changes.
@immutable
class GitSemanticColors extends ThemeExtension<GitSemanticColors> {
  const GitSemanticColors({
    required this.added,
    required this.modified,
    required this.deleted,
    required this.renamed,
    required this.untracked,
    required this.conflict,
    required this.laneColors,
  });

  /// Added files, staged success states.
  final Color added;

  /// Modified files, warnings that are not errors.
  final Color modified;

  /// Deleted files, failed git output.
  final Color deleted;

  /// Renamed and copied files.
  final Color renamed;

  /// Untracked and ignored files.
  final Color untracked;

  /// Merge conflicts.
  final Color conflict;

  /// Commit-graph lane cycle. Lanes are 2 px lines, so these meet the 3:1
  /// non-text threshold rather than the 4.5:1 text threshold.
  final List<Color> laneColors;

  /// Palette for light themes.
  static const GitSemanticColors light = GitSemanticColors(
    added: Color(0xFF006318),
    modified: Color(0xFF7D4800),
    deleted: Color(0xFFA70007),
    renamed: Color(0xFF005794),
    untracked: Color(0xFF555656),
    conflict: Color(0xFFA40040),
    laneColors: [
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

  /// Palette for dark themes.
  static const GitSemanticColors dark = GitSemanticColors(
    added: Color(0xFF59BC5B),
    modified: Color(0xFFFF9800),
    deleted: Color(0xFFFF8272),
    renamed: Color(0xFF58ACFF),
    untracked: Color(0xFFA8A8A8),
    conflict: Color(0xFFFF7E98),
    laneColors: [
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

  /// Foreground for text painted on a solid semantic colour (filled success
  /// buttons and badges). 0.179 is the luminance at which black and white
  /// text contrast equally; above it black reads better, below it white.
  /// Raw literals, not Colors.black/white: the avoid_hardcoded_colors lint
  /// forbids the Colors class everywhere in lib/.
  static Color foregroundOn(Color background) =>
      background.computeLuminance() > 0.179
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  @override
  GitSemanticColors copyWith({
    Color? added,
    Color? modified,
    Color? deleted,
    Color? renamed,
    Color? untracked,
    Color? conflict,
    List<Color>? laneColors,
  }) {
    return GitSemanticColors(
      added: added ?? this.added,
      modified: modified ?? this.modified,
      deleted: deleted ?? this.deleted,
      renamed: renamed ?? this.renamed,
      untracked: untracked ?? this.untracked,
      conflict: conflict ?? this.conflict,
      laneColors: laneColors ?? this.laneColors,
    );
  }

  @override
  GitSemanticColors lerp(ThemeExtension<GitSemanticColors>? other, double t) {
    if (other is! GitSemanticColors) return this;
    return GitSemanticColors(
      added: Color.lerp(added, other.added, t)!,
      modified: Color.lerp(modified, other.modified, t)!,
      deleted: Color.lerp(deleted, other.deleted, t)!,
      renamed: Color.lerp(renamed, other.renamed, t)!,
      untracked: Color.lerp(untracked, other.untracked, t)!,
      conflict: Color.lerp(conflict, other.conflict, t)!,
      laneColors: [
        for (var i = 0; i < laneColors.length; i++)
          Color.lerp(
            laneColors[i],
            i < other.laneColors.length ? other.laneColors[i] : laneColors[i],
            t,
          )!,
      ],
    );
  }
}

/// Convenient access to the palette from any build method.
extension GitSemanticColorsContext on BuildContext {
  /// The git palette registered by the active theme; falls back to the preset
  /// matching the theme brightness so bare test themes keep working.
  GitSemanticColors get gitColors =>
      Theme.of(this).extension<GitSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? GitSemanticColors.dark
          : GitSemanticColors.light);
}
