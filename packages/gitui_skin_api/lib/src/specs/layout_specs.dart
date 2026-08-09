import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../vocabulary.dart';

/// A collection of equal things laid out in as many columns as fit.
///
/// [onColumnsChanged] is the one place in the whole contract where a member
/// reports STRUCTURE back to the application, and it is there because the
/// keyboard controller needs it: an up or down arrow in a card grid must move
/// by a whole row, which takes the column count. Today the screen re-implements
/// the delegate's own formula to get it; once the skin owns the geometry the
/// application cannot compute it at all, so the member must report it. It
/// carries no design value - it is a count of columns.
///
/// The member owns its scroll view and deliberately says nothing about it
/// (#438). A viewport inset is the skin's own rhythm around its own scroll
/// view - an application word for it would be a design decision wearing a
/// neutral name. A scroll position ("keep tile N visible") is promisable in
/// principle, but no site states it and the shipped grids never scrolled the
/// highlight into view, so a slot for it would be a control that silently
/// does nothing - the exact drift the blueprint exists to falsify. Both stay
/// out until a live floor asks for them.
@immutable
final class GridSpec {
  /// Declares one grid.
  const GridSpec({
    required this.children,
    this.density = GridDensity.normal,
    this.tileHeight = TileHeight.language,
    this.onColumnsChanged,
  });

  /// The things, in order.
  ///
  /// A materialised list, deliberately (#438): a windowed or lazily-built
  /// grid cannot be asked for here, and that is not a gap. Windowing has no
  /// design voice - every language would answer it identically and no
  /// instrument could tell an eager skin from a lazy one - so it is a
  /// property of the host toolkit's scroll machinery, not a contract word.
  /// Only the widget objects are eager either way; what a skin elements and
  /// paints remains its own business.
  final List<ContentPort> children;

  /// How tightly packed the user wants them.
  final GridDensity density;

  /// Who owns a tile's height: the language's own proportion, or the content
  /// standing at exactly the room it needs.
  final TileHeight tileHeight;

  /// How to tell the application how many columns it ended up with, so its
  /// keyboard navigation can move by rows.
  final ValueChanged<int>? onColumnsChanged;
}

/// Two regions side by side, with a boundary the user can move.
///
/// The stored fraction is USER STATE and crosses the seam the same way a
/// shell's selected index does. The handle's width, its hit slop, its cursor,
/// its hairline and the limits it clamps to are all the skin's - which is
/// exactly the pile of numbers a screen builds by hand today.
@immutable
final class SplitPaneSpec {
  /// Declares one split.
  const SplitPaneSpec({
    required this.primary,
    required this.secondary,
    required this.axis,
    required this.fraction,
    required this.resizableSide,
    this.onFractionChanged,
  });

  /// The region that comes first in reading order.
  final ContentPort primary;

  /// The region that comes second.
  final ContentPort secondary;

  /// Whether they sit beside or above one another. Structure: it is what the
  /// screen IS, and the blueprint must honour it exactly.
  final Axis axis;

  /// How the space is currently divided, from 0 to 1.
  final double fraction;

  /// Which half the user drags. Carried because macOS's `ResizablePane`
  /// requires it, and because the answer is a fact about this layout rather
  /// than a look.
  final PaneSide resizableSide;

  /// How to tell the application the user moved the boundary. Null means the
  /// division is fixed.
  final ValueChanged<double>? onFractionChanged;
}

/// One label-and-value pair.
@immutable
final class PropertyRow {
  /// Declares one pair.
  const PropertyRow({required this.label, required this.value});

  /// What the value is called - WITHOUT a colon, because the colon is
  /// typography and belongs to the skin.
  final String label;

  /// The value itself.
  final ContentPort value;
}

/// A run of label-and-value pairs whose labels line up.
///
/// The member is at the SET rather than at the row because the alignment is a
/// property of the set: the label column sizes to the longest label, and the
/// existing implementation's own comment records why a fixed width cannot
/// work - the same labels are longer in every other locale.
@immutable
final class PropertyListSpec {
  /// Declares one property list.
  const PropertyListSpec({required this.rows});

  /// The pairs, in reading order.
  final List<PropertyRow> rows;
}
