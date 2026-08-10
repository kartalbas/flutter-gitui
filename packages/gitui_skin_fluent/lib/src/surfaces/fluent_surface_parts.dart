/// The pieces the surface members share: the tile fill ladder, the row
/// foreground, the selection pill, the menu anchor and the double-tap
/// tracker. The InfoBadge lives in `controls/fluent_info_badge.dart`,
/// where the chrome facet shares it too.
///
/// One file rather than a table per member, because WinUI itself shares
/// them: a list tile, a tree row and a settings row all resolve their fill
/// through the same `uncheckedInputColor` ladder and mark their selection
/// with the same accent pill, and two copies of a ladder is how two
/// surfaces drift apart. Every value carries its provenance - the published
/// WinUI resource or the reference checkout at D:/repos/github/fluent_ui
/// (read, never compiled or shipped).
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_control_marks.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';

/// The metrics the surface members draw at, each with its source.
abstract final class FluentSurfaceMetrics {
  /// A one-line list tile's minimum height.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/surfaces/list_tile.dart:5
  /// (`kOneLineTileHeight = 40`).
  static const double tileMinHeight = 40;

  /// A list tile's minimum width (list_tile.dart:336).
  static const double tileMinWidth = 88;

  /// The gap between neighbouring tiles: 4 to the sides, 2 above and below
  /// (list_tile.dart:20-23, `kDefaultListTileMargin`).
  static const EdgeInsetsGeometry tileMargin = EdgeInsetsDirectional.symmetric(
    horizontal: 4,
    vertical: 2,
  );

  /// A tile's content padding: end 12, top 6, bottom 6
  /// (list_tile.dart:8-12, `kDefaultListTilePadding`). The start is owned
  /// by the selection region - 12 when nothing marks it
  /// (list_tile.dart:288).
  static const EdgeInsetsGeometry tilePadding = EdgeInsetsDirectional.only(
    end: 12,
    top: 6,
    bottom: 6,
  );

  /// The start inset a tile keeps where no selection mark sits
  /// (list_tile.dart:288, the `placeholder`).
  static const double tileSelectionSlot = 12;

  /// The gap after a tile's leading slot (list_tile.dart:295).
  static const double tileLeadingGap = 14;

  /// The selection pill: 3 epx wide, stadium-ended, 8 epx before the
  /// content (list_tile.dart:382-396).
  static const double pillWidth = 3;

  /// The gap between the pill and the content (list_tile.dart:393-395).
  static const double pillEndGap = 8;

  /// How much of the tile's height the pill occupies at rest
  /// (list_tile.dart:383, `height * 0.7`).
  static const double pillHeightFactor = 0.7;

  /// How far the pill collapses while the tile is pressed
  /// (list_tile.dart:373, `tileHeight * 0.3`).
  static const double pillPressedFactor = 0.3;

  /// A tree row's minimum height: 26, or 28 when it carries a checkbox
  /// (fluent_ui@4.16.1 lib/src/controls/navigation/tree_view.dart:
  /// 1437-1442).
  static const double treeRowMinHeight = 26;

  /// The checked tree row's minimum height (tree_view.dart:1438-1439).
  static const double treeRowCheckedMinHeight = 28;

  /// How far one level of a tree indents the next: two rungs of the
  /// reference's own whitespace unit (tree_view.dart:41 `_whiteSpace = 8`,
  /// consumed at :1451-1453 as `depth * _whiteSpace * 2`).
  static const double treeIndent = 16;

  /// The chevron cell of a tree row: 24 wide - "three times the chevron's
  /// (max) width" (tree_view.dart:1500-1502) - and the same 24 pads a
  /// leaf so siblings align (tree_view.dart:1523-1525).
  static const double treeChevronCell = 24;

  /// The chevron glyph itself, 8 epx (tree_view.dart:1514; the Expander
  /// draws the same mark at the same size, surfaces/expander.dart:406).
  static const double chevronGlyph = 8;

  /// A tree row's corner (tree_view.dart:1472) and an Expander chevron
  /// box's corner (expander.dart:379): 6.
  static const double rowCornerRadius = 6;

  /// A list tile's corner (list_tile.dart:15-17, `kDefaultListTileShape`).
  static const double tileCornerRadius = 4;

  /// The selection pill's corner in its positioned form
  /// (tree_view.dart:1570).
  static const double pillCornerRadius = 4;

  /// An Expander header's minimum height (expander.dart:322).
  static const double expanderHeaderMinHeight = 42;

  /// An Expander header's start inset (expander.dart:343).
  static const double expanderHeaderStartInset = 16;

  /// The gap after an Expander's leading mark (expander.dart:349-352).
  static const double expanderLeadingGap = 10;

  /// The gap before an Expander's trailing slot (expander.dart:354-358).
  static const double expanderTrailingGap = 20;

  /// The padding inside an Expander's chevron box (expander.dart:369-372).
  static const double expanderChevronPad = 10;

  /// An Expander body's content padding (expander.dart:235, the
  /// `contentPadding` default of 16 on every side).
  static const double expanderBodyInset = 16;

  /// A tab strip item's height (fluent_ui@4.16.1
  /// lib/src/controls/navigation/tab_view/tab_view.dart:14,
  /// `_kTileHeight = 34`).
  static const double tabHeight = 34;

  /// A tab's top corner (tab_view/tab.dart:384).
  static const double tabTopCornerRadius = 6;

  /// A selected tab's content padding (tab.dart:391-397).
  static const EdgeInsetsGeometry tabSelectedPadding =
      EdgeInsetsDirectional.only(start: 9, top: 3, end: 5, bottom: 4);

  /// An unselected tab's content padding (tab.dart:398-403).
  static const EdgeInsetsGeometry tabPadding = EdgeInsetsDirectional.only(
    start: 8,
    top: 3,
    end: 4,
    bottom: 3,
  );

  /// A tab label's size: the reference pins its tab text at 12
  /// (tab.dart:416-417) - a control-private metric like the InfoBadge's
  /// 11, not a rung of the type ramp.
  static const double tabFontSize = 12;

  /// An InfoBar's padding: 14 everywhere but the end, which is 8 so the
  /// close control can carry its own inset
  /// (fluent_ui@4.16.1 lib/src/controls/surfaces/info_bar.dart:579-584).
  static const EdgeInsetsGeometry infoBarPadding = EdgeInsetsDirectional.only(
    start: 14,
    top: 14,
    bottom: 14,
    end: 8,
  );

  /// The gap after an InfoBar's severity mark (info_bar.dart:415).
  static const double infoBarIconGap = 14;

  /// An InfoBar's close mark, 16 epx (info_bar.dart:631).
  static const double dismissGlyph = 16;

  /// The wash a line's own meaning puts behind a code row.
  ///
  /// Not a WinUI resource - no design language has one for "this line was
  /// added" - and not this skin's invention either: 12% is the strength
  /// the application's own diff viewer always used and the Material skin
  /// records for the same job (`MaterialSurfaces._codeLineWash`), kept
  /// identical here so one repository question ("how loud is a diff
  /// line's meaning") has one measured answer. The colours washed are this
  /// skin's own `FluentGitPalette`.
  static const double codeLineWash = 0.12;

  /// One commit-graph lane's width, the dot's radius and the edge stroke.
  ///
  /// Application heritage rather than any language's canon: the three
  /// numbers that sat beside the application's own `commit_graph_painter`
  /// before the member existed (12 / 4 / 2, with the eight-lane render
  /// cap), the same lineage the Material skin's painter records. No
  /// design language publishes a commit graph.
  static const double graphLaneWidth = 12;

  /// The commit dot's radius (application heritage, see [graphLaneWidth]).
  static const double graphDotRadius = 4;

  /// The lane stroke (application heritage, see [graphLaneWidth]).
  static const double graphStrokeWidth = 2;

  /// The most lanes a gutter will reserve room for (application heritage,
  /// see [graphLaneWidth]).
  static const int graphLaneCap = 8;
}

/// The state-dependent colours the surface members share.
abstract final class FluentSurfaceInk {
  /// The subtle fill ladder every Fluent tile resolves its ground through:
  /// nothing at rest, `SubtleFillColorSecondary` hovered,
  /// `SubtleFillColorTertiary` pressed
  /// (`ButtonThemeData.uncheckedInputColor` with `transparentWhenNone` and
  /// `transparentWhenDisabled`, fluent_ui@4.16.1
  /// lib/src/controls/buttons/theme.dart:364-380).
  ///
  /// A SELECTED tile resolves with the hovered state unioned in, so it
  /// wears the hover fill at rest - which is WinUI's own selected-tile
  /// treatment (list_tile.dart:280-286).
  static Color tileFill(
    FluentResources res,
    Set<WidgetState> states, {
    bool selected = false,
  }) {
    final Set<WidgetState> resolved = selected
        ? <WidgetState>{...states, WidgetState.hovered}
        : states;
    if (resolved.contains(WidgetState.disabled)) {
      return res.subtleFillColorTransparent;
    }
    if (resolved.contains(WidgetState.pressed)) {
      return res.subtleFillColorTertiary;
    }
    if (resolved.contains(WidgetState.hovered)) {
      return res.subtleFillColorSecondary;
    }
    return res.subtleFillColorTransparent;
  }

  /// The foreground a row's own text takes: primary at rest, SECONDARY
  /// while pressed - the press dims the words along with the fill -
  /// disabled when the row is (tree_view.dart:1423-1428).
  static Color rowForeground(FluentResources res, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return res.textFillColorDisabled;
    }
    if (states.contains(WidgetState.pressed)) {
      return res.textFillColorSecondary;
    }
    return res.textFillColorPrimary;
  }

  /// The colour the selection pill is drawn in.
  ///
  /// The accent brush while the collection holds the keyboard
  /// (list_tile.dart:387-391); the strong neutral fill while focus lives
  /// elsewhere. The second half is this skin's own answer to the
  /// contract's `containerFocused` pair - WinUI has no published
  /// unfocused-selection pill, and the strong fill is the language's own
  /// neutral emphasis (`ControlStrongFillColorDefault`) - so the selection
  /// stays clearly marked without claiming the keyboard.
  static Color pillColor(FluentThemeData theme, {required bool focused}) =>
      focused
      ? theme.accent.defaultBrushFor(theme.brightness)
      : theme.resources.controlStrongFillColorDefault;

  /// The InfoBar ground a banner's tone means
  /// (info_bar.dart:585-601): success, caution and critical grounds for
  /// their tones, the attention ground for everything else - WinUI's
  /// informational bar, whose ground is deliberately near-neutral.
  static Color bannerGround(FluentResources res, Tone tone) {
    if (tone == Tone.success) return res.systemFillColorSuccessBackground;
    if (tone == Tone.warning) return res.systemFillColorCautionBackground;
    if (tone == Tone.danger || tone == Tone.invalid) {
      return res.systemFillColorCriticalBackground;
    }
    return res.systemFillColorAttentionBackground;
  }
}

/// The 3 epx accent pill a selected tile or tree row wears at its start.
///
/// The whole behaviour is the reference's (list_tile.dart:363-400): the
/// pill animates its height at the medium step, stands at 70% of the row
/// while selected, collapses to 30% of that while the row is pressed, and
/// to nothing when the selection leaves.
final class FluentSelectionPill extends StatelessWidget {
  /// Draws the pill for [selected] under [pressed] and [containerFocused].
  const FluentSelectionPill({
    super.key,
    required this.selected,
    required this.pressed,
    required this.containerFocused,
  });

  /// Whether the row is the selection.
  final bool selected;

  /// Whether the row is pressed right now, which shrinks the pill.
  final bool pressed;

  /// Whether the collection holding the row has the keyboard, which
  /// decides the pill's colour - see [FluentSurfaceInk.pillColor].
  final bool containerFocused;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    // The reference never sizes the pill against the incoming constraints:
    // it reads the TILE's own minimum height through a LayoutBuilder and
    // hands the pill an absolute extent inside a SizedBox of that height
    // (list_tile.dart:339-341,363-383, `tileHeight = constraints.minHeight`
    // and `height * 0.7`). Sizing against the parent breaks in both of a
    // list's regimes - a viewport's unbounded height turns a fraction into
    // NaN, a bounded one turns a Center into a stretch - so this pill is
    // pinned to the tile minimum exactly the same way.
    const double rowHeight = FluentSurfaceMetrics.tileMinHeight;
    return SizedBox(
      height: rowHeight,
      child: TweenAnimationBuilder<double>(
        // The medium step on the standard curve (list_tile.dart:366-368).
        duration: FluentMotion.medium,
        curve: FluentMotion.curve,
        tween: Tween<double>(
          begin: 0,
          end: selected
              ? (pressed
                    ? rowHeight * FluentSurfaceMetrics.pillPressedFactor
                    : rowHeight)
              : 0.0,
        ),
        builder: (BuildContext context, double extent, Widget? child) => Center(
          child: Container(
            // list_tile.dart:383: `height * 0.7`.
            height: extent * FluentSurfaceMetrics.pillHeightFactor,
            width: FluentSurfaceMetrics.pillWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FluentGeometry.stadiumRadius),
              color: selected
                  ? FluentSurfaceInk.pillColor(theme, focused: containerFocused)
                  : const Color(0x00000000),
            ),
          ),
        ),
      ),
    );
  }
}

/// The anchor a row or a tree node hangs its own menu off: the WinUI
/// "more" button - the subtle icon-button box under the drawn three-dot
/// mark - opening the entries through [Overlays.menu], the application's
/// one overlay door.
///
/// Going through the front door is what re-captures the envelope, so the
/// menu is drawn by the same skin in the same brightness as the row - the
/// overlay facet's point-anchored flyout answers it.
///
/// An empty menu draws nothing at all: an anchor with nothing behind it is
/// a control the user cannot use.
final class FluentMenuAnchorButton extends StatelessWidget {
  /// Builds the anchor for [entries].
  const FluentMenuAnchorButton({super.key, required this.entries});

  /// The row's menu, as data.
  final List<MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final FluentThemeData theme = FluentTheme.of(context);
    return Builder(
      builder: (BuildContext anchor) => FluentPressable(
        onPressed: () =>
            Overlays.menu(anchor, at: _below(anchor), entries: entries),
        // The one English string this anchor carries: the application
        // names a menu's ENTRIES but not its anchor, and this package has
        // no localisation source to borrow a name from - the same
        // registered gap the banner's dismiss control documents.
        semanticsLabel: 'Menu',
        builder: (BuildContext context, Set<WidgetState> states) {
          final FluentResources res = theme.resources;
          // The subtle icon-button anatomy (buttons/icon_button.dart:
          // 110-133): 8 epx around the mark, corner 4, the subtle ladder.
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              // 8 epx around the mark (icon_button.dart:113-114); the
              // value happens to sit on the spacing ramp's S rung.
              padding: const EdgeInsets.all(FluentMetrics.spaceS),
              decoration: BoxDecoration(
                color: states.contains(WidgetState.pressed)
                    ? res.subtleFillColorTertiary
                    : states.contains(WidgetState.hovered)
                    ? res.subtleFillColorSecondary
                    : res.subtleFillColorTransparent,
                borderRadius: BorderRadius.circular(
                  FluentGeometry.controlCornerRadius,
                ),
              ),
              child: FluentMoreMark(
                color: FluentSurfaceInk.rowForeground(res, states),
                size: FluentMetrics.glyphNormal,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Where the menu opens: under the anchor's start corner, the flyout's
  /// own resting placement.
  static Offset _below(BuildContext anchor) {
    final RenderObject? object = anchor.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return Offset.zero;
    return object.localToGlobal(object.size.bottomLeft(Offset.zero));
  }
}

/// Recognises the double click from the interval between taps, so a row
/// can act on the PRESS: routing `onDoubleTap` through a gesture detector
/// would hold every single tap for the 300 ms double-tap window, and a row
/// that answers late feels broken. The same recognition the Material row
/// records; the window is the framework's own `kDoubleTapTimeout`.
final class FluentTapInterval {
  /// The framework's double-tap window, 300 ms
  /// (flutter/gestures/constants.dart, `kDoubleTapTimeout`).
  static const Duration timeout = Duration(milliseconds: 300);

  DateTime? _lastTap;

  /// Reports a tap NOW: always [onTap], and also [onActivate] when this
  /// tap lands within the window of the previous one.
  void tap(VoidCallback? onTap, VoidCallback? onActivate) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTap;
    _lastTap = now;
    onTap?.call();
    if (onActivate != null && last != null && now.difference(last) < timeout) {
      _lastTap = null;
      onActivate();
    }
  }
}
