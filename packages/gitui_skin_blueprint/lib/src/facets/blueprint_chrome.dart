import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../blueprint_ink.dart';
import 'blueprint_controls.dart';
import 'blueprint_surfaces.dart';

/// The frame, naked.
///
/// Four members, and two rules they all follow. First, everything a spec
/// states is either drawn distinguishably or its reason for not being drawn
/// is written where the parameter is consumed - the obligation of
/// `docs/SKIN-CONTRACT-MEMBERS.md` §9. Second, wherever the frame contains a
/// thing another facet already owns - a banner, a button - it renders it
/// through that facet rather than sketching a second version, because two
/// renderings of one spec inside one skin is the same defect as two
/// affordances for one job.
final class BlueprintChrome implements SkinChrome {
  /// Takes the distance every rung resolves against, and the vocabulary this
  /// build draws with.
  const BlueprintChrome(
    this.distance, {
    this.vocabulary = BlueprintVocabulary.standard,
  });

  /// How far apart things are under this instrument. Zero unless the skin was
  /// built with a distance.
  final BlueprintDistance distance;

  /// The two colours and the two metric scales in force.
  ///
  /// It arrives here rather than at each facet because `wrapRoot` is the one
  /// place a root treatment is installed, and installing it there means every
  /// other facet reads it out of the tree - so a chaos family reaches the
  /// whole skin without any facet naming it.
  final BlueprintVocabulary vocabulary;

  /// The blueprint's one type size, in logical pixels. The engine's own
  /// default, restated so the user's text-scale preference has a number to
  /// multiply.
  static const double _oneTypeSize = 14;

  /// Installs the ink defaults, which is what makes the instrument an
  /// instrument.
  ///
  /// If this installed nothing, a leaked raw `Text` would render in the
  /// engine's default white and pass a paper-and-ink pixel invariant
  /// invisibly; installing ink turns the SDK's own fallbacks into leak
  /// detectors. Of the request's seven fields, [SkinRequest.textScale] is the
  /// one the blueprint can honour visibly - it multiplies the single type
  /// size, because the scale is the user's and only the ramp is the skin's.
  /// [SkinRequest.animationScale] is consumed by construction: every duration
  /// here is zero and zero times any scale is zero. The remaining five -
  /// brightness, the accent seed, the two font families and the code scale -
  /// cannot be drawn without a second colour, a palette, a family or a second
  /// type size, which are exactly the things the blueprint must not have (one
  /// size is what makes a leaked ramp visible, the same reason one family
  /// makes a leaked font visible); they are carried onto the debug surface by
  /// [_RootFacts] instead, so a request a skin drops still shows up as a
  /// difference from the blueprint in the widget tree.
  @override
  Widget wrapRoot(
    BuildContext context, {
    required Widget child,
    required SkinRequest request,
  }) => _RootFacts(
    request: request,
    vocabulary: vocabulary,
    child: BlueprintVocabulary.install(
      vocabulary: vocabulary,
      child: IconTheme(
        data: IconThemeData(color: vocabulary.ink),
        child: DefaultTextStyle(
          style: TextStyle(
            color: vocabulary.ink,
            fontSize: _oneTypeSize * request.textScale,
          ),
          child: child,
        ),
      ),
    ),
  );

  /// The whole window: every region the spec's data names, each routed
  /// through the application's own pane host.
  @override
  Widget shell(BuildContext context, ShellSpec spec) =>
      _BlueprintShell(spec: spec, distance: distance);

  /// One screen: its name, its actions, its warnings and its body.
  @override
  Widget screen(BuildContext context, ScreenSpec spec) {
    final SelectionBarSpec? selectionBar = spec.selectionBar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: distance.gap(Proximity.sectioned),
      children: <Widget>[
        Row(
          spacing: distance.gap(Proximity.separate),
          children: <Widget>[
            BlueprintMark(BlueprintMarks.textRole(TextRole.pageTitle)),
            // Flexible, for the same reason the status strip is: a screen
            // title is the application's own words in one of six languages,
            // and a title that overflows paints stripes the census would
            // report against the application.
            Flexible(child: BlueprintText(spec.title)),
            Expanded(child: _toolbarStrip(context, spec.toolbar, distance)),
            // The screen's primary actions: the need behind the slot is the
            // floating action button, so the blueprint renders them at the
            // frame's edge, promoted to the primary stroke and the prominent
            // box regardless of what the entries would claim in an ordinary
            // bar - "what this screen is for" IS the emphasis.
            for (final ToolbarActionEntry action in spec.primaryActions)
              _toolbarEntry(
                context,
                action,
                distance,
                emphasisOverride: Emphasis.primary,
                scale: ControlScale.prominent,
              ),
          ],
        ),
        if (spec.banner != null)
          BlueprintSurfaces(distance).banner(context, spec.banner!),
        if (selectionBar != null) _selectionBar(context, selectionBar),
        Expanded(child: spec.body.mount()),
        if (spec.footer != null) spec.footer!.mount(),
      ],
    );
  }

  /// The batch-action strip shown while things are multi-selected.
  Widget _selectionBar(BuildContext context, SelectionBarSpec bar) =>
      BlueprintBox(
        child: Row(
          spacing: distance.gap(Proximity.separate),
          children: <Widget>[
            BlueprintMark(BlueprintMarks.count(bar.selectedCount)),
            BlueprintPressable(
              onPressed: bar.onClear,
              child: const BlueprintBox(child: BlueprintMark('[clear]')),
            ),
            Expanded(child: _toolbarStrip(context, bar.actions, distance)),
          ],
        ),
      );

  /// The inside of a dialog: title, content and the ways out.
  ///
  /// The extent renders as the surface's width - an alert narrower than a
  /// form, a form narrower than a browser - because "what kind of thing does
  /// this dialog contain" is the information the vocabulary carries and width
  /// is the one distinguishable rendering a naked square has for it. The
  /// actions are real buttons from this skin's own controls facet, in the
  /// application's reading order: each role maps to an emphasis (affirmative
  /// is the primary way out, dismissive is quiet, everything else is
  /// secondary) and a destructive role additionally carries the danger tone,
  /// which is the decomposition the contract made when it split the old
  /// button variant compound.
  ///
  /// Two spec fields are deliberately not read here because they belong to
  /// the layers around this one: `barrierDismissible` is the route's question
  /// and `overlays.presentDialog` consumes it, and `onSubmit` is the keyboard
  /// contract's and the application's own dialog keyboard host consumes it.
  @override
  Widget dialogSurface(BuildContext context, DialogSpec spec) {
    final BlueprintControls controls = BlueprintControls(distance);
    final double maxWidth = switch (spec.extent) {
      DialogExtent.alert => 256,
      DialogExtent.form => 384,
      DialogExtent.browser => 512,
    };
    final String marks =
        '${BlueprintMarks.textRole(TextRole.pageTitle)}'
        '${BlueprintMarks.tone(spec.tone)}'
        '${spec.icon == null ? BlueprintMarks.none : BlueprintMarks.icon(spec.icon!)}';
    return Align(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: BlueprintBox(
          rings: BlueprintGeometry.rings(Elevation.overlay),
          child: ColoredBox(
            color: BlueprintInk.paper(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: distance.gap(Proximity.sectioned),
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    BlueprintMark(marks),
                    Flexible(child: BlueprintText(spec.title)),
                  ],
                ),
                Flexible(child: spec.content.mount()),
                if (spec.actions.isNotEmpty)
                  Row(
                    spacing: distance.gap(Proximity.grouped),
                    children: <Widget>[
                      for (final DialogAction action in spec.actions)
                        controls.button(context, _actionButton(action)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maps one dialog action onto this skin's own button.
  static ButtonSpec _actionButton(DialogAction action) => ButtonSpec(
    label: action.label,
    // `enabled`, `isLoading` and a null callback all resolve to "not
    // invokable" - the spec's own isEnabled - and a loading action stays
    // visibly busy through the button's own isLoading rendering.
    onPressed: action.isEnabled ? action.onPressed : null,
    emphasis: switch (action.role) {
      DialogActionRole.affirmative => Emphasis.primary,
      DialogActionRole.destructive => Emphasis.secondary,
      DialogActionRole.dismissive => Emphasis.quiet,
      DialogActionRole.neutral => Emphasis.secondary,
    },
    tone: action.role == DialogActionRole.destructive
        ? Tone.danger
        : Tone.neutral,
    leading: action.icon,
    isLoading: action.isLoading,
  );
}

/// Carries the parts of the user's request the blueprint cannot draw onto the
/// debug surface, so that every field of the request is genuinely consumed.
///
/// [toStringShort] is the line the widget inspector and `debugDumpApp` print
/// for this node; a skin that ignores a request field shows up as a
/// difference from the blueprint there, which is the same second-check role
/// every drawn parameter plays on screen.
class _RootFacts extends StatelessWidget {
  const _RootFacts({
    required this.request,
    required this.vocabulary,
    required this.child,
  });

  /// The user's choices, as the application stated them.
  final SkinRequest request;

  /// What this build is drawing with, printed so that a T5 run says on its own
  /// debug line which family and which seed produced it.
  final BlueprintVocabulary vocabulary;

  /// The application, already wrapped in the ink defaults.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  String toStringShort() =>
      'chrome.wrapRoot(${request.brightness.name} '
      'accent:${request.accentSeed} text:x${request.textScale} '
      'code:x${request.codeScale} '
      'motion:x${request.animationScale} mono:${request.monoFamily} '
      'ui:${request.uiFamily} $vocabulary)';
}

/// The naked shell: every region of the window, in pane order.
class _BlueprintShell extends StatelessWidget {
  const _BlueprintShell({required this.spec, required this.distance});

  /// What the window contains.
  final ShellSpec spec;

  /// How far apart things are under this instrument.
  final BlueprintDistance distance;

  /// Routes one pane through the application's keyboard structure, or
  /// returns it bare when the application installed none.
  Widget _hosted(ShellPane pane, Widget contents) =>
      spec.paneHost?.call(pane, contents) ?? contents;

  @override
  Widget build(BuildContext context) {
    // The arrangement is this skin's own choice, and the choice is the
    // enum's declaration order: rail, toolbar, content, log, stacked. WHICH
    // regions exist is what the spec's data says - destinations make a rail,
    // groups make a toolbar, a visible aside makes the log - and every one
    // passes through the application's [ShellSpec.paneHost], so the F6 / Tab
    // order the application installs there is independent of this stack: the
    // naked skin proves the cycle survives any arrangement precisely by not
    // being told what the cycle is.
    final ShellAside? aside = spec.aside;
    final List<Widget> regions = <Widget>[
      // A shell with nowhere to go has no navigation strip, and the identity
      // travels with the strip it leads - the same latitude a paneOrder that
      // omitted the rail used to grant.
      if (spec.destinations.isNotEmpty) _hosted(ShellPane.rail, _rail(context)),
      // An empty toolbar draws nothing distinguishable, so the strip exists
      // exactly when a group does.
      if (spec.toolbar.isNotEmpty)
        _hosted(
          ShellPane.toolbar,
          _toolbarStrip(context, spec.toolbar, distance),
        ),
      Expanded(child: _hosted(ShellPane.content, _content())),
      if (aside != null && aside.visible)
        Expanded(child: _hosted(ShellPane.log, _aside(context, aside))),
    ];
    final Widget shell = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: distance.gap(Proximity.sectioned),
      children: <Widget>[
        // The banner is a standing message across the top of the WINDOW, so
        // it sits above every region the arrangement stacks below it.
        if (spec.banner != null)
          BlueprintSurfaces(distance).banner(context, spec.banner!),
        ...regions,
        if (spec.status != null || spec.activity != null) _statusStrip(context),
      ],
    );
    final BlockingProgressSpec? blocking = spec.blocking;
    if (blocking == null) return shell;
    // Blocking progress is a LAYER under this skin - the slot exists exactly
    // because route-versus-layer is the skin's decision - and the barrier is
    // paper at half strength, which stays on the census's legal line because
    // white over any paper-ink blend is still a paper-ink blend.
    return Stack(
      children: <Widget>[
        shell,
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Color(0x80FFFFFF)),
        ),
        Center(child: _blocking(context, blocking)),
      ],
    );
  }

  /// The navigation strip: who the application is, where the user can go,
  /// and - when the application states a density - the control that changes
  /// it.
  Widget _rail(BuildContext context) {
    final NavigationDensity? density = spec.density;
    final bool hidden = density == NavigationDensity.hidden;
    final bool condensed = density == NavigationDensity.condensed;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: distance.gap(Proximity.grouped),
        children: <Widget>[
          // At NavigationDensity.hidden the navigation itself is off screen -
          // that is what the value means - but the density control survives,
          // because a toggle that vanished with the thing it restores could
          // never bring it back.
          if (!hidden) _identity(context),
          if (!hidden)
            for (int index = 0; index < spec.destinations.length; index++)
              _destination(context, index, condensed: condensed),
          if (density != null && spec.onDensityChanged != null)
            _densityToggle(density),
        ],
      ),
    );
  }

  /// The application's name and its two marks: the role, and the raster.
  ///
  /// [AppIdentity.appIcon] IS painted, inside a [BlueprintOpaque]. It is not in
  /// §9.2's exemption table, and that table's rule is that everything absent
  /// from it is rendered - so dropping it would have made a skin that drops it
  /// indistinguishable from a skin that draws it, for precisely the field the
  /// macOS skin cannot drop (`MacosAlertDialog.appIcon` is a required Widget).
  /// The census cannot read a photograph, which is what the opaque region is
  /// for and why it is counted.
  ///
  /// The extent is the smallest box a normal control may be drawn in, so the
  /// raster is bounded by the same geometry vocabulary as everything else
  /// rather than by a number chosen here.
  Widget _identity(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      BlueprintMark(BlueprintMarks.icon(spec.identity.icon)),
      SizedBox.square(
        dimension: BlueprintGeometry.extent(context, ControlScale.normal),
        child: BlueprintOpaque(
          site: 'chrome.shell/appIcon',
          child: Semantics(
            image: true,
            label: spec.identity.name,
            child: Image(image: spec.identity.appIcon),
          ),
        ),
      ),
      BlueprintText(spec.identity.name),
    ],
  );

  /// One destination: an outlined square that is filled while current.
  Widget _destination(
    BuildContext context,
    int index, {
    required bool condensed,
  }) {
    final ShellDestination destination = spec.destinations[index];
    final bool selected = index == spec.selectedIndex;
    return BlueprintPressable(
      onPressed: () => spec.onSelect(index),
      // The label survives condensation as the accessible name, so reducing
      // the navigation to glyphs never reduces what a screen reader hears.
      semanticsLabel: destination.label,
      selected: selected,
      child: BlueprintBox(
        filled: selected,
        minExtent: BlueprintGeometry.extent(context, ControlScale.normal),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BlueprintMark(
              BlueprintMarks.icon(
                selected ? destination.selectedIcon : destination.icon,
              ),
            ),
            if (!condensed) BlueprintText(destination.label),
            if (destination.badgeCount != null)
              BlueprintMark(BlueprintMarks.count(destination.badgeCount!)),
          ],
        ),
      ),
    );
  }

  /// The display-mode control, drawn only because the application stated a
  /// density AND asked to hear about changes - the nullable-density contract
  /// in reverse. It shows the current value and advances to the next on each
  /// press, so all three values are reachable from the keyboard alone.
  Widget _densityToggle(NavigationDensity density) {
    final NavigationDensity next = NavigationDensity
        .values[(density.index + 1) % NavigationDensity.values.length];
    return BlueprintPressable(
      onPressed: () => spec.onDensityChanged!(next),
      child: BlueprintBox(child: BlueprintMark('[${density.name}]')),
    );
  }

  /// The selected destination's body, mounted through its port.
  Widget _content() {
    if (spec.destinations.isEmpty) return const SizedBox.shrink();
    final int index = spec.selectedIndex.clamp(0, spec.destinations.length - 1);
    return spec.destinations[index].body().mount();
  }

  /// The command-log region: its name, its own actions, its content and -
  /// when the application listens - the affordance that hides it.
  Widget _aside(BuildContext context, ShellAside aside) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        spacing: distance.gap(Proximity.grouped),
        children: <Widget>[
          BlueprintMark(BlueprintMarks.textRole(TextRole.sectionTitle)),
          Expanded(child: BlueprintText(aside.title)),
          for (final ToolbarActionEntry action in aside.actions)
            _toolbarEntry(context, action, distance),
          if (aside.onVisibilityChanged != null)
            BlueprintPressable(
              onPressed: () => aside.onVisibilityChanged!(false),
              child: const BlueprintBox(child: BlueprintMark('[hide]')),
            ),
        ],
      ),
      Expanded(child: aside.content.mount()),
    ],
  );

  /// The standing line along the bottom: the status at the start, the running
  /// operation at the end.
  ///
  /// Both halves are [Flexible], and that is not tidiness. A status label and
  /// a running operation are both the application's own words in one of six
  /// languages, and two min-size halves of a fixed-width strip overflow the
  /// moment they are long - which paints the framework's yellow-and-black
  /// stripes, i.e. pixels the chromatic census reports as an application leak
  /// that the application did not cause. The instrument may not fail on the
  /// content it exists to measure.
  Widget _statusStrip(BuildContext context) {
    final ShellStatus? status = spec.status;
    final ActivitySpec? activity = spec.activity;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        if (status != null)
          Flexible(child: _status(context, status))
        else
          const SizedBox.shrink(),
        if (activity != null) Flexible(child: _activity(context, activity)),
      ],
    );
  }

  /// What the shell is currently saying, operable when the application gave
  /// it something to do.
  Widget _status(BuildContext context, ShellStatus status) {
    final Widget row = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (status.icon != null)
          BlueprintMark(BlueprintMarks.icon(status.icon!)),
        if (BlueprintMarks.tone(status.tone).isNotEmpty)
          BlueprintMark(BlueprintMarks.tone(status.tone)),
        BlueprintText(status.label),
        if (status.detail != null) ...<Widget>[
          BlueprintMark(BlueprintMarks.textRole(TextRole.detail)),
          BlueprintText(status.detail!),
        ],
      ],
    );
    final VoidCallback? onTap = status.onTap;
    if (onTap == null) return row;
    return BlueprintPressable(onPressed: onTap, child: row);
  }

  /// The non-blocking report that something is running.
  ///
  /// An indeterminate operation renders the unknowable-progress mark; a
  /// countable one renders its fraction from its own steps, and the raw
  /// step count beside it so nothing the application stated is invisible.
  Widget _activity(BuildContext context, ActivitySpec activity) {
    final int? currentStep = activity.currentStep;
    final int? totalSteps = activity.totalSteps;
    final double? fraction =
        !activity.indeterminate &&
            currentStep != null &&
            totalSteps != null &&
            totalSteps > 0
        ? currentStep / totalSteps
        : null;
    final Widget row = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        BlueprintMark(BlueprintMarks.progress(fraction, ProgressExtent.inline)),
        BlueprintText(activity.operation),
        if (currentStep != null && totalSteps != null)
          BlueprintMark('($currentStep/$totalSteps)'),
      ],
    );
    if (activity.onShowDetail == null) return row;
    return BlueprintPressable(onPressed: activity.onShowDetail, child: row);
  }

  /// The operation the user must wait for, as the layer's centred card.
  Widget _blocking(
    BuildContext context,
    BlockingProgressSpec blocking,
  ) => BlueprintBox(
    rings: BlueprintGeometry.rings(Elevation.overlay),
    child: ColoredBox(
      color: BlueprintInk.paper(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BlueprintText(blocking.operation),
          BlueprintMark(
            BlueprintMarks.progress(blocking.fraction, ProgressExtent.block),
          ),
          if (blocking.currentStep != null && blocking.totalSteps != null)
            BlueprintMark('(${blocking.currentStep}/${blocking.totalSteps})'),
          if (blocking.detail != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BlueprintMark(BlueprintMarks.textRole(TextRole.detail)),
                BlueprintText(blocking.detail!),
              ],
            ),
        ],
      ),
    ),
  );
}

/// A whole action bar: its groups in order, scrolling when the window is
/// narrower than the bar.
///
/// Scrolling IS this skin's overflow answer. The contract gives overflow to
/// the skin, and the blueprint sheds nothing because shedding would need a
/// menu whose arrangement is a design decision; a scroll keeps every entry
/// reachable and every priority visible. The one piece of overflow knowledge
/// the application holds - which group to shed first - is rendered as a mark
/// on the group, so a priority the application never varies shows up as a
/// constant.
Widget _toolbarStrip(
  BuildContext context,
  List<ToolbarGroup> groups,
  BlueprintDistance distance,
) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    spacing: distance.gap(Proximity.separate),
    children: <Widget>[
      for (final ToolbarGroup group in groups)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: distance.gap(Proximity.grouped),
          children: <Widget>[
            if (group.priority != ToolbarPriority.normal)
              BlueprintMark('[${group.priority.name}]'),
            for (final ToolbarEntry entry in group.entries)
              _toolbarEntry(context, entry, distance),
          ],
        ),
    ],
  ),
);

/// One entry of an action bar, in whichever of its four kinds.
Widget _toolbarEntry(
  BuildContext context,
  ToolbarEntry entry,
  BlueprintDistance distance, {
  Emphasis? emphasisOverride,
  ControlScale scale = ControlScale.compact,
}) {
  switch (entry) {
    case ToolbarSeparatorEntry():
      return SizedBox(
        height: BlueprintGeometry.extent(context, ControlScale.compact),
        child: Container(
          width: BlueprintInk.hairline(context),
          color: BlueprintInk.ink(context),
        ),
      );
    case final ToolbarActionEntry action:
      final Emphasis emphasis = emphasisOverride ?? action.emphasis;
      return BlueprintPressable(
        onPressed: action.onPressed,
        tooltip: action.tooltip,
        semanticsLabel: action.label,
        child: BlueprintBox(
          stroke: BlueprintGeometry.stroke(context, emphasis),
          dashed: BlueprintGeometry.dashed(emphasis),
          minExtent: BlueprintGeometry.extent(context, scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              BlueprintMark(BlueprintMarks.icon(action.icon)),
              // What the action MEANS, drawn as the tone's own mark exactly as
              // `controls.button` draws it - an ordinary command has no mark
              // to show, a destructive one does. Without it the instrument
              // would be ignoring a slot the contract carries, which is the
              // one thing this skin may never do.
              if (BlueprintMarks.tone(action.tone).isNotEmpty)
                BlueprintMark(BlueprintMarks.tone(action.tone)),
              BlueprintText(action.label),
              if (action.badgeCount != null)
                BlueprintMark(BlueprintMarks.count(action.badgeCount!)),
              // A bar that silently dropped what it cannot do would explain
              // nothing, so an unavailable action stays visible and says so.
              if (action.onPressed == null)
                const BlueprintMark(BlueprintMarks.disabled),
            ],
          ),
        ),
      );
    case final ToolbarPickerEntry picker:
      final bool hasChoices = picker.entries.isNotEmpty;
      final String value = picker.value.isEmpty
          ? (picker.emptyLabel ?? BlueprintMarks.none)
          : picker.value;
      return _menuAnchor(
        context,
        distance: distance,
        entries: picker.entries,
        tooltip: picker.tooltip ?? picker.label,
        semanticsLabel: picker.label,
        enabled: hasChoices,
        scale: scale,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            BlueprintMark(BlueprintMarks.icon(picker.icon)),
            BlueprintText(picker.label),
            const BlueprintMark(':'),
            BlueprintText(value),
            if (!hasChoices) const BlueprintMark(BlueprintMarks.disabled),
          ],
        ),
      );
    case final ToolbarMenuEntry menu:
      // Through `Overlays.anchor`, the contract's own front door, and not
      // through this file's `_menuAnchor` helper - which is what the picker
      // above still uses, because a picker's content is a sentence this
      // instrument writes ("Repository: gitui") and no anchor spec says that.
      //
      // The reason is a measurement, not a preference. `Overlays.anchor`
      // plants the contract's `SkinMenuAnchor` identity, and the scene sweep
      // counts it: with Material's screen frame going through the front door
      // and this one not, the settings scene measured 136 components through
      // the contract under Material and 135 under the blueprint - a
      // resting-state disagreement, which the register's own text calls a
      // defect rather than an entry. Both frames now mount the same one
      // anchor, so the count is skin-independent again by construction.
      //
      // NAMED, not silent: this drops `ToolbarMenuEntry.label`, the optional
      // words beside the mark, because `MenuAnchorSpec` has no word for them
      // and the anchor is mark-only in both languages that implement it. No
      // call site passes the label today, and the slot's own doc makes it the
      // frame's option ("where the frame has room for them") rather than an
      // obligation - but it is a real gap in the anchor vocabulary and is
      // reported as one.
      return Overlays.anchor(
        spec: MenuAnchorSpec(
          icon: menu.icon,
          tooltip: menu.tooltip,
          badgeCount: menu.badgeCount,
          enabled: menu.entries.isNotEmpty,
          scale: scale,
        ),
        entries: menu.entries,
      );
    case final ToolbarChoiceEntry choice:
      // Through this skin's own `controls.choiceGroup`, at the bar's scale.
      // "Pick exactly one of a few" is a control the instrument already draws
      // - a row of outlined boxes with the chosen one filled - and drawing a
      // second version of it here would be the instrument disagreeing with
      // itself about what a choice looks like. The scale is the bar's rather
      // than the spec's, for the same reason every other entry takes it: how
      // much room a control gets INSIDE a bar is the frame's arithmetic.
      //
      // Through `withSpec` and not through `choice.spec`: the switch matched
      // at the bound, and the spec's callback only survives at the type the
      // application declared it with. See `ToolbarChoiceEntry.withSpec`.
      return choice.withSpec(
        <S>(ChoiceGroupSpec<S> spec) =>
            BlueprintControls(distance).choiceGroup<S>(
              context,
              ChoiceGroupSpec<S>(
                options: spec.options,
                selected: spec.selected,
                onSelected: spec.onSelected,
                label: spec.label,
                scale: scale,
              ),
            ),
      );
  }
}

/// An anchor that opens this skin's own menu under itself.
///
/// The entries are data, so the anchor is the skin's - which is the whole
/// point of the picker being data rather than a pre-built widget - and the
/// menu it opens goes through `Overlays.menu`, the application's own front
/// door, rather than through this skin's `presentMenu` directly. That is not
/// politeness: the front door is what captures the envelope and builds the
/// host, and a skin that called its own member directly would have to
/// construct a host it deliberately cannot construct.
Widget _menuAnchor(
  BuildContext context, {
  required BlueprintDistance distance,
  required List<MenuEntry> entries,
  required Widget content,
  required String? tooltip,
  required String? semanticsLabel,
  required bool enabled,
  required ControlScale scale,
}) => Builder(
  builder: (BuildContext anchorContext) => BlueprintPressable(
    onPressed: enabled
        ? () {
            final RenderObject? renderObject = anchorContext.findRenderObject();
            Offset at = Offset.zero;
            if (renderObject is RenderBox && renderObject.hasSize) {
              at = renderObject.localToGlobal(
                Offset(0, renderObject.size.height),
              );
            }
            unawaited(Overlays.menu(anchorContext, at: at, entries: entries));
          }
        : null,
    tooltip: tooltip,
    semanticsLabel: semanticsLabel,
    child: BlueprintBox(
      minExtent: BlueprintGeometry.extent(context, scale),
      child: content,
    ),
  ),
);
