import 'package:flutter/widgets.dart';

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
