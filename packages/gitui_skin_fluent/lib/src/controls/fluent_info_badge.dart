import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';

/// The WinUI InfoBadge, shared by every surface that rides a count or a
/// one-word status on something else: a stadium at a 16 epx minimum with
/// 4 epx side padding and its value at 11
/// (fluent_ui@4.16.1 lib/src/controls/utils/info_badge.dart:106-125; 11 is
/// the `InfoBadgeValueFontSize` resource at :119).
///
/// The fill is the preset the tone means (microsoft-ui-xaml
/// InfoBadge_themeresources.xaml): Attention = the accent brush,
/// Informational = the solid neutral, Success / Caution / Critical = the
/// system fills - and `FluentInk.foreground` already answers accent,
/// success, warning and danger with exactly those brushes, so every
/// non-neutral tone resolves through it. The git tones land on this
/// skin's own palette the same way, because WinUI has no badge preset for
/// "this file is staged". `ControlScale` deliberately does not appear:
/// the InfoBadge is a one-size control, the same registered collapse the
/// worded controls carry.
final class FluentInfoBadge extends StatelessWidget {
  /// Draws [label] in [tone]'s fill.
  const FluentInfoBadge({
    super.key,
    required this.label,
    this.tone = Tone.accent,
    this.secondary,
    this.icon,
  });

  /// What the badge says.
  final String label;

  /// What it means; the attention (accent) badge when unstated, which is
  /// WinUI's default InfoBadge.
  final Tone tone;

  /// The other half of a paired statistic, or null.
  final BadgeFact? secondary;

  /// A mark beside the words. The Fluent glyph table does not exist yet
  /// (the registered gap every `IconRole` slot in this package carries),
  /// so the slot reserves its box on the compact rung and draws nothing
  /// in it.
  final IconRole? icon;

  /// The stadium's minimum extent (info_badge.dart:106-112).
  static const double minExtent = 16;

  /// The side padding (info_badge.dart:113-117).
  static const double sidePad = 4;

  /// The value's size (info_badge.dart:119, `InfoBadgeValueFontSize`).
  static const double valueFontSize = 11;

  /// The fill [tone] means; see the class doc.
  static Color fillFor(FluentThemeData theme, Tone tone) =>
      tone == Tone.neutral || tone == Tone.muted
      ? theme.resources.systemFillColorSolidNeutral
      : FluentInk.foreground(theme, tone);

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final TextStyle value = FluentTypeResolution.styleOf(
      context,
      TextRole.micro,
      // The InfoBadge's own metric for its value - the same override the
      // icon button's badge records.
    ).copyWith(fontSize: valueFontSize);

    // A paired badge cannot fill with either fact's colour - one fill
    // cannot mean two things - so the surface takes the quiet neutral
    // wash and each fact's own foreground carries its meaning; the
    // palette already holds AA over every surface this skin paints.
    if (secondary != null) {
      return _stadium(
        fill: theme.resources.systemFillColorNeutralBackground,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _glyphSlot(),
            Text(
              label,
              style: value.copyWith(color: FluentInk.foreground(theme, tone)),
            ),
            const SizedBox(width: sidePad),
            Text(
              secondary!.label,
              style: value.copyWith(
                color: FluentInk.foreground(theme, secondary!.tone),
              ),
            ),
          ],
        ),
      );
    }

    final Color fill = fillFor(theme, tone);
    return _stadium(
      fill: fill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _glyphSlot(),
          Text(
            label,
            textAlign: TextAlign.center,
            style: value.copyWith(color: FluentInk.foregroundOn(fill)),
          ),
        ],
      ),
    );
  }

  /// The reserved box an [IconRole] will occupy when the glyph table
  /// lands; nothing when the badge carries no mark.
  Widget _glyphSlot() => icon == null
      ? const SizedBox.shrink()
      : const Padding(
          padding: EdgeInsetsDirectional.only(end: sidePad),
          child: SizedBox.square(dimension: FluentMetrics.glyphCompact),
        );

  Widget _stadium({required Color fill, required Widget child}) => Container(
    constraints: const BoxConstraints(
      minWidth: minExtent,
      minHeight: minExtent,
    ),
    padding: const EdgeInsetsDirectional.only(
      start: sidePad,
      end: sidePad,
      bottom: 1,
    ),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(FluentGeometry.stadiumRadius),
    ),
    child: child,
  );
}

/// The count form of the badge: WinUI's value InfoBadge in the attention
/// (accent) preset, which is what a navigation pane item, a selection
/// strip and a list row all ride their counts on.
final class FluentInfoBadgePill extends StatelessWidget {
  /// Draws [count].
  const FluentInfoBadgePill({super.key, required this.count});

  /// How many.
  final int count;

  @override
  Widget build(BuildContext context) => FluentInfoBadge(label: '$count');
}

/// The riding form: the count pill on [child]'s top end corner, which is
/// how WinUI parks an InfoBadge on an icon-only control - the icon
/// button's badge and a compact pane item's (fluent_ui@4.16.1
/// lib/src/controls/navigation/navigation_view/pane_items.dart:283-295
/// positions it off the mark's corner exactly like this).
///
/// A separate widget rather than a flag on [FluentInfoBadge], because the
/// pill is the one drawing either way - this only decides WHERE it stands.
final class FluentInfoBadgeRider extends StatelessWidget {
  /// Rides [count] on [child]'s top end corner.
  const FluentInfoBadgeRider({
    super.key,
    required this.count,
    required this.child,
  });

  /// How many.
  final int count;

  /// The control the badge rides on.
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      child,
      PositionedDirectional(
        top: -4,
        end: -4,
        child: FluentInfoBadgePill(count: count),
      ),
    ],
  );
}
