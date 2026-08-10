import 'package:flutter/widgets.dart';

import '../icon_role.dart';
import '../vocabulary.dart';
import 'control_specs.dart';
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
    this.tone = Tone.neutral,
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

  /// What the action MEANS: an ordinary command, or one that destroys
  /// something.
  ///
  /// Added because the selection bar could not say it (#442). `SelectionBarSpec`
  /// is filled from what `BatchOperationsBar` used to be handed, and a
  /// `BatchAction` carried an `isDestructive` flag that the skin drew as a
  /// danger-sided button - the same statement `MenuAction.role` already makes
  /// for a menu row. With no slot for it here that flag had nowhere to go, so
  /// the Material selection bar hard-coded `Tone.neutral` and "delete these
  /// three tags" read exactly like "push these three tags". A meaning with no
  /// word is the one thing this contract may not round off, so the word is
  /// here rather than the meaning being dropped.
  ///
  /// [Emphasis] is a separate question and stays separate: how LOUDLY an
  /// action asks to be used is not what it means, and the two combine (a quiet
  /// destructive action and a prominent one are both real).
  final Tone tone;

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
  ///
  /// A standing contract finding (#442 closing): no skin can currently
  /// render this. Both chromes route the entry through `Overlays.anchor`,
  /// and [MenuAnchorSpec] has no label slot, so the words go nowhere -
  /// silently, because no caller passes them today. Under the blueprint's
  /// own rule (a parameter it ignores does not exist) the field is a
  /// promise waiting on a decision: either `MenuAnchorSpec` grows the word,
  /// implemented in every skin that has overlays, or this field is retired.
  final String? label;

  /// A count riding on the anchor, or null.
  final int? badgeCount;
}

/// A choice among a few mutually exclusive presentations, offered from the
/// bar.
///
/// Distinct from [ToolbarPickerEntry] and NOT a rounding onto it. A picker
/// names the SUBJECT the other controls act on - this workspace, this
/// repository, this branch - and every language answers that with a pull-down
/// naming one thing. This entry answers a different question: the same subject,
/// shown a different way. Two screens of this application put exactly that in
/// their bar (the repositories and workspaces grid/list switch), each with a
/// raw `SegmentedButton` because the bar had no word for it, and filing them
/// under "picker" would have said the view mode is the thing being named.
///
/// It carries a [ChoiceGroupSpec] rather than re-declaring options, because
/// "pick exactly one of a few" is already a control every skin implements
/// (`controls.choiceGroup`), and a second declaration of it in the toolbar
/// vocabulary would be two spellings of one question. What each language does
/// with it in a BAR stays the language's answer: Material a segmented button,
/// Fluent a `CommandBar` toggle set, macOS a segmented control in the toolbar.
final class ToolbarChoiceEntry<T> extends ToolbarEntry {
  /// Declares one choice in the bar.
  const ToolbarChoiceEntry(this.spec);

  /// The choices, which one is chosen, and how to report a new one.
  final ChoiceGroupSpec<T> spec;

  /// Hands [spec] back at the type it was DECLARED with.
  ///
  /// A sealed switch matches this entry at its bound -
  /// `ToolbarChoiceEntry&lt;Object?&gt;` - which is enough to reach the spec
  /// but not to use it: reading
  /// `spec.onSelected` through that view types the callback as
  /// `ValueChanged<Object?>`, and a `ValueChanged<ProjectsViewMode>` is not
  /// one. That is not a cast a skin could tighten; it fails at runtime the
  /// first time the entry is built, which is exactly how it was found.
  ///
  /// So the type argument is handed back through a polymorphic callback
  /// instead of through a cast: [use] is called at this entry's own `T`, and a
  /// skin writes `entry.withSpec(<S>(ChoiceGroupSpec<S> spec) => controls
  /// .choiceGroup<S>(context, spec))` with nothing to get wrong. It builds no
  /// widget and decides nothing - the spec stays data.
  R withSpec<R>(R Function<S>(ChoiceGroupSpec<S> spec) use) => use<T>(spec);
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
