// T3, the attribution walk (#249, docs/SKIN-CONTRACT.md §3.5).
//
// > Walk the element tree from the root. **Prune at every `SkinPainted`.
// > Resume at every `ContentPortBoundary`.** Everything reachable in the
// > un-pruned region was built by application code.
//
// Then assert that the un-pruned region contains only widgets on an
// ALLOW-LIST of structural and behavioural types. An allow-list rather than a
// deny-list, because a deny-list is only as good as its enumeration and the
// panel demonstrated the hole concretely on this repository: the original
// named `DecoratedBox` and `Container(decoration:)` but not `ColoredBox`, and
// `lib/` contains 0 `DecoratedBox(`, 0 `ColoredBox(` and 168 `Container(` - so
// `Container(color: grey)` builds the one node the deny-list omitted and
// paints the one colour an achromatic invariant permits.
//
// This file is the walk. It renders nothing, captures nothing and needs no
// image comparator, which is why it is the check that runs on the owner's
// Windows machine where all 68 goldens are skipped.
//
// **What it is used for today, and what it is not.** §5.9 makes T3 blocking
// from P2, because before then the whole application is above the fence and
// every widget in it reports - which is a true measurement and a useless
// gate. So `attribution_walk_test.dart` runs it over trees built here, and
// what those tests prove is the property the walk depends on: that the
// partition is REPRESENTABLE. That was the open question - the fence used to
// be planted inside `chrome.wrapRoot`'s child, so a skin's own root treatment
// landed in the half attributed to the application, and the three most-called
// layout members took raw widgets, so application content mounted with no
// boundary above it and could never be attributed at all.

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// One widget the walk attributes to application code.
class AttributedWidget {
  const AttributedWidget(this.element);

  /// Where it is in the tree. Kept rather than flattened to a string so a
  /// caller can ask it anything the report needs.
  final Element element;

  /// What was built, by name.
  String get name => element.widget.runtimeType.toString();

  /// The chain that created it, which is what carries the file and the line
  /// once `--track-widget-creation` is on - and it is on under `flutter test`.
  /// This is the same mechanism the framework itself uses to print "The
  /// relevant error-causing widget was: ...".
  String get creatorChain => element.debugGetCreatorChain(8);

  @override
  String toString() => creatorChain;
}

/// The structural and behavioural widgets application code may still build.
///
/// Structure by the Zero Test (§1): remove one and the screen stops laying
/// out, or stops being operable from the keyboard. None of them paints.
///
/// The six at the end are the correction `docs/SKIN-CONTRACT-MEMBERS.md` §11
/// requires before T3's first real run: `Center` (114 sites), `Align` (8),
/// `Spacer` (14), `IntrinsicHeight` (6), `SafeArea` (3) and
/// `NotificationListener` (3) are all structure and would all have reported as
/// leaks on day one.
const Set<String> kStructuralAllowList = <String>{
  // Flex and constraint topology.
  'Column', 'Row', 'Flex', 'Expanded', 'Flexible', 'Stack', 'Positioned',
  'ConstrainedBox', 'LayoutBuilder', 'SizedBox', 'Padding',
  // Scrolling.
  'SingleChildScrollView', 'ListView', 'CustomScrollView', 'Scrollable',
  'Viewport', 'SliverList', 'SliverToBoxAdapter',
  // Behaviour.
  'Focus', 'FocusScope', 'FocusTraversalGroup', 'Actions', 'Shortcuts',
  'Semantics', 'MergeSemantics', 'ExcludeSemantics', 'GestureDetector',
  'MouseRegion', 'Listener', 'Builder', 'StatefulBuilder',
  // Plumbing that carries no appearance.
  'Directionality', 'MediaQuery', 'Localizations', 'Overlay', 'OverlayEntry',
  'ProviderScope', 'Consumer', 'ValueListenableBuilder', 'AnimatedBuilder',
  // §11's six.
  'Center', 'Align', 'Spacer', 'IntrinsicHeight', 'SafeArea',
  'NotificationListener',
};

/// Everything the application built, in the region the skin did not paint.
///
/// [allowList] is the set of widget type names that may appear there; anything
/// else is returned. Framework internals are skipped by [isFrameworkInternal],
/// because a `_InheritedTheme` or a `RawGestureDetector` is not something
/// application code wrote - the widget that DID get written is its ancestor,
/// and reporting both would bury the one line a developer has to change.
List<AttributedWidget> attributionWalk(
  Element root, {
  Set<String> allowList = kStructuralAllowList,
}) {
  final List<AttributedWidget> found = <AttributedWidget>[];

  void visit(Element element, {required bool inSkin}) {
    final Widget widget = element.widget;
    bool nowInSkin = inSkin;
    if (widget is SkinPainted) {
      nowInSkin = true;
    } else if (widget is ContentPortBoundary) {
      nowInSkin = false;
    } else if (!inSkin &&
        !isFrameworkInternal(widget) &&
        !allowList.contains(widget.runtimeType.toString())) {
      found.add(AttributedWidget(element));
    }
    element.visitChildren((Element child) => visit(child, inSkin: nowInSkin));
  }

  visit(root, inSkin: false);
  return found;
}

/// Whether this widget is one the framework built rather than one a developer
/// wrote.
///
/// A private type is the giveaway, and it is the SDK's own convention rather
/// than a guess: everything under `_` is unnameable outside its library, so no
/// application file can have constructed it directly.
bool isFrameworkInternal(Widget widget) =>
    widget.runtimeType.toString().startsWith('_');
