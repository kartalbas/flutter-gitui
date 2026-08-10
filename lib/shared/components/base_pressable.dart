import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The application's way of saying "this region can be acted on".
///
/// **This is a façade** (#249, §2.11): the body is one delegation to
/// `surfaces.pressable`, and what an `InkWell` used to decide here is the
/// skin's — whether the response is a ripple at all, which direction the
/// surface moves under the pointer, how focus is drawn, and what the region
/// looks like once it is picked.
///
/// The direction matters more than it sounds: Material *lightens* under a
/// press and Fluent *darkens*, so a hand-drawn response is not merely a
/// different shade but a different statement, and a Material ripple in a macOS
/// window is wrong on sight rather than merely unfamiliar. That is exactly the
/// kind of thing the application cannot know and must not guess.
///
/// **One trap this façade exists to prevent.** An `InkWell`'s state layers are
/// painted by the nearest `Material` ANCESTOR, underneath everything the well
/// wraps — so wrapping an opaque fill hides them completely. Every switcher in
/// the toolbar had no visible hover, focus or press feedback for exactly that
/// reason, and nobody noticed until a corner was found stated twice (#420).
/// A member cannot make that mistake: it owns the fill and the response
/// together, so they cannot be layered in the wrong order.
///
/// What stays with the caller is what the application knows: what the region
/// does when chosen, opened or asked for its menu; whether it is currently
/// picked; whether it may be acted on at all; and what it does, in words, for
/// someone who cannot tell by looking.
class BasePressable extends StatelessWidget {
  /// What the user is acting on.
  final Widget child;

  /// What happens when it is chosen.
  final VoidCallback? onTap;

  /// What happens when it is opened.
  final VoidCallback? onDoubleTap;

  /// What happens when the user asks for its menu, at the point they asked.
  final ValueChanged<Offset>? onContextMenu;

  /// Whether it is currently picked.
  final bool selected;

  /// Whether it may be acted on at all.
  final bool enabled;

  /// What it does, for the pointer — required in spirit on a region whose
  /// purpose is not obvious from its content.
  final String? tooltip;

  const BasePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onContextMenu,
    this.selected = false,
    this.enabled = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) =>
      SkinScope.render(context, (Skin skin, BuildContext inner) {
        return skin.surfaces.pressable(
          inner,
          PressableSpec(
            child: ContentPort(child),
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onContextMenu: onContextMenu,
            selected: selected,
            enabled: enabled,
            tooltip: tooltip,
          ),
        );
      });
}
