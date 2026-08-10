import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_button.dart';
import '../controls/fluent_checkbox.dart';
import '../controls/fluent_control_marks.dart';
import '../controls/fluent_info_badge.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import '../surfaces/fluent_commit_graph.dart';
import '../surfaces/fluent_list_row.dart';
import '../surfaces/fluent_surface_parts.dart';
import '../surfaces/fluent_tabs.dart';
import '../surfaces/fluent_tree.dart';

/// Things that hold other things, drawn against Fluent 2 - with no widget
/// library underneath.
///
/// **How Fluent grounds a surface**, because it is the opposite decision
/// from Material's and every member below rests on it: Fluent has no tonal
/// elevation. A surface is a LAYERED FILL plus a ONE-EPX STROKE - a card is
/// `CardBackgroundFillColorDefault` behind `CardStrokeColorDefault`
/// (fluent_ui@4.16.1 lib/src/controls/surfaces/card.dart:107-112), a raised
/// state is the subtle hover layer composited OVER the resting fill, and
/// only the overlay tier casts a shadow. `FluentInk.depth` carries that
/// grammar and every container here resolves through it.
///
/// **The registered gaps of this slice**, reported rather than hidden:
///
///  * **The Fluent glyph table does not exist yet** - the same gap every
///    facet of this package carries. Every [IconRole] slot reserves its
///    exact box on the published icon ramp and draws nothing in it; a slot
///    whose meaning is stated (`TreeNodeSpec.leadingTone`, a banner's
///    severity mark) carries that meaning as the slot's own `IconTheme`
///    colour, so the day the table lands the mark drops in already toned.
///  * **The overlay facet is only partially real.** A row's or node's
///    menu anchor is this facet's own control and opens through
///    [Overlays.menu] - the application's one overlay door - which the
///    overlay facet's point-anchored flyout already answers; the members
///    still fenced there (tooltip flyouts among them) keep every
///    `tooltip` here announced to the semantics tree rather than shown,
///    and a selectable block renders its selection without a floating
///    toolbar.
///  * **Two controls name themselves in English** ('Dismiss' on a
///    banner's close, 'Menu' on a row's anchor): the contract gives
///    neither a name slot, the Material skin borrows its framework's
///    localizations, and a drawn skin has none to borrow. Registered as a
///    contract finding, not repaired by inventing a slot.
final class FluentSurfaces implements SkinSurfaces {
  /// Builds the Fluent surfaces.
  const FluentSurfaces();

  // ---------------------------------------------------------------------
  // Containers
  // ---------------------------------------------------------------------

  /// **Here is one self-contained object the user can pick** - a
  /// repository, a workspace, a project.
  ///
  /// The WinUI Card: a layer fill behind a 1 epx stroke at corner 4
  /// (card.dart:50-54,:107-112), with 12 the interior's own default inset
  /// (card.dart:50) - the contract's [Inset] resolves the actual value.
  /// Depth is the layer grammar, not a shadow ramp: `flush` paints
  /// nothing, `resting` the card pair, `raised` composites the subtle
  /// hover layer over the resting fill, and only `overlay` lifts onto the
  /// solid flyout surface under the flyout stroke and shadow
  /// (`FluentInk.depth`).
  ///
  /// Selection is WinUI's item-selection vocabulary rather than a tonal
  /// container swap: a selected card wears a 2 epx accent stroke, and a
  /// multi-selected one adds the checked mark in its top end corner - the
  /// GridView item's multiple-selection treatment (WinUI "Selection modes
  /// overview": multiple selection marks each item with a checkbox).
  /// While the collection's focus lives elsewhere the stroke falls back to
  /// the strong neutral, still clearly the selection, no longer claiming
  /// the keyboard - the same pairing the selection pill documents.
  ///
  /// An object's own identity ([CardSpec.tone]) is worn on the STROKE: in
  /// a language whose card is a fill plus a stroke, the stroke is where an
  /// edge colour means something, and washing the fill would repaint the
  /// ground the content was composed against.
  @override
  Widget card(BuildContext context, CardSpec spec) => _FluentCard(spec: spec);

  /// **Here is a named standing region of the interface** - the commit
  /// log, the file tree, the details pane.
  ///
  /// The card surface under the Expander's header anatomy: the header is
  /// a 42 epx minimum band starting 16 from the edge
  /// (expander.dart:322,:343) whose title speaks in Body Strong - the
  /// section-title answer the type facet records, the same step the
  /// InfoBar titles with - separated from the content by the language's
  /// own divider (`DividerStrokeColorDefault`). A panel does not expand;
  /// that is [disclosure]'s job, and the header actions are drawn as
  /// subtle worded buttons because a panel's actions carry words and the
  /// glyph half of the pair is the registered glyph-table gap.
  @override
  Widget panel(BuildContext context, PanelSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final FluentDepth depth = FluentInk.depth(theme, spec.elevation);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: depth.fill,
        border: Border.all(color: depth.stroke),
        borderRadius: BorderRadius.circular(FluentGeometry.controlCornerRadius),
        boxShadow: depth.shadows(FluentInk.shadowInk(theme.brightness)),
      ),
      child: DefaultTextStyle(
        style: FluentTypeResolution.styleOf(
          context,
          TextRole.body,
        ).copyWith(color: res.textFillColorPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: FluentSurfaceMetrics.expanderHeaderMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FluentSurfaceMetrics.expanderHeaderStartInset,
                  end: FluentMetrics.spaceS,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        spec.title,
                        style: FluentTypeResolution.styleOf(
                          context,
                          TextRole.sectionTitle,
                        ).copyWith(color: res.textFillColorPrimary),
                      ),
                    ),
                    for (final ToolbarActionEntry action in spec.actions)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: FluentMetrics.spaceXS,
                        ),
                        child: _PanelAction(action: action),
                      ),
                  ],
                ),
              ),
            ),
            _rule(res),
            Flexible(
              child: Padding(
                padding: EdgeInsets.all(FluentSpacing.inset(spec.inset)),
                child: spec.content.mount(),
              ),
            ),
            if (spec.footer != null) ...<Widget>[
              _rule(res),
              Padding(
                padding: EdgeInsets.all(FluentSpacing.inset(spec.inset)),
                child: spec.footer!.mount(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// **The user can choose to see more of this** - a settings section, a
  /// command-log entry, a stash row.
  ///
  /// The WinUI Expander, whole (fluent_ui@4.16.1
  /// lib/src/controls/surfaces/expander.dart): the 42 epx card-filled
  /// header whose bottom corners square off while it is open, the chevron
  /// in its own subtle 10-padded box answering the header's hover and
  /// press, the half-turn at the medium step, and the body on the QUIETER
  /// card layer (`CardBackgroundFillColorSecondary`) behind the same
  /// stroke. Expansion stays application state; this skin only animates
  /// the reveal, at the reference's own medium step.
  @override
  Widget disclosure(BuildContext context, DisclosureSpec spec) =>
      _FluentDisclosure(spec: spec);

  // ---------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------

  /// **Here is one entry in a list of like things.** [FluentListRow]: the
  /// WinUI ListViewItem - the subtle fill ladder, the accent selection
  /// pill, the checked mark for a gathered row - with every slot of the
  /// spec drawn.
  @override
  Widget listRow(BuildContext context, ListRowSpec spec) =>
      FluentListRow(spec: spec);

  /// **Here is a hierarchy the user walks, opens and picks from.**
  /// [FluentTree]: the WinUI TreeView at arity N - this skin owns the
  /// walk, the viewport and the reveal.
  @override
  Widget tree(BuildContext context, TreeSpec spec) => FluentTree(spec: spec);

  /// **Here are several views of the same subject; the user picks one.**
  /// [FluentTabs]: the WinUI TabView, whose selected tab merges into the
  /// content layer and which builds only the body on show.
  @override
  Widget tabs(BuildContext context, TabSetSpec spec) => FluentTabs(spec: spec);

  /// **Here is a table of values the user reads across and down.**
  ///
  /// Composed, not delegated, and that is the honest Fluent answer: WinUI
  /// ships no data grid, so the language's own parts do the job - the
  /// header band on the alternate solid ground under Body Strong, the
  /// language's divider as every rule, and the cells inset by
  /// [GridDensity] on the spacing ramp's tight / normal / roomy rungs.
  /// A short row's missing cells stay empty rather than collapsing the
  /// column: alignment is what the grid is FOR.
  @override
  Widget dataGrid(BuildContext context, DataGridSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final double pad = FluentSpacing.inset(switch (spec.density) {
      GridDensity.compact => Inset.tight,
      GridDensity.normal => Inset.normal,
      GridDensity.roomy => Inset.roomy,
    });
    if (spec.columns.isEmpty) return const SizedBox.shrink();

    TableRow line(List<Widget> cells, {Color? fill}) => TableRow(
      decoration: fill == null ? null : BoxDecoration(color: fill),
      children: <Widget>[
        for (int column = 0; column < spec.columns.length; column++)
          Padding(
            padding: EdgeInsets.all(pad),
            child: column < cells.length
                ? cells[column]
                : const SizedBox.shrink(),
          ),
      ],
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DefaultTextStyle(
          style: FluentTypeResolution.styleOf(
            context,
            TextRole.body,
          ).copyWith(color: res.textFillColorPrimary),
          child: Table(
            border: TableBorder.all(color: res.dividerStrokeColorDefault),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: <TableRow>[
              line(fill: res.solidBackgroundFillColorSecondary, <Widget>[
                for (final String column in spec.columns)
                  Text(
                    column,
                    style: FluentTypeResolution.styleOf(
                      context,
                      TextRole.sectionTitle,
                    ).copyWith(color: res.textFillColorPrimary),
                  ),
              ]),
              for (final List<ContentPort> row in spec.rows)
                line(<Widget>[
                  for (final ContentPort cell in row) cell.mount(),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Marks and small standing things
  // ---------------------------------------------------------------------

  /// **This region can be acted on, and must say so under the pointer and
  /// under the keyboard.**
  ///
  /// The subtle ladder at the control corner - nothing at rest, the
  /// subtle hover fill, the FAINTER pressed fill that recedes under the
  /// finger - riding the same [FluentPressable] every control of this
  /// package rides, so a pressable region hovers, presses, focuses and
  /// answers Enter and Space exactly like a button does. The focus
  /// rectangle is the language's two strokes and appears only from the
  /// keyboard. A selected region wears the selected tile's fill. The
  /// double click is recognised from the interval between taps so the
  /// single tap answers the press.
  @override
  Widget pressable(BuildContext context, PressableSpec spec) =>
      _FluentPressableRegion(spec: spec);

  /// **How many, riding on something else?**
  ///
  /// The WinUI InfoBadge, in the preset its tone means (InfoBadge
  /// theme resources: Attention = accent, Informational = solid neutral,
  /// Success / Caution / Critical = the system fills), and this skin's
  /// own git palette where WinUI has no word. [ControlScale] draws one
  /// box at every step: the InfoBadge is a one-size control, the same
  /// registered collapse the worded controls carry.
  @override
  Widget badge(BuildContext context, BadgeSpec spec) => FluentInfoBadge(
    label: spec.label,
    tone: spec.tone,
    secondary: spec.secondary,
    icon: spec.icon,
  );

  /// **Here is a named thing the user can take away again** - an active
  /// filter, a chosen tag.
  ///
  /// WinUI ships no chip; Fluent 2's Tag (fluent2.microsoft.design, Tag)
  /// is the model - a neutral rounded rectangle with an optional dismiss -
  /// and it is composed here from this package's own provenanced parts:
  /// the standard control fill and stroke at the control corner, the
  /// caption step for the label, the tone carried by the label's ink, and
  /// the removal as its own subtle control wearing the drawn dismiss
  /// cross at the compact rung. The removal is separately focusable and
  /// carries [TagSpec.removeTooltip] as its name, which the contract's
  /// own constructor guarantees exists.
  @override
  Widget tag(BuildContext context, TagSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final Color foreground = spec.tone == Tone.neutral
        ? res.textFillColorPrimary
        : FluentInk.foreground(theme, spec.tone);

    Widget body(Set<WidgetState> states) => AnimatedContainer(
      duration: FluentMotion.faster,
      curve: FluentMotion.curve,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FluentMetrics.spaceS,
        vertical: FluentMetrics.spaceXXS,
      ),
      decoration: BoxDecoration(
        // The standard control's fill ladder and resting stroke
        // (buttons/theme.dart:292-308,:326-350 - the flat stroke; the
        // elevation gradient belongs to a BUTTON, and a tag is not one).
        color: states.contains(WidgetState.pressed)
            ? res.controlFillColorTertiary
            : states.contains(WidgetState.hovered)
            ? res.controlFillColorSecondary
            : res.controlFillColorDefault,
        border: Border.all(color: res.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(FluentGeometry.controlCornerRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (spec.icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: FluentMetrics.spaceXS,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: FluentMetrics.glyphCompact,
                  color: foreground,
                ),
                child: const SizedBox.square(
                  dimension: FluentMetrics.glyphCompact,
                ),
              ),
            ),
          Text(
            spec.label,
            style: FluentTypeResolution.styleOf(
              context,
              TextRole.micro,
            ).copyWith(color: foreground),
          ),
        ],
      ),
    );

    final Widget pill = spec.onTap == null
        ? body(const <WidgetState>{})
        : FluentPressable(
            onPressed: spec.onTap,
            semanticsLabel: spec.label,
            builder: (BuildContext context, Set<WidgetState> states) =>
                FluentFocusRing(
                  focused: states.contains(WidgetState.focused),
                  child: body(states),
                ),
          );

    if (spec.onRemoved == null) return pill;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        pill,
        const SizedBox(width: FluentMetrics.spaceXS),
        _DismissButton(
          tooltip: spec.removeTooltip!,
          onPressed: spec.onRemoved!,
          size: FluentMetrics.glyphCompact,
        ),
      ],
    );
  }

  /// **Which person or thing is this?** - as a single compact mark.
  ///
  /// The WinUI PersonPicture: a circle carrying initials or a glyph
  /// (learn.microsoft.com/windows/apps/design/controls/person-picture).
  /// The diameter is twice the icon-ramp rung the scale names
  /// (24 / 32 / 40) - derived from the published ramp, the same
  /// derivation the empty state's hero mark records. Identity fills the
  /// circle SOLID - Fluent 2's coloured avatar - under the
  /// contrast-correct foreground; a thing with no identity takes the
  /// solid neutral.
  @override
  Widget avatar(BuildContext context, AvatarSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final double diameter = FluentSpacing.glyph(spec.scale) * 2;
    final Color fill = spec.tone == Tone.neutral
        ? theme.resources.systemFillColorSolidNeutral
        : FluentInk.foreground(theme, spec.tone);
    final Color foreground = FluentInk.foregroundOn(fill);
    final TextRole role = switch (spec.scale) {
      ControlScale.compact => TextRole.micro,
      ControlScale.normal => TextRole.body,
      ControlScale.prominent => TextRole.pageTitle,
    };
    return Semantics(
      label: spec.semanticsLabel,
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: spec.monogram != null
            ? Text(
                spec.monogram!,
                style: FluentTypeResolution.styleOf(
                  context,
                  role,
                ).copyWith(color: foreground),
              )
            : IconTheme.merge(
                data: IconThemeData(
                  size: FluentSpacing.glyph(spec.scale),
                  color: foreground,
                ),
                child: SizedBox.square(
                  dimension: FluentSpacing.glyph(spec.scale),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Things that say something
  // ---------------------------------------------------------------------

  /// **Something about this whole surface needs saying**, and it stays
  /// said until the condition changes.
  ///
  /// The WinUI InfoBar (fluent_ui@4.16.1
  /// lib/src/controls/surfaces/info_bar.dart): the severity ground behind
  /// the card stroke at corner 4 (:585-601), 14 of padding with 8 at the
  /// end so the close control carries its own (:579-584), the severity
  /// mark's slot coloured per severity - the informational mark takes the
  /// accent, which is WinUI's own collapse (:616-626) - the title in Body
  /// Strong beside the message (:380), the actions as this skin's own
  /// standard buttons, and the dismissal as its own control wearing the
  /// drawn cross at 16 (:631).
  @override
  Widget banner(BuildContext context, BannerSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final Color mark = switch (spec.tone.name) {
      'success' => res.systemFillColorSuccess,
      'warning' => res.systemFillColorCaution,
      'danger' || 'invalid' => res.systemFillColorCritical,
      _ => FluentInk.foreground(theme, spec.tone),
    };
    return Container(
      padding: FluentSurfaceMetrics.infoBarPadding,
      decoration: BoxDecoration(
        color: FluentSurfaceInk.bannerGround(res, spec.tone),
        borderRadius: BorderRadius.circular(FluentGeometry.controlCornerRadius),
        border: Border.all(color: res.cardStrokeColorDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (spec.icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: FluentSurfaceMetrics.infoBarIconGap,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: FluentMetrics.glyphNormal,
                  color: mark,
                ),
                child: const SizedBox.square(
                  dimension: FluentMetrics.glyphNormal,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  spec.title,
                  style: FluentTypeResolution.styleOf(
                    context,
                    TextRole.sectionTitle,
                  ).copyWith(color: res.textFillColorPrimary),
                ),
                if (spec.body != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: FluentMetrics.spaceXS,
                    ),
                    child: Text(
                      spec.body!,
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.body,
                      ).copyWith(color: res.textFillColorPrimary),
                    ),
                  ),
                if (spec.actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: FluentMetrics.spaceS,
                    ),
                    child: Wrap(
                      spacing: FluentMetrics.spaceS,
                      runSpacing: FluentMetrics.spaceS,
                      children: <Widget>[
                        for (final NoticeAction action in spec.actions)
                          Semantics(
                            tooltip: action.tooltip,
                            child: FluentButton(
                              spec: ButtonSpec(
                                label: action.label,
                                onPressed: action.onPressed,
                                emphasis: Emphasis.secondary,
                                leading: action.icon,
                                tooltip: action.tooltip,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (spec.onDismiss != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: FluentMetrics.spaceS,
              ),
              child: _DismissButton(
                // The one English name this control carries: the
                // contract has no slot for it and this package no
                // localisation source - the registered finding the
                // facet doc reports.
                tooltip: 'Dismiss',
                onPressed: spec.onDismiss!,
                size: FluentSurfaceMetrics.dismissGlyph,
              ),
            ),
        ],
      ),
    );
  }

  /// **There is nothing here yet, and here is what to do about it.**
  ///
  /// A centred column at the roomy inset: the hero slot at twice the
  /// prominent icon rung (40 - the same doubling the application's own
  /// empty state derived its mark from), wearing the state's tone so an
  /// error state never dresses as ordinary emptiness; the headline in the
  /// region-title step; the explanation in body on the secondary ink; and
  /// the ways out as this skin's own buttons at the emphasis each action
  /// states.
  @override
  Widget emptyState(BuildContext context, EmptyStateSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final double hero = FluentMetrics.glyphProminent * 2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FluentMetrics.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(
                size: hero,
                color: FluentInk.foreground(theme, spec.tone),
              ),
              child: SizedBox.square(dimension: hero),
            ),
            const SizedBox(height: FluentMetrics.spaceL),
            Text(
              spec.title,
              textAlign: TextAlign.center,
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.pageTitle,
              ).copyWith(color: res.textFillColorPrimary),
            ),
            const SizedBox(height: FluentMetrics.spaceS),
            Text(
              spec.message,
              textAlign: TextAlign.center,
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.body,
              ).copyWith(color: res.textFillColorSecondary),
            ),
            if (spec.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: FluentMetrics.spaceL),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final EmptyStateAction action in spec.actions)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: FluentMetrics.spaceXS,
                      ),
                      child: FluentButton(
                        spec: ButtonSpec(
                          label: action.label,
                          onPressed: action.onPressed,
                          emphasis: action.emphasis,
                          leading: action.icon,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// **Things can be dragged onto this region.**
  ///
  /// The region dims under the language's own smoke - the layer WinUI
  /// puts behind a surface that floats above inert content
  /// (`ContentDialog`'s barrier, fluent_ui@4.16.1
  /// lib/src/controls/flyouts/content_dialog.dart:240, `0x8A000000`) -
  /// and the callout IS an overlay-tier surface: the solid flyout ground
  /// behind the flyout stroke at the overlay corner, casting the one
  /// shadow Fluent's depth grammar allows (`FluentInk.depth`,
  /// `Elevation.overlay`). The content underneath stays visible through
  /// the smoke: the user is dropping onto something and must keep seeing
  /// what.
  @override
  Widget dropTarget(BuildContext context, DropTargetSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentDepth depth = FluentInk.depth(theme, Elevation.overlay);
    return Stack(
      children: <Widget>[
        spec.child.mount(),
        if (spec.active)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                // The smoke (content_dialog.dart:240).
                color: const Color(0x8A000000),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(FluentMetrics.spaceXL),
                    decoration: BoxDecoration(
                      color: depth.fill,
                      borderRadius: BorderRadius.circular(
                        FluentGeometry.overlayCornerRadius,
                      ),
                      border: Border.all(color: depth.stroke),
                      boxShadow: depth.shadows(
                        FluentInk.shadowInk(theme.brightness),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconTheme.merge(
                          data: IconThemeData(
                            size: FluentMetrics.glyphProminent * 2,
                            color: theme.accent.defaultBrushFor(
                              theme.brightness,
                            ),
                          ),
                          child: SizedBox.square(
                            dimension: FluentMetrics.glyphProminent * 2,
                          ),
                        ),
                        const SizedBox(height: FluentMetrics.spaceM),
                        Text(
                          spec.label,
                          textAlign: TextAlign.center,
                          style:
                              FluentTypeResolution.styleOf(
                                context,
                                TextRole.pageTitle,
                              ).copyWith(
                                color: theme.resources.textFillColorPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Text that is not prose
  // ---------------------------------------------------------------------

  /// **Here is one line of a diff or of a code view.**
  ///
  /// Widgets, not a painter: that is this skin's performance answer for
  /// now, revisable inside this member without the application knowing.
  /// The line's meaning is a wash of its own git colour behind it - the
  /// strength is the application's measured 12%, the colours this skin's
  /// palette - a hunk header washes the accent, a file header takes the
  /// alternate solid ground, and a SELECTED line takes the selected
  /// tile's fill plus the accent pill, so "picked" reads the same on a
  /// diff line as on a list row. A run at `Tone.neutral` inherits the
  /// line's tone - neutral one level down means "no meaning of its OWN" -
  /// and an emphasised run answers with Semibold, the language's own
  /// emphasis (SPEC: "Use Semibold instead of Bold for emphasis").
  ///
  /// The gutter reserves both columns on a paired line even where one
  /// number is absent - the blank column is what keeps an added line's
  /// code aligned - and only the carried side on an unpaired one. Numbers
  /// and git's own marker render in the resolved code style: a column of
  /// digits is readable because every digit is the same width.
  @override
  Widget codeLine(BuildContext context, CodeLineSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final TextStyle code = FluentTypeResolution.styleOf(context, TextRole.code);
    final Color foreground = _codeLineForeground(theme, spec.tone);
    final bool numbered = spec.oldNumber != null || spec.newNumber != null;

    final Widget line = Container(
      color: spec.selected
          ? res.subtleFillColorSecondary
          : _codeLineFill(theme, spec.tone),
      padding: const EdgeInsets.symmetric(
        horizontal: FluentMetrics.spaceS,
        vertical: FluentMetrics.spaceXXS,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (numbered) ...<Widget>[
            if (spec.paired || spec.oldNumber != null)
              _lineNumber(res, spec.oldNumber, code),
            if (spec.paired || spec.newNumber != null)
              _lineNumber(res, spec.newNumber, code),
          ],
          if (spec.marker != null)
            Text(spec.marker!, style: code.copyWith(color: foreground)),
          const SizedBox(width: FluentMetrics.spaceXS),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  for (final TextRun run in spec.runs)
                    TextSpan(
                      text: run.text,
                      style: code.copyWith(
                        color: _codeLineForeground(
                          theme,
                          run.tone == Tone.neutral ? spec.tone : run.tone,
                        ),
                        fontWeight: run.emphasised ? FontWeight.w600 : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (spec.onTap == null && !spec.selected) return line;
    return _CodeLineShell(spec: spec, child: line);
  }

  /// **Here is a whole block of machine output the user reads and
  /// copies** - git stdout, a command-log entry, a commit message body.
  ///
  /// The resolved code style in the tone's own ink. Selectability is
  /// behaviour and is honoured with a real selection region; what it does
  /// not get is a floating selection toolbar, which is an overlay surface
  /// and waits on the overlays facet - the same registered gap every
  /// tooltip carries. An unwrapped block scrolls horizontally rather than
  /// clipping: output the user cannot reach the end of is output they
  /// cannot read.
  @override
  Widget codeBlock(BuildContext context, CodeBlockSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final TextStyle mono = FluentTypeResolution.styleOf(
      context,
      TextRole.code,
    ).copyWith(color: FluentInk.foreground(theme, spec.tone));
    Widget body = Text(
      spec.text,
      style: mono,
      softWrap: spec.wrap,
      maxLines: spec.maxLines,
      overflow: spec.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
    );
    if (!spec.wrap) {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: body,
      );
    }
    // A selection needs an Overlay to host its handles; a member pumped
    // without one (a bare test) renders unselectable rather than
    // throwing for the harness's missing host.
    if (spec.selectable && Overlay.maybeOf(context) != null) {
      body = SelectableRegion(
        selectionControls: emptyTextSelectionControls,
        child: body,
      );
    }
    return body;
  }

  /// **Here is how this commit connects to the ones above and below
  /// it.** [FluentCommitGraphRow]: this skin's own painter over its own
  /// series ink.
  @override
  Widget commitGraphRow(BuildContext context, GraphRowSpec spec) =>
      FluentCommitGraphRow(spec: spec);

  /// **Reserve the room this row's graph needs beside its content.**
  /// [FluentCommitGraphGutter]: the painter's own lane arithmetic,
  /// returned as room.
  @override
  Widget commitGraphGutter(BuildContext context, GraphGutterSpec spec) =>
      FluentCommitGraphGutter(spec: spec);

  // ---------------------------------------------------------------------
  // The two pictorial members
  // ---------------------------------------------------------------------

  /// **Here is a document written in Markdown.**
  ///
  /// The renderer is a parser, not a design language; the STYLE SHEET is
  /// entirely this skin's, which is what the member exists to own. The
  /// document's headings walk down the Windows type ramp from Title - the
  /// upper rungs the interface itself never spends, exactly where a
  /// document is allowed to spend them - prose and lists speak Body, a
  /// quote drops to the secondary ink in italic, code takes the resolved
  /// code style on the alternate solid ground behind the control corner,
  /// and a link takes the accent brush.
  @override
  Widget markdown(BuildContext context, MarkdownSpec spec) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    TextStyle role(TextRole r) => FluentTypeResolution.styleOf(context, r);
    final Color ink = res.textFillColorPrimary;
    return Markdown(
      data: spec.source,
      selectable: spec.selectable,
      imageDirectory: spec.baseDirectory,
      onTapLink: spec.onLinkTapped == null
          ? null
          : (String label, String? href, String title) {
              if (href != null) spec.onLinkTapped!(href);
            },
      styleSheet: MarkdownStyleSheet(
        p: role(TextRole.body).copyWith(color: ink),
        // The ramp's upper steps, top down: Title 28, Subtitle 20, Body
        // Large 18 (FluentTypeRamp provenance), then Body Strong.
        h1: FluentTypeRamp.title.copyWith(color: ink),
        h2: FluentTypeRamp.subtitle.copyWith(color: ink),
        h3: FluentTypeRamp.bodyLarge.copyWith(color: ink),
        h4: role(TextRole.sectionTitle).copyWith(color: ink),
        h5: role(TextRole.sectionTitle).copyWith(color: ink),
        h6: role(TextRole.sectionTitle).copyWith(color: ink),
        listBullet: role(TextRole.body).copyWith(color: ink),
        blockquote: role(TextRole.body).copyWith(
          color: res.textFillColorSecondary,
          fontStyle: FontStyle.italic,
        ),
        a: role(
          TextRole.body,
        ).copyWith(color: theme.accent.defaultBrushFor(theme.brightness)),
        code: role(TextRole.code).copyWith(
          color: ink,
          backgroundColor: res.solidBackgroundFillColorSecondary,
        ),
        codeblockDecoration: BoxDecoration(
          color: res.solidBackgroundFillColorSecondary,
          borderRadius: BorderRadius.circular(
            FluentGeometry.controlCornerRadius,
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: res.dividerStrokeColorDefault)),
        ),
      ),
    );
  }

  /// **Here is a picture the user wants to look at closely.**
  ///
  /// The behaviour is what the member is for: the picture pans and zooms,
  /// to the same 3x ceiling the application's old viewer allowed, over
  /// the alternate solid ground so the picture's own edges stay visible
  /// on either brightness.
  @override
  Widget imageViewer(BuildContext context, ImageViewerSpec spec) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Semantics(
      image: true,
      label: spec.semanticsLabel,
      child: ColoredBox(
        color: res.solidBackgroundFillColorSecondary,
        child: InteractiveViewer(
          maxScale: 3,
          child: Center(child: Image(image: spec.image)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Composition, shared by the members above
  // ---------------------------------------------------------------------

  /// The hairline between a container's sections: the language's own
  /// divider (fluent_ui@4.16.1 lib/src/controls/utils/divider.dart:
  /// 186-195 - thickness 1, `DividerStrokeColorDefault`).
  static Widget _rule(FluentResources res) => Container(
    height: FluentGeometry.strokeWidth,
    color: res.dividerStrokeColorDefault,
  );

  /// The wash a code line's meaning puts behind it; see [codeLine].
  static Color? _codeLineFill(FluentThemeData theme, Tone tone) {
    if (tone == Tone.neutral || tone == Tone.muted) return null;
    if (tone == Tone.info) {
      return theme.resources.solidBackgroundFillColorSecondary;
    }
    return FluentInk.foreground(
      theme,
      tone,
    ).withValues(alpha: FluentSurfaceMetrics.codeLineWash);
  }

  /// The ink a code line's meaning writes in; see [codeLine].
  static Color _codeLineForeground(FluentThemeData theme, Tone tone) {
    if (tone == Tone.info) return theme.resources.textFillColorPrimary;
    return FluentInk.foreground(theme, tone);
  }

  /// One side of a diff's number gutter: fixed width and right-aligned,
  /// so the code column starts at the same x on every line. The 48 is
  /// application heritage - the reservation the application's own diff
  /// gutter always made, the same number the Material skin derives.
  static Widget _lineNumber(FluentResources res, int? number, TextStyle code) =>
      SizedBox(
        width: 48,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: FluentMetrics.spaceS),
          child: Text(
            number?.toString() ?? '',
            textAlign: TextAlign.right,
            style: code.copyWith(color: res.textFillColorSecondary),
          ),
        ),
      );
}

/// The card member's body; a widget so its focus node has a lifetime.
final class _FluentCard extends StatefulWidget {
  const _FluentCard({required this.spec});

  final CardSpec spec;

  @override
  State<_FluentCard> createState() => _FluentCardState();
}

class _FluentCardState extends State<_FluentCard> {
  /// A card collection is a single Tab stop with a roving highlight, so
  /// the card refuses focus - the Material skin's CARD-003, made here
  /// with a node that cannot take it.
  final FocusNode _focusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'FluentCard',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CardSpec spec = widget.spec;
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool selected = spec.selection != RowSelection.none;
    final bool operable = spec.onTap != null || spec.onContextMenu != null;

    final Color? identity = spec.tone == Tone.neutral
        ? null
        : FluentInk.foreground(theme, spec.tone);

    // The depth grammar: raised composites the hover layer OVER the
    // resting fill, so the base stays the resting card's.
    final FluentDepth depth = FluentInk.depth(theme, spec.elevation);
    final Color baseFill = spec.elevation == Elevation.raised
        ? FluentInk.depth(theme, Elevation.resting).fill
        : depth.fill;
    final Color raisedLayer = spec.elevation == Elevation.raised
        ? depth.fill
        : res.subtleFillColorTransparent;

    final BorderSide edge = selected
        ? BorderSide(
            width: 2,
            color: spec.containerFocused
                ? (identity ?? theme.accent.defaultBrushFor(theme.brightness))
                : res.controlStrongStrokeColorDefault,
          )
        : BorderSide(
            color: identity ?? depth.stroke,
            width: FluentGeometry.strokeWidth,
          );

    return Semantics(
      container: true,
      selected: selected,
      child: FluentPressable(
        mergeSemantics: false,
        focusNode: _focusNode,
        onPressed: spec.onTap,
        onContextMenu: spec.onContextMenu,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Set<WidgetState> live = operable
              ? states
              : const <WidgetState>{};
          return DecoratedBox(
            decoration: BoxDecoration(
              color: baseFill,
              border: Border.fromBorderSide(edge),
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
              boxShadow: depth.shadows(FluentInk.shadowInk(theme.brightness)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                // The raised layer and the state layer share the
                // composite: a hover is one more subtle layer over
                // whatever the card already painted.
                color: live.isEmpty && !selected
                    ? raisedLayer
                    : FluentSurfaceInk.tileFill(res, live, selected: selected),
                child: Stack(
                  children: <Widget>[
                    DefaultTextStyle(
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.body,
                      ).copyWith(color: res.textFillColorPrimary),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (spec.header != null) ...<Widget>[
                            spec.header!.mount(),
                            FluentSurfaces._rule(res),
                          ],
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.all(
                                FluentSpacing.inset(spec.inset),
                              ),
                              child: spec.content.mount(),
                            ),
                          ),
                          if (spec.footer != null) ...<Widget>[
                            FluentSurfaces._rule(res),
                            spec.footer!.mount(),
                          ],
                        ],
                      ),
                    ),
                    // The gathered card's checked mark, top end corner:
                    // WinUI's multiple-selection treatment. Inert - the
                    // card itself answers the press - and excluded from
                    // semantics because the card already says selected.
                    if (spec.selection == RowSelection.multi)
                      PositionedDirectional(
                        top: FluentMetrics.spaceS,
                        end: FluentMetrics.spaceS,
                        child: ExcludeSemantics(
                          child: FluentCheckboxBox(
                            value: true,
                            states: const <WidgetState>{},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The disclosure member's body: the WinUI Expander.
final class _FluentDisclosure extends StatelessWidget {
  const _FluentDisclosure({required this.spec});

  final DisclosureSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          expanded: spec.expanded,
          child: FluentPressable(
            mergeSemantics: false,
            onPressed: spec.enabled
                ? () => spec.onExpandedChanged(!spec.expanded)
                : null,
            builder: (BuildContext context, Set<WidgetState> states) {
              final Color foreground = states.contains(WidgetState.disabled)
                  ? res.textFillColorDisabled
                  : res.textFillColorPrimary;
              return Container(
                constraints: const BoxConstraints(
                  minHeight: FluentSurfaceMetrics.expanderHeaderMinHeight,
                ),
                decoration: ShapeDecoration(
                  // The header is a card band whose bottom corners
                  // square off while the body is open
                  // (expander.dart:327-341).
                  color: res.cardBackgroundFillColorDefault,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: res.cardStrokeColorDefault),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(
                        FluentSurfaceMetrics.rowCornerRadius,
                      ),
                      bottom: Radius.circular(
                        spec.expanded
                            ? 0
                            : FluentSurfaceMetrics.rowCornerRadius,
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsetsDirectional.only(
                  start: FluentSurfaceMetrics.expanderHeaderStartInset,
                ),
                child: Row(
                  children: <Widget>[
                    if (spec.leading != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: FluentSurfaceMetrics.expanderLeadingGap,
                        ),
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
                    Expanded(
                      child: DefaultTextStyle(
                        style: FluentTypeResolution.styleOf(
                          context,
                          TextRole.body,
                        ).copyWith(color: foreground),
                        child: spec.header.mount(),
                      ),
                    ),
                    if (spec.trailing != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: FluentSurfaceMetrics.expanderTrailingGap,
                        ),
                        child: spec.trailing!.mount(),
                      ),
                    // The chevron in its own subtle box, answering the
                    // header's states (expander.dart:359-411).
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: spec.trailing != null
                            ? FluentMetrics.spaceS
                            : FluentSurfaceMetrics.expanderTrailingGap,
                        end: FluentMetrics.spaceS,
                        top: FluentMetrics.spaceS,
                        bottom: FluentMetrics.spaceS,
                      ),
                      child: FluentFocusRing(
                        focused: states.contains(WidgetState.focused),
                        child: AnimatedContainer(
                          duration: FluentMotion.faster,
                          curve: FluentMotion.curve,
                          padding: const EdgeInsets.all(
                            FluentSurfaceMetrics.expanderChevronPad,
                          ),
                          decoration: BoxDecoration(
                            color: FluentSurfaceInk.tileFill(res, states),
                            borderRadius: BorderRadius.circular(
                              FluentSurfaceMetrics.rowCornerRadius,
                            ),
                          ),
                          child: AnimatedRotation(
                            // The half-turn at the medium step
                            // (expander.dart:383-395; the reference
                            // rotates over the second half of one
                            // controller - one step, one duration, is
                            // this skin's registered simplification).
                            turns: spec.expanded ? 0.5 : 0,
                            duration: FluentMotion.medium,
                            curve: FluentMotion.curve,
                            child: FluentChevron(
                              color: foreground,
                              size: FluentSurfaceMetrics.chevronGlyph,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // The reveal, at the reference's medium step (expander.dart:
        // 284-296). The body sits on the quieter card layer behind the
        // same stroke, bottom corners only (expander.dart:427-446).
        ClipRect(
          child: AnimatedSize(
            duration: FluentMotion.medium,
            curve: FluentMotion.curve,
            alignment: Alignment.topCenter,
            child: !spec.expanded
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      FluentSurfaceMetrics.expanderBodyInset,
                    ),
                    decoration: ShapeDecoration(
                      color: res.cardBackgroundFillColorSecondary,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: res.cardStrokeColorDefault),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(
                            FluentSurfaceMetrics.rowCornerRadius,
                          ),
                        ),
                      ),
                    ),
                    child: DefaultTextStyle(
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.body,
                      ).copyWith(color: res.textFillColorPrimary),
                      child: spec.body.mount(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The pressable member's body; stateful for the tap interval.
final class _FluentPressableRegion extends StatefulWidget {
  const _FluentPressableRegion({required this.spec});

  final PressableSpec spec;

  @override
  State<_FluentPressableRegion> createState() => _FluentPressableRegionState();
}

class _FluentPressableRegionState extends State<_FluentPressableRegion> {
  final FluentTapInterval _taps = FluentTapInterval();

  @override
  Widget build(BuildContext context) {
    final PressableSpec spec = widget.spec;
    final FluentThemeData theme = FluentTheme.of(context);
    final bool operable =
        spec.enabled &&
        (spec.onTap != null ||
            spec.onDoubleTap != null ||
            spec.onContextMenu != null);
    return Semantics(
      label: spec.semanticsLabel,
      // Announced, not shown: the hovering tooltip is an overlay
      // surface and waits on the overlays facet - the facet doc's
      // registered gap.
      tooltip: spec.tooltip,
      selected: spec.selected,
      enabled: operable,
      child: FluentPressable(
        mergeSemantics: false,
        onPressed: operable && (spec.onTap != null || spec.onDoubleTap != null)
            ? () => _taps.tap(spec.onTap, spec.onDoubleTap)
            : null,
        onContextMenu: operable ? spec.onContextMenu : null,
        builder: (BuildContext context, Set<WidgetState> states) =>
            FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                decoration: BoxDecoration(
                  color: FluentSurfaceInk.tileFill(
                    theme.resources,
                    states,
                    selected: spec.selected,
                  ),
                  borderRadius: BorderRadius.circular(
                    FluentGeometry.controlCornerRadius,
                  ),
                ),
                child: spec.child.mount(),
              ),
            ),
      ),
    );
  }
}

/// One action in a panel's header: a subtle worded button carrying its
/// mark's reserved slot, its name and - announced - its tooltip, which
/// most importantly carries the REASON while the action is unavailable.
final class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.action});

  final ToolbarActionEntry action;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return FluentPressable(
      onPressed: action.onPressed,
      semanticsLabel: action.label,
      builder: (BuildContext context, Set<WidgetState> states) {
        final Color foreground = states.contains(WidgetState.disabled)
            ? res.textFillColorDisabled
            : action.tone == Tone.neutral
            ? FluentSurfaceInk.rowForeground(res, states)
            : FluentInk.foreground(theme, action.tone);
        return FluentFocusRing(
          focused: states.contains(WidgetState.focused),
          child: AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: FluentMetrics.spaceS,
              vertical: FluentMetrics.spaceXS,
            ),
            decoration: BoxDecoration(
              color: FluentSurfaceInk.tileFill(res, states),
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
            ),
            // Inside the pressable's merge, so the one node a reader
            // reaches carries the name AND the reason an unavailable
            // action is unavailable.
            child: Semantics(
              tooltip: action.tooltip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconTheme.merge(
                    data: IconThemeData(
                      size: FluentMetrics.glyphNormal,
                      color: foreground,
                    ),
                    child: const SizedBox.square(
                      dimension: FluentMetrics.glyphNormal,
                    ),
                  ),
                  const SizedBox(width: FluentMetrics.spaceXS),
                  Text(
                    action.label,
                    style: FluentTypeResolution.styleOf(
                      context,
                      TextRole.control,
                    ).copyWith(color: foreground),
                  ),
                  if (action.badgeCount != null) ...<Widget>[
                    const SizedBox(width: FluentMetrics.spaceXS),
                    FluentInfoBadgePill(count: action.badgeCount!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A dismissal: the drawn cross in its own subtle box, separately
/// focusable, named by its tooltip.
final class _DismissButton extends StatelessWidget {
  const _DismissButton({
    required this.tooltip,
    required this.onPressed,
    required this.size,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return FluentPressable(
      onPressed: onPressed,
      semanticsLabel: tooltip,
      builder: (BuildContext context, Set<WidgetState> states) =>
          FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              padding: const EdgeInsets.all(FluentMetrics.spaceXS),
              decoration: BoxDecoration(
                color: FluentSurfaceInk.tileFill(res, states),
                borderRadius: BorderRadius.circular(
                  FluentGeometry.controlCornerRadius,
                ),
              ),
              // Inside the pressable's merge, so the one semantics node a
              // reader reaches carries the name AND the description.
              child: Semantics(
                tooltip: tooltip,
                child: FluentDismissMark(
                  color: FluentSurfaceInk.rowForeground(res, states),
                  size: size,
                ),
              ),
            ),
          ),
    );
  }
}

/// The interactive shell of a code line, kept out of the hot path: an
/// unselected, untappable line - the overwhelming majority of a diff -
/// builds no gesture machinery at all.
final class _CodeLineShell extends StatefulWidget {
  const _CodeLineShell({required this.spec, required this.child});

  final CodeLineSpec spec;
  final Widget child;

  @override
  State<_CodeLineShell> createState() => _CodeLineShellState();
}

class _CodeLineShellState extends State<_CodeLineShell> {
  final FocusNode _focusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'FluentCodeLine',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return Semantics(
      selected: widget.spec.selected,
      child: FluentPressable(
        mergeSemantics: false,
        focusNode: _focusNode,
        onPressed: widget.spec.onTap,
        builder: (BuildContext context, Set<WidgetState> states) => Stack(
          children: <Widget>[
            widget.child,
            // The selected line's pill: "picked" reads the same on a
            // diff line as on a list row.
            if (widget.spec.selected)
              PositionedDirectional(
                top: FluentMetrics.spaceXXS,
                bottom: FluentMetrics.spaceXXS,
                start: 0,
                child: Container(
                  width: FluentSurfaceMetrics.pillWidth,
                  decoration: BoxDecoration(
                    color: FluentSurfaceInk.pillColor(theme, focused: true),
                    borderRadius: BorderRadius.circular(
                      FluentSurfaceMetrics.pillCornerRadius,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
