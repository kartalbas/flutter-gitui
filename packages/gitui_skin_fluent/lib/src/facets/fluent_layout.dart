import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_ink.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';

/// How things sit next to one another, the Fluent way.
///
/// Every rung resolves through `FluentSpacing`, which lands the contract's
/// five Proximity and five Inset rungs on five distinct steps of the
/// published Fluent 2 spacing ramp - denser than Material's throughout,
/// which is exactly the divergence the vocabulary's own doc predicts and
/// the reason this facet is worth having as a falsifier at all. The flex
/// members share their MECHANISM with the blueprint and the Material skin
/// (a `Column`'s own `spacing`, the ancestor walk of the free-standing gap,
/// the intrinsic label column of the property list) because those mechanisms
/// are the contract's semantics; everything the eye can tell apart - the
/// distances, the divider's ink, the split handle's answer to the pointer,
/// the tile a grid shapes - is this language's own.
final class FluentLayout implements SkinLayout {
  /// Builds the layout facet.
  const FluentLayout();

  /// Things under one another, at the declared closeness.
  ///
  /// A plain [Column] whose `spacing` is the resolved Fluent rung. Each
  /// child is MOUNTED rather than placed, because the boundary mounting
  /// plants is what lets the attribution walk resume inside the most-called
  /// member in the contract.
  @override
  Widget column(
    BuildContext context,
    List<ContentPort> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.stretch,
    MainAxisSize size = MainAxisSize.min,
  }) => Column(
    mainAxisAlignment: main,
    crossAxisAlignment: cross,
    mainAxisSize: size,
    spacing: FluentSpacing.gap(gap),
    children: <Widget>[for (final ContentPort child in children) child.mount()],
  );

  /// Things beside one another, at the declared closeness.
  ///
  /// With `wrap: true` the run becomes a [Wrap], because "these belong
  /// beside one another and may break into more lines" is structure the
  /// application states. A wrap cannot stretch its children across the
  /// cross axis and has no main-axis size of its own - it sizes to its runs
  /// - so [CrossAxisAlignment.stretch], [CrossAxisAlignment.baseline] and
  /// [size] have no wrap equivalent to map onto; they resolve to the wrap's
  /// start alignment and its natural sizing, and stay honoured on the
  /// non-wrapping path.
  @override
  Widget row(
    BuildContext context,
    List<ContentPort> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.center,
    MainAxisSize size = MainAxisSize.max,
    bool wrap = false,
  }) {
    final double resolved = FluentSpacing.gap(gap);
    final List<Widget> mounted = <Widget>[
      for (final ContentPort child in children) child.mount(),
    ];
    if (!wrap) {
      return Row(
        mainAxisAlignment: main,
        crossAxisAlignment: cross,
        mainAxisSize: size,
        spacing: resolved,
        children: mounted,
      );
    }
    return Wrap(
      spacing: resolved,
      runSpacing: resolved,
      alignment: switch (main) {
        MainAxisAlignment.start => WrapAlignment.start,
        MainAxisAlignment.end => WrapAlignment.end,
        MainAxisAlignment.center => WrapAlignment.center,
        MainAxisAlignment.spaceBetween => WrapAlignment.spaceBetween,
        MainAxisAlignment.spaceAround => WrapAlignment.spaceAround,
        MainAxisAlignment.spaceEvenly => WrapAlignment.spaceEvenly,
      },
      crossAxisAlignment: switch (cross) {
        CrossAxisAlignment.start => WrapCrossAlignment.start,
        CrossAxisAlignment.end => WrapCrossAlignment.end,
        CrossAxisAlignment.center => WrapCrossAlignment.center,
        // A wrap cannot stretch a run's children and cannot align baselines;
        // start is the least opinionated stand-in for both.
        CrossAxisAlignment.stretch => WrapCrossAlignment.start,
        CrossAxisAlignment.baseline => WrapCrossAlignment.start,
      },
      children: mounted,
    );
  }

  /// Equals, in as many columns as fit.
  @override
  Widget grid(BuildContext context, GridSpec spec) => _FluentGrid(spec: spec);

  /// Two regions sharing the space, divided where the user last put the
  /// boundary.
  @override
  Widget splitPane(BuildContext context, SplitPaneSpec spec) =>
      _FluentSplitPane(spec: spec);

  /// Named values whose names line up.
  ///
  /// A [Table] with an intrinsic label column, the same mechanism the other
  /// two skins reach for and for the same reason: the label column must size
  /// to the longest label because the same labels are longer in every other
  /// locale, so a fixed width cannot survive translation.
  ///
  /// Two things here are Fluent speaking rather than layout mechanics:
  ///
  ///  * **No colon.** The spec carries the label without one and this
  ///    language does not add one back: WinUI's own label idiom renders the
  ///    bare words - the reference's `InfoLabel` draws exactly the label it
  ///    was given and appends nothing (fluent_ui@4.16.1
  ///    lib/src/controls/utils/info_label.dart:49-52), and the label-value
  ///    pairs of Windows 11's own Settings surfaces carry no terminal
  ///    punctuation. Material answers the same slot WITH a colon, which is
  ///    precisely the kind of divergence the colon-is-typography decision
  ///    exists to allow.
  ///  * **The label is Regular body, not an emboldened step.** The
  ///    reference's InfoLabel sets its label in `typography.body`
  ///    (info_label.dart:49-52); Fluent builds a pair's hierarchy from
  ///    placement - the aligned column - not from weight. The style resolves
  ///    through the one door and carries no colour, so the label follows
  ///    the surface it sits on like every other line of text.
  @override
  Widget propertyList(BuildContext context, PropertyListSpec spec) {
    final double labelGap = FluentSpacing.gap(Proximity.related);
    final double rowGap = FluentSpacing.gap(Proximity.grouped);
    final int last = spec.rows.length - 1;
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: <TableRow>[
        for (int index = 0; index < spec.rows.length; index++)
          TableRow(
            children: <Widget>[
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: labelGap,
                  bottom: index == last ? 0 : rowGap,
                ),
                child: Text(
                  spec.rows[index].label,
                  style: FluentTypeResolution.styleOf(context, TextRole.body),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: index == last ? 0 : rowGap,
                ),
                child: spec.rows[index].value.mount(),
              ),
            ],
          ),
      ],
    );
  }

  /// Breathing room, from this skin's inset scale.
  ///
  /// [x] and [y] override [all] per axis, so a call that says "normal all
  /// round but tight vertically" resolves each axis independently - the
  /// same shape `EdgeInsets.symmetric` gives the code this member replaces.
  @override
  Widget inset(
    BuildContext context,
    ContentPort child, {
    Inset all = Inset.normal,
    Inset? x,
    Inset? y,
  }) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: FluentSpacing.inset(x ?? all),
      vertical: FluentSpacing.inset(y ?? all),
    ),
    child: child.mount(),
  );

  /// A statement of division: the language's own one-pixel rule.
  ///
  /// Thickness and ink are the reference Divider's
  /// (fluent_ui@4.16.1 lib/src/controls/utils/divider.dart:186-195,
  /// `DividerThemeData.standard`: thickness 1, `DividerStrokeColorDefault`).
  /// The reference's default 10-pixel end margins are deliberately NOT
  /// carried: how far a rule stands from the edge is exactly what [indent]
  /// states in the contract's own vocabulary - `Inset.none` means the rule
  /// reaches the edge, and the language's own menus zero those margins for
  /// the same reason (`MenuFlyoutSeparator`, flyouts/menu_flyout.dart:
  /// 371-378). The indent insets the LEADING edge only, because that is
  /// what an indented divider means: the rule starts where the content it
  /// belongs to starts.
  @override
  Widget separator(
    BuildContext context, {
    Axis axis = Axis.horizontal,
    Inset indent = Inset.none,
  }) {
    final FluentResources res = FluentTheme.of(context).resources;
    final double lead = FluentSpacing.inset(indent);
    return axis == Axis.horizontal
        ? Container(
            // divider.dart:188, thickness 1.
            height: 1,
            margin: EdgeInsetsDirectional.only(start: lead),
            color: res.dividerStrokeColorDefault,
          )
        : Container(
            width: 1,
            margin: EdgeInsetsDirectional.only(top: lead),
            color: res.dividerStrokeColorDefault,
          );
  }

  /// One non-uniform gap between two neighbours.
  @override
  Widget gap(BuildContext context, Proximity proximity) =>
      _FluentGap(extent: FluentSpacing.gap(proximity));
}

/// A gap that reads its direction from the enclosing flex.
///
/// The contract promises that one member serves both axes, so the widget
/// walks its ancestors at build time for the nearest [Flex] - which covers
/// [Column] and [Row], both subtypes - and takes its main axis. The walk
/// stops at the first multi-child render widget either way, because a gap
/// sitting in a [Stack] or a viewport does not belong to some flex further
/// out; with no flex in reach it falls back to vertical, the axis of the
/// column it would most plausibly have been lifted out of. The same widget,
/// with the same reasoning, exists in the blueprint and the Material skin -
/// the mechanism is the contract's semantics, not any skin's appearance.
class _FluentGap extends StatelessWidget {
  const _FluentGap({required this.extent});

  /// The resolved rung, in logical pixels.
  final double extent;

  @override
  Widget build(BuildContext context) {
    Axis axis = Axis.vertical;
    context.visitAncestorElements((Element element) {
      final Widget widget = element.widget;
      if (widget is Flex) {
        axis = widget.direction;
        return false;
      }
      if (widget is MultiChildRenderObjectWidget) return false;
      return true;
    });
    return axis == Axis.horizontal
        ? SizedBox(width: extent)
        : SizedBox(height: extent);
  }
}

/// As many columns as fit, reported honestly.
///
/// A [GridView] under a `SliverGridDelegateWithMaxCrossAxisExtent`, with the
/// column count derived from the width by the delegate's own formula so the
/// application's keyboard controller can move by whole rows - once the skin
/// owns the geometry the application cannot re-derive it, so the member
/// must report it.
class _FluentGrid extends StatefulWidget {
  const _FluentGrid({required this.spec});

  /// The grid being laid out.
  final GridSpec spec;

  @override
  State<_FluentGrid> createState() => _FluentGridState();
}

class _FluentGridState extends State<_FluentGrid> {
  int? _reportedColumns;

  /// The widest a tile may be before the grid grants another column.
  ///
  /// The numbers are this skin's own, declared as such: neither the Fluent 2
  /// token set nor the reference publishes a card-grid tile extent. They
  /// step denser than Material's (280/350/400) because this whole language
  /// does - the same direction its spacing ramp takes.
  static double _tileExtent(GridDensity density) => switch (density) {
    GridDensity.compact => 240,
    GridDensity.normal => 320,
    GridDensity.roomy => 400,
  };

  /// The proportion this skin shapes a language-owned tile to: the Windows
  /// wide tile, 310 x 150 ("Tile sizes and dimensions", the published
  /// Windows tile grid - Small 71, Medium 150, Wide 310x150). The
  /// vocabulary's own doc predicts "Fluent's wider tile" against Material's
  /// landscape card, and this is that answer made concrete: a Fluent tile
  /// is roughly twice as wide as it stands tall, where Material's is 1.2:1.
  /// Under [TileHeight.content] no proportion applies at all.
  static const double _aspectRatio = 310 / 150;

  @override
  Widget build(BuildContext context) {
    final double extent = _tileExtent(widget.spec.density);
    // The gutter between equals is the ramp's grouped rung - members of one
    // group - on both axes and both paths.
    final double spacing = FluentSpacing.gap(Proximity.grouped);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Same formula SliverGridDelegateWithMaxCrossAxisExtent resolves its
        // column count with, so what is reported is what is laid out.
        final int columns = constraints.hasBoundedWidth
            ? (constraints.maxWidth / (extent + spacing)).ceil()
            : widget.spec.children.length;
        final int resolved = columns < 1 ? 1 : columns;
        _report(resolved);
        if (widget.spec.tileHeight == TileHeight.content) {
          return _contentRows(resolved, spacing);
        }
        return GridView(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: extent,
            childAspectRatio: _aspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          children: <Widget>[
            for (final ContentPort child in widget.spec.children) child.mount(),
          ],
        );
      },
    );
  }

  /// Rows of content-owned tiles.
  ///
  /// A grid whose content owns its height cannot be a [GridView]: every
  /// sliver grid delegate resolves ONE main-axis extent per column count,
  /// which is exactly the promise [TileHeight.content] withdraws. So the
  /// tiles are laid in rows whose members share the height of the tallest
  /// among them - row lines stay level while every tile gets the room its
  /// content asked for. Column count and gutters are the same as the
  /// language-owned path's.
  Widget _contentRows(int columns, double spacing) {
    final List<Widget> cells = <Widget>[
      for (final ContentPort child in widget.spec.children) child.mount(),
    ];
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < cells.length; start += columns) {
      final int end = start + columns < cells.length
          ? start + columns
          : cells.length;
      final List<Widget> row = cells.sublist(start, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing,
            children: <Widget>[
              for (final Widget cell in row) Expanded(child: cell),
              // Fillers keep a short last row's tiles the same width as
              // every other row's.
              for (int filler = row.length; filler < columns; filler++)
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: rows,
      ),
    );
  }

  /// Tells the application the resolved column count, once per change.
  ///
  /// Deferred to after the frame because the count is learned during
  /// layout, and a callback that set state synchronously from inside a
  /// layout pass would re-enter build.
  void _report(int columns) {
    if (_reportedColumns == columns) return;
    _reportedColumns = columns;
    final ValueChanged<int>? onColumnsChanged = widget.spec.onColumnsChanged;
    if (onColumnsChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) onColumnsChanged(columns);
    });
  }
}

/// Two ports divided by a boundary the user can drag, the Windows way: the
/// resizable pane HOLDS its width while the window changes, and the other
/// pane takes what remains - which is how every paned Windows surface
/// (File Explorer's navigation pane foremost) answers a window resize.
///
/// Neither the Fluent 2 token set nor the reference checkout ships a
/// splitter, so the handle is this skin's own composition from the
/// language's published vocabulary, each part named:
///
///  * the rule down the centre is the language's divider - 1px,
///    `DividerStrokeColorDefault` (fluent_ui@4.16.1
///    lib/src/controls/utils/divider.dart:186-195);
///  * the hit strip around it is 8 epx - `spacingHorizontalS`, the ramp
///    rung between two parts of one statement, which is what the two
///    halves of a split are;
///  * the strip answers the pointer the way every subtle Fluent control
///    does: `SubtleFillColorSecondary` composites over the surface while
///    hovered (the subtle ladder, fluent_ui buttons/theme.dart:364-380) -
///    a divider that will move says so before it is grabbed;
///  * the floor a pane cannot be dragged below is 120 epx, this skin's own
///    number declared as such: the language publishes no splitter to cite,
///    and the floor exists so neither half can be dragged into uselessness.
class _FluentSplitPane extends StatefulWidget {
  const _FluentSplitPane({required this.spec});

  /// The split being laid out.
  final SplitPaneSpec spec;

  @override
  State<_FluentSplitPane> createState() => _FluentSplitPaneState();
}

class _FluentSplitPaneState extends State<_FluentSplitPane> {
  /// Whether the pointer is over the handle right now.
  bool _hovered = false;

  /// The strip's full hit target: the ramp's S rung (FluentMetrics.spaceS).
  static const double _handleExtent = FluentMetrics.spaceS;

  /// The narrowest a pane may be dragged. This skin's own floor - see the
  /// class doc.
  static const double _minPaneExtent = 120;

  SplitPaneSpec get spec => widget.spec;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    final bool horizontal = spec.axis == Axis.horizontal;
    final bool leadingResizes = spec.resizableSide == PaneSide.leading;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double total = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        // The fraction is the PRIMARY pane's share of the whole, whichever
        // side owns the handle; the sized pane's extent derives from it, so
        // the two spellings of one division cannot drift apart.
        final double primaryShare = spec.fraction.clamp(0.0, 1.0);
        final double resizableExtent = _clampPane(
          (leadingResizes ? primaryShare : 1 - primaryShare) * total,
          total,
        );

        final Widget hairline = Center(
          child: Container(
            // divider.dart:188, thickness 1.
            width: horizontal ? 1 : null,
            height: horizontal ? null : 1,
            color: res.dividerStrokeColorDefault,
          ),
        );
        Widget handle = SizedBox(
          width: horizontal ? _handleExtent : null,
          height: horizontal ? null : _handleExtent,
          child: hairline,
        );
        if (spec.onFractionChanged != null) {
          // A boundary that can move says so: the resize cursor on
          // approach, and the subtle hover layer while the pointer is on
          // the strip. A fixed division draws the hairline alone and
          // advertises nothing.
          handle = MouseRegion(
            cursor: horizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: horizontal
                  ? (DragUpdateDetails details) =>
                        _drag(details.delta.dx, resizableExtent, total)
                  : null,
              onVerticalDragUpdate: horizontal
                  ? null
                  : (DragUpdateDetails details) =>
                        _drag(details.delta.dy, resizableExtent, total),
              child: SizedBox(
                width: horizontal ? _handleExtent : null,
                height: horizontal ? null : _handleExtent,
                child: ColoredBox(
                  color: _hovered
                      ? res.subtleFillColorSecondary
                      : res.subtleFillColorTransparent,
                  child: hairline,
                ),
              ),
            ),
          );
        }

        final Widget sized = SizedBox(
          width: horizontal ? resizableExtent : null,
          height: horizontal ? null : resizableExtent,
          child: (leadingResizes ? spec.primary : spec.secondary).mount(),
        );
        final Widget flexible = Expanded(
          child: (leadingResizes ? spec.secondary : spec.primary).mount(),
        );
        return Flex(
          direction: spec.axis,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: leadingResizes
              ? <Widget>[sized, handle, flexible]
              : <Widget>[flexible, handle, sized],
        );
      },
    );
  }

  /// The pane extent, clamped to this skin's floor and to the space that
  /// actually exists - a window narrower than two floors must still lay
  /// out, so the OTHER pane keeps its floor too where there is room.
  static double _clampPane(double extent, double total) {
    final double available = (total - _handleExtent).clamp(0.0, total);
    final double max = (available - _minPaneExtent).clamp(0.0, available);
    final double min = _minPaneExtent < max ? _minPaneExtent : max;
    return extent.clamp(min, max);
  }

  /// Converts a drag into a new primary-share fraction against the measured
  /// whole.
  ///
  /// The sign depends on which side the sized pane sits: with the handle
  /// after a leading pane, dragging towards the trailing edge grows it, and
  /// with the handle before a trailing pane the same drag shrinks it. The
  /// reported fraction is always the primary pane's share, so the caller
  /// stores one number with one meaning.
  void _drag(double delta, double currentExtent, double total) {
    if (total <= 0) return;
    final bool leadingResizes = spec.resizableSide == PaneSide.leading;
    final double next = _clampPane(
      currentExtent + (leadingResizes ? delta : -delta),
      total,
    );
    final double share = (next / total).clamp(0.0, 1.0);
    spec.onFractionChanged!(leadingResizes ? share : 1 - share);
  }
}
