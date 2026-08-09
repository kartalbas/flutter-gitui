import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_checkbox.dart';
import 'fluent_pressable.dart';

/// The Fluent answer to `SkinControls.iconButton`: WHAT CAN THE USER DO
/// HERE, AS A MARK - drawn against the WinUI IconButton and ToggleButton.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/buttons/icon_button.dart:110-133):
///
///  * 8 epx padding around the glyph slot, corner 4;
///  * the SUBTLE ladder: transparent at rest, `SubtleFillColorSecondary`
///    hovered, `Tertiary` pressed (via `uncheckedInputColor` with
///    `transparentWhenNone`, buttons/theme.dart:364-380), the standard
///    button's disabled fill when disabled;
///  * a SELECTED icon button wears the ToggleButton's checked treatment -
///    the checked-input accent ramp under the on-accent foreground
///    (inputs/toggle_button.dart:162-169) - and `selected: false` stays
///    plain, so the three states of `IconButtonSpec.selected` stay three.
///
/// [ControlScale] sizes the glyph slot on the Fluent icon ramp
/// (12 / 16 / 20, `FluentSpacing.glyph`); the box follows from the fixed
/// 8 epx padding, which is the one-height answer this language gives every
/// control.
///
/// **The mark itself is not drawn yet**, and that is the registered Fluent
/// glyph-table gap, not a decision of this member: an [IconRole] resolves
/// through a per-language glyph vocabulary this skin does not have (see
/// `FluentButton`'s doc). The slot keeps the glyph's exact box so the
/// control's geometry, states, focus rectangle, badge and accessible name
/// are all final; the day the table lands, the mark drops into a box that
/// never moves. The control stays operable throughout because the tooltip
/// is its accessible name and the box is its full hit target.
///
/// **The tooltip is announced, not shown**: a hovering tooltip is an
/// overlay surface and this skin has no overlay facet yet - the same
/// registered gap `FluentButton` carries for `ButtonSpec.tooltip`.
final class FluentIconButton extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentIconButton({super.key, required this.spec});

  /// What the application declared.
  final IconButtonSpec spec;

  /// The padding around the glyph slot (icon_button.dart:113-114).
  static const double slotPadding = 8;

  /// The control corner (icon_button.dart:131-133).
  static const double cornerRadius = 4;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final bool disabled = spec.onPressed == null;
    final double glyphExtent = FluentSpacing.glyph(spec.scale);

    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      toggled: spec.selected,
      tooltip: spec.tooltip,
      child: FluentPressable(
        onPressed: spec.onPressed,
        semanticsLabel: spec.tooltip,
        builder: (BuildContext context, Set<WidgetState> states) {
          final FluentResources res = theme.resources;
          final bool selected = spec.selected ?? false;

          final Color fill;
          final Color foreground;
          if (selected) {
            // The ToggleButton's checked treatment
            // (toggle_button.dart:162-169; foreground per
            // filled_button.dart:113-123).
            fill = fluentCheckedInputColor(theme, states);
            foreground = states.contains(WidgetState.pressed)
                ? res.textOnAccentFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.textOnAccentFillColorDisabled
                : res.textOnAccentFillColorPrimary;
          } else {
            // icon_button.dart:116-130.
            fill = states.contains(WidgetState.disabled)
                ? res.controlFillColorDisabled
                : states.contains(WidgetState.pressed)
                ? res.subtleFillColorTertiary
                : states.contains(WidgetState.hovered)
                ? res.subtleFillColorSecondary
                : res.subtleFillColorTransparent;
            foreground = states.contains(WidgetState.disabled)
                ? res.textFillColorDisabled
                : FluentInk.foreground(theme, spec.tone);
          }

          final Widget box = AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            padding: const EdgeInsets.all(slotPadding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground, size: glyphExtent),
              // The glyph slot, held at its exact extent until the Fluent
              // glyph table lands - see the class doc.
              child: SizedBox.square(dimension: glyphExtent),
            ),
          );

          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: spec.badgeCount == null
                ? box
                : _Badged(count: spec.badgeCount!, child: box),
          );
        },
      ),
    );
  }
}

/// A count riding the control's top end corner, drawn as the WinUI
/// InfoBadge (fluent_ui@4.16.1 lib/src/controls/utils/info_badge.dart:
/// 106-125): a 16 epx minimum stadium, 4 epx side padding, the value at
/// 11 epx (:119, the `InfoBadgeValueFontSize` resource) - in the accent
/// brush under the on-accent foreground, which is WinUI's attention badge.
final class _Badged extends StatelessWidget {
  const _Badged({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        PositionedDirectional(
          top: -4,
          end: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              end: 4,
              bottom: 1,
            ),
            decoration: BoxDecoration(
              color: theme.accent.defaultBrushFor(theme.brightness),
              borderRadius: BorderRadius.circular(FluentGeometry.stadiumRadius),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: FluentTypeResolution.styleOf(context, TextRole.micro)
                  .copyWith(
                    // InfoBadgeValueFontSize, info_badge.dart:119.
                    fontSize: 11,
                    color: theme.resources.textOnAccentFillColorPrimary,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
