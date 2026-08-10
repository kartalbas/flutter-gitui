import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_motion.dart';

/// How things change, the Fluent way.
///
/// Named `FluentMotionFacet` because the plain name belongs to the
/// language's own duration set (`FluentMotion` in `fluent_motion.dart`),
/// which every control in this package already reads; a facet that shadowed
/// it would make half the package's imports ambiguous.
///
/// Both members answer with a FADE on the language's published clock: WinUI
/// brings content in and out with its fade theme animations
/// (`FadeInThemeAnimation` / `FadeOutThemeAnimation`, the XAML "fade in/out
/// animations" the guidance prescribes for "bringing an item into view or
/// removing it"), and the reference feeds every such implicit change from
/// the same four-step duration set this skin carries
/// (fluent_ui@4.16.1 lib/src/styles/theme.dart:440-443) on the one standard
/// curve (theme.dart:197,447, `Curves.easeInOut`). The role-to-duration
/// judgement lives in `FluentMotionDurations`, beside the constants, so the
/// one place a role changes speed is a line in that file.
///
/// The vehicle is [AnimatedSwitcher] - the toolkit's own primitive for "one
/// child became another in place" - which is the same mechanism the
/// Material facet and (at `Duration.zero`) the blueprint ride, because the
/// mechanism is the contract's semantics: what a skin owns is the clock and
/// the curve, and Fluent's are not Material's. A zero animation scale
/// resolves every duration to zero: the user who turned motion off gets
/// state changes that are simply true, not fast.
final class FluentMotionFacet implements SkinMotion {
  /// Builds the motion facet.
  const FluentMotionFacet();

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
    duration: FluentMotionDurations.resolve(context, role),
    switchInCurve: FluentMotion.curve,
    switchOutCurve: FluentMotion.curve,
    child: visible
        // The key tells the switcher that "shown" and "hidden" are
        // different children rather than one child rebuilding, which is
        // what makes the fade run at all.
        ? KeyedSubtree(key: const ValueKey<bool>(true), child: child.mount())
        : const SizedBox.shrink(key: ValueKey<bool>(false)),
  );

  /// One thing replaced another, in the same place.
  ///
  /// [stateKey] is honoured structurally as well as visually: it keys the
  /// mounted subtree, so when the key changes the framework discards the
  /// old element and its state instead of quietly updating it in place, and
  /// the switcher cross-fades the two. That is the whole meaning of "one
  /// thing became another rather than one thing merely rebuilding", and it
  /// is the same key discipline the blueprint keeps at `Duration.zero`.
  @override
  Widget swap(
    BuildContext context, {
    required ContentPort child,
    required Object stateKey,
    MotionRole role = MotionRole.transition,
  }) => AnimatedSwitcher(
    duration: FluentMotionDurations.resolve(context, role),
    switchInCurve: FluentMotion.curve,
    switchOutCurve: FluentMotion.curve,
    child: KeyedSubtree(key: ValueKey<Object>(stateKey), child: child.mount()),
  );
}
