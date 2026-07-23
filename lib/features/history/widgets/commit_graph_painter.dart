import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/commit_graph.dart';

/// Paints one commit row's slice of the graph: the dot, the edges into and
/// out of it, and the lanes passing by.
///
/// The painter spans the whole list item, divider strip included, so each
/// row's lane segments meet the neighboring rows' edge to edge; a painter
/// confined to the leading widget would leave a gap at every divider.
class CommitGraphRowPainter extends CustomPainter {
  const CommitGraphRowPainter({required this.row});

  final CommitGraphRow row;

  static const double _laneWidth = 12.0;

  /// A pathological window can need dozens of lanes; capping the rendered
  /// columns keeps the graph from crowding out the subject text. Columns
  /// beyond the cap pin to the last one, which merely overlaps their lines.
  static const int _maxRenderedLanes = 8;

  static const double _dotRadius = 4.0;
  static const double _strokeWidth = 2.0;

  /// The strip BaseListItem appends below its content for the divider. The
  /// dot must center on the content, not on content plus divider.
  static const double _dividerStrip = AppTheme.paddingS + 1.0;

  /// Width the leading slot reserves so the graph and the text never overlap.
  static double leadingWidthFor(int laneCount) =>
      _laneWidth * laneCount.clamp(1, _maxRenderedLanes);

  static double _laneX(int lane) =>
      AppTheme.paddingL +
      _laneWidth * (lane.clamp(0, _maxRenderedLanes - 1) + 0.5);

  static Color _laneColor(int colorIndex) =>
      AppTheme.commitGraphLaneColors[colorIndex %
          AppTheme.commitGraphLaneColors.length];

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = (size.height - _dividerStrip) / 2;
    final dotX = _laneX(row.lane);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final edge in row.passing) {
      final x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.colorIndex);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
    }

    for (final edge in row.incoming) {
      final x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.colorIndex);
      final path = Path()..moveTo(x, 0);
      if (x == dotX) {
        path.lineTo(dotX, centerY);
      } else {
        path.quadraticBezierTo(x, centerY, dotX, centerY);
      }
      canvas.drawPath(path, stroke);
    }

    for (final edge in row.outgoing) {
      final x = _laneX(edge.lane);
      stroke.color = _laneColor(edge.colorIndex);
      final path = Path()..moveTo(dotX, centerY);
      if (x == dotX) {
        path.lineTo(dotX, size.height);
      } else {
        path.quadraticBezierTo(x, centerY, x, size.height);
      }
      canvas.drawPath(path, stroke);
    }

    // A ring instead of a filled dot is what keeps a merge readable at a
    // glance even where the joining edge is only a few pixels long.
    final dotPaint = Paint()..color = _laneColor(row.colorIndex);
    if (row.isMerge) {
      dotPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
    }
    canvas.drawCircle(Offset(dotX, centerY), _dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(CommitGraphRowPainter oldDelegate) =>
      !identical(oldDelegate.row, row);
}
