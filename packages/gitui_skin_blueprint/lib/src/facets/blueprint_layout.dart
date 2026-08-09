import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// How things sit next to one another, naked.
///
/// This is the facet the instrument's [BlueprintDistance] exists for: every
/// [Proximity] and every [Inset] resolves through it, so that the whole test
/// suite can be run once at `distance: 0` and once at `distance: 64` and any
/// result that differs between the two proves the application depends on a
/// specific distance. Nothing else in this facet holds a number the
/// application could come to depend on - the few pixel values that do appear
/// (a tile extent, a hairline) are the skin's own, which is the side of the
/// line where numbers are legal.
final class BlueprintLayout implements SkinLayout {
  /// Takes the distance every rung resolves against.
  const BlueprintLayout(this.distance);

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance.
  final BlueprintDistance distance;

  /// Things under one another, exactly as given.
  ///
  /// A plain [Column] whose `spacing` is the resolved rung - the gap widgets
  /// the application used to interleave are absorbed by the flex itself, so
  /// there is nothing here for a leak to hide in. Each child is MOUNTED rather
  /// than placed: the boundary that mounting plants is what lets the
  /// attribution walk resume inside the most-called member in the contract.
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
    spacing: distance.gap(gap),
    children: <Widget>[for (final ContentPort child in children) child.mount()],
  );

  /// Things beside one another, exactly as given.
  ///
  /// With `wrap: true` the run becomes a [Wrap], because "these belong beside
  /// one another and may break into more lines" is structure the application
  /// states. A wrap cannot stretch its children across the cross axis and has
  /// no main-axis size of its own - it sizes to its runs - so
  /// [CrossAxisAlignment.stretch], [CrossAxisAlignment.baseline] and [size]
  /// have no wrap equivalent to map onto; they resolve to the wrap's start
  /// alignment and to its natural sizing, and the parameters remain honoured
  /// on the non-wrapping path.
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
    final double resolved = distance.gap(gap);
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
  Widget grid(BuildContext context, GridSpec spec) =>
      _BlueprintGrid(spec: spec);

  /// Two regions sharing the space, divided where the user last put the
  /// boundary.
  @override
  Widget splitPane(BuildContext context, SplitPaneSpec spec) =>
      _BlueprintSplitPane(spec: spec);

  /// Named values whose names line up.
  ///
  /// A [Table] with an intrinsic label column, which is the same mechanism the
  /// existing implementation reaches for and for the same reason: the label
  /// column must size to the longest label because the same labels are longer
  /// in every other locale, so a fixed width cannot survive translation. The
  /// colon after each label is drawn here, by the skin - the spec carries the
  /// label WITHOUT it, because the colon is typography.
  @override
  Widget propertyList(BuildContext context, PropertyListSpec spec) {
    final double labelGap = distance.gap(Proximity.related);
    final double rowGap = distance.gap(Proximity.grouped);
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BlueprintText(spec.rows[index].label),
                    const BlueprintMark(':'),
                  ],
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

  /// Breathing room, resolved through the instrument's distance.
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
      horizontal: distance.inset(x ?? all),
      vertical: distance.inset(y ?? all),
    ),
    child: child.mount(),
  );

  /// A statement of division: one hairline of ink.
  ///
  /// The indent resolves through the instrument's distance like every other
  /// rung, and it insets the LEADING edge only, because that is what an
  /// indented divider means - the rule starts where the content it belongs to
  /// starts.
  @override
  Widget separator(
    BuildContext context, {
    Axis axis = Axis.horizontal,
    Inset indent = Inset.none,
  }) {
    final double lead = distance.inset(indent);
    return axis == Axis.horizontal
        ? Container(
            height: BlueprintInk.hairline(context),
            margin: EdgeInsetsDirectional.only(start: lead),
            color: BlueprintInk.ink(context),
          )
        : Container(
            width: BlueprintInk.hairline(context),
            margin: EdgeInsetsDirectional.only(top: lead),
            color: BlueprintInk.ink(context),
          );
  }

  /// One non-uniform gap between two neighbours.
  @override
  Widget gap(BuildContext context, Proximity proximity) =>
      _BlueprintGap(extent: distance.gap(proximity));
}

/// A gap that reads its direction from the enclosing flex.
///
/// The contract promises that one member serves both axes, so the widget
/// walks its ancestors at build time for the nearest [Flex] - which covers
/// [Column] and [Row], both subtypes - and takes its main axis. The walk
/// stops at the first multi-child render widget either way, because a gap
/// sitting in a [Stack] or a viewport does not belong to some flex further
/// out; with no flex in reach it falls back to vertical, the axis of the
/// column it would most plausibly have been lifted out of.
///
/// The one case this cannot see is a same-element [Flex] whose direction
/// changes in place without its children rebuilding; a render-tree read would
/// catch that, but `RenderFlex` is not exported through
/// `package:flutter/widgets.dart`, and this package imports nothing else from
/// Flutter. A column that becomes a row is a different widget type and
/// rebuilds its children, so the practical gap is only the raw `Flex` whose
/// `direction` is mutated - which the application does not do.
class _BlueprintGap extends StatelessWidget {
  const _BlueprintGap({required this.extent});

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
/// Stateful because the column count is reported through a callback, and a
/// callback fired during layout would re-enter build; the report is deferred
/// to after the frame and de-duplicated, so the application hears about a
/// count exactly when it changes.
class _BlueprintGrid extends StatefulWidget {
  const _BlueprintGrid({required this.spec});

  /// The grid being laid out.
  final GridSpec spec;

  @override
  State<_BlueprintGrid> createState() => _BlueprintGridState();
}

class _BlueprintGridState extends State<_BlueprintGrid> {
  int? _reportedColumns;

  /// The narrowest a tile may be before the grid gives up a column.
  ///
  /// Three densities must be told apart, and at zero inset the tile width is
  /// the only thing left to vary - the same reasoning `BlueprintGeometry`
  /// applies to `ControlScale`. The numbers are the skin's own.
  static double _tileExtent(GridDensity density) => switch (density) {
    GridDensity.compact => 128,
    GridDensity.normal => 256,
    GridDensity.roomy => 384,
  };

  /// Who owns a tile's height, drawn without a proportion.
  ///
  /// The instrument has no shape of its own to give a tile, so
  /// [TileHeight.language] is answered with the one thing a language asserts
  /// that content does not: uniformity. A language-owned row stands at one
  /// height - each tile stretched to its row's tallest - while content-owned
  /// tiles each stand at exactly the height of what they hold, ragged. The
  /// two answers differ wherever two tiles in a row differ, and neither
  /// involves a number the application could come to depend on.
  Widget _row(List<Widget> cells, {MainAxisSize size = MainAxisSize.max}) {
    if (widget.spec.tileHeight == TileHeight.content) {
      return Row(
        mainAxisSize: size,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells,
      );
    }
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: size,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final List<Widget> children = <Widget>[
        for (final ContentPort child in widget.spec.children) child.mount(),
      ];
      if (!constraints.hasBoundedWidth) {
        // Unbounded width means everything fits on one line, and saying so
        // is the honest report: a grid that always answered 1 would break
        // the keyboard controller and hide a real dependency.
        final int columns = children.isEmpty ? 1 : children.length;
        _report(columns);
        return SingleChildScrollView(
          child: _row(children, size: MainAxisSize.min),
        );
      }
      final double extent = _tileExtent(widget.spec.density);
      final int fit = (constraints.maxWidth / extent).floor();
      final int columns = children.isEmpty ? 1 : fit.clamp(1, children.length);
      _report(columns);
      final List<Widget> rows = <Widget>[];
      for (int start = 0; start < children.length; start += columns) {
        final int end = start + columns < children.length
            ? start + columns
            : children.length;
        final List<Widget> cells = children.sublist(start, end);
        rows.add(
          _row(<Widget>[
            for (final Widget cell in cells) Expanded(child: cell),
            // Fillers keep a short last row's cells the same width as
            // every other row's.
            for (int filler = cells.length; filler < columns; filler++)
              const Expanded(child: SizedBox.shrink()),
          ]),
        );
      }
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      );
    },
  );

  /// Tells the application the measured column count, once per change.
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

/// Two ports divided by a draggable hairline.
///
/// The fraction is user state and belongs to the application; everything else
/// - the hairline, the handle's hit region, the cursor - is the skin's. The
/// division is expressed as integer flex factors, so no layout pass ever
/// holds an unrounded pixel the application could come to depend on.
class _BlueprintSplitPane extends StatelessWidget {
  const _BlueprintSplitPane({required this.spec});

  /// The split being laid out.
  final SplitPaneSpec spec;

  @override
  Widget build(BuildContext context) {
    final int primaryFlex = (spec.fraction.clamp(0.0, 1.0) * 1000)
        .round()
        .clamp(1, 999);
    // Which half owns the handle, drawn as a mark on the handle itself so the
    // parameter is distinguishable: the mark points INTO the pane whose edge
    // the user is dragging.
    final String sideMark = switch ((spec.axis, spec.resizableSide)) {
      (Axis.horizontal, PaneSide.leading) => '<',
      (Axis.horizontal, PaneSide.trailing) => '>',
      (Axis.vertical, PaneSide.leading) => '^',
      (Axis.vertical, PaneSide.trailing) => 'v',
    };
    Widget handle = Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned.fill(
          child: Center(
            child: spec.axis == Axis.horizontal
                ? Container(
                    width: BlueprintInk.hairline(context),
                    color: BlueprintInk.ink(context),
                  )
                : Container(
                    height: BlueprintInk.hairline(context),
                    color: BlueprintInk.ink(context),
                  ),
          ),
        ),
        BlueprintMark(sideMark),
      ],
    );
    if (spec.onFractionChanged != null) {
      handle = MouseRegion(
        cursor: spec.axis == Axis.horizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (DragUpdateDetails details) => _drag(context, details),
          child: handle,
        ),
      );
    }
    return Flex(
      direction: spec.axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: primaryFlex, child: spec.primary.mount()),
        handle,
        Expanded(flex: 1000 - primaryFlex, child: spec.secondary.mount()),
      ],
    );
  }

  /// Converts a drag into a new fraction against the measured whole.
  void _drag(BuildContext context, DragUpdateDetails details) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final double total = spec.axis == Axis.horizontal
        ? renderObject.size.width
        : renderObject.size.height;
    if (total <= 0) return;
    final double delta = spec.axis == Axis.horizontal
        ? details.delta.dx
        : details.delta.dy;
    spec.onFractionChanged!((spec.fraction + delta / total).clamp(0.0, 1.0));
  }
}
