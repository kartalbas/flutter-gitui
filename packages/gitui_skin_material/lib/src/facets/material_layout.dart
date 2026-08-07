import 'package:flutter/material.dart' hide MaterialType;
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../material_ink.dart';

/// How things sit next to one another, the Material way.
///
/// The eight members replace the 676 measured gap widgets, the `EdgeInsets`
/// reads, the 47 dividers, the hand-built split pane in `browse_screen.dart`,
/// the column-count arithmetic in `repositories_screen.dart` and the
/// label/value table in `file_blame_panel.dart`. Every rung resolves through
/// `MaterialSpacing`, which carries the application's own five steps - so the
/// extraction moves the numbers without changing a single one of them.
final class MaterialLayout implements SkinLayout {
  /// Builds the layout facet.
  const MaterialLayout();

  /// Things under one another, at the declared closeness.
  ///
  /// A plain [Column] whose `spacing` is the resolved rung: the gap widgets
  /// the application used to interleave are absorbed by the flex itself,
  /// which is what makes the P3c migration delete more code than it adds.
  /// Each child is MOUNTED rather than placed, because the boundary mounting
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
    spacing: MaterialSpacing.gap(gap),
    children: <Widget>[for (final ContentPort child in children) child.mount()],
  );

  /// Things beside one another, at the declared closeness.
  ///
  /// With `wrap: true` the run becomes a [Wrap], because "these belong beside
  /// one another and may break into more lines" is structure the application
  /// states. A wrap cannot stretch its children across the cross axis and
  /// has no main-axis size of its own - it sizes to its runs - so
  /// [CrossAxisAlignment.stretch], [CrossAxisAlignment.baseline] and [size]
  /// have no wrap equivalent to map onto; they resolve to the wrap's start
  /// alignment and its natural sizing, and stay honoured on the non-wrapping
  /// path.
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
    final double resolved = MaterialSpacing.gap(gap);
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
  Widget grid(BuildContext context, GridSpec spec) => _MaterialGrid(spec: spec);

  /// Two regions sharing the space, divided where the user last put the
  /// boundary.
  @override
  Widget splitPane(BuildContext context, SplitPaneSpec spec) =>
      _MaterialSplitPane(spec: spec);

  /// Named values whose names line up.
  ///
  /// The extraction of `file_blame_panel.dart`'s statistics table: a [Table]
  /// whose label column is intrinsic and whose value column flexes. The label
  /// column sizes itself to the longest label and every row shares that
  /// width, so the values line up. It used to be a fixed 60 pixels in the
  /// application, which is narrower than "Total Lines:" even in English: the
  /// label wrapped inside the word and the top-aligned value ended up beside
  /// its first line, reading as a superscript. A fixed width could not hold
  /// anyway - the same labels are longer in every other locale
  /// ("Zeilen gesamt:", "Lineas Totales:") - which is why the member is at
  /// the set rather than at the row.
  ///
  /// The colon after each label is drawn here, by the skin: the spec carries
  /// the label without it, because the colon is typography.
  @override
  Widget propertyList(BuildContext context, PropertyListSpec spec) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.titleSmall;
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        for (final PropertyRow row in spec.rows)
          TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MaterialMetrics.spaceS,
                ),
                // ignore: avoid_text_with_style
                child: Text('${row.label}:', style: labelStyle),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: MaterialMetrics.spaceM,
                  top: MaterialMetrics.spaceS,
                  bottom: MaterialMetrics.spaceS,
                ),
                child: row.value.mount(),
              ),
            ],
          ),
      ],
    );
  }

  /// Breathing room, from this skin's inset scale.
  ///
  /// [x] and [y] override [all] per axis, so a call that says "normal all
  /// round but tight vertically" resolves each axis independently - the same
  /// shape `EdgeInsets.symmetric` gives the code this member replaces.
  @override
  Widget inset(
    BuildContext context,
    ContentPort child, {
    Inset all = Inset.normal,
    Inset? x,
    Inset? y,
  }) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MaterialSpacing.inset(x ?? all),
      vertical: MaterialSpacing.inset(y ?? all),
    ),
    child: child.mount(),
  );

  /// A statement of division: Material's own rule.
  ///
  /// [Divider] and [VerticalDivider] with no arguments beyond the indent,
  /// exactly as the application's 47 sites call them - the thickness and the
  /// colour come from the divider theme `wrapRoot` installs
  /// (`useM2StyleDividerInM3`), so the rule this member draws is the rule the
  /// application already draws. The indent insets the LEADING edge only,
  /// because that is what an indented divider means: the rule starts where
  /// the content it belongs to starts.
  @override
  Widget separator(
    BuildContext context, {
    Axis axis = Axis.horizontal,
    Inset indent = Inset.none,
  }) {
    final double lead = MaterialSpacing.inset(indent);
    return axis == Axis.horizontal
        ? Divider(indent: lead)
        : VerticalDivider(indent: lead);
  }

  /// One non-uniform gap between two neighbours.
  @override
  Widget gap(BuildContext context, Proximity proximity) =>
      _MaterialGap(extent: MaterialSpacing.gap(proximity));
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
/// with the same reasoning, exists in the blueprint - the mechanism is the
/// contract's semantics, not either skin's appearance.
class _MaterialGap extends StatelessWidget {
  const _MaterialGap({required this.extent});

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
/// The extraction of the repositories screen's card grid: a [GridView] under
/// a `SliverGridDelegateWithMaxCrossAxisExtent`, with the column count
/// derived from the width so the keyboard controller can move by whole rows.
/// The formula is the same one the screen used - which is the delegate's own -
/// and moving it here is the point: once the skin owns the geometry the
/// application cannot re-derive it, so the member must report it.
class _MaterialGrid extends StatefulWidget {
  const _MaterialGrid({required this.spec});

  /// The grid being laid out.
  final GridSpec spec;

  @override
  State<_MaterialGrid> createState() => _MaterialGridState();
}

class _MaterialGridState extends State<_MaterialGrid> {
  int? _reportedColumns;

  /// The widest a tile may be before the grid grants another column.
  ///
  /// The two live grids measured 400 (repository cards) and 350 (workspace
  /// cards); the density rungs keep both reachable and add the tighter step
  /// the vocabulary promises. The numbers are this skin's own.
  static double _tileExtent(GridDensity density) => switch (density) {
    GridDensity.compact => 280,
    GridDensity.normal => 350,
    GridDensity.roomy => 400,
  };

  /// The aspect ratio and gutter both grids share today
  /// (repositories_screen.dart's delegate: `childAspectRatio: 1.2`,
  /// cross- and main-axis spacing at the grouped rung).
  static const double _aspectRatio = 1.2;

  @override
  Widget build(BuildContext context) {
    final double extent = _tileExtent(widget.spec.density);
    const double spacing = MaterialMetrics.spaceM;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The grid resolves its column count from the width, so the
        // controller must learn it here for vertical arrows to move by whole
        // rows. Same formula SliverGridDelegateWithMaxCrossAxisExtent uses.
        final int columns = constraints.hasBoundedWidth
            ? (constraints.maxWidth / (extent + spacing)).ceil()
            : widget.spec.children.length;
        _report(columns < 1 ? 1 : columns);
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

  /// Tells the application the resolved column count, once per change.
  ///
  /// Deferred to after the frame because the count is learned during layout,
  /// and a callback that set state synchronously from inside a layout pass
  /// would re-enter build. The application's own version wrote a plain field
  /// on its keyboard controller and could do so inline; a contract callback
  /// cannot know it is that harmless.
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

/// Two ports divided by a boundary the user can drag.
///
/// The extraction of the browse screen's resizable divider: an 8-pixel
/// [MouseRegion] strip with the column-resize cursor, a transparent fill so
/// the whole strip is a target, and a one-pixel hairline in the theme's
/// divider colour down its centre. The fraction is user state and belongs to
/// the application; the handle's width, its hit slop, its cursor, its
/// hairline and the limits it clamps to are all this skin's - which is
/// exactly the pile of numbers the screen used to build by hand.
class _MaterialSplitPane extends StatelessWidget {
  const _MaterialSplitPane({required this.spec});

  /// The split being laid out.
  final SplitPaneSpec spec;

  /// The strip's full hit target, and the browse screen's own 8 pixels.
  static const double _handleExtent = 8;

  /// The narrowest and widest the resizable pane may be dragged, the same
  /// clamp the browse screen kept its file tree inside (200..600 logical
  /// pixels). Clamping the PANE rather than the fraction is deliberate: the
  /// point of the clamp is that neither half can be dragged into
  /// uselessness, and only a length says that.
  static const double _minPaneExtent = 200;
  static const double _maxPaneExtent = 600;

  @override
  Widget build(BuildContext context) {
    final bool horizontal = spec.axis == Axis.horizontal;
    final bool leadingResizes = spec.resizableSide == PaneSide.leading;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double total = horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        // The fraction is the PRIMARY pane's share of the whole, whichever
        // side owns the handle; the sized pane's extent is derived from it,
        // so the two spellings of one division cannot drift apart.
        final double primaryShare = spec.fraction.clamp(0.0, 1.0);
        final double resizableExtent = _clampPane(
          (leadingResizes ? primaryShare : 1 - primaryShare) * total,
          total,
        );

        Widget handle = MouseRegion(
          cursor: horizontal
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
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
              // The strip itself stays invisible; only the hairline down its
              // centre is drawn, in the divider colour the theme already
              // uses for every other rule.
              child: Center(
                child: Container(
                  width: horizontal ? 1 : null,
                  height: horizontal ? null : 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
          ),
        );
        if (spec.onFractionChanged == null) {
          // A fixed division draws the hairline without the cursor or the
          // gesture, so a boundary that cannot move does not advertise that
          // it can.
          handle = SizedBox(
            width: horizontal ? _handleExtent : null,
            height: horizontal ? null : _handleExtent,
            child: Center(
              child: Container(
                width: horizontal ? 1 : null,
                height: horizontal ? null : 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
          );
        }

        // The resizable side takes its measured extent and the other side
        // takes the rest, which is exactly the browse screen's SizedBox +
        // Expanded arrangement with the tree on the leading side.
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

  /// The pane extent, clamped to this skin's limits and to the space that
  /// actually exists - a window narrower than the minimum must still lay out.
  static double _clampPane(double extent, double total) {
    final double available = (total - _handleExtent).clamp(0.0, total);
    final double max = _maxPaneExtent < available ? _maxPaneExtent : available;
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
