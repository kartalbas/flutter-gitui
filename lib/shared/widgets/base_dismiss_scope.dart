import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One rule for Escape: dismiss the innermost dismissible surface.
///
/// Each dismissible surface — a dialog, an expanded speed dial, a filled
/// search field, an active mode — wraps itself in a scope and says through
/// [enabled] whether it currently has something to dismiss. The mechanism is a
/// non-focusable, skip-traversal [Focus] whose only job is to watch Escape on
/// the key-bubbling path: an event travels from the focused widget outward, so
/// the innermost enabled scope consumes it first, a disabled scope lets it
/// pass to the next one out, and when nothing is enabled Escape reaches
/// nothing at all. Nesting therefore resolves itself with no registry and no
/// coordination between surfaces.
///
/// The scope never takes focus and is not a Tab stop; it does not change what
/// the user sees or where the keyboard lives, and every key other than an
/// enabled Escape passes through untouched.
class BaseDismissScope extends StatelessWidget {
  const BaseDismissScope({
    super.key,
    required this.enabled,
    required this.onDismiss,
    required this.child,
  });

  /// Whether this surface currently has something to dismiss. A disabled
  /// scope is transparent: Escape travels on to the next scope out.
  final bool enabled;

  /// Dismisses the surface: close, collapse, clear, leave the mode.
  final VoidCallback onDismiss;

  /// The surface the scope guards.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      debugLabel: 'BaseDismissScope',
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!enabled) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.escape) {
          return KeyEventResult.ignored;
        }
        onDismiss();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
