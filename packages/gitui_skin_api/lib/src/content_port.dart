/// The partition: what a skin painted, what the application painted, and the
/// two fences that tell them apart.
///
/// These types and the scope that plants them are ONE library on purpose. The
/// attribution walk (`docs/SKIN-CONTRACT.md` §3.5) prunes at every
/// [SkinPainted] and resumes at every [ContentPortBoundary], and that partition
/// is only trustworthy if nobody outside this file can plant either fence:
/// a single `SkinPainted(child: someApplicationSubtree)` written anywhere in
/// the repository would remove that subtree from the walk permanently, in one
/// line that no reviewer would look at twice. So both constructors are
/// library-private and the three places that legitimately plant a fence -
/// [ContentPort.mount], [SkinScope.render] and the overlay hosts - live in
/// this same library, as a part file. Making it unwritable is cheaper than
/// remembering not to write it.
library;

import 'package:flutter/widgets.dart';

import 'skin.dart';
import 'specs/chrome_specs.dart';
import 'specs/overlay_specs.dart';
import 'vocabulary.dart';

part 'skin_scope.dart';

/// The single type through which a `Widget` may cross into a skin.
///
/// The question a port answers is "where does this piece of application
/// content go", never "what should it look like". A skin POSITIONS and
/// CONSTRAINS a port and must never style it: no `DefaultTextStyle` around it,
/// no `IconTheme`, no decoration beyond the surface that was asked for. The
/// content inside already asked the skin for everything it needed.
///
/// The same partition answers the migration-window question the dialog seam
/// left open: **content crosses the port with its ambient needs already
/// satisfied.** A skin re-establishes its own scope inside a route and
/// nothing else - it does not know, and must not know, which widget library
/// the application built its content from. While application content is still
/// made of Material widgets (a `TextField` asserts a `Material` ancestor),
/// the APPLICATION supplies that ancestor inside the port; a skin that
/// happened to build one (Material's own dialog surface does) was satisfying
/// the need by coincidence, and the blueprint measured the coincidence the
/// moment the surface moved behind the contract.
///
/// The child is PRIVATE, and that is the load-bearing detail. [mount] is the
/// only way to reach it, and [mount] plants the boundary the attribution walk
/// resumes at - so a skin that read the child directly instead of mounting it
/// would have silently exempted that entire subtree from the leak detector
/// forever. Making it unreachable is cheaper than remembering not to reach it.
@immutable
final class ContentPort {
  /// Wraps [child] so it can be handed to a skin.
  const ContentPort(this._child);

  final Widget _child;

  /// Produces the content, fenced.
  ///
  /// Every call returns a fresh [ContentPortBoundary], which is what tells the
  /// attribution walk "everything below here was built by application code
  /// again". A skin calls this exactly where it wants the content to appear.
  Widget mount() => ContentPortBoundary._(child: _child);
}

/// Planted around everything a skin renderer returns, and nowhere else.
///
/// The attribution walk PRUNES here: nothing below was built by application
/// code, so nothing below is a leak. Its constructor is private to this
/// library, so the only widgets that carry it are the ones [SkinScope.render]
/// and the overlay hosts wrap - which is what lets the walk trust the
/// partition instead of trusting everyone who ever imports this package.
final class SkinPainted extends InheritedWidget {
  /// Fences [child] as skin-painted.
  const SkinPainted._({required super.child});

  @override
  bool updateShouldNotify(covariant SkinPainted oldWidget) => false;
}

/// Planted by [ContentPort.mount], and nowhere else.
///
/// The attribution walk RESUMES here: this subtree came back out of the skin
/// and belongs to the application again, so a paint widget below this point is
/// a leak with a file and a line. Private for the same reason [SkinPainted] is:
/// a resume planted anywhere else would attribute a skin's own widgets to the
/// application, which is the same defect pointing the other way.
final class ContentPortBoundary extends InheritedWidget {
  /// Fences [child] as application-built.
  const ContentPortBoundary._({required super.child});

  @override
  bool updateShouldNotify(covariant ContentPortBoundary oldWidget) => false;
}
