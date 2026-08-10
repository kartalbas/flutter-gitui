import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_info_badge.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_focus_ring.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_surface_parts.dart';

/// The Fluent answer to `surfaces.tabs`: the WinUI TabView, drawn.
///
/// Anatomy and states from the reference (fluent_ui@4.16.1
/// lib/src/controls/navigation/tab_view/tab.dart, tab_view.dart):
///
///  * a 34 epx strip whose tabs round only their top corners at 6
///    (tab_view.dart:14, tab.dart:384);
///  * the selected tab fills with the content layer
///    (`SolidBackgroundFillColorTertiary`) and MERGES into the body,
///    which is painted in the same layer - that continuity is the
///    control's whole idea (tab.dart:371-372);
///  * an unselected tab rests transparent, hovers and presses on the
///    `LayerOnMicaBaseAlt` ladder, and keeps the SECONDARY foreground
///    until it is hovered or chosen (tab.dart:351-382);
///  * only the selected body is built: the reference's TabView shows one
///    body at a time and builds no neighbours, which is this language's
///    own answer to `TabEntry.body` being a builder - where Material's
///    page view holds every neighbour alive.
///
/// The strip scrolls horizontally when the tabs outgrow it, as the
/// reference's does; the body fills the height the member is given, so
/// this member needs a bounded one - the same shape `TabBarView` asserts
/// and both floor sites already provide.
final class FluentTabs extends StatelessWidget {
  /// Draws [spec] in Fluent.
  const FluentTabs({super.key, required this.spec});

  /// What the application declared.
  final TabSetSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final int selected = spec.tabs.isEmpty
        ? -1
        : spec.selectedIndex.clamp(0, spec.tabs.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: FluentSurfaceMetrics.tabHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int index = 0; index < spec.tabs.length; index++)
                  _FluentTab(
                    entry: spec.tabs[index],
                    selected: index == selected,
                    onSelect: () => spec.onSelect(index),
                  ),
              ],
            ),
          ),
        ),
        // The content layer the selected tab merges into (tab.dart:372
        // is the tab's half of it; the body is the other half).
        Expanded(
          child: ColoredBox(
            color: res.solidBackgroundFillColorTertiary,
            child: selected < 0
                ? const SizedBox.shrink()
                : spec.tabs[selected].body().mount(),
          ),
        ),
      ],
    );
  }
}

/// One tab of the strip.
final class _FluentTab extends StatelessWidget {
  const _FluentTab({
    required this.entry,
    required this.selected,
    required this.onSelect,
  });

  final TabEntry entry;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return Semantics(
      selected: selected,
      child: FluentPressable(
        onPressed: onSelect,
        semanticsLabel: entry.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          // Fill: tab.dart:368-382. The selected tab paints the content
          // layer; the rest ride the LayerOnMicaBaseAlt ladder.
          final Color fill = selected
              ? res.solidBackgroundFillColorTertiary
              : states.contains(WidgetState.pressed)
              ? res.layerOnMicaBaseAltFillColorDefault
              : states.contains(WidgetState.hovered)
              ? res.layerOnMicaBaseAltFillColorSecondary
              : res.layerOnMicaBaseAltFillColorTransparent;
          // Foreground: tab.dart:351-365. Unselected tabs speak in the
          // secondary ink until hovered.
          final Color foreground = selected
              ? res.textFillColorPrimary
              : states.contains(WidgetState.pressed)
              ? res.textFillColorSecondary
              : states.contains(WidgetState.hovered)
              ? res.textFillColorPrimary
              : states.contains(WidgetState.disabled)
              ? res.textFillColorDisabled
              : res.textFillColorSecondary;
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              height: FluentSurfaceMetrics.tabHeight,
              padding: selected
                  ? FluentSurfaceMetrics.tabSelectedPadding
                  : FluentSurfaceMetrics.tabPadding,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(FluentSurfaceMetrics.tabTopCornerRadius),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // The mark's slot at the standard 16 with the
                  // reference's 10 epx gap (tab.dart:441); the glyph
                  // table is the registered gap.
                  if (entry.icon != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: FluentMetrics.glyphNormal,
                          color: foreground,
                        ),
                        child: const SizedBox.square(
                          dimension: FluentMetrics.glyphNormal,
                        ),
                      ),
                    ),
                  Text(
                    entry.label,
                    style:
                        FluentTypeResolution.styleOf(
                          context,
                          TextRole.control,
                        ).copyWith(
                          // The tab's own 12 over the control step
                          // (tab.dart:416-417) - a control-private
                          // metric like the InfoBadge's 11.
                          fontSize: FluentSurfaceMetrics.tabFontSize,
                          color: foreground,
                        ),
                  ),
                  if (entry.badgeCount != null)
                    Padding(
                      // The badge rides at the reference's 4 epx gap
                      // (tab.dart:470).
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: FluentInfoBadge(label: '${entry.badgeCount}'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
