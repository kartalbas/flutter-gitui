import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../vocabulary.dart';
import 'overlay_specs.dart';

/// One entry in a frame's action bar.
///
/// Sealed so a skin can switch over it exhaustively: a new kind of entry
/// becomes a compile error in every skin rather than an entry that silently
/// renders as nothing.
sealed class ToolbarEntry {
  /// Const base constructor for the sealed set.
  const ToolbarEntry();
}

/// Something the user can do from the bar.
final class ToolbarActionEntry extends ToolbarEntry {
  /// Declares one action.
  const ToolbarActionEntry({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.emphasis = Emphasis.secondary,
    this.badgeCount,
  });

  /// The action's mark.
  final IconRole icon;

  /// The action's words, shown wherever a glyph alone would be a guess -
  /// which is exactly what happens once the skin sheds it into an overflow
  /// menu.
  final String label;

  /// What the action does, named for the pointer and for a screen reader. It
  /// also carries the REASON when the action is unavailable, which is why it
  /// is required rather than optional.
  final String tooltip;

  /// Null disables the action. It stays visible either way, because a bar that
  /// silently drops what it cannot do explains nothing.
  final VoidCallback? onPressed;

  /// How loudly this action asks to be used.
  final Emphasis emphasis;

  /// A count riding on the action, or null.
  final int? badgeCount;
}

/// A control that NAMES the thing the other controls act on.
///
/// The four switchers - workspace, repository, branch, global branch - are not
/// actions, and every language puts them somewhere different. Data rather than
/// a pre-built `Widget` because a pre-built control can never become either
/// canonical answer: `MacosPulldownButton` asserts title XOR icon, and
/// `CommandBarBuilderItem` can only wrap another `CommandBarItem`.
final class ToolbarPickerEntry extends ToolbarEntry {
  /// Declares one picker.
  const ToolbarPickerEntry({
    required this.label,
    required this.value,
    required this.icon,
    required this.entries,
    this.tooltip,
    this.emptyLabel,
  });

  /// What kind of thing is being named: "Repository", "Branch".
  final String label;

  /// Which one is named right now.
  final String value;

  /// The mark for the kind of thing.
  final IconRole icon;

  /// What else could be named. Data, so the skin builds its own anchor.
  final List<MenuEntry> entries;

  /// The pointer and screen-reader description, if the label is not enough.
  final String? tooltip;

  /// What to say when there is nothing to choose from yet.
  final String? emptyLabel;
}

/// A menu hanging off the bar: quick settings, the language picker.
///
/// Distinct from [ToolbarPickerEntry] because a picker names a subject and a
/// menu offers commands - two of the three languages render those with
/// different controls.
final class ToolbarMenuEntry extends ToolbarEntry {
  /// Declares one anchored menu.
  const ToolbarMenuEntry({
    required this.icon,
    required this.tooltip,
    required this.entries,
    this.label,
    this.badgeCount,
  });

  /// The menu's mark.
  final IconRole icon;

  /// What the menu is for, for the pointer and for a screen reader.
  final String tooltip;

  /// What is in it.
  final List<MenuEntry> entries;

  /// Words beside the mark, where the frame has room for them.
  final String? label;

  /// A count riding on the anchor, or null.
  final int? badgeCount;
}

/// A rule between two runs of entries, carrying nothing of its own.
final class ToolbarSeparatorEntry extends ToolbarEntry {
  /// Declares one separator.
  const ToolbarSeparatorEntry();
}

/// A run of entries that belong together, with the one piece of overflow
/// knowledge the application has and the skin does not.
@immutable
final class ToolbarGroup {
  /// Groups [entries] at [priority].
  const ToolbarGroup(this.entries, {this.priority = ToolbarPriority.normal});

  /// The entries, in reading order.
  final List<ToolbarEntry> entries;

  /// What to shed first. Everything else about overflow - whether it happens
  /// at all, where the menu goes, what it looks like - belongs to the skin,
  /// because two of the three languages already own overflow at the bar.
  final ToolbarPriority priority;
}
