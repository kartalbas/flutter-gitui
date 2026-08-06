import 'package:flutter/widgets.dart';

/// The keyboard semantics of every item collection, defined once.
///
/// Arrows move a roving highlight, Home/End jump to the edges, Enter/Space
/// activate the highlighted item. A grid sets [crossAxisCount] so ArrowUp/Down
/// move by whole rows while ArrowLeft/Right step through the flattened order.
/// Pushing down or right past the last item does not move; it calls
/// [onTrailingBoundary] instead, which is where a windowed list hangs its
/// "load more".
///
/// Selection is pluggable. By default the controller stores the highlighted
/// index itself (internal mode). A screen whose selection lives elsewhere — a
/// provider, for history's commit selection — passes [readIndex]/[writeIndex]
/// and the controller stores nothing: every read asks, every move writes
/// (delegated mode).
///
/// The controller owns the collection's single [focusNode] so the whole
/// collection is one Tab stop; [KeyboardNavigableListView]/[GridView]/
/// [TreeView] host it and translate key events into these methods.
class ItemNavigationController extends ChangeNotifier {
  ItemNavigationController({
    this.crossAxisCount = 1,
    this.onActivate,
    this.onTrailingBoundary,
    int Function()? readIndex,
    void Function(int index)? writeIndex,
  }) : assert(crossAxisCount >= 1, 'crossAxisCount must be at least 1'),
       assert(
         (readIndex == null) == (writeIndex == null),
         'readIndex and writeIndex delegate selection together: '
         'provide both or neither',
       ),
       _readIndex = readIndex,
       _writeIndex = writeIndex;

  /// Items per row. 1 is a list or tree; a grid sets its column count so
  /// vertical arrows move by whole rows.
  final int crossAxisCount;

  /// The highlighted item's action, fired by Enter or Space (and by nothing
  /// else — a collection with no activation semantics leaves it null).
  final void Function(int index)? onActivate;

  /// Called instead of moving when navigation pushes past the last item:
  /// ArrowDown on the last row, ArrowRight on the last item, End when the
  /// last item is already highlighted. A windowed list loads its next page
  /// here; everyone else leaves it null and the edge is simply firm.
  final VoidCallback? onTrailingBoundary;

  final int Function()? _readIndex;
  final void Function(int index)? _writeIndex;

  /// The collection's one focus node: the whole collection is a single Tab
  /// stop and the highlight roves inside it. Hosted by the navigable view.
  final FocusNode focusNode = FocusNode(debugLabel: 'ItemNavigationController');

  int _internalIndex = -1;
  int _itemCount = 0;

  /// Whether selection lives outside the controller (readIndex/writeIndex).
  bool get isDelegated => _readIndex != null;

  /// Number of items navigated over. The hosting view keeps this in sync;
  /// subclasses that derive it (the tree from its flattened rows) override
  /// the getter.
  int get itemCount => _itemCount;

  set itemCount(int value) {
    assert(value >= 0, 'itemCount cannot be negative');
    _itemCount = value;
    // Internal selection must not dangle past a shrunken collection. Delegated
    // selection is validated by its owner. Deliberately no notification: the
    // count is set during the hosting view's build.
    if (_writeIndex == null && _internalIndex >= value) {
      _internalIndex = value - 1;
    }
  }

  /// The highlighted index, or -1 for none.
  int get selectedIndex => _readIndex?.call() ?? _internalIndex;

  /// Whether [index] is the highlighted item.
  bool isSelected(int index) => index == selectedIndex;

  /// Internal-mode backing index, for subclasses that manage selection
  /// through their own lifecycle (the tree revalidates it on every reflatten).
  /// Writes do not notify; the subclass decides when listeners hear about it.
  @protected
  int get internalSelectedIndex => _internalIndex;

  @protected
  set internalSelectedIndex(int value) {
    assert(
      _writeIndex == null,
      'internalSelectedIndex is meaningless in delegated mode',
    );
    _internalIndex = value;
  }

  /// Whether the highlight may rest on [index]. Navigation skips indices this
  /// rejects, in the direction of travel. The tree overrides it to skip
  /// directories when configured to.
  @protected
  bool isIndexSelectable(int index) => true;

  /// Called after navigation or [select] moved the highlight to [index],
  /// before listeners are notified. Subclasses add their follow-through here
  /// (the tree scrolls the row into view and reports the selected node).
  @protected
  void didSelect(int index) {}

  /// ArrowUp: previous item, or the previous row in a grid.
  void moveUp() => _moveBy(-crossAxisCount);

  /// ArrowDown: next item, or the next row in a grid. At the trailing edge it
  /// fires [onTrailingBoundary] instead of moving.
  void moveDown() => _moveBy(crossAxisCount);

  /// ArrowLeft in a grid: one step back through the flattened order.
  void moveLeft() => _moveBy(-1);

  /// ArrowRight in a grid: one step forward through the flattened order. At
  /// the trailing edge it fires [onTrailingBoundary] instead of moving.
  void moveRight() => _moveBy(1);

  /// Home: the first selectable item.
  void moveToFirst() {
    final target = _firstSelectable();
    if (target < 0 || target == selectedIndex) return;
    _applyMove(target);
  }

  /// End: the last selectable item. When it is already highlighted the user
  /// is pushing against the trailing edge, so [onTrailingBoundary] fires.
  void moveToLast() {
    final count = itemCount;
    var target = count - 1;
    while (target >= 0 && !isIndexSelectable(target)) {
      target--;
    }
    if (target < 0) return;
    if (target == selectedIndex) {
      onTrailingBoundary?.call();
      return;
    }
    _applyMove(target);
  }

  /// Enter/Space: fire [onActivate] for the highlighted item.
  void activate() {
    final index = selectedIndex;
    if (index < 0 || index >= itemCount) return;
    if (!isIndexSelectable(index)) return;
    onActivate?.call(index);
  }

  /// Programmatic selection, used by tap handlers. Accepts -1 to clear.
  /// Out-of-range indices and re-selecting the current item are no-ops.
  void select(int index) {
    if (index < -1 || index >= itemCount) return;
    if (index == selectedIndex) return;
    _applyMove(index);
  }

  /// Focus the collection (its single Tab stop).
  void requestFocus() => focusNode.requestFocus();

  void _moveBy(int stride) {
    final count = itemCount;
    if (count == 0) return;

    final current = selectedIndex;
    if (current < 0 || current >= count) {
      // Moving into an unselected collection highlights the first item,
      // whichever direction was pressed.
      moveToFirst();
      return;
    }

    var target = current + stride;

    if (stride > 0 && target >= count) {
      // A grid row above a shorter last row still has items below it, just
      // not in this column: land on the last item. A push from the last row
      // itself is the trailing boundary.
      final lastRowStart = ((count - 1) ~/ crossAxisCount) * crossAxisCount;
      if (stride == crossAxisCount &&
          crossAxisCount > 1 &&
          current < lastRowStart) {
        if (!isIndexSelectable(count - 1)) return;
        _applyMove(count - 1);
        return;
      }
      onTrailingBoundary?.call();
      return;
    }

    if (target < 0) return; // Leading edge: firm, no hook.

    // Skip unselectable items in the direction of travel, by the same stride
    // so a grid stays in its column. Running out of items while only
    // unselectable ones remain is not a boundary: items exist, they just
    // cannot hold the highlight.
    while (target >= 0 && target < count && !isIndexSelectable(target)) {
      target += stride;
    }
    if (target < 0 || target >= count) return;
    _applyMove(target);
  }

  int _firstSelectable() {
    final count = itemCount;
    var target = 0;
    while (target < count && !isIndexSelectable(target)) {
      target++;
    }
    return target < count ? target : -1;
  }

  void _applyMove(int index) {
    final write = _writeIndex;
    if (write != null) {
      write(index);
    } else {
      _internalIndex = index;
    }
    didSelect(index);
    notifyListeners();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}
