import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ContentPort, GridDensity, GridSpec, Skin, SkinScope, TileHeight;

import '../controllers/item_navigation_controller.dart';
import '../controllers/tree_view_controller.dart';
import '../models/tree_node.dart';
import '../utils/keyboard_guards.dart';

/// Builds one item of a navigable list or grid. [isSelected] marks the roving
/// highlight; [containerHasFocus] says whether the collection itself holds
/// keyboard focus, so the item can render a focus ring versus a muted
/// highlight.
typedef NavigableItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      bool isSelected,
      bool containerHasFocus,
    );

/// Builds one row of a navigable tree. Same contract as [NavigableItemBuilder]
/// with the flattened node and its depth resolved for the caller.
typedef NavigableTreeItemBuilder<T extends TreeNodeMixin> =
    Widget Function(
      BuildContext context,
      T node,
      int depth,
      bool isSelected,
      bool containerHasFocus,
    );

/// Function keys never collide with text input or with the shared navigation
/// semantics, so an extra binding may always claim them. The dedicated menu
/// key behaves like one: no editable interprets it and navigation never maps
/// it, so a collection may bind its context menu to it bare.
final Set<LogicalKeyboardKey> _functionKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
  LogicalKeyboardKey.contextMenu,
};

/// Editing keys an extra binding may claim unmodified. They are not part of
/// the shared navigation semantics, and a focused editable cannot lose them
/// either: [_CollectionFocusState._onKeyEvent] consults
/// [focusedEditableOwnsKey] before any binding runs, and that guard always
/// keeps Backspace and Delete with an editable. With no editable focused the
/// keys are genuinely free — and bare Delete on a focused file tree is the
/// established desktop behaviour (Explorer and Finder both delete on it), so
/// it must not be exiled to a chord.
final Set<LogicalKeyboardKey> _editingKeysTheGuardClears = <LogicalKeyboardKey>{
  LogicalKeyboardKey.delete,
  LogicalKeyboardKey.backspace,
};

bool _bindingsAvoidReservedKeys(Map<SingleActivator, VoidCallback>? bindings) {
  if (bindings == null) return true;
  return bindings.keys.every(
    (activator) =>
        activator.control ||
        activator.alt ||
        activator.meta ||
        _functionKeys.contains(activator.trigger) ||
        _editingKeysTheGuardClears.contains(activator.trigger),
  );
}

const String _bindingsAssertMessage =
    'additionalBindings may only bind modified (Ctrl/Alt/Meta), function or '
    'menu keys, plus bare Delete/Backspace, which the editable guard clears '
    'before any binding runs. Other unmodified keys belong to the shared '
    'navigation semantics or to a focused editable; binding them here would '
    'shadow one or the other.';

/// A scrollable list that is one Tab stop with a roving highlight.
///
/// The collection owns a single focus node (the controller's), so Tab enters
/// it once and leaves it once; arrows, Home/End and Enter/Space move and
/// activate through [ItemNavigationController]. Key handling lives on that
/// node only — it can never capture keys for sibling panels, and it yields any
/// key a focused editable interprets (see [focusedEditableOwnsKey]).
class KeyboardNavigableListView extends StatefulWidget {
  KeyboardNavigableListView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent,
    this.autofocus = false,
    this.additionalBindings,
    this.padding,
    this.trailing,
  }) : assert(
         _bindingsAvoidReservedKeys(additionalBindings),
         _bindingsAssertMessage,
       );

  /// The shared navigation semantics; also owns the collection's focus node.
  final ItemNavigationController controller;

  /// Number of items. The view keeps the controller's count in sync.
  final int itemCount;

  /// Builds each item; see [NavigableItemBuilder].
  final NavigableItemBuilder itemBuilder;

  /// Fixed main-axis extent per item. Enables keeping the highlight scrolled
  /// into view (and fixed-extent layout); without it the view does not
  /// auto-scroll.
  final double? itemExtent;

  /// Whether this collection claims initial focus. A screen has exactly one
  /// autofocus; the default keeps a second collection from racing for it.
  final bool autofocus;

  /// Extra shortcuts scoped to the collection, restricted to modified or
  /// function keys plus bare Delete/Backspace — other unmodified keys belong
  /// to navigation or a focused editable.
  final Map<SingleActivator, VoidCallback>? additionalBindings;

  /// Padding for the scroll view.
  final EdgeInsetsGeometry? padding;

  /// One extra row rendered after the items, scrolling with them but outside
  /// the navigation: the highlight never rests on it and [itemCount] does not
  /// include it. This is where a windowed list puts its load-more footer —
  /// the row's own controls stay ordinary focusable widgets.
  final Widget? trailing;

  @override
  State<KeyboardNavigableListView> createState() =>
      _KeyboardNavigableListViewState();
}

class _KeyboardNavigableListViewState extends State<KeyboardNavigableListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_keepSelectionVisible);
  }

  @override
  void didUpdateWidget(KeyboardNavigableListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_keepSelectionVisible);
      widget.controller.addListener(_keepSelectionVisible);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_keepSelectionVisible);
    _scrollController.dispose();
    super.dispose();
  }

  void _keepSelectionVisible() {
    _scrollRowIntoView(
      scrollController: _scrollController,
      row: widget.controller.selectedIndex,
      rowExtent: widget.itemExtent,
    );
  }

  KeyEventResult _handleNavigationKey(KeyEvent event) {
    return _handleLinearNavigationKey(event, widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.itemCount = widget.itemCount;
    return _CollectionFocus(
      controller: widget.controller,
      autofocus: widget.autofocus,
      additionalBindings: widget.additionalBindings,
      handleNavigationKey: _handleNavigationKey,
      builder: (context, hasFocus) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView.builder(
          controller: _scrollController,
          padding: widget.padding,
          // A trailing row of a different height would break the fixed-extent
          // contract, so the extent only applies to the pure-items case.
          itemExtent: widget.trailing == null ? widget.itemExtent : null,
          itemCount: widget.itemCount + (widget.trailing == null ? 0 : 1),
          itemBuilder: (context, index) {
            if (index == widget.itemCount) return widget.trailing!;
            return widget.itemBuilder(
              context,
              index,
              widget.controller.isSelected(index),
              hasFocus,
            );
          },
        ),
      ),
    );
  }
}

/// A scrollable grid that is one Tab stop with a roving highlight.
///
/// Same keyboard contract as [KeyboardNavigableListView]; the controller's
/// [ItemNavigationController.crossAxisCount] makes vertical arrows move by
/// whole rows while ArrowLeft/Right step through the flattened order.
///
/// **The geometry is `layout.grid`'s** (#249 P5). The tile extent, the tile's
/// height, both gutters and the column count used to be a
/// `SliverGridDelegateWithMaxCrossAxisExtent` each hosting screen built by
/// hand — and each screen then re-implemented that delegate's own column-count
/// formula on the side, because [ItemNavigationController.crossAxisCount]
/// needs the answer. Both halves are the member's: the screen states how
/// tightly packed the tiles should sit ([density]) and who owns a tile's
/// height ([tileHeight]), and the member reports the resolved column count
/// back through `GridSpec.onColumnsChanged` — the one place in the whole
/// contract where a member reports STRUCTURE to the application, and it
/// exists precisely for this controller. The measured `gridDelegate` this
/// view carried while `GridSpec` had no word for a tile's height is gone:
/// `TileHeight.content` now states the workspace grid's requirement — the
/// card decides its own room — through the contract (#438).
///
/// What this view keeps is the half that was never a design decision: the
/// single focus node, the key handling, the roving highlight and the per-item
/// `isSelected`/`containerHasFocus` flags.
///
/// Two capabilities left with the P5 migration, because the member owns the
/// scroll view and `GridSpec` deliberately says nothing about it: a `padding`
/// around the viewport and the `rowExtent` that used to keep the highlight
/// scrolled into view. Neither had a caller — both grids passed neither — so
/// nothing on screen changed; `GridSpec`'s class doc records why neither
/// became a contract word (#438).
class KeyboardNavigableGridView extends StatelessWidget {
  KeyboardNavigableGridView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.density = GridDensity.normal,
    this.tileHeight = TileHeight.language,
    this.autofocus = false,
    this.additionalBindings,
  }) : assert(
         _bindingsAvoidReservedKeys(additionalBindings),
         _bindingsAssertMessage,
       );

  /// The shared navigation semantics. Its `crossAxisCount` is written by the
  /// member through `GridSpec.onColumnsChanged`, so it always describes the
  /// columns actually laid out.
  final ItemNavigationController controller;

  /// Number of items. The view keeps the controller's count in sync.
  final int itemCount;

  /// Builds each item; see [NavigableItemBuilder].
  final NavigableItemBuilder itemBuilder;

  /// How tightly packed the tiles should be. The skin turns this into a tile
  /// extent and its gutters.
  final GridDensity density;

  /// Who owns a tile's height: the design language's own proportion, or the
  /// content standing at exactly the room it needs.
  final TileHeight tileHeight;

  /// Whether this collection claims initial focus.
  final bool autofocus;

  /// Extra shortcuts scoped to the collection, restricted to modified or
  /// function keys plus bare Delete/Backspace.
  final Map<SingleActivator, VoidCallback>? additionalBindings;

  KeyEventResult _handleNavigationKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveRight();
      return KeyEventResult.handled;
    }
    return _handleLinearNavigationKey(event, controller);
  }

  @override
  Widget build(BuildContext context) {
    controller.itemCount = itemCount;
    return _CollectionFocus(
      controller: controller,
      autofocus: autofocus,
      additionalBindings: additionalBindings,
      handleNavigationKey: _handleNavigationKey,
      builder: (context, hasFocus) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _body(context, hasFocus),
      ),
    );
  }

  Widget _body(BuildContext context, bool hasFocus) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.layout.grid(
        inner,
        GridSpec(
          density: density,
          tileHeight: tileHeight,
          // The member measures the width and answers with the column count;
          // the controller needs it for ArrowUp/ArrowDown to move by a whole
          // row. The answer arrives after the frame that measured it, which
          // is early enough: no key can be pressed before the grid has been
          // laid out once.
          onColumnsChanged: (int columns) =>
              controller.crossAxisCount = columns,
          children: <ContentPort>[
            for (int index = 0; index < itemCount; index++)
              ContentPort(
                itemBuilder(
                  inner,
                  index,
                  controller.isSelected(index),
                  hasFocus,
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// A tree rendered as a flattened list that is one Tab stop with a roving
/// highlight.
///
/// Movement, Home/End and activation come from [TreeViewController]:
/// ArrowLeft/Right collapse and expand the highlighted directory, Enter/Space
/// toggle it (or fire the file action). The controller also owns the scroll
/// position, so `scrollToSelected` keeps working for programmatic selection.
class KeyboardNavigableTreeView<T extends TreeNodeMixin>
    extends StatelessWidget {
  KeyboardNavigableTreeView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.depthOf,
    this.autofocus = false,
    this.additionalBindings,
    this.padding,
  }) : assert(
         _bindingsAvoidReservedKeys(additionalBindings),
         _bindingsAssertMessage,
       );

  /// The tree's controller: flattened rows, expansion, selection, scrolling.
  final TreeViewController<T> controller;

  /// Builds each visible row; see [NavigableTreeItemBuilder].
  final NavigableTreeItemBuilder<T> itemBuilder;

  /// Resolves a node's indentation depth. Defaults to counting path
  /// separators, which suits repository-relative paths; a tree over absolute
  /// paths passes its own (depth relative to the tree root).
  final int Function(T node)? depthOf;

  /// Whether this collection claims initial focus.
  final bool autofocus;

  /// Extra shortcuts scoped to the collection, restricted to modified or
  /// function keys plus bare Delete/Backspace.
  final Map<SingleActivator, VoidCallback>? additionalBindings;

  /// Padding for the scroll view.
  final EdgeInsetsGeometry? padding;

  int _defaultDepthOf(T node) {
    final forwardSeparators = node.fullPath.split('/').length - 1;
    final windowsSeparators = node.fullPath.split('\\').length - 1;
    return forwardSeparators > windowsSeparators
        ? forwardSeparators
        : windowsSeparators;
  }

  KeyEventResult _handleNavigationKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      controller.navigateUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.navigateDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.collapseSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      controller.expandSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      controller.moveToFirst();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      controller.moveToLast();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      // Repeats are consumed but only the press toggles: holding Enter must
      // not stage a file once per repeat tick.
      if (event is KeyDownEvent) {
        controller.toggleSelectedNode();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final resolveDepth = depthOf ?? _defaultDepthOf;
    return _CollectionFocus(
      controller: controller,
      autofocus: autofocus,
      additionalBindings: additionalBindings,
      handleNavigationKey: _handleNavigationKey,
      builder: (context, hasFocus) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView.builder(
          controller: controller.scrollController,
          padding: padding,
          itemCount: controller.flattenedNodes.length,
          itemBuilder: (context, index) {
            final node = controller.flattenedNodes[index];
            return itemBuilder(
              context,
              node,
              resolveDepth(node),
              controller.isSelected(index),
              hasFocus,
            );
          },
        ),
      ),
    );
  }
}

/// Shared list navigation: vertical arrows, Home/End, Enter/Space. The grid
/// adds horizontal arrows on top; the tree replaces the mapping entirely.
KeyEventResult _handleLinearNavigationKey(
  KeyEvent event,
  ItemNavigationController controller,
) {
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.arrowUp) {
    controller.moveUp();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    controller.moveDown();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.home) {
    controller.moveToFirst();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.end) {
    controller.moveToLast();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space) {
    // Repeats are consumed but only the press activates: holding Enter must
    // not fire the item action once per repeat tick.
    if (event is KeyDownEvent) {
      controller.activate();
    }
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Keeps row [row] of a fixed-extent scroll view inside the viewport, the
/// same arithmetic [TreeViewController.scrollToSelected] uses.
void _scrollRowIntoView({
  required ScrollController scrollController,
  required int row,
  required double? rowExtent,
}) {
  if (rowExtent == null || row < 0 || !scrollController.hasClients) return;

  final position = row * rowExtent;
  final viewportHeight = scrollController.position.viewportDimension;
  final currentScroll = scrollController.offset;

  if (position < currentScroll) {
    scrollController.jumpTo(position);
  } else if (position + rowExtent > currentScroll + viewportHeight) {
    scrollController.jumpTo(position + rowExtent - viewportHeight);
  }
}

/// The one focus node of a navigable collection.
///
/// Hosts the controller's focus node in a single [Focus] widget: the
/// collection is one Tab stop, key handling exists only on this node (never
/// on an ancestor that would also wrap sibling panels), a pointer press
/// anywhere inside claims focus, and every key a focused editable interprets
/// is left alone.
class _CollectionFocus extends StatefulWidget {
  const _CollectionFocus({
    required this.controller,
    required this.autofocus,
    required this.additionalBindings,
    required this.handleNavigationKey,
    required this.builder,
  });

  final ItemNavigationController controller;
  final bool autofocus;
  final Map<SingleActivator, VoidCallback>? additionalBindings;
  final KeyEventResult Function(KeyEvent event) handleNavigationKey;
  final Widget Function(BuildContext context, bool hasFocus) builder;

  @override
  State<_CollectionFocus> createState() => _CollectionFocusState();
}

class _CollectionFocusState extends State<_CollectionFocus> {
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      // A collection fed by async providers mounts frames after its surface
      // settled, by which time a focus-of-last-resort anchor (the region
      // host's skip-traversal node) may already hold focus — and a plain
      // autofocus is then silently discarded. The anchor is by definition
      // the weakest possible claim, so the collection may displace it; a
      // real control the user focused (skipTraversal false) is never
      // stolen from.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = FocusManager.instance.primaryFocus;
        if (current == null ||
            current is FocusScopeNode ||
            current.skipTraversal) {
          widget.controller.requestFocus();
        }
      });
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    // An editable inside the collection (an inline rename, a filter field)
    // keeps every key it interprets.
    if (focusedEditableOwnsKey(event)) return KeyEventResult.ignored;

    final bindings = widget.additionalBindings;
    if (bindings != null) {
      for (final entry in bindings.entries) {
        if (entry.key.accepts(event, HardwareKeyboard.instance)) {
          entry.value();
          return KeyEventResult.handled;
        }
      }
    }

    // Modified chords that no binding claimed belong to someone else
    // (Ctrl+Home, app-level shortcuts); plain navigation must not swallow
    // them just because the trigger key matches.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    return widget.handleNavigationKey(event);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // A press anywhere in the collection makes it the focused Tab stop, so
      // clicking a row and pressing ArrowDown just works.
      onPointerDown: (_) => widget.controller.requestFocus(),
      child: Focus(
        focusNode: widget.controller.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (value) => setState(() => _hasFocus = value),
        onKeyEvent: _onKeyEvent,
        child: widget.builder(context, _hasFocus),
      ),
    );
  }
}
