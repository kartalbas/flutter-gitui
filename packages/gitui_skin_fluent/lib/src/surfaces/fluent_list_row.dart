import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_checkbox.dart';
import '../controls/fluent_info_badge.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_surface_parts.dart';

/// The Fluent answer to `surfaces.listRow`: the WinUI ListViewItem, drawn.
///
/// Anatomy and states from the reference's ListTile
/// (fluent_ui@4.16.1 lib/src/controls/surfaces/list_tile.dart):
///
///  * the 40 epx one-line minimum inside a 4/2 margin, corner 4
///    (:5,:15-23);
///  * the subtle fill ladder, with a SELECTED row wearing the hover fill
///    at rest (:275-286);
///  * `RowSelection.primary` marks itself with the 3 epx accent pill,
///    animated at the medium step and collapsing while pressed
///    (:363-400) - WinUI's single-selection vocabulary;
///  * `RowSelection.multi` marks itself with the checked checkbox at its
///    head, drawn inert exactly as the reference draws it - the ROW
///    answers the press, not the mark (:346-362);
///  * the title in the item-title role over the subtitle in the detail
///    role and the secondary ink (:303-314, through this skin's own type
///    door rather than the reference's one-off 16).
///
/// Departures, each stated rather than silent:
///
///  * the selection region is one width (12, the `none` placeholder's,
///    :288) in every mode. The reference reserves 12 for `none` and 11
///    for the pill because its selection MODE is a list-level fact; the
///    contract states selection per row, and siblings whose start edges
///    differ by a pixel would read as a rendering fault;
///  * the row is NOT its own Tab stop: the application's roving-highlight
///    contract owns the keyboard, so the row's focus node refuses focus -
///    the same decision the Material card registers as CARD-003.
final class FluentListRow extends StatefulWidget {
  /// Draws [spec] in Fluent.
  const FluentListRow({super.key, required this.spec});

  /// What the application declared.
  final ListRowSpec spec;

  @override
  State<FluentListRow> createState() => _FluentListRowState();
}

class _FluentListRowState extends State<FluentListRow> {
  /// Refuses focus: the collection is the Tab stop, not the row.
  final FocusNode _focusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'FluentListRow',
  );

  /// Recognises the double click from the interval between taps, so the
  /// row can act on the press.
  final FluentTapInterval _taps = FluentTapInterval();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _operable =>
      widget.spec.onTap != null ||
      widget.spec.onActivate != null ||
      widget.spec.onContextMenu != null;

  @override
  Widget build(BuildContext context) {
    final ListRowSpec spec = widget.spec;
    final FluentThemeData theme = FluentTheme.of(context);
    final bool selected = spec.selection != RowSelection.none;

    return Semantics(
      container: true,
      selected: selected,
      child: FluentPressable(
        mergeSemantics: false,
        focusNode: _focusNode,
        onPressed: spec.onTap == null && spec.onActivate == null
            ? null
            : () => _taps.tap(spec.onTap, spec.onActivate),
        onContextMenu: spec.onContextMenu,
        builder: (BuildContext context, Set<WidgetState> states) {
          final FluentResources res = theme.resources;
          // A row with no affordances at all is a container, not a
          // disabled control: it wears no state at all.
          final Set<WidgetState> live = _operable
              ? states
              : const <WidgetState>{};
          final Color foreground = FluentSurfaceInk.rowForeground(res, live);
          return AnimatedContainer(
            // The container answers a state change at the faster step on
            // the standard curve, exactly as every control's does
            // (buttons/base.dart:218-219).
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            margin: FluentSurfaceMetrics.tileMargin,
            constraints: const BoxConstraints(
              minHeight: FluentSurfaceMetrics.tileMinHeight,
              minWidth: FluentSurfaceMetrics.tileMinWidth,
            ),
            decoration: BoxDecoration(
              color: FluentSurfaceInk.tileFill(res, live, selected: selected),
              borderRadius: BorderRadius.circular(
                FluentSurfaceMetrics.tileCornerRadius,
              ),
            ),
            child: Row(
              children: <Widget>[
                _selectionRegion(theme, spec, live),
                Expanded(
                  child: Padding(
                    padding: FluentSurfaceMetrics.tilePadding,
                    child: DefaultTextStyle(
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.body,
                      ).copyWith(color: foreground),
                      child: Row(
                        children: <Widget>[
                          if (spec.leading != null) ...<Widget>[
                            spec.leading!.mount(),
                            const SizedBox(
                              width: FluentSurfaceMetrics.tileLeadingGap,
                            ),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                DefaultTextStyle(
                                  style: FluentTypeResolution.styleOf(
                                    context,
                                    TextRole.itemTitle,
                                  ).copyWith(color: foreground),
                                  child: spec.title.mount(),
                                ),
                                if (spec.subtitle != null)
                                  DefaultTextStyle(
                                    style:
                                        FluentTypeResolution.styleOf(
                                          context,
                                          TextRole.detail,
                                        ).copyWith(
                                          color: res.textFillColorSecondary,
                                        ),
                                    child: spec.subtitle!.mount(),
                                  ),
                              ],
                            ),
                          ),
                          if (spec.badgeCount != null) ...<Widget>[
                            const SizedBox(width: FluentMetrics.spaceS),
                            FluentInfoBadge(label: '${spec.badgeCount}'),
                          ],
                          if (spec.trailing != null) ...<Widget>[
                            const SizedBox(width: FluentMetrics.spaceS),
                            spec.trailing!.mount(),
                          ],
                          if (spec.menu.isNotEmpty) ...<Widget>[
                            const SizedBox(width: FluentMetrics.spaceS),
                            FluentMenuAnchorButton(entries: spec.menu),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The row's start: the pill, the checked mark, or the placeholder -
  /// all inside the same 12 epx reservation (see the class doc).
  Widget _selectionRegion(
    FluentThemeData theme,
    ListRowSpec spec,
    Set<WidgetState> states,
  ) {
    switch (spec.selection) {
      case RowSelection.none:
        return const SizedBox(width: FluentSurfaceMetrics.tileSelectionSlot);
      case RowSelection.primary:
        return SizedBox(
          width: FluentSurfaceMetrics.tileSelectionSlot,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              end: FluentSurfaceMetrics.pillEndGap,
            ),
            child: FluentSelectionPill(
              selected: true,
              pressed: states.contains(WidgetState.pressed),
              containerFocused: spec.containerFocused,
            ),
          ),
        );
      case RowSelection.multi:
        // The reference's multiple-selection mark, inert on purpose: it
        // states the row's gathered-ness and the ROW answers the press
        // (list_tile.dart:352-361, IgnorePointer + ExcludeFocus).
        return const Padding(
          padding: EdgeInsetsDirectional.only(start: 6, end: 12),
          child: ExcludeSemantics(
            child: FluentCheckboxBox(value: true, states: <WidgetState>{}),
          ),
        );
    }
  }
}
