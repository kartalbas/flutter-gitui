import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'fluent_request_scope.dart';

/// Fluent's animation constants, stated once.
///
/// WinUI publishes control motion as a small set of durations
/// (`ControlFasterAnimationDuration` and friends); the reference checkout
/// carries them verbatim at fluent_ui@4.16.1 lib/src/styles/theme.dart:440-447
/// and feeds them to every implicit animation a control runs
/// (`buttons/base.dart:218-238`). The FEEL of a Fluent control answering the
/// pointer is these numbers, which is why the behaviour suite pins them from
/// the paint stream rather than trusting this file.
abstract final class FluentMotion {
  /// A control's container answering a state change: 83 ms.
  ///
  /// fluent_ui@4.16.1 lib/src/styles/theme.dart:440
  /// (`fasterAnimationDuration`); consumed by the button container at
  /// buttons/base.dart:218-219.
  static const Duration faster = Duration(milliseconds: 83);

  /// A control's text answering a state change, and the length of the
  /// pressed flash a keyboard activation shows: 167 ms.
  ///
  /// fluent_ui@4.16.1 lib/src/styles/theme.dart:441
  /// (`fastAnimationDuration`); consumed at buttons/base.dart:231-232 and
  /// controls/utils/hover_button.dart:249.
  static const Duration fast = Duration(milliseconds: 167);

  /// Larger transitions: 250 ms. fluent_ui@4.16.1
  /// lib/src/styles/theme.dart:442 (`mediumAnimationDuration`).
  static const Duration medium = Duration(milliseconds: 250);

  /// The slowest published step: 358 ms. fluent_ui@4.16.1
  /// lib/src/styles/theme.dart:443 (`slowAnimationDuration`).
  static const Duration slow = Duration(milliseconds: 358);

  /// The curve every control-state animation runs on.
  ///
  /// fluent_ui@4.16.1 lib/src/styles/theme.dart:197 (`standardCurve =
  /// Curves.easeInOut`), installed as the theme default at theme.dart:447.
  static const Curve curve = Curves.easeInOut;

  /// How long a pointer release keeps the pressed state before letting go:
  /// 100 ms. Without it a fast click never shows its press at all.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/utils/hover_button.dart:316-321
  /// (`onTapUp` delays clearing `_pressing` by 100 ms).
  static const Duration pressedRelease = Duration(milliseconds: 100);
}

/// How this skin turns a [MotionRole] into a length of time.
///
/// The mapping half is the judgement and it is stated once, here, so the one
/// place a role changes speed is a line in this file - the same arrangement
/// as `MaterialMotionDurations` (`gitui_skin_material/lib/src/
/// material_theme.dart:704`), resolved against Fluent's own published set:
///
///  * [MotionRole.feedback] -> [FluentMotion.fast] (167 ms): the step the
///    language answers an interaction with - a control's text answering a
///    state change (buttons/base.dart:231-232), the pressed flash of a
///    keyboard activation (hover_button.dart:249), and the default flyout
///    transition (flyouts/flyout.dart:807, `transitionDuration ??=
///    theme.fastAnimationDuration`). [FluentMotion.faster] is deliberately
///    not reachable from here: 83 ms is a control container's internal step,
///    consumed by the controls that own it.
///  * [MotionRole.transition] -> [FluentMotion.medium] (250 ms): one thing
///    becoming another (theme.dart:442).
///  * [MotionRole.emphasis] -> [FluentMotion.slow] (358 ms), the slowest
///    published step (theme.dart:443). The vocabulary's own doc records that
///    Fluent has no emphasis FAMILY the way Material's `Easing.emphasized*`
///    is one - what this language can honestly offer a change the user must
///    not miss is its slowest duration on its one standard curve, and that
///    judgement is registered here rather than hidden.
abstract final class FluentMotionDurations {
  /// The duration [role] takes at the user's [scale].
  ///
  /// [MotionRole.instant] is zero regardless of the scale, because "state
  /// that must be true before the user's eye arrives" is not a fast
  /// animation - it is no animation. A zero [scale] resolves everything to
  /// zero: the user who turned motion off gets state changes that are
  /// simply true. The multiply-and-round arithmetic is the same the
  /// Material skin applies to the same user setting
  /// (`material_theme.dart:719-728`), so one preference means one thing
  /// across skins.
  static Duration of(MotionRole role, double scale) {
    final Duration base = switch (role) {
      MotionRole.instant => Duration.zero,
      MotionRole.feedback => FluentMotion.fast,
      MotionRole.transition => FluentMotion.medium,
      MotionRole.emphasis => FluentMotion.slow,
    };
    if (base == Duration.zero || scale == 0) return Duration.zero;
    return Duration(milliseconds: (base.inMilliseconds * scale).round());
  }

  /// The duration [role] takes under the request in force at [context].
  ///
  /// Falls back to a scale of 1.0 where no scope is installed - only a test
  /// rendering a facet without its root - which renders the language's own
  /// speed rather than freezing or hiding motion.
  static Duration resolve(BuildContext context, MotionRole role) =>
      of(role, FluentRequestScope.maybeOf(context)?.animationScale ?? 1.0);
}
