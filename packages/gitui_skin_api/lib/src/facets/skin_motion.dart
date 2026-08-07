import 'package:flutter/widgets.dart';

import '../content_port.dart';
import '../vocabulary.dart';

/// How things change.
///
/// Two members, not the seven an earlier count implied, and the number is a
/// measurement rather than a preference: the whole of `lib/` contains one
/// animation controller, one rotation, one cross-fade, no switcher, no
/// animated size, and exactly one read of a motion value as a value. Every one
/// of those sites is inside a component that becomes a member of this
/// contract, so after the migration the measured application-owned motion is
/// **zero sites**.
///
/// The facet still exists because the alternative has no legal home. The spine
/// rule bans a `Duration`-typed read, `SkinRequest.animationScale` is consumed
/// by the skin and not by the application, and there is no third option - so
/// the moment one screen wants a fade, the choice would be between reopening
/// the contract and hand-rolling an animation. Two members cost the blueprint
/// about twenty lines and close the facet.
abstract interface class SkinMotion {
  /// **This appeared, or went away, in place.**
  ///
  /// The application states the fact and what kind of change it is; the skin
  /// decides how long that takes and along which curve - including not at all,
  /// which is what the blueprint answers and what lets the zero-and-extremes
  /// sweep see a motion dependence at all.
  Widget reveal(
    BuildContext context, {
    required ContentPort child,
    required bool visible,
    MotionRole role = MotionRole.feedback,
  });

  /// **This replaced that, in the same place.**
  ///
  /// [stateKey] is how the skin knows one thing became another rather than one
  /// thing merely rebuilding. It is application state - which commit, which
  /// tab, which repository - and carries nothing visual.
  Widget swap(
    BuildContext context, {
    required ContentPort child,
    required Object stateKey,
    MotionRole role = MotionRole.transition,
  });
}
