import 'package:flutter/widgets.dart';

/// Fluent's control metrics, stated once.
///
/// Every number here is published or read out of the reference checkout,
/// never tuned by eye; the citation sits beside each value.
abstract final class FluentGeometry {
  /// Controls round at 4 epx.
  ///
  /// WinUI `ControlCornerRadius` (XAML theme resources); confirmed all over
  /// the reference, e.g. fluent_ui@4.16.1
  /// lib/src/controls/buttons/theme.dart:334 (`BorderRadius.circular(4)`).
  static const double controlCornerRadius = 4;

  /// Overlays and surfaces round at 8 epx.
  ///
  /// WinUI `OverlayCornerRadius` (XAML theme resources). Not consumed by any
  /// control yet; declared with the control radius so the pair the language
  /// defines stays a pair.
  static const double overlayCornerRadius = 8;

  /// The fully-rounded corner of a stadium-shaped part: the switch track
  /// and knob, the InfoBadge.
  ///
  /// The reference writes `BorderRadius.circular(100)` at every such site
  /// (fluent_ui@4.16.1 lib/src/controls/inputs/toggle_switch.dart:434-441,
  /// lib/src/controls/utils/info_badge.dart:101,115): any radius at least
  /// half the part's extent renders the same stadium, and 100 is the
  /// reference's own spelling of "always enough".
  static const double stadiumRadius = 100;

  /// A button's content padding: 11 / 5 / 11 / 6 (start / top / end /
  /// bottom). The asymmetric bottom is WinUI's own optical correction for
  /// Segoe's metrics, not a typo.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/buttons/button.dart:6-11
  /// (`kDefaultButtonPadding`, "matches the padding used by WinUI button
  /// controls").
  static const EdgeInsetsGeometry buttonPadding =
      EdgeInsetsDirectional.fromSTEB(11, 5, 11, 6);

  /// A control outline is one physical stroke.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/utils/
  /// rounded_rectangle_gradient_border.dart:70 (`width = 1.0`) and the
  /// default `BorderSide.width` the solid states use
  /// (buttons/theme.dart:331-335).
  static const double strokeWidth = 1;

  /// The glyph size inside a button when nothing asks otherwise.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/buttons/base.dart:229
  /// (`size: iconSize ?? 14.0`).
  static const double buttonIconSize = 14;

  /// The high-visibility focus rectangle's outer stroke: 2 epx.
  ///
  /// WinUI focus visuals ("Focus visuals" design page: 2px outer border);
  /// fluent_ui@4.16.1 lib/src/controls/utils/focus.dart:213-215.
  static const double focusStrokeOuterWidth = 2;

  /// Its inner stroke: 1 epx.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/utils/focus.dart:217 (a default
  /// `BorderSide`, width 1).
  static const double focusStrokeInnerWidth = 1;

  /// The rectangle's corner radius: 6 epx - the 4 epx control corner grown
  /// by the 2 epx the rectangle stands off the control.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/utils/focus.dart:212
  /// (`BorderRadius.circular(6)`).
  static const double focusCornerRadius = 6;

  /// How far the rectangle sits outside the control: the sum of both stroke
  /// widths, so neither stroke ever covers the control itself.
  ///
  /// fluent_ui@4.16.1 lib/src/controls/utils/focus.dart:93-108 (`borderWidth
  /// = primary.width + secondary.width`, offsets `-borderWidth`,
  /// `renderOutside` defaulting true at focus.dart:220).
  static const double focusRingOffset =
      focusStrokeOuterWidth + focusStrokeInnerWidth;
}
