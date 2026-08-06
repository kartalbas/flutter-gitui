import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controllers/item_navigation_controller.dart';
import '../utils/keyboard_guards.dart';

/// Lets a single-line search field drive its result collection: ArrowUp/Down
/// move the collection's roving highlight and Enter activates the highlighted
/// item, while the caret — and every key the field itself interprets — stays
/// in the field. Filtering and choosing become one keyboard flow, the pattern
/// proven in the hosted-repository picker, expressed through the shared
/// [ItemNavigationController] instead of a per-screen `Shortcuts` map.
///
/// The mechanism is a non-focusable, skip-traversal [Focus] wrapped around
/// the field: key events bubble outward from the focused editable, so the
/// handoff only ever sees keys typed into its own subtree. It acts solely
/// when an editable holds the focus (a focused clear button keeps its Enter),
/// yields every key the editable interprets via [focusedEditableOwnsKey]
/// (characters, Backspace, caret movement — and everything, in a multiline
/// field), and ignores modified chords, which belong to app-level shortcuts.
class SearchFieldHandoff extends StatelessWidget {
  const SearchFieldHandoff({
    super.key,
    required this.controller,
    required this.child,
  });

  /// The collection the field filters; arrows and Enter are forwarded to it.
  final ItemNavigationController controller;

  /// The search field (or a subtree containing it).
  final Widget child;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    // A key the focused editable acts on itself is never taken from it.
    if (focusedEditableOwnsKey(event)) return KeyEventResult.ignored;

    // Only a focused editable hands off; when focus sits on another control
    // inside the wrapped subtree (the field's clear button), that control
    // keeps all of its keys.
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.findAncestorStateOfType<EditableTextState>() == null) {
      return KeyEventResult.ignored;
    }

    // Modified chords belong to someone else (app-level shortcuts).
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      controller.moveUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      controller.moveDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // Repeats are consumed but only the press activates: holding Enter must
      // not fire the highlighted item's action once per repeat tick.
      if (event is KeyDownEvent) {
        controller.activate();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      debugLabel: 'SearchFieldHandoff',
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: child,
    );
  }
}
