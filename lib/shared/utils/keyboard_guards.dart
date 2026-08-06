import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keys a focused editable interprets no matter how many lines it has.
///
/// Backspace/Delete edit, ArrowLeft/Right move the caret, Home/End jump
/// within the line. Stealing any of these while the user is typing breaks
/// the field.
final Set<LogicalKeyboardKey> _keysEditablesAlwaysOwn = <LogicalKeyboardKey>{
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.delete,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
};

/// Keys only a multiline editable interprets.
///
/// In a single-line field ArrowUp/Down have no caret to move and Enter has no
/// newline to insert, so a surrounding handler may claim them; in a multiline
/// field they move between lines and insert newlines and must stay with the
/// field.
final Set<LogicalKeyboardKey> _keysMultilineEditablesOwn = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
};

/// Whether the editable text field holding primary focus interprets [event]
/// itself, so no surrounding key handler may consume it.
///
/// This is the single guard every app-level binding of an unmodified key must
/// route through: the navigable collection views, a search field's list
/// handoff, and the dismiss scopes. It returns true when primary focus sits
/// inside an [EditableTextState] and the key is one the editable acts on —
/// any character-producing key, plus Backspace/Delete, ArrowLeft/Right and
/// Home/End always, plus ArrowUp/Down and Enter in a multiline field only.
/// With no editable focused it always returns false, and keys an editable
/// ignores (Escape, Tab, function keys) fall through regardless.
///
/// (EditableText attaches its focus node to a Focus widget inside its own
/// subtree, so the editable is found as an ancestor of the focused context.)
bool focusedEditableOwnsKey(KeyEvent event) {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  final editable = focusContext?.findAncestorStateOfType<EditableTextState>();
  if (editable == null) return false;

  // A key that produces text belongs to the field. Control codes are filtered
  // out because platforms report Enter as '\r', Tab as '\t' and similar: those
  // are decided by the named-key rules below, not by their character payload.
  final character = event.character;
  if (character != null &&
      character.isNotEmpty &&
      !character.codeUnits.every((unit) => unit < 0x20 || unit == 0x7F)) {
    return true;
  }

  final key = event.logicalKey;
  if (_keysEditablesAlwaysOwn.contains(key)) return true;

  final isMultiline = editable.widget.maxLines != 1;
  return isMultiline && _keysMultilineEditablesOwn.contains(key);
}
