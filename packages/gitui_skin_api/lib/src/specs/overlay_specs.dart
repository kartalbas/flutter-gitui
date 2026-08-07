import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../vocabulary.dart';

/// One entry in a menu, expressed as data rather than as a widget.
///
/// A menu is where the three languages disagree not about styling but about
/// TYPE. Fluent's `MenuFlyout` takes `List<MenuFlyoutItemBase>`, which is not
/// even a `Widget`, so no adapter reaches it from a list of Material entries -
/// that failure is harmless because it does not compile. The failure that
/// SHIPS is the other one: a `List<Widget>` compiles cleanly into a foreign
/// menu and then renders Material rows, Material ink and Material typography
/// inside it, with none of the host language's dividers, destructive treatment
/// or dismissal behaviour.
///
/// Sealed so every skin can switch over it exhaustively: a new kind of entry
/// becomes a compile error in each skin rather than an entry that silently
/// renders as nothing.
sealed class MenuEntry {
  /// Const base constructor for the sealed set.
  const MenuEntry();
}

/// A rule drawn between two groups of entries, carrying no action of its own.
///
/// Its own kind rather than a flag, because it is not one: a separator has no
/// words, no mark and nothing to invoke, and every language draws it with its
/// own dedicated element.
final class MenuSeparator extends MenuEntry {
  /// Declares one separator.
  const MenuSeparator();
}

/// A heading naming the run of entries below it.
///
/// It exists because the application already renders one - a disabled item
/// holding a small label in a muted role - and a shape the sealed set cannot
/// carry is a shape the application keeps painting itself.
final class MenuSection extends MenuEntry {
  /// Declares one heading.
  const MenuSection(this.label);

  /// What the run below is about.
  final String label;
}

/// One invokable entry in a menu.
final class MenuAction extends MenuEntry {
  /// Declares one entry.
  const MenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.role = MenuActionRole.normal,
    this.enabled = true,
  });

  /// The entry's words, and its accessible name.
  final String label;

  /// The entry's mark. Required rather than optional because every menu in
  /// this application is mark-led, and a single markless row inside an
  /// otherwise aligned column reads as a rendering fault.
  final IconRole icon;

  /// What the entry does. Null disables it.
  final VoidCallback? onPressed;

  /// What the entry means.
  final MenuActionRole role;

  /// Whether the entry may be invoked right now. Distinct from a null
  /// [onPressed] only in how it reads at the call site: an entry that is
  /// present but temporarily unavailable says so, and stays in the menu with
  /// its reason visible rather than disappearing from it.
  final bool enabled;

  /// The resolved answer to "can the user invoke this now".
  bool get isEnabled => enabled && onPressed != null;
}

/// An entry that states a fact the user can flip.
///
/// A separate kind rather than a flag on [MenuAction] because it answers a
/// different question - "is this on" rather than "do this" - and the
/// application already renders three of them by hand today.
final class MenuCheckable extends MenuEntry {
  /// Declares one checkable entry.
  const MenuCheckable({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.icon,
    this.enabled = true,
  });

  /// The fact, in words.
  final String label;

  /// Whether it currently holds.
  final bool checked;

  /// How to tell the application the user flipped it. Null disables the entry.
  final ValueChanged<bool>? onChanged;

  /// An optional leading mark. Optional here, unlike on [MenuAction], because
  /// the check state is already the row's leading signal.
  final IconRole? icon;

  /// Whether the entry may be flipped right now.
  final bool enabled;

  /// The resolved answer to "can the user flip this now".
  bool get isEnabled => enabled && onChanged != null;
}

/// Something the user can do from a notice or a banner.
@immutable
final class NoticeAction {
  /// Declares one action.
  const NoticeAction({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.icon,
  });

  /// The action's words.
  final String label;

  /// What it does, for the pointer and for a screen reader. Required because a
  /// notice may be rendered mark-only in a status area that has no room for
  /// words, and an unnamed mark is not an accessible control.
  final String tooltip;

  /// What happens when it is used.
  final VoidCallback onPressed;

  /// An optional mark.
  final IconRole? icon;
}

/// What a transient notice says.
///
/// The actions and the lifetime are not speculation about a future
/// notification centre: `notification_service` already attaches an action to
/// an error notice and already sets a 365-day duration on it, so a spec
/// without these fields would lose shipped behaviour the moment the contract
/// landed.
@immutable
final class NoticeSpec {
  /// Declares one notice.
  const NoticeSpec({
    required this.tone,
    required this.title,
    this.body,
    this.icon,
    this.actions = const <NoticeAction>[],
    this.lifetime = NoticeLifetime.brief,
  });

  /// What it means.
  final Tone tone;

  /// The statement.
  final String title;

  /// The longer form, where the language has room for one.
  final String? body;

  /// A mark beside it.
  final IconRole? icon;

  /// What the user can do about it.
  final List<NoticeAction> actions;

  /// Whether it is allowed to go away on its own.
  final NoticeLifetime lifetime;
}

/// A live notice, as an opaque handle.
///
/// It carries no design value, and the only two things it can do are the two
/// the application already does today: `notification_service` calls
/// `clearSnackBars()` and `hideCurrentSnackBar()` to stop a never-dismissing
/// error notice queueing behind another. Returning `void` from `notify` would
/// have been a regression against shipped behaviour, not a deferred feature.
abstract interface class NoticeHandle {
  /// Takes the notice away now.
  void dismiss();

  /// Whether it is still on screen.
  bool get isShowing;
}

/// What a popover is, and what it belongs to.
///
/// A popover is content attached to the control the user just operated. WHERE
/// it goes, how it is anchored and what its edge looks like are the skin's
/// answers; the application states only what the content is for and whether it
/// is a continuation of the control that opened it.
@immutable
final class PopoverSpec {
  /// Declares one popover.
  const PopoverSpec({
    required this.semanticsLabel,
    this.continuesAnchor = false,
    this.barrierDismissible = true,
  });

  /// What this popover is, for a screen reader. Required because a popover has
  /// no title bar to name it.
  final String semanticsLabel;

  /// Whether the popover is a continuation of the control that opened it - a
  /// suggestion list under a field - rather than a surface of its own.
  ///
  /// A statement of relationship, not of width: it is what lets a skin decide
  /// to match the anchor's measurements, and it is the only thing the
  /// application knows about that relationship.
  final bool continuesAnchor;

  /// Whether clicking outside closes it.
  final bool barrierDismissible;
}
