import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';

/// How things change, naked: instantly.
///
/// This is the facet that did not exist - the contract declared `SkinMotion`
/// and specified nothing behind the name, and the census settled it at two
/// members. Both are implemented here as INSTANT, and both still accept every
/// parameter, because a duration the blueprint dropped is one the next skin
/// author would drop too: the blueprint is the template a fourth skin copies.
///
/// Every duration under this skin is `Duration.zero`, for two reasons that
/// point the same way. Any non-zero duration would be a design value, which
/// the blueprint may not hold; and the zero-and-extremes sweep's whole method
/// is that nothing animates - a test that fails under the blueprint because a
/// transition no longer takes time is a test that was asserting design, and
/// only `Duration.zero` can expose it.
///
/// The [MotionRole] is not lost. §9.2 of the member list places it among the
/// parameters a naked square cannot render distinguishably - drawing a
/// different animation per role IS motion design - so it goes to the debug
/// surface instead: the widget each member returns names its member, its role
/// marker and its current state in [Widget.toStringShort], which is what the
/// widget inspector and `debugDumpApp` print. A skin that drops the role
/// still shows up as a difference from the blueprint there.
final class BlueprintMotion implements SkinMotion {
  /// Takes the distance every rung resolves against.
  const BlueprintMotion(this.distance);

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance. Motion has no rung to resolve - it is carried so
  /// that every facet is constructed the same way and a facet can grow a use
  /// for it without changing `BlueprintSkin`.
  final BlueprintDistance distance;

  /// Something appeared or went away, in place - now.
  ///
  /// While [visible] is false nothing is mounted at all, which is the same
  /// end state an animating skin reaches when its exit transition finishes;
  /// the blueprint simply has no interval in between. The port is mounted
  /// only in the visible branch so the attribution boundary exists exactly
  /// when the content does.
  @override
  Widget reveal(
    BuildContext context, {
    required ContentPort child,
    required bool visible,
    MotionRole role = MotionRole.feedback,
  }) => _InstantMotion(
    member: 'motion.reveal',
    role: role,
    state: visible ? 'visible' : 'hidden',
    child: visible ? child.mount() : const SizedBox.shrink(),
  );

  /// One thing replaced another, in the same place - now.
  ///
  /// [stateKey] is honoured structurally rather than visually: it keys the
  /// mounted subtree, so when the key changes the framework discards the old
  /// element and its state instead of quietly updating it in place. That is
  /// the whole meaning of "one thing became another rather than one thing
  /// merely rebuilding", and it is exactly what an animating skin needs the
  /// key for too - the blueprint keeps the semantics and drops only the
  /// crossfade.
  @override
  Widget swap(
    BuildContext context, {
    required ContentPort child,
    required Object stateKey,
    MotionRole role = MotionRole.transition,
  }) => _InstantMotion(
    member: 'motion.swap',
    role: role,
    state: '$stateKey',
    child: KeyedSubtree(key: ValueKey<Object>(stateKey), child: child.mount()),
  );
}

/// The instant stand-in for an animation: it renders its child and nothing
/// else, and prints what it stands for on the debug surface.
///
/// The role could not be drawn without becoming motion design, so it is
/// carried where a developer inspecting the tree reads it - [toStringShort]
/// is the line the widget inspector and `debugDumpApp` show for this node.
/// The class deliberately does not extend the child's own semantics or
/// layout: an instant motion IS its child.
class _InstantMotion extends StatelessWidget {
  const _InstantMotion({
    required this.member,
    required this.role,
    required this.state,
    required this.child,
  });

  /// Which contract member produced this node.
  final String member;

  /// What kind of change the application declared.
  final MotionRole role;

  /// The state the change is currently in, in words.
  final String state;

  /// The content, already mounted through its port.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  String toStringShort() => '$member ${BlueprintMarks.motion(role)} $state';
}
