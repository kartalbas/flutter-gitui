import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../specs/layout_specs.dart';
import '../vocabulary.dart';

/// How things sit next to one another.
///
/// This is the facet that replaces the token bag, and it is where the contract
/// earns its central claim. A token bag would have moved WHERE a number comes
/// from without moving WHO decided that a gap exists, where it goes and which
/// rung it takes - so `context.space.m * 1.5` would still have been legal, and
/// still have been layout decided in the application.
///
/// `Expanded`, `Flexible`, `Stack`, `Positioned`, `ConstrainedBox` and
/// `LayoutBuilder` deliberately have no members here. Flex and constraint
/// topology is STRUCTURE - remove it and the screen stops laying out - so it
/// stays in application code and the blueprint must honour it exactly.
///
/// Every piece of content this facet arranges crosses as a [ContentPort], and
/// these three members are why that matters more here than anywhere else: they
/// are the most-called members in the whole contract, so a raw `Widget` here
/// would mean most of the application's own widget tree entered a skin with no
/// boundary above it - and the attribution walk, which resumes only at a
/// [ContentPortBoundary], would report nothing at all for any of it.
abstract interface class SkinLayout {
  /// **These things belong under one another; how closely?**
  ///
  /// The application declares the relationship and the order; the skin decides
  /// the distance. This is what absorbs the interleaved gap widgets rather
  /// than merely renaming their numbers.
  Widget column(
    BuildContext context,
    List<ContentPort> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.stretch,
    MainAxisSize size = MainAxisSize.min,
  });

  /// **These things belong beside one another; how closely?**
  Widget row(
    BuildContext context,
    List<ContentPort> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.center,
    MainAxisSize size = MainAxisSize.max,
    bool wrap = false,
  });

  /// **These things are equals; show as many at once as make sense.**
  ///
  /// The one member that reports structure back: the application's keyboard
  /// navigation needs the resulting column count to move by whole rows, and
  /// once the skin owns the geometry the application can no longer work it
  /// out.
  Widget grid(BuildContext context, GridSpec spec);

  /// **These two regions share the space, and the user decides how.**
  Widget splitPane(BuildContext context, SplitPaneSpec spec);

  /// **These are named values, and their names should line up.**
  ///
  /// At the SET rather than the row, because the alignment is a property of
  /// the set - and because a fixed label width cannot survive translation,
  /// which the existing implementation's own comment already records.
  Widget propertyList(BuildContext context, PropertyListSpec spec);

  /// **How far should this content sit from its container's edge?**
  Widget inset(
    BuildContext context,
    ContentPort child, {
    Inset all = Inset.normal,
    Inset? x,
    Inset? y,
  });

  /// **These two regions are about different things.**
  ///
  /// A statement of division, not a line: a language that divides with space
  /// rather than with a rule is answering the same question correctly.
  Widget separator(
    BuildContext context, {
    Axis axis = Axis.horizontal,
    Inset indent = Inset.none,
  });

  /// **These two neighbours are this closely related.**
  ///
  /// For the runs that are not uniform, where a single `gap:` on the enclosing
  /// column or row cannot say it. It reads the enclosing flex's direction from
  /// the render tree, so one member serves both axes.
  Widget gap(BuildContext context, Proximity proximity);
}
