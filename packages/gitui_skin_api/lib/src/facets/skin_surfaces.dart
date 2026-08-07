import 'package:flutter/widgets.dart';

import '../specs/surface_specs.dart';

/// Things that hold other things.
///
/// Nineteen members, the largest facet, and `treeRow` is deliberately absent:
/// the arity of a tree is the TREE, because Fluent's canonical answer covers N
/// of our rows at once, and a per-row member left standing beside it is the
/// one a migrating screen would reach for.
abstract interface class SkinSurfaces {
  /// **Here is one self-contained object the user can pick.**
  Widget card(BuildContext context, CardSpec spec);

  /// **Here is a named standing region of the interface.**
  Widget panel(BuildContext context, PanelSpec spec);

  /// **The user can choose to see more of this.**
  Widget disclosure(BuildContext context, DisclosureSpec spec);

  /// **Here is one entry in a list of like things.**
  Widget listRow(BuildContext context, ListRowSpec spec);

  /// **Here is a hierarchy the user walks, opens and picks from.**
  Widget tree(BuildContext context, TreeSpec spec);

  /// **Here are several views of the same subject; the user picks one.**
  ///
  /// The bodies come with it, because two of the three languages' tab views
  /// own their children and a strip-only member would make both unreachable.
  Widget tabs(BuildContext context, TabSetSpec spec);

  /// **Here is a table of values the user reads across and down.**
  Widget dataGrid(BuildContext context, DataGridSpec spec);

  /// **This region can be acted on, and must say so under the pointer and
  /// under the keyboard.**
  ///
  /// It exists because the structural alternatives give a tap target with no
  /// state layer at all, and a touch target without one is an unfinished
  /// control by this repository's rules.
  Widget pressable(BuildContext context, PressableSpec spec);

  /// **How many, riding on something else?**
  Widget badge(BuildContext context, BadgeSpec spec);

  /// **Here is a named thing the user can take away again.**
  ///
  /// Split from [badge] because the two do not overlap even inside one
  /// language: a badge has no removal and no tooltip slot, and a removable
  /// pill needs both.
  Widget tag(BuildContext context, TagSpec spec);

  /// **Which person or thing is this?** - as a single compact mark.
  Widget avatar(BuildContext context, AvatarSpec spec);

  /// **Something about this whole surface needs saying.**
  Widget banner(BuildContext context, BannerSpec spec);

  /// **There is nothing here yet, and here is what to do about it.**
  Widget emptyState(BuildContext context, EmptyStateSpec spec);

  /// **Things can be dragged onto this region.**
  Widget dropTarget(BuildContext context, DropTargetSpec spec);

  /// **Here is one line of a diff or of a code view.**
  ///
  /// A member of its own so that a skin may decide whether ten thousand lines
  /// are painted with widgets or with a painter. That is a performance
  /// decision about numbers, and numbers live on the skin's side of the line.
  Widget codeLine(BuildContext context, CodeLineSpec spec);

  /// **Here is a whole block of machine output the user reads and copies.**
  Widget codeBlock(BuildContext context, CodeBlockSpec spec);

  /// **Here is how this commit connects to the ones above and below it.**
  ///
  /// The application's only `CustomPainter` becomes this member, which closes
  /// the attribution walk's only blind spot by construction: after it lands
  /// there is no `paint()` call in application code for a leak to hide in.
  Widget commitGraphRow(BuildContext context, GraphRowSpec spec);

  /// **Here is a document written in Markdown.**
  Widget markdown(BuildContext context, MarkdownSpec spec);

  /// **Here is a picture the user wants to look at closely.**
  Widget imageViewer(BuildContext context, ImageViewerSpec spec);
}
