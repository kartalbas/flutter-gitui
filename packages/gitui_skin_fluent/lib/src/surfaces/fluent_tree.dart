import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_checkbox.dart';
import '../controls/fluent_control_marks.dart';
import '../controls/fluent_info_badge.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_surface_parts.dart';

/// The Fluent answer to `surfaces.tree`: the WinUI TreeView, drawn.
///
/// The member is at the TREE, so this owns the walk: `roots` is flattened
/// against `expanded`, a node's children exist only while the node is
/// open, and only the rows a bounded viewport asks for are built - a
/// ten-thousand-file working tree must not build ten thousand rows to
/// show twenty. Both application trees already sit inside an `Expanded`,
/// so the bounded height this needs is the height they already have.
///
/// Row anatomy and states from the reference
/// (fluent_ui@4.16.1 lib/src/controls/navigation/tree_view.dart):
/// the 26 epx row (28 with a checkbox) inside a 4/2 margin at corner 6
/// (:1418-1442), 16 epx of indent per level (:41,:1451-1453), the 24 epx
/// chevron cell that also pads a leaf so siblings align (:1496-1525), the
/// pressed-dims-the-words foreground (:1423-1428), and the 3 epx accent
/// pill on the selected row (:1559-1571).
///
/// [TreeSpec.revealed] is honoured when the value arrives or changes,
/// never on every rebuild, so the user can still scroll away from a
/// revealed node: the same contract obligation the spec's own doc states.
final class FluentTree extends StatefulWidget {
  /// Draws [spec] in Fluent.
  const FluentTree({super.key, required this.spec});

  /// What the application declared.
  final TreeSpec spec;

  @override
  State<FluentTree> createState() => _FluentTreeState();
}

/// One row of the flattened walk.
final class _FlatNode {
  const _FlatNode(this.node, this.depth, this.open);

  final TreeNodeSpec node;
  final int depth;
  final bool open;
}

class _FluentTreeState extends State<FluentTree> {
  final ScrollController _scrollController = ScrollController();

  /// Marks the revealed node's row so its real geometry can be measured
  /// once it is built. At most one row wears it.
  final GlobalKey _revealedKey = GlobalKey();

  /// The estimate that gets a far-away row built: the row's minimum plus
  /// its vertical margins. It only has to land within the cache extent of
  /// the truth - the correction pass reads the row's real geometry.
  static const double _nominalRowExtent =
      FluentSurfaceMetrics.treeRowMinHeight + 4;

  List<_FlatNode> _rows = const <_FlatNode>[];

  @override
  void initState() {
    super.initState();
    if (widget.spec.revealed != null) _scheduleReveal();
  }

  @override
  void didUpdateWidget(FluentTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.revealed != null &&
        widget.spec.revealed != oldWidget.spec.revealed) {
      _scheduleReveal();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Post-frame, because a reveal scheduled from init or an update runs
  /// before this frame's layout exists.
  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) _reveal();
    });
  }

  void _reveal() {
    if (!_scrollController.hasClients) return;
    if (_revealedKey.currentContext != null) {
      _settleRevealedRow();
      return;
    }
    // The row is not built. Revealing a node hidden under a collapsed
    // ancestor is a no-op - expansion is application state, not this
    // skin's to mutate - so a missing index simply returns.
    final Object? revealed = widget.spec.revealed;
    final int index = _rows.indexWhere(
      (_FlatNode row) => row.node.id == revealed,
    );
    if (index < 0) return;
    final ScrollPosition position = _scrollController.position;
    _scrollController.jumpTo(
      (index * _nominalRowExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) _settleRevealedRow();
    });
  }

  /// Scrolls only as far as puts the revealed row fully inside the
  /// viewport: nothing when it already is, to its own edge when it is
  /// not - minimal motion, which is this language's own reveal.
  void _settleRevealedRow() {
    final BuildContext? revealedContext = _revealedKey.currentContext;
    if (revealedContext == null || !_scrollController.hasClients) return;
    final RenderObject? row = revealedContext.findRenderObject();
    if (row == null) return;
    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      row,
    );
    if (viewport == null) return;
    final double atLeading = viewport.getOffsetToReveal(row, 0).offset;
    final double atTrailing = viewport.getOffsetToReveal(row, 1).offset;
    final ScrollPosition position = _scrollController.position;
    final double target = _scrollController.offset
        .clamp(atTrailing, atLeading)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != _scrollController.offset) _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final TreeSpec spec = widget.spec;
    final List<_FlatNode> rows = <_FlatNode>[];
    void walk(List<TreeNodeSpec> nodes, int depth) {
      for (final TreeNodeSpec node in nodes) {
        final bool open = spec.expanded.contains(node.id);
        rows.add(_FlatNode(node, depth, open));
        if (open) walk(node.children, depth + 1);
      }
    }

    walk(spec.roots, 0);
    _rows = rows;
    return ListView.builder(
      controller: _scrollController,
      itemCount: rows.length,
      itemBuilder: (BuildContext row, int index) {
        final Widget built = _FluentTreeRow(spec: spec, row: rows[index]);
        if (spec.revealed != null && rows[index].node.id == spec.revealed) {
          return KeyedSubtree(key: _revealedKey, child: built);
        }
        return built;
      },
    );
  }
}

/// One row of the tree. Stateful because it acts on the press: the double
/// click is recognised from the interval between taps, and the row's
/// focus node refuses focus so the roving-highlight collection stays one
/// Tab stop.
final class _FluentTreeRow extends StatefulWidget {
  const _FluentTreeRow({required this.spec, required this.row});

  final TreeSpec spec;
  final _FlatNode row;

  @override
  State<_FluentTreeRow> createState() => _FluentTreeRowState();
}

class _FluentTreeRowState extends State<_FluentTreeRow> {
  final FocusNode _focusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'FluentTreeRow',
  );

  final FluentTapInterval _taps = FluentTapInterval();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TreeSpec spec = widget.spec;
    final TreeNodeSpec node = widget.row.node;
    final FluentThemeData theme = FluentTheme.of(context);
    final bool selected = spec.selected.contains(node.id);
    final bool parent = node.children.isNotEmpty;

    return Semantics(
      container: true,
      selected: selected,
      child: FluentPressable(
        mergeSemantics: false,
        focusNode: _focusNode,
        onPressed: () => _taps.tap(
          () => spec.onSelect(node.id),
          spec.onActivate == null ? null : () => spec.onActivate!(node.id),
        ),
        onContextMenu: spec.onContextMenu == null
            ? null
            : (Offset at) => spec.onContextMenu!(node.id, at),
        builder: (BuildContext context, Set<WidgetState> states) {
          final FluentResources res = theme.resources;
          final Color foreground = FluentSurfaceInk.rowForeground(res, states);
          return Stack(
            children: <Widget>[
              AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                margin: FluentSurfaceMetrics.tileMargin,
                constraints: BoxConstraints(
                  minHeight: node.checked != null
                      ? FluentSurfaceMetrics.treeRowCheckedMinHeight
                      : FluentSurfaceMetrics.treeRowMinHeight,
                ),
                padding: EdgeInsetsDirectional.only(
                  start: widget.row.depth * FluentSurfaceMetrics.treeIndent,
                ),
                decoration: BoxDecoration(
                  color: FluentSurfaceInk.tileFill(
                    res,
                    states,
                    selected: selected,
                  ),
                  borderRadius: BorderRadius.circular(
                    FluentSurfaceMetrics.rowCornerRadius,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    // The checkbox, where the node states a checked fact.
                    // Its own gesture inside the selectable row, exactly
                    // as the reference nests it (tree_view.dart:
                    // 1477-1489); the next state of a mixed box is
                    // checked, matching the checkbox control's own cycle.
                    if (node.checked != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 8,
                          end: 8,
                        ),
                        child: Semantics(
                          checked: node.checked ?? false,
                          mixed: node.checked == null,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: spec.onCheck == null
                                ? null
                                : () => spec.onCheck!(
                                    node.id,
                                    node.checked != true,
                                  ),
                            child: FluentCheckboxBox(
                              value: node.checked,
                              states: states,
                            ),
                          ),
                        ),
                      ),
                    // The chevron cell: 24 wide for a parent's chevron,
                    // and the same 24 on a leaf so siblings align
                    // (tree_view.dart:1496-1525). Opening is its own
                    // gesture - clicking the chevron opens the node,
                    // clicking the row selects it, and the two are not
                    // the same gesture.
                    if (parent)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => spec.onToggleExpanded(node.id),
                        child: SizedBox(
                          width: FluentSurfaceMetrics.treeChevronCell,
                          height: node.checked != null
                              ? FluentSurfaceMetrics.treeRowCheckedMinHeight
                              : FluentSurfaceMetrics.treeRowMinHeight,
                          child: Center(
                            child: FluentChevron(
                              color: foreground,
                              size: FluentSurfaceMetrics.chevronGlyph,
                              // Resting points down (open); a closed
                              // node points into the reading direction
                              // (tree_view.dart:1508-1513).
                              turns: widget.row.open
                                  ? 0
                                  : Directionality.of(context) ==
                                        TextDirection.ltr
                                  ? 3
                                  : 1,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(
                        width: FluentSurfaceMetrics.treeChevronCell,
                      ),
                    // The leading mark's slot: 20 wide at the prominent
                    // glyph (tree_view.dart:1528-1542). The glyph table
                    // is this package's registered gap, so the slot
                    // reserves its box and carries the mark's stated
                    // meaning as the slot's own colour - the day the
                    // table lands, the mark drops in already toned.
                    if (node.leading != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 8,
                          end: 16,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: FluentMetrics.glyphProminent,
                            color: node.leadingTone == null
                                ? foreground
                                : FluentInk.foreground(
                                    theme,
                                    node.leadingTone!,
                                  ),
                          ),
                          child: const SizedBox(
                            width: FluentMetrics.glyphProminent,
                          ),
                        ),
                      )
                    else
                      // The reference's whitespace unit (tree_view.dart:41).
                      const SizedBox(width: FluentMetrics.spaceS),
                    Expanded(
                      child: DefaultTextStyle(
                        // The reference pins its tree content at 12
                        // (tree_view.dart:1548-1552) - a control-private
                        // metric over the body step, the same kind of
                        // override the InfoBadge's 11 is.
                        style: FluentTypeResolution.styleOf(
                          context,
                          TextRole.body,
                        ).copyWith(fontSize: 12, color: foreground),
                        child: node.content.mount(),
                      ),
                    ),
                    if (node.badgeCount != null) ...<Widget>[
                      const SizedBox(width: FluentMetrics.spaceS),
                      FluentInfoBadge(label: '${node.badgeCount}'),
                    ],
                    if (node.trailing != null) ...<Widget>[
                      const SizedBox(width: FluentMetrics.spaceS),
                      node.trailing!.mount(),
                    ],
                    if (node.menu.isNotEmpty) ...<Widget>[
                      const SizedBox(width: FluentMetrics.spaceS),
                      FluentMenuAnchorButton(entries: node.menu),
                    ],
                    const SizedBox(width: FluentMetrics.spaceS),
                  ],
                ),
              ),
              // The selection pill: 3 epx, inset 6 from either end,
              // corner 4, in the accent while the tree holds the
              // keyboard (tree_view.dart:1559-1571; colour pairing per
              // FluentSurfaceInk.pillColor).
              if (selected)
                PositionedDirectional(
                  top: 6,
                  bottom: 6,
                  start: 0,
                  child: Container(
                    width: FluentSurfaceMetrics.pillWidth,
                    decoration: BoxDecoration(
                      color: FluentSurfaceInk.pillColor(
                        theme,
                        focused: spec.containerFocused,
                      ),
                      borderRadius: BorderRadius.circular(
                        FluentSurfaceMetrics.pillCornerRadius,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
