import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../material_theme.dart';

/// How things change, the Material way.
///
/// Two members, because the measured application-owned motion after the
/// contract lands is zero sites: the one `AnimationController`, the one
/// `AnimatedRotation` and the one `AnimatedCrossFade` all live inside
/// components that become other members. The facet exists for the case that
/// has no other legal home - the spine rule bans a `Duration`-typed read and
/// `SkinRequest.animationScale` is consumed by the skin, not the application.
///
/// **Material's answer is the application's existing durations.** There was
/// no `reveal` or `swap` widget to move, so what is extracted here is the
/// application's motion *system*: the three Material 3 duration tokens
/// `AppTheme` pinned (short3 / medium1 / medium3), multiplied by the user's
/// animation-speed setting, now resolved by [MaterialMotionDurations] against
/// the request `chrome.wrapRoot` installs. The vehicle for both members is
/// [AnimatedSwitcher], which is Material's own primitive for "one child
/// became another in place" and fades between them - the same treatment the
/// application's `FadeUpwardsPageTransitionsBuilder` pages and
/// `AnimatedCrossFade` disclosure already use for the same meaning.
///
/// A zero animation scale resolves every duration to zero, exactly as
/// `AppTheme.getAnimationDuration` returned `Duration.zero` for the "none"
/// setting - the user who turned motion off gets state changes that are
/// simply true, not fast.
final class MaterialMotion implements SkinMotion {
  /// Builds the motion facet.
  const MaterialMotion();

  /// Something appeared, or went away, in place.
  ///
  /// While [visible] is false nothing stays mounted once the exit fade has
  /// finished - `AnimatedSwitcher` removes the outgoing child at the end of
  /// its transition, so the end state is identical to the blueprint's
  /// instant one and a test that pumps past the duration sees the same tree
  /// either way. The port is mounted only in the visible branch, so the
  /// attribution boundary exists exactly when the content does.
  @override
  Widget reveal(
    BuildContext context, {
    required ContentPort child,
    required bool visible,
    MotionRole role = MotionRole.feedback,
  }) => AnimatedSwitcher(
    duration: MaterialMotionDurations.resolve(context, role),
    child: visible
        // The key tells the switcher that "shown" and "hidden" are different
        // children rather than one child rebuilding, which is what makes the
        // fade run at all.
        ? KeyedSubtree(key: const ValueKey<bool>(true), child: child.mount())
        : const SizedBox.shrink(key: ValueKey<bool>(false)),
  );

  /// One thing replaced another, in the same place.
  ///
  /// [stateKey] is honoured structurally as well as visually: it keys the
  /// mounted subtree, so when the key changes the framework discards the old
  /// element and its state instead of quietly updating it in place, and the
  /// switcher cross-fades the two. That is the whole meaning of "one thing
  /// became another rather than one thing merely rebuilding", and it is the
  /// same key discipline the blueprint keeps at `Duration.zero`.
  @override
  Widget swap(
    BuildContext context, {
    required ContentPort child,
    required Object stateKey,
    MotionRole role = MotionRole.transition,
  }) => AnimatedSwitcher(
    duration: MaterialMotionDurations.resolve(context, role),
    child: KeyedSubtree(key: ValueKey<Object>(stateKey), child: child.mount()),
  );
}
