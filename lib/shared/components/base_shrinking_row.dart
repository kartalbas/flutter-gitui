import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A horizontal row that gives every child its natural width while they all
/// fit, and shrinks only the widest children when they do not.
///
/// [Row] cannot express this: its flexible children split the free space by
/// flex factor in a single pass, so a short label gets squeezed to its share
/// even when the space it gives up cannot be used by anything else. This row
/// instead finds the smallest width ceiling that brings the children within
/// the available width and imposes it only on the children above it (the
/// "water filling" used by desktop tab strips). A child that is already
/// narrower than the ceiling keeps its natural width.
///
/// A shrunk child is laid out under a tighter max-width constraint and is
/// expected to degrade gracefully (the Base* controls ellipsize their
/// labels). [minChildWidth] is the floor below which a child is not squeezed
/// any further, so its fixed chrome (icon, paddings, affordances) never
/// overflows; when even the floored children exceed the incoming constraint
/// the row clips at its own edge instead of painting over its neighbors.
///
/// A child that lays out to zero width (a control hiding itself with
/// [SizedBox.shrink]) takes no [spacing] either, so an invisible child leaves
/// no double gap behind.
///
/// The row is left-to-right; every locale this application ships is LTR.
class BaseShrinkingRow extends MultiChildRenderObjectWidget {
  const BaseShrinkingRow({
    super.key,
    this.spacing = 0,
    this.minChildWidth = 0,
    required super.children,
  });

  /// Horizontal gap between children of nonzero width.
  final double spacing;

  /// The width below which a child is never squeezed. Callers set it to the
  /// widest fixed chrome among their children.
  final double minChildWidth;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderShrinkingRow(spacing: spacing, minChildWidth: minChildWidth);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderShrinkingRow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..minChildWidth = minChildWidth;
  }
}

/// Parent data for [RenderShrinkingRow] children.
class ShrinkingRowParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object of [BaseShrinkingRow]; see the widget for the layout
/// contract.
class RenderShrinkingRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ShrinkingRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ShrinkingRowParentData> {
  RenderShrinkingRow({required double spacing, required double minChildWidth})
    : _spacing = spacing,
      _minChildWidth = minChildWidth;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _minChildWidth;
  double get minChildWidth => _minChildWidth;
  set minChildWidth(double value) {
    if (_minChildWidth == value) return;
    _minChildWidth = value;
    markNeedsLayout();
  }

  /// Whether the floored children exceed the row's own size, in which case
  /// painting clips at the edge instead of running over the neighbors.
  bool _needsClip = false;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ShrinkingRowParentData) {
      child.parentData = ShrinkingRowParentData();
    }
  }

  /// Every child's natural width: what it lays out to when only the height is
  /// constrained.
  List<double> _naturalWidths(BoxConstraints constraints) {
    final childConstraints = BoxConstraints(maxHeight: constraints.maxHeight);
    final widths = <double>[];
    var child = firstChild;
    while (child != null) {
      widths.add(child.getDryLayout(childConstraints).width);
      child = childAfter(child);
    }
    return widths;
  }

  /// The width each child may take: its natural width when everything fits
  /// into [availableWidth], otherwise the smallest ceiling - floored at
  /// [minChildWidth] - that makes the visible children and their gaps fit.
  List<double> _resolveWidths(List<double> natural, double availableWidth) {
    final visible = <double>[
      for (final width in natural)
        if (width > 0) width,
    ];
    if (visible.isEmpty) return natural;

    final budget = availableWidth - spacing * (visible.length - 1);
    final total = visible.fold<double>(0, (sum, width) => sum + width);
    if (total <= budget) return natural;

    // Water filling: let the narrowest children keep their natural width and
    // find the ceiling the remaining ones share.
    final ascending = [...visible]..sort();
    var ceiling = minChildWidth;
    var kept = 0.0;
    for (var index = 0; index < ascending.length; index++) {
      final candidate = (budget - kept) / (ascending.length - index);
      if (candidate <= ascending[index]) {
        ceiling = candidate;
        break;
      }
      kept += ascending[index];
    }
    ceiling = math.max(ceiling, minChildWidth);

    return [
      for (final width in natural) width > 0 ? math.min(width, ceiling) : 0.0,
    ];
  }

  Size _layout(
    BoxConstraints constraints, {
    required ChildLayouter layoutChild,
  }) {
    final widths = _resolveWidths(
      _naturalWidths(constraints),
      constraints.maxWidth,
    );

    var contentWidth = 0.0;
    var contentHeight = 0.0;
    var visibleCount = 0;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      final childSize = layoutChild(
        child,
        BoxConstraints(
          maxWidth: widths[index],
          maxHeight: constraints.maxHeight,
        ),
      );
      if (childSize.width > 0) {
        contentWidth += childSize.width;
        visibleCount += 1;
      }
      contentHeight = math.max(contentHeight, childSize.height);
      child = childAfter(child);
      index += 1;
    }
    if (visibleCount > 1) contentWidth += spacing * (visibleCount - 1);

    return constraints.constrain(Size(contentWidth, contentHeight));
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _layout(
      constraints,
      layoutChild: (child, childConstraints) =>
          child.getDryLayout(childConstraints),
    );
  }

  @override
  void performLayout() {
    size = _layout(
      constraints,
      layoutChild: (child, childConstraints) {
        child.layout(childConstraints, parentUsesSize: true);
        return child.size;
      },
    );

    // Position pass: children sit left to right, vertically centered, with a
    // gap only after a visible child.
    var x = 0.0;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as ShrinkingRowParentData;
      parentData.offset = Offset(x, (size.height - child.size.height) / 2);
      if (child.size.width > 0) x += child.size.width + spacing;
      child = childAfter(child);
    }
    final contentWidth = x == 0 ? 0.0 : x - spacing;
    // A hair of tolerance so floating-point noise cannot force a clip layer.
    _needsClip = contentWidth > size.width + 0.01;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_needsClip) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        defaultPaint,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    // The row can squeeze every visible child down to [minChildWidth]; a child
    // naturally narrower than that keeps its natural width.
    var total = 0.0;
    var visibleCount = 0;
    var child = firstChild;
    while (child != null) {
      final natural = child.getMaxIntrinsicWidth(height);
      if (natural > 0) {
        total += math.min(natural, minChildWidth);
        visibleCount += 1;
      }
      child = childAfter(child);
    }
    if (visibleCount > 1) total += spacing * (visibleCount - 1);
    return total;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var total = 0.0;
    var visibleCount = 0;
    var child = firstChild;
    while (child != null) {
      final natural = child.getMaxIntrinsicWidth(height);
      if (natural > 0) {
        total += natural;
        visibleCount += 1;
      }
      child = childAfter(child);
    }
    if (visibleCount > 1) total += spacing * (visibleCount - 1);
    return total;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      height = math.max(height, child.getMinIntrinsicHeight(width));
      child = childAfter(child);
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      height = math.max(height, child.getMaxIntrinsicHeight(width));
      child = childAfter(child);
    }
    return height;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }
}
