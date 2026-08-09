import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../icon_role.dart';
import '../vocabulary.dart';
import 'overlay_specs.dart';
import 'toolbar_specs.dart';
import 'type_specs.dart';

/// A container that holds one thing and can be chosen.
///
/// The question is "here is a self-contained object the user can pick" - a
/// repository, a workspace. It deliberately carries only [Elevation] and no
/// filled-versus-outlined switch: that distinction is Material's containment
/// model, and Fluent and macOS lean on it differently. Material's own loss is
/// registered rather than the contract growing a Material-shaped field.
@immutable
final class CardSpec {
  /// Declares one card.
  const CardSpec({
    required this.content,
    this.header,
    this.footer,
    this.elevation = Elevation.resting,
    this.selection = RowSelection.none,
    this.containerFocused = true,
    this.tone = Tone.neutral,
    this.inset = Inset.roomy,
    this.onTap,
    this.onContextMenu,
  });

  /// What the card is about.
  final ContentPort content;

  /// Something naming the card above its content.
  final ContentPort? header;

  /// Something closing the card below its content.
  final ContentPort? footer;

  /// How far off the page this card stands.
  final Elevation elevation;

  /// Whether the user has picked this card, and how.
  final RowSelection selection;

  /// Whether the collection holding this card has the keyboard.
  ///
  /// Selection and container focus are two independent facts, and the PAIR
  /// decides what is drawn: while the collection is focused the selected card
  /// wears its focus ring, and while focus lives elsewhere the selection keeps
  /// its quieter treatment - still clearly the selection, no longer claiming
  /// the keyboard. One enum cannot say that, which is why the flag exists.
  final bool containerFocused;

  /// What this card is ABOUT, where the object carries its own identity
  /// colour. `Tone.series(n)` is how a workspace's colour reaches a card
  /// without the application ever knowing which colour that is.
  final Tone tone;

  /// How far the content sits from the card's own edge.
  final Inset inset;

  /// What happens when the card is chosen. Null means it is only a container.
  final VoidCallback? onTap;

  /// What happens when the user asks for the card's own menu.
  final ValueChanged<Offset>? onContextMenu;
}

/// A named region of a screen that holds other things.
///
/// Distinct from a card: a card is one object the user picks, a panel is a
/// standing region of the interface with a name and, sometimes, its own
/// actions. A panel does not expand or collapse - that question belongs to
/// `surfaces.disclosure`, and answering it in two places would be two members
/// for one job.
@immutable
final class PanelSpec {
  /// Declares one panel.
  const PanelSpec({
    required this.title,
    required this.content,
    this.actions = const <ToolbarActionEntry>[],
    this.footer,
    this.elevation = Elevation.resting,
    this.inset = Inset.roomy,
  });

  /// What the region is called.
  final String title;

  /// What is in it.
  final ContentPort content;

  /// Actions belonging to the region's own header. A flat list rather than
  /// [ToolbarGroup]s because a panel header does not overflow: a region small
  /// enough to need overflow is a region whose actions belong in a menu.
  final List<ToolbarActionEntry> actions;

  /// Something closing the region below its content.
  final ContentPort? footer;

  /// How far off the page this region stands.
  final Elevation elevation;

  /// How far the content sits from the region's own edge.
  final Inset inset;
}

/// A header that reveals a body.
///
/// The question is "the user can choose to see more of this". It is NOT the
/// same unit as a panel: a settings section, a command-log entry and a stash
/// row all expand, and none of them is a panel. Named `disclosure` rather than
/// `expander` or `expansionTile` because both of those are a language's class
/// name, while disclosure is the platform-neutral behavioural term.
@immutable
final class DisclosureSpec {
  /// Declares one disclosure.
  const DisclosureSpec({
    required this.header,
    required this.body,
    required this.expanded,
    required this.onExpandedChanged,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  /// What is always visible.
  final ContentPort header;

  /// What is visible only while it is open.
  final ContentPort body;

  /// Whether it is open. Application state, so a rebuild cannot lose it.
  final bool expanded;

  /// How to tell the application the user opened or closed it.
  final ValueChanged<bool> onExpandedChanged;

  /// A mark at the head of the header.
  final IconRole? leading;

  /// Something at the tail of the header, beside whatever chevron the language
  /// draws for itself.
  final ContentPort? trailing;

  /// Whether it may be opened at all. A disclosure with nothing inside stays
  /// visible and says so, rather than disappearing.
  final bool enabled;
}

/// One row of a list.
@immutable
final class ListRowSpec {
  /// Declares one row.
  const ListRowSpec({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badgeCount,
    this.menu = const <MenuEntry>[],
    this.selection = RowSelection.none,
    this.containerFocused = true,
    this.onTap,
    this.onActivate,
    this.onContextMenu,
  });

  /// What the row names.
  ///
  /// Title and subtitle are two ports rather than one, because all three
  /// languages keep them apart with separate type roles. With one opaque
  /// content port a skin could only fill `title:`, so every two-line row in
  /// the application would build its own column and choose its own type
  /// roles - application code deciding typography, which is the exact leak the
  /// contract exists to stop.
  final ContentPort title;

  /// What qualifies it: a path, a date, an author.
  final ContentPort? subtitle;

  /// Something at the head of the row.
  final ContentPort? leading;

  /// Something at the tail of the row.
  final ContentPort? trailing;

  /// How many things this row stands for, or null.
  final int? badgeCount;

  /// The row's own menu, as data.
  ///
  /// Data rather than a pre-built anchor, because a pre-built control can
  /// never become the canonical one: `MacosPulldownButton` asserts title XOR
  /// icon. The skin builds its own anchor from these entries.
  final List<MenuEntry> menu;

  /// Whether the user has picked this row, and how.
  final RowSelection selection;

  /// Whether the list holding this row has the keyboard. See
  /// [CardSpec.containerFocused] for why selection alone cannot say this.
  final bool containerFocused;

  /// What happens when the row is chosen.
  final VoidCallback? onTap;

  /// What happens when the row is opened - a double click, or Enter.
  final VoidCallback? onActivate;

  /// What happens when the user asks for the row's own menu.
  final ValueChanged<Offset>? onContextMenu;
}

/// One node of a tree, and everything hanging off it.
@immutable
final class TreeNodeSpec {
  /// Declares one node.
  const TreeNodeSpec({
    required this.id,
    required this.content,
    this.children = const <TreeNodeSpec>[],
    this.leading,
    this.trailing,
    this.badgeCount,
    this.checked,
    this.menu = const <MenuEntry>[],
  });

  /// How the application recognises this node again when the user acts on it.
  final Object id;

  /// What the node says.
  final ContentPort content;

  /// What is under it.
  final List<TreeNodeSpec> children;

  /// A mark at the head of the node.
  final IconRole? leading;

  /// Something at the tail of the node.
  final ContentPort? trailing;

  /// How many things this node stands for, or null.
  final int? badgeCount;

  /// Whether this node is checked - and `null` for the folder whose children
  /// are only partly checked, which is a live state in this application.
  final bool? checked;

  /// The node's own menu, as data.
  final List<MenuEntry> menu;
}

/// A whole tree.
///
/// The member is at the TREE and not at the row, forced by the contract's own
/// arity rule: Fluent's canonical answer covers N of our rows at once, so the
/// member moves up to N. Expansion and selection are carried here as
/// APPLICATION-owned data, and a skin whose canonical widget wants a
/// controller creates and drives its own from them. The roving-highlight
/// keyboard contract stays wrapped AROUND whatever this member returns.
@immutable
final class TreeSpec {
  /// Declares one tree.
  const TreeSpec({
    required this.roots,
    required this.expanded,
    required this.selected,
    required this.onToggleExpanded,
    required this.onSelect,
    this.onActivate,
    this.onCheck,
    this.onContextMenu,
    this.containerFocused = true,
  });

  /// The top of the tree.
  final List<TreeNodeSpec> roots;

  /// Which nodes are open, by id.
  final Set<Object> expanded;

  /// Which nodes are picked, by id.
  final Set<Object> selected;

  /// How to tell the application the user opened or closed a node.
  final ValueChanged<Object> onToggleExpanded;

  /// How to tell the application the user picked a node.
  final ValueChanged<Object> onSelect;

  /// How to tell the application the user opened a node.
  final ValueChanged<Object>? onActivate;

  /// How to tell the application the user checked a node.
  final void Function(Object id, bool? value)? onCheck;

  /// How to tell the application the user asked for a node's menu.
  final void Function(Object id, Offset at)? onContextMenu;

  /// Whether the tree has the keyboard. See [CardSpec.containerFocused].
  final bool containerFocused;
}

/// One tab, and what it contains.
@immutable
final class TabEntry {
  /// Declares one tab.
  const TabEntry({
    required this.label,
    required this.body,
    this.icon,
    this.badgeCount,
  });

  /// What the tab is called.
  final String label;

  /// What is under it. A BUILDER, for the same reason a shell destination's
  /// body is one: it is the only shape every language's tab view drives
  /// without a wrapper.
  final ContentPort Function() body;

  /// A mark beside the name.
  final IconRole? icon;

  /// How many things are waiting under it, or null.
  final int? badgeCount;
}

/// A set of tabs and their bodies.
///
/// The member covers the bodies rather than only the strip, and that is forced
/// by measurement rather than taste: `MacosTabView` asserts that its
/// controller, its tabs and its children are all the same length - it OWNS its
/// children - and Fluent's `TabView` owns its bodies, its close affordances
/// and its overflow together. A strip-only member would make the canonical
/// widget of two of the three languages unreachable.
@immutable
final class TabSetSpec {
  /// Declares one tab set.
  const TabSetSpec({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// The tabs, in reading order.
  final List<TabEntry> tabs;

  /// Which one is showing.
  final int selectedIndex;

  /// How to tell the application the user moved.
  final ValueChanged<int> onSelect;
}

/// A table of values the user reads across and down.
///
/// No sorting: the floor does not sort, and members are derived from need in
/// at least one source rather than from a package's full parameter list. Named
/// `dataGrid` rather than `dataTable` because `DataTable` is Material's class
/// name, and this is already the contract's clearest Material-only member.
@immutable
final class DataGridSpec {
  /// Declares one grid.
  const DataGridSpec({
    required this.columns,
    required this.rows,
    this.density = GridDensity.normal,
  });

  /// What each column is called.
  final List<String> columns;

  /// The cells, row-major.
  final List<List<ContentPort>> rows;

  /// How tightly packed the user wants it.
  final GridDensity density;
}

/// An arbitrary region the user can act on, wearing the language's own hover,
/// focus and press feedback.
///
/// It exists because the alternative is worse: the attribution walk admits
/// `GestureDetector` and `MouseRegion` as structure, and both give a tap
/// target with NO state layer at all, while this repository's rules make a
/// state layer on every touch target non-negotiable. Its child is a
/// [ContentPort], so the walk resumes inside it and this member cannot become
/// an escape hatch that hides painting - it can only be over-used, which is a
/// judgement recorded openly rather than a hole.
@immutable
final class PressableSpec {
  /// Declares one pressable region.
  const PressableSpec({
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onContextMenu,
    this.selected = false,
    this.enabled = true,
    this.tooltip,
    this.semanticsLabel,
  });

  /// What the user is acting on.
  final ContentPort child;

  /// What happens when it is chosen.
  final VoidCallback? onTap;

  /// What happens when it is opened.
  final VoidCallback? onDoubleTap;

  /// What happens when the user asks for its menu.
  final ValueChanged<Offset>? onContextMenu;

  /// Whether it is currently picked.
  final bool selected;

  /// Whether it may be acted on at all.
  final bool enabled;

  /// What it does, for the pointer.
  final String? tooltip;

  /// What it is, for a screen reader, where the content inside does not
  /// already say so.
  final String? semanticsLabel;
}

/// A count or a mark riding on something else.
@immutable
final class BadgeSpec {
  /// Declares one badge.
  const BadgeSpec({
    required this.label,
    this.icon,
    this.tone = Tone.neutral,
    this.scale = ControlScale.normal,
  });

  /// What it says - usually a count, sometimes a single word.
  final String label;

  /// A mark instead of, or beside, the words.
  final IconRole? icon;

  /// What it means.
  final Tone tone;

  /// How much room it is entitled to.
  final ControlScale scale;
}

/// A labelled pill the user can remove.
///
/// Split out of the badge because the two do not overlap even inside Material:
/// a badge is a count with no delete and no tap, and the removable pill is a
/// chip carrying `onDeleted`, its own delete mark and a tooltip for it. One
/// member cannot map onto both without carrying every field of each - and the
/// tooltip is the decider, because this repository requires one on every
/// mark-only control and a badge has no slot for it.
@immutable
final class TagSpec {
  /// Declares one tag.
  const TagSpec({
    required this.label,
    this.icon,
    this.tone = Tone.neutral,
    this.onRemoved,
    this.removeTooltip,
    this.onTap,
  });

  /// What the tag says.
  final String label;

  /// A mark at its head.
  final IconRole? icon;

  /// What it means.
  final Tone tone;

  /// How to take it away. Null means it cannot be removed.
  final VoidCallback? onRemoved;

  /// What removing it does, for the pointer and for a screen reader. Required
  /// in spirit whenever [onRemoved] is set.
  final String? removeTooltip;

  /// What happens when the tag itself is chosen.
  final VoidCallback? onTap;
}

/// The circular mark standing for a person or a thing.
///
/// A member rather than a glyph inside a leading port, because a port may only
/// be POSITIONED and CONSTRAINED by a skin and never styled: if the monogram
/// went into a port, the circle around it and its foreground pairing would
/// have to be drawn by the application. That is the leak, not the fix.
@immutable
final class AvatarSpec {
  /// Declares one avatar. Exactly one of [monogram] and [glyph] is the mark.
  const AvatarSpec({
    this.monogram,
    this.glyph,
    this.tone = Tone.neutral,
    this.scale = ControlScale.normal,
    this.semanticsLabel,
  }) : assert(
         monogram != null || glyph != null,
         'An avatar with neither a monogram nor a glyph has nothing to '
         'stand for.',
       );

  /// The initials, where the thing has a name.
  final String? monogram;

  /// A mark, where it does not.
  final IconRole? glyph;

  /// What it is about. `Tone.series(n)` is how a per-object identity colour
  /// reaches it without the application knowing which colour that is.
  final Tone tone;

  /// How much room it is entitled to.
  final ControlScale scale;

  /// Who or what it stands for, for a screen reader.
  final String? semanticsLabel;
}

/// A standing message across the top of a surface.
///
/// It carries actions because the Material canon requires them:
/// `MaterialBanner` declares `required this.actions` and asserts the list is
/// non-empty, so a banner spec carrying only a tone and a message would make
/// it impossible for the Material skin to call its own canonical widget at
/// all - hand-painting imposed by the contract, at exactly the point the
/// contract exists to prevent it.
@immutable
final class BannerSpec {
  /// Declares one banner.
  const BannerSpec({
    required this.tone,
    required this.title,
    this.body,
    this.icon,
    this.actions = const <NoticeAction>[],
    this.onDismiss,
  });

  /// What it means.
  final Tone tone;

  /// The statement.
  final String title;

  /// The longer form.
  final String? body;

  /// A mark beside it.
  final IconRole? icon;

  /// What the user can do about it.
  final List<NoticeAction> actions;

  /// How to make it go away. Null means it stays until the condition does.
  final VoidCallback? onDismiss;
}

/// Something the user can do from an empty state.
@immutable
final class EmptyStateAction {
  /// Declares one action.
  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasis = Emphasis.secondary,
  });

  /// The action's words.
  final String label;

  /// The action's mark.
  final IconRole icon;

  /// What it does.
  final VoidCallback onPressed;

  /// How loudly it asks to be used. The one action that fills the emptiness is
  /// [Emphasis.primary]; the rest are not.
  final Emphasis emphasis;
}

/// What to show where there is nothing yet.
@immutable
final class EmptyStateSpec {
  /// Declares one empty state.
  const EmptyStateSpec({
    required this.icon,
    required this.title,
    required this.message,
    this.tone = Tone.muted,
    this.actions = const <EmptyStateAction>[],
  });

  /// A mark standing for the thing that is missing.
  final IconRole icon;

  /// What the state MEANS, worn by the hero mark.
  ///
  /// The member owns the mark's size outright - the spec carries none - but
  /// it cannot own the mark's meaning, because "there is nothing here yet"
  /// and "this could not be loaded" are different statements and the mark is
  /// where the difference is loudest. [Tone.muted] is the default: ordinary
  /// emptiness is secondary to whatever the user came for. A state standing
  /// in for a FAILURE says [Tone.danger] instead, so a real error is never
  /// dressed as an ordinary empty pane.
  final Tone tone;

  /// What is missing, in a few words.
  final String title;

  /// Why, and what the user might do about it.
  final String message;

  /// The ways out of the emptiness.
  final List<EmptyStateAction> actions;
}

/// A region that accepts things dragged onto it.
///
/// The application knows two facts - what this region accepts, and whether
/// something is over it right now. Everything else the current screen decides
/// by hand (a tinted wash, a callout, a border, an oversized glyph) is five
/// paint decisions sitting in a feature file, which is why the member exists
/// even though no language ships a canonical drop target.
@immutable
final class DropTargetSpec {
  /// Declares one drop target.
  const DropTargetSpec({
    required this.child,
    required this.active,
    required this.icon,
    required this.label,
  });

  /// What is underneath, and stays visible.
  final ContentPort child;

  /// Whether something is being dragged over it right now.
  final bool active;

  /// A mark standing for what it accepts.
  final IconRole icon;

  /// What it accepts, in words.
  final String label;
}

/// One line of a diff or of a code view.
///
/// A member rather than a tone on a generic surface, because the skin must be
/// free to decide whether a 10,000-line diff is painted with widgets or with a
/// painter - and that is a performance decision about numbers, which live on
/// the skin's side of the line.
@immutable
final class CodeLineSpec {
  /// Declares one line.
  const CodeLineSpec({
    required this.runs,
    this.tone = Tone.neutral,
    this.marker,
    this.oldNumber,
    this.newNumber,
    this.selected = false,
    this.onTap,
  });

  /// The line, split into the runs whose meanings differ: an intra-line edit,
  /// a search hit, a stretch of unchanged text.
  final List<TextRun> runs;

  /// What the whole line means: added, deleted, unchanged, a hunk header.
  final Tone tone;

  /// The gutter character git itself writes - `+`, `-`, a space. Content, not
  /// decoration: it is what makes a copied diff still a diff.
  final String? marker;

  /// The line's number on the left-hand side, or null where it has none.
  final int? oldNumber;

  /// The line's number on the right-hand side, or null where it has none.
  final int? newNumber;

  /// Whether the user has picked this line - to stage it, to comment on it.
  final bool selected;

  /// What happens when the line is chosen.
  final VoidCallback? onTap;
}

/// A whole block of read-only, monospaced output.
///
/// Git stdout, a command-log entry, a blame line, a commit message body. Its
/// own member rather than a flag on `type.text`, because a block carries a
/// fill, an edge and a family that a flag cannot express - and because
/// `codeLine` is per-line, and 200 lines of git output is not 200 lines' worth
/// of work.
@immutable
final class CodeBlockSpec {
  /// Declares one block.
  const CodeBlockSpec({
    required this.text,
    this.tone = Tone.neutral,
    this.selectable = true,
    this.wrap = false,
    this.maxLines,
  });

  /// The output, verbatim.
  final String text;

  /// What it means: ordinary output, an error, a warning.
  final Tone tone;

  /// Whether the user can select and copy it. Selectability is BEHAVIOUR -
  /// what the user can do - so the application states it and the skin supplies
  /// its own selection affordances.
  final bool selectable;

  /// Whether long lines fold. A fact about the content: command output is read
  /// unwrapped, a commit message is read wrapped.
  final bool wrap;

  /// How much to show before the block is truncated, or null for all of it.
  final int? maxLines;
}

/// One lane crossing a commit-graph row.
@immutable
final class GraphEdgeSpec {
  /// Declares one lane crossing.
  const GraphEdgeSpec({required this.lane, required this.toneIndex});

  /// Which column it occupies.
  final int lane;

  /// Which member of the skin's generated series colours it. An INDEX, never a
  /// colour: the palette and its length both belong to the skin, exactly as
  /// they do for `Tone.series`.
  final int toneIndex;
}

/// The graph gutter of one commit row, as data.
///
/// This is the application's only `CustomPainter` today, and the whole reason
/// it becomes a member: a painter is the one place every lint is blind, so the
/// lanes, the dot and the edges cross as numbers-free data and each skin owns
/// the painting - along with the lane width, the dot radius and the stroke
/// width that live beside it.
@immutable
final class GraphRowSpec {
  /// Declares one row's graph.
  const GraphRowSpec({
    required this.lane,
    required this.toneIndex,
    required this.isMerge,
    required this.laneCount,
    this.incoming = const <GraphEdgeSpec>[],
    this.outgoing = const <GraphEdgeSpec>[],
    this.passing = const <GraphEdgeSpec>[],
    this.isCurrent = false,
  });

  /// Which column this commit's dot sits in.
  final int lane;

  /// Which member of the skin's series colours the dot and the lane it
  /// continues.
  final int toneIndex;

  /// Whether this commit joins several parents, so the skin can mark it.
  final bool isMerge;

  /// How many lanes are in play across the whole window, so the skin knows how
  /// wide the gutter has to be. A COUNT, not a width.
  final int laneCount;

  /// Edges arriving from the row above.
  final List<GraphEdgeSpec> incoming;

  /// Edges leaving towards the row below.
  final List<GraphEdgeSpec> outgoing;

  /// Lanes running straight through without touching the dot.
  final List<GraphEdgeSpec> passing;

  /// Whether this is the commit HEAD is on.
  final bool isCurrent;
}

/// A document written in Markdown.
///
/// The skin owns the style sheet, which is why this member needs no escape
/// hatch: the application never constructs one, so there is no `TextStyle` for
/// it to choose.
@immutable
final class MarkdownSpec {
  /// Declares one document.
  const MarkdownSpec({
    required this.source,
    this.selectable = true,
    this.onLinkTapped,
    this.baseDirectory,
  });

  /// The document, as text.
  final String source;

  /// Whether the user can select and copy it.
  final bool selectable;

  /// What happens when a link in it is followed. Null means links are inert.
  final ValueChanged<String>? onLinkTapped;

  /// Where relative links and images in the document resolve from.
  final String? baseDirectory;
}

/// A picture the user can look at closely.
@immutable
final class ImageViewerSpec {
  /// Declares one viewer.
  const ImageViewerSpec({required this.image, this.semanticsLabel});

  /// Which picture. An `ImageProvider` says which, never how large.
  final ImageProvider<Object> image;

  /// What it shows, for a screen reader.
  final String? semanticsLabel;
}
