import 'package:flutter/material.dart' hide MaterialType;
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../material_glyphs.dart';
import '../material_ink.dart';
import '../material_theme.dart';
import 'material_controls.dart';
import 'material_surfaces.dart';

/// The frame: the root, the shell, the screens, the dialog surface - the
/// Material way.
///
/// The four members are extractions, not designs: `wrapRoot` is
/// `AppTheme.lightTheme`/`darkTheme` (via `MaterialThemeFactory`), `shell` is
/// `app_shell.dart:294-682` with `OverflowActionBar` and `BaseSwitcher`
/// folded in, `screen` is the 18 raw scaffolds plus `StandardAppBar` and
/// `BatchOperationsBar`, and `dialogSurface` is `base_dialog.dart`'s build
/// with `base_viewer_dialog.dart` answering the browser extent.
///
/// Wherever the frame contains a thing another facet already owns - a
/// banner, a button, a progress bar - it renders it through that facet
/// rather than sketching a second version, because two renderings of one
/// spec inside one skin is the same defect as two affordances for one job.
final class MaterialChrome implements SkinChrome {
  /// Builds the frame facet.
  const MaterialChrome();

  /// Installs Material's own theme, built from the user's request.
  ///
  /// The theme is the application's own `FlexThemeData` factory, moved
  /// (see `MaterialThemeFactory` for what moved and what translated). The
  /// [Theme] widget carries the [IconTheme] with it; a root
  /// [DefaultTextStyle] is deliberately NOT installed, because that is not
  /// Material's model - `MaterialApp` installs only the red error style as a
  /// leak alarm, and every Material surface publishes its own text style for
  /// its own content. Installing a friendly default here would silence the
  /// very fallback that makes a missing `Material` ancestor visible.
  ///
  /// [MaterialRequestScope] travels with the theme so the facets can resolve
  /// the two per-user values the theme deliberately does not publish: the
  /// animation scale (motion) and the monospace family (type). That is what
  /// replaces the application's `AnimationSpeedExtension`, whose entire
  /// purpose was to make a `Duration` readable by application code.
  ///
  /// **An [AnimatedTheme], not a [Theme], and that is load-bearing.** Material
  /// cross-fades between two themes rather than cutting: `MaterialApp` has
  /// always installed its own `AnimatedTheme` over `theme`/`darkTheme`
  /// (Flutter 3.44.4 packages/flutter/lib/src/material/app.dart,
  /// `_MaterialAppState._materialBuilder`), which is why switching Settings ->
  /// Theme from Light to Dark reads as a 200 ms dissolve of every surface at
  /// once. A root treatment that installed a plain `Theme` under that one would
  /// override the lerp with a discrete theme and turn the dissolve into a hard
  /// cut - so the widget is part of what is being extracted, not a detail of
  /// the host. `kThemeAnimationDuration` is kept rather than scaled by
  /// [SkinRequest.animationScale] because that is what the application has
  /// always rendered for every animation-speed setting, this included, and P2
  /// moves rendering rather than changing it.
  ///
  /// It costs nothing at rest: an implicitly animated widget starts with its
  /// tween's begin and end both at the target, so the first frame after any
  /// mount renders exactly `themeFor(request)` and no animation is scheduled.
  @override
  Widget wrapRoot(
    BuildContext context, {
    required Widget child,
    required SkinRequest request,
  }) => MaterialRequestScope(
    request: request,
    child: AnimatedTheme(
      data: MaterialThemeFactory.themeFor(request),
      child: child,
    ),
  );

  /// The whole application window.
  @override
  Widget shell(BuildContext context, ShellSpec spec) =>
      _MaterialShell(spec: spec);

  /// One screen inside the shell.
  ///
  /// The extraction of the standard screen frame: a [Scaffold] whose app bar
  /// is `StandardAppBar`'s arrangement (the title, the screen's own actions
  /// as icon buttons, a trailing menu anchor per menu entry), whose selection
  /// bar is `BatchOperationsBar` along the bottom, and whose primary actions
  /// take Material's own answer to "what is this screen for" - the floating
  /// action button.
  @override
  Widget screen(BuildContext context, ScreenSpec spec) {
    const MaterialSurfaces surfaces = MaterialSurfaces();
    final SelectionBarSpec? selectionBar = spec.selectionBar;
    return Scaffold(
      appBar: AppBar(
        title: Text(spec.title),
        actions: <Widget>[
          for (final ToolbarGroup group in spec.toolbar)
            for (final ToolbarEntry entry in group.entries) ...<Widget>[
              _toolbarEntry(context, entry),
              const SizedBox(width: MaterialMetrics.spaceS),
            ],
        ],
      ),
      body: Column(
        children: <Widget>[
          if (spec.banner != null) surfaces.banner(context, spec.banner!),
          Expanded(child: spec.body.mount()),
          if (spec.footer != null) spec.footer!.mount(),
        ],
      ),
      bottomNavigationBar: selectionBar == null
          ? null
          : _MaterialSelectionBar(spec: selectionBar),
      floatingActionButton: spec.primaryActions.isEmpty
          ? null
          : _primaryActions(context, spec.primaryActions),
    );
  }

  /// The screen's primary actions as Material's floating action button.
  ///
  /// One action is the plain FAB. Several collapse into one FAB that opens
  /// them as a menu - the shape the application's draggable speed dial
  /// renders today, with the drag affordance being that component's own
  /// business until it moves in at P5. Escape-to-collapse is behaviour and
  /// stays with the application either way.
  static Widget _primaryActions(
    BuildContext context,
    List<ToolbarActionEntry> actions,
  ) {
    if (actions.length == 1) {
      final ToolbarActionEntry action = actions.single;
      return FloatingActionButton(
        tooltip: action.tooltip,
        onPressed: action.onPressed,
        child: Icon(MaterialGlyphs.of(action.icon)),
      );
    }
    return Builder(
      builder: (BuildContext anchorContext) => FloatingActionButton(
        tooltip: MaterialLocalizations.of(anchorContext).moreButtonTooltip,
        onPressed: () => _openMenuUnder(anchorContext, <MenuEntry>[
          for (final ToolbarActionEntry action in actions)
            MenuAction(
              label: action.label,
              icon: action.icon,
              onPressed: action.onPressed,
            ),
        ]),
        child: Icon(MaterialGlyphs.of(IconRole.plus)),
      ),
    );
  }

  /// One entry of a screen's app bar.
  static Widget _toolbarEntry(BuildContext context, ToolbarEntry entry) {
    const MaterialControls controls = MaterialControls();
    switch (entry) {
      case ToolbarSeparatorEntry():
        return const SizedBox(width: MaterialMetrics.spaceS);
      case final ToolbarActionEntry action:
        return controls.iconButton(
          context,
          IconButtonSpec(
            icon: action.icon,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
            badgeCount: action.badgeCount,
          ),
        );
      case final ToolbarPickerEntry picker:
        return _MaterialToolbarPicker(picker: picker);
      case final ToolbarMenuEntry menu:
        return Builder(
          builder: (BuildContext anchorContext) => controls.iconButton(
            anchorContext,
            IconButtonSpec(
              icon: menu.icon,
              tooltip: menu.tooltip,
              badgeCount: menu.badgeCount,
              onPressed: menu.entries.isEmpty
                  ? null
                  : () => _openMenuUnder(anchorContext, menu.entries),
            ),
          ),
        );
    }
  }

  /// The inside of a dialog: the title, the content and the ways out.
  ///
  /// Only the surface. The route belongs to `overlays.presentDialog` and the
  /// keyboard contract to the application's own `DialogKeyboardHost`, which
  /// the API package has already wrapped around this widget by the time it
  /// builds - Escape, Enter, the multiline exception and the destructive
  /// withholding are all decided before this member is reached, which is why
  /// nothing here handles a key.
  @override
  Widget dialogSurface(BuildContext context, DialogSpec spec) =>
      spec.extent == DialogExtent.browser
      ? _MaterialViewerDialogSurface(spec: spec)
      : _MaterialDialogSurface(spec: spec);
}

/// Opens this skin's own menu under the control at [anchorContext].
///
/// The menu goes through `Overlays.menu`, the application's own front door,
/// rather than through this skin's `presentMenu` directly. That is not
/// politeness: the front door is what captures the envelope and builds the
/// host, and a skin that called its own member directly would have to
/// construct a host it deliberately cannot construct.
void _openMenuUnder(BuildContext anchorContext, List<MenuEntry> entries) {
  final RenderObject? renderObject = anchorContext.findRenderObject();
  Offset at = Offset.zero;
  if (renderObject is RenderBox && renderObject.hasSize) {
    at = renderObject.localToGlobal(Offset(0, renderObject.size.height));
  }
  // The future is deliberately not awaited: a menu's outcome is dispatched by
  // the overlay member itself, and an anchor has nothing to do with it.
  // ignore: unawaited_futures
  Overlays.menu(anchorContext, at: at, entries: entries);
}

/// The whole window, extracted from `app_shell.dart:294-682`.
///
/// Stateful for exactly one reason: when the application leaves
/// `ShellSpec.density` null it is saying "this skin owns its own display
/// mode", and Material's rail - unlike Fluent's pane or macOS's window - has
/// no built-in toggle, so this skin keeps the collapsed/expanded fact itself
/// and draws its own caret, which is the affordance `app_shell.dart:353`
/// used to draw in application code.
class _MaterialShell extends StatefulWidget {
  const _MaterialShell({required this.spec});

  /// What the window contains.
  final ShellSpec spec;

  @override
  State<_MaterialShell> createState() => _MaterialShellState();
}

class _MaterialShellState extends State<_MaterialShell> {
  /// The display mode this skin keeps when the application declares none.
  bool _ownExtended = true;

  ShellSpec get spec => widget.spec;

  NavigationDensity get _density =>
      spec.density ??
      (_ownExtended ? NavigationDensity.full : NavigationDensity.condensed);

  @override
  Widget build(BuildContext context) {
    final Set<ShellPane> panes = spec.paneOrder.toSet();
    final ShellAside? aside = spec.aside;
    final BlockingProgressSpec? blocking = spec.blocking;

    // The visual arrangement is this skin's and it is exactly the measured
    // one: rail, hairline, a column of toolbar over content, and the log
    // panel at the trailing edge. `paneOrder` states WHICH regions exist and
    // in which order the F6 cycle walks them - that is what the user can do,
    // it is owned by the application's own focus regions wrapped around this
    // return, and no arrangement here may change it.
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (panes.contains(ShellPane.rail) &&
                  _density != NavigationDensity.hidden) ...<Widget>[
                _rail(context),
                const VerticalDivider(thickness: 1, width: 1),
              ],
              Expanded(
                child: Column(
                  children: <Widget>[
                    if (panes.contains(ShellPane.toolbar))
                      _MaterialShellToolbar(groups: spec.toolbar),
                    // The warning banner and the active screen form the
                    // content region together: the banner is part of what the
                    // user is working on, not part of the toolbar, so Tab and
                    // F6 treat them as one pane.
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          if (spec.banner != null)
                            const MaterialSurfaces().banner(
                              context,
                              spec.banner!,
                            ),
                          Expanded(child: _content()),
                        ],
                      ),
                    ),
                    if (spec.status != null || spec.activity != null)
                      _statusStrip(context),
                  ],
                ),
              ),
              if (panes.contains(ShellPane.log) &&
                  aside != null &&
                  aside.visible)
                aside.content.mount(),
            ],
          ),
          // The activity strip floats over the content's top edge so a
          // background operation never steals input or layout; see
          // [_MaterialActivityLine] for the extraction.
          if (spec.activity != null)
            Align(
              alignment: Alignment.topCenter,
              child: _MaterialActivityLine(spec: spec.activity!),
            ),
          if (blocking != null) ..._blocking(context, blocking),
        ],
      ),
    );
  }

  /// The navigation rail, extracted with its identity, its badges and the
  /// display-mode caret.
  Widget _rail(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool extended = _density == NavigationDensity.full;
    final bool ownsToggle = spec.density == null;
    return NavigationRail(
      extended: extended,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      selectedIndex: spec.selectedIndex,
      onDestinationSelected: spec.onSelect,
      leading: Column(
        children: <Widget>[
          const SizedBox(height: MaterialMetrics.spaceM),
          Column(
            children: <Widget>[
              // The application drew its identity mark at the bold weight;
              // the glyph table deliberately carries one weight plus named
              // selected marks (see MaterialGlyphs), so the identity renders
              // at the regular weight until the shell wiring at P5 asks the
              // table for a bold entry.
              Icon(
                MaterialGlyphs.of(spec.identity.icon),
                size: MaterialMetrics.iconXL,
                color: theme.colorScheme.primary,
              ),
              if (extended) ...<Widget>[
                const SizedBox(height: MaterialMetrics.spaceS),
                // ignore: avoid_text_with_style
                Text(
                  spec.identity.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: MaterialMetrics.spaceL),
        ],
      ),
      // The caret is this SKIN's affordance now: Material's rail ships no
      // toggle of its own, so the skin draws one whenever it either owns the
      // display mode outright (a null density) or the application asked to
      // hear about changes. Two affordances for one job stays impossible,
      // because a skin whose canonical navigation had its own control would
      // leave this out entirely.
      trailing: (ownsToggle || spec.onDensityChanged != null)
          ? Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: MaterialMetrics.spaceM,
                  ),
                  child: const MaterialControls().iconButton(
                    context,
                    IconButtonSpec(
                      icon: extended ? IconRole.caretLeft : IconRole.caretRight,
                      tooltip: extended
                          ? MaterialLocalizations.of(
                              context,
                            ).expandedIconTapHint
                          : MaterialLocalizations.of(
                              context,
                            ).collapsedIconTapHint,
                      onPressed: _toggleDensity,
                    ),
                  ),
                ),
              ),
            )
          : null,
      destinations: <NavigationRailDestination>[
        for (final ShellDestination destination in spec.destinations)
          NavigationRailDestination(
            icon: _iconWithBadge(
              Icon(MaterialGlyphs.of(destination.icon)),
              destination.badgeCount,
            ),
            // The selected mark is its own ROLE on the spec - "selected" is
            // a different glyph in this application, not merely a different
            // weight - so both states resolve through the one table.
            selectedIcon: _iconWithBadge(
              Icon(MaterialGlyphs.of(destination.selectedIcon)),
              destination.badgeCount,
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }

  void _toggleDensity() {
    final NavigationDensity next = _density == NavigationDensity.full
        ? NavigationDensity.condensed
        : NavigationDensity.full;
    final ValueChanged<NavigationDensity>? onDensityChanged =
        spec.onDensityChanged;
    if (onDensityChanged != null) {
      onDensityChanged(next);
    }
    if (spec.density == null) {
      setState(() => _ownExtended = next == NavigationDensity.full);
    }
  }

  /// A destination glyph with its count riding on it, or the bare glyph when
  /// there is nothing to report - the same suppression the shell has always
  /// applied, because a zero-count badge is noise wearing a number.
  ///
  /// Material's own [Badge.count] rather than the application's
  /// `BaseIconBadge`: delegating to the canonical widget is exactly this
  /// package's job, which is why the app-wide ban is lifted on this line and
  /// nowhere the rule can still do its work.
  static Widget _iconWithBadge(Widget icon, int? count) {
    if (count == null || count == 0) return icon;
    // ignore: avoid_badge
    return Badge.count(count: count, child: icon);
  }

  /// The selected destination's body, mounted through its port.
  Widget _content() {
    if (spec.destinations.isEmpty) return const SizedBox.shrink();
    final int index = spec.selectedIndex.clamp(0, spec.destinations.length - 1);
    return spec.destinations[index].body().mount();
  }

  /// The standing status line along the bottom.
  Widget _statusStrip(BuildContext context) {
    final ShellStatus? status = spec.status;
    if (status == null) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MaterialMetrics.spaceM,
        vertical: MaterialMetrics.spaceXS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (status.icon != null) ...<Widget>[
            Icon(
              MaterialGlyphs.of(status.icon!),
              size: MaterialMetrics.iconS,
              color: MaterialInk.foreground(context, status.tone),
            ),
            const SizedBox(width: MaterialMetrics.spaceS),
          ],
          Flexible(
            // ignore: avoid_text_with_style
            child: Text(
              status.detail == null
                  ? status.label
                  : '${status.label} - ${status.detail}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: MaterialInk.foreground(context, status.tone),
              ),
            ),
          ),
        ],
      ),
    );
    final VoidCallback? onTap = status.onTap;
    if (onTap != null) {
      row = InkWell(onTap: onTap, child: row);
    }
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(width: double.infinity, child: row),
    );
  }

  /// The blocking layer, extracted from `progress_overlay.dart`'s blocking
  /// branch: the scrim, and the centred card naming the operation.
  List<Widget> _blocking(BuildContext context, BlockingProgressSpec blocking) {
    final double? fraction = blocking.fraction;
    return <Widget>[
      // Semi-transparent background: the scrim role at the M3 barrier
      // opacity.
      ModalBarrier(
        dismissible: false,
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(MaterialMetrics.spaceL),
          // The resting card the application's progress overlay drew, kept as
          // this skin's own arrangement: the operation's name beside a
          // spinner glyph, the bar, the step count against the percentage,
          // and the current sub-step underneath.
          // ignore: avoid_card
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(MaterialMetrics.spaceM),
              child: Container(
                constraints: const BoxConstraints(minWidth: 400, maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          MaterialGlyphs.of(IconRole.circleNotch),
                          size: MaterialMetrics.iconL,
                        ),
                        const SizedBox(width: MaterialMetrics.spaceM),
                        Expanded(
                          // ignore: avoid_text_with_style
                          child: Text(
                            blocking.operation,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MaterialMetrics.spaceL),
                    LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(
                        MaterialMetrics.radiusS,
                      ),
                    ),
                    if (fraction != null &&
                        blocking.currentStep != null &&
                        blocking.totalSteps != null) ...<Widget>[
                      const SizedBox(height: MaterialMetrics.spaceM),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // ignore: avoid_text_with_style
                          Text(
                            '${blocking.currentStep} / ${blocking.totalSteps}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          // ignore: avoid_text_with_style
                          Text(
                            '${(fraction * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    if (blocking.detail != null) ...<Widget>[
                      const SizedBox(height: MaterialMetrics.spaceM),
                      // ignore: avoid_text_with_style
                      Text(
                        blocking.detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// The thin non-blocking activity line, extracted from
/// `progress_overlay.dart`'s background branch.
///
/// Background operations must never steal input or attention, so they get
/// the thin line along the top edge that browsers and editors use, instead
/// of a dialog blocking the whole window (#288). Work the application
/// started by itself also carries a name and, where the total is known, a
/// count: an anonymous line cannot say what is running or whether it is
/// progressing at all.
class _MaterialActivityLine extends StatelessWidget {
  const _MaterialActivityLine({required this.spec});

  /// The running operation.
  final ActivitySpec spec;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int? currentStep = spec.currentStep;
    final int? totalSteps = spec.totalSteps;
    final bool showsCount =
        !spec.indeterminate &&
        currentStep != null &&
        totalSteps != null &&
        totalSteps > 0;
    final String caption = showsCount
        ? '${spec.operation}… $currentStep/$totalSteps'
        : '${spec.operation}…';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The line itself must not swallow clicks meant for the content it
        // floats over; only the caption is a target.
        SizedBox(
          width: double.infinity,
          child: IgnorePointer(
            child: LinearProgressIndicator(
              minHeight: 3,
              value: showsCount ? currentStep / totalSteps : null,
            ),
          ),
        ),
        if (spec.operation.isNotEmpty)
          Material(
            color: colors.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(MaterialMetrics.radiusS),
            ),
            // The count says how far the sweep got, not which repository is
            // slow, which already finished, or which failed and why. That is
            // one click away rather than absent.
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(MaterialMetrics.radiusS),
              ),
              onTap: spec.onShowDetail,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MaterialMetrics.spaceM,
                  vertical: MaterialMetrics.spaceXS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // ignore: avoid_text_with_style
                    Text(
                      caption,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (spec.onShowDetail != null) ...<Widget>[
                      const SizedBox(width: MaterialMetrics.spaceXS),
                      Icon(
                        MaterialGlyphs.of(IconRole.caretRight),
                        size: MaterialMetrics.iconXS,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The shell's action bar, extracted from the toolbar region of
/// `app_shell.dart:416-568` with `OverflowActionBar` folded in.
class _MaterialShellToolbar extends StatelessWidget {
  const _MaterialShellToolbar({required this.groups});

  /// The bar's groups, in the application's order.
  final List<ToolbarGroup> groups;

  /// Layout width of one compact icon button: the 48 dp tap target the
  /// button pads itself out to, not its 32 dp visual container. The
  /// arithmetic computes how many actions fit in a row, so it must follow
  /// the box the row actually lays out.
  static const double _itemExtent = 48;

  /// Width of the overflow button. It carries its own tap target and needs
  /// its own reservation: it happens to equal [_itemExtent] today, but the
  /// two describe different widgets and have diverged before.
  static const double _menuExtent = 48;

  static const double _spacing = MaterialMetrics.spaceS;

  /// The widest a sheddable group may claim before it must collapse into its
  /// own overflow menu: three icons and their gaps, the measured width of
  /// the application's utility cluster.
  static const double _sheddableWidth = 3 * _itemExtent + 2 * _spacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // The bar's entries fall into three treatments the application measured
    // out one by one: the pickers name the things every other control acts
    // on and get their width first; the ordinary action groups share what is
    // left and hand what no longer fits to their overflow menus; and the
    // sheddable groups are capped so they collapse into their menus instead
    // of pushing the pickers off the bar (#359). Standing menus stay put at
    // the trailing edge: each is a popup of its own rather than an action
    // with a single callback, so neither can be folded into an overflow.
    final List<ToolbarPickerEntry> pickers = <ToolbarPickerEntry>[
      for (final ToolbarGroup group in groups)
        for (final ToolbarEntry entry in group.entries)
          if (entry is ToolbarPickerEntry) entry,
    ];
    final List<ToolbarActionEntry> normalActions = <ToolbarActionEntry>[
      for (final ToolbarGroup group in groups)
        if (group.priority != ToolbarPriority.sheddable)
          for (final ToolbarEntry entry in group.entries)
            if (entry is ToolbarActionEntry) entry,
    ];
    final List<ToolbarActionEntry> sheddableActions = <ToolbarActionEntry>[
      for (final ToolbarGroup group in groups)
        if (group.priority == ToolbarPriority.sheddable)
          for (final ToolbarEntry entry in group.entries)
            if (entry is ToolbarActionEntry) entry,
    ];
    final List<ToolbarMenuEntry> menus = <ToolbarMenuEntry>[
      for (final ToolbarGroup group in groups)
        for (final ToolbarEntry entry in group.entries)
          if (entry is ToolbarMenuEntry) entry,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MaterialMetrics.spaceM,
        vertical: MaterialMetrics.spaceS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      // Measured, because how much room the actions may claim before
      // collapsing into their overflow menu depends on the window width.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints inner) => Row(
                  children: <Widget>[
                    // The pickers get the width they need before the actions
                    // claim any: they name the workspace, repository and
                    // branch every other control acts on, and a clipped name
                    // says nothing, whereas an action that no longer fits
                    // stays reachable in its overflow menu. Their ceiling
                    // reserves that menu's button, so the actions can never
                    // be squeezed out entirely. Within the ceiling each
                    // picker shrinks to an ellipsized label rather than the
                    // group scrolling, which used to cut the last picker
                    // mid-widget into a seemingly empty sliver.
                    if (pickers.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                              (inner.maxWidth -
                                      MaterialMetrics.spaceM -
                                      _menuExtent)
                                  .clamp(0.0, inner.maxWidth),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final ToolbarPickerEntry picker in pickers)
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: MaterialMetrics.spaceM,
                                  ),
                                  child: _MaterialToolbarPicker(picker: picker),
                                ),
                              ),
                          ],
                        ),
                      ),
                    // The actions stay rendered without a target and grey
                    // out with a reason carried in their tooltips, so the
                    // toolbar never shows an unexplained gap (#303).
                    // Expanded, so they take exactly what the pickers leave -
                    // at least their overflow menu button, by the ceiling
                    // above - and hand whatever no longer fits to that menu.
                    // Aligned left so the group stays attached to the
                    // pickers it operates on.
                    if (normalActions.isNotEmpty)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _OverflowActionRow(actions: normalActions),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _spacing),
            // Capped like the actions, so the sheddable group collapses into
            // its own overflow menu instead of claiming full width and
            // pushing the pickers off the bar. Without a cap this group is
            // the only one that never yields, and the row overflows.
            if (sheddableActions.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (constraints.maxWidth * 0.25).clamp(
                    // Never below the overflow button itself, or the bar
                    // cannot even draw the menu it collapsed into.
                    _menuExtent,
                    _sheddableWidth,
                  ),
                ),
                child: _OverflowActionRow(actions: sheddableActions),
              ),
            for (final ToolbarMenuEntry menu in menus) ...<Widget>[
              const SizedBox(width: _spacing),
              MaterialChrome._toolbarEntry(context, menu),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row of icon actions that moves what does not fit into an overflow menu.
///
/// The extraction of `OverflowActionBar`, formula and all. A toolbar that
/// simply scrolls its actions out of sight looks like the actions are gone:
/// there is nothing to indicate more exists, and no way to reach it without
/// discovering the scroll. The overflow button is the usual answer, and it
/// also lets the hidden actions carry their name, which an icon squeezed
/// into a narrow bar cannot.
class _OverflowActionRow extends StatelessWidget {
  const _OverflowActionRow({required this.actions});

  /// The actions, in the application's order.
  final List<ToolbarActionEntry> actions;

  /// How many actions fit before the overflow button is needed.
  ///
  /// Returns the number to show as icons; the rest belong in the menu. When
  /// everything fits, no slot is reserved for the overflow button -
  /// reserving one unconditionally would push out an action that had room.
  static int visibleActionCount({
    required double availableWidth,
    required int actionCount,
  }) {
    if (actionCount <= 0) return 0;
    const double itemExtent = _MaterialShellToolbar._itemExtent;
    const double spacing = _MaterialShellToolbar._spacing;
    const double menuExtent = _MaterialShellToolbar._menuExtent;

    // n items need n widths and n-1 gaps.
    final double widthForAll =
        actionCount * itemExtent + (actionCount - 1) * spacing;
    if (widthForAll <= availableWidth) return actionCount;

    // Otherwise every shown item is followed by a gap, and the overflow
    // button closes the row with its own reservation.
    const double perItem = itemExtent + spacing;
    final int fitting = ((availableWidth - menuExtent) / perItem).floor();
    return fitting.clamp(0, actionCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    const MaterialControls controls = MaterialControls();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int visible = visibleActionCount(
          availableWidth: constraints.maxWidth,
          actionCount: actions.length,
        );
        final List<ToolbarActionEntry> hidden = actions
            .skip(visible)
            .toList(growable: false);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < visible; index++) ...<Widget>[
              if (index > 0)
                const SizedBox(width: _MaterialShellToolbar._spacing),
              controls.iconButton(
                context,
                IconButtonSpec(
                  icon: actions[index].icon,
                  tooltip: actions[index].tooltip,
                  onPressed: actions[index].onPressed,
                  scale: ControlScale.compact,
                  badgeCount: actions[index].badgeCount,
                ),
              ),
            ],
            if (hidden.isNotEmpty) ...<Widget>[
              if (visible > 0)
                const SizedBox(width: _MaterialShellToolbar._spacing),
              Builder(
                builder: (BuildContext anchorContext) => controls.iconButton(
                  anchorContext,
                  IconButtonSpec(
                    icon: IconRole.dotsThreeVertical,
                    tooltip: MaterialLocalizations.of(
                      anchorContext,
                    ).moreButtonTooltip,
                    scale: ControlScale.compact,
                    onPressed: () => _openMenuUnder(anchorContext, <MenuEntry>[
                      // A hidden action keeps its name - that is the overflow
                      // menu's advantage over a scroll - and a disabled one
                      // stays in the menu with its reason in its tooltip
                      // rather than vanishing from it.
                      for (final ToolbarActionEntry action in hidden)
                        MenuAction(
                          label: action.label,
                          icon: action.icon,
                          onPressed: action.onPressed,
                        ),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One picker: the extraction of `BaseSwitcher`, opening its entries as this
/// skin's own menu.
///
/// The picker NAMES the thing other controls act on; it is not an action.
/// The entries are data, so the anchor is the skin's - which is the whole
/// point of the picker being data rather than a pre-built widget.
class _MaterialToolbarPicker extends StatelessWidget {
  const _MaterialToolbarPicker({required this.picker});

  /// The picker being drawn.
  final ToolbarPickerEntry picker;

  /// The narrowest width a picker can be squeezed to before its fixed chrome
  /// would overflow: 1+1 border, 16+16 padding, 16 glyph, 8+8 gaps and the
  /// 16 dropdown arrow come to 82, plus room for the ellipsis to start. A
  /// width-limited bar must not constrain one below this.
  static const double _minShrunkWidth = 90;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasChoices = picker.entries.isNotEmpty;
    final String value = picker.value.isEmpty
        ? (picker.emptyLabel ?? '')
        : picker.value;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: _minShrunkWidth),
      child: Builder(
        builder: (BuildContext anchorContext) => InkWell(
          onTap: hasChoices
              ? () => _openMenuUnder(anchorContext, picker.entries)
              : null,
          borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
          child: Tooltip(
            message: picker.tooltip ?? picker.label,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MaterialMetrics.spaceM,
                vertical: MaterialMetrics.spaceS,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    MaterialGlyphs.of(picker.icon),
                    size: MaterialMetrics.iconS,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: MaterialMetrics.spaceS),
                  // Flexible, so a width-constrained picker shrinks its label
                  // (ellipsized) rather than overflowing; when unconstrained
                  // the loose fit leaves the natural width untouched.
                  Flexible(
                    // ignore: avoid_text_with_style
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (hasChoices) ...<Widget>[
                    const SizedBox(width: MaterialMetrics.spaceS),
                    Icon(
                      Icons.arrow_drop_down,
                      size: MaterialMetrics.iconS,
                      color: theme.colorScheme.onSurface,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The batch bar shown while things are multi-selected, extracted from
/// `BatchOperationsBar`.
class _MaterialSelectionBar extends StatelessWidget {
  const _MaterialSelectionBar({required this.spec});

  /// The current selection and what can be done to it.
  final SelectionBarSpec spec;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    const MaterialControls controls = MaterialControls();
    return Container(
      padding: const EdgeInsets.all(MaterialMetrics.spaceM),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Icon(
              MaterialGlyphs.of(IconRole.checkSquare),
              size: MaterialMetrics.iconM,
              color: colors.primary,
            ),
            const SizedBox(width: MaterialMetrics.spaceS),
            // The count is the information; its sentence ("3 selected") is
            // the application's translation and arrives with the P5 wiring.
            // ignore: avoid_text_with_style
            Text(
              '${spec.selectedCount}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const Spacer(),
            for (final ToolbarGroup group in spec.actions)
              for (final ToolbarEntry entry in group.entries)
                if (entry is ToolbarActionEntry)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: MaterialMetrics.spaceS,
                    ),
                    child: controls.button(
                      context,
                      ButtonSpec(
                        label: entry.label,
                        onPressed: entry.onPressed,
                        emphasis: entry.emphasis,
                        tone: Tone.neutral,
                        leading: entry.icon,
                        tooltip: entry.tooltip,
                      ),
                    ),
                  ),
            const SizedBox(width: MaterialMetrics.spaceS),
            controls.iconButton(
              context,
              IconButtonSpec(
                icon: IconRole.x,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: spec.onClear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ordinary dialog surface, extracted from `base_dialog.dart`'s build.
class _MaterialDialogSurface extends StatelessWidget {
  const _MaterialDialogSurface({required this.spec});

  /// What the dialog asks.
  final DialogSpec spec;

  /// The width each extent is entitled to. The form width is the
  /// application's own default dialog width; the alert is narrower because a
  /// sentence and two answers at 650 logical pixels reads as an empty room.
  /// These are what fifteen call sites approximated with a number.
  static double _maxWidthFor(DialogExtent extent) => switch (extent) {
    DialogExtent.alert => 400,
    DialogExtent.form => 650,
    // The browser extent renders through _MaterialViewerDialogSurface and
    // never reaches this table; the value only keeps the switch total.
    DialogExtent.browser => 650,
  };

  /// The narrowest a dialog may be, the application's own floor.
  static const double _minWidth = 300;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool destructive = spec.tone == Tone.danger;

    // The tone decides the treatment exactly as DialogVariant did: a
    // destructive dialog warns by default and paints its glyph and title in
    // the error role; every other dialog shows a glyph only when the
    // application named one, in the primary role, with the title on the
    // surface.
    final IconData? glyph = spec.icon != null
        ? MaterialGlyphs.of(spec.icon!)
        : (destructive ? MaterialGlyphs.of(IconRole.warning) : null);
    final Color iconColor = destructive ? colors.error : colors.primary;
    final Color titleColor = destructive ? colors.error : colors.onSurface;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size available = MediaQuery.sizeOf(context);
        // Honour the extent's width; the 90% only survives as a ceiling so a
        // wide dialog cannot outgrow a small screen, and the height still
        // shrinks to its content below.
        final double widthCeiling = available.width * 0.9;
        final double extentWidth = _maxWidthFor(spec.extent);
        final double dialogWidth = extentWidth < widthCeiling
            ? extentWidth
            : widthCeiling;
        final double dialogHeight = available.height * 0.9;

        // ignore: avoid_dialog
        return Dialog(
          // 12 dp, not Material 3's 28 (DLG-001 in this package's
          // docs/deviation_register.yaml). This is a Windows/Linux desktop
          // application, and 28 dp is a phone-scale corner: it is the one
          // radius in the whole app that would read as a mobile sheet. 12 dp
          // is the surface corner this app already uses for the cards and
          // panels the dialog hosts, and it sits between the 8 dp of Windows
          // 11's own ContentDialog and the 12 dp of libadwaita's.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth.clamp(_minWidth, double.infinity),
              maxHeight: dialogHeight,
            ),
            child: Padding(
              // Material 3's dialog insets, which happen to be exactly this
              // app's own spacing steps: 24 dp around the whole dialog, 16
              // between the title and the content, 24 between the content
              // and the action row. These are AlertDialog's defaults
              // (flutter/lib/src/material/dialog.dart:825 for the title
              // padding, :857 for the content padding, :1994 for the actions
              // padding). The uniform 32 dp this used to spend was never
              // measured against them.
              padding: const EdgeInsets.all(MaterialMetrics.spaceL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (glyph != null) ...<Widget>[
                        // The M3 dialog icon is the ambient 24 dp glyph:
                        // AlertDialog wraps it in an IconTheme that sets a
                        // colour and nothing else
                        // (flutter/lib/src/material/dialog.dart:818), so the
                        // size comes from the theme. The 28 that once stood
                        // here was on no icon scale at all.
                        Icon(
                          glyph,
                          size: MaterialMetrics.iconL,
                          color: iconColor,
                        ),
                        const SizedBox(width: MaterialMetrics.spaceM),
                      ],
                      Expanded(
                        // ignore: avoid_text_with_style
                        child: Text(
                          spec.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (spec.barrierDismissible) ...<Widget>[
                        const SizedBox(width: MaterialMetrics.spaceM),
                        const MaterialControls().iconButton(
                          context,
                          IconButtonSpec(
                            icon: IconRole.x,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MaterialMetrics.spaceM),
                  // Content section (scrollable if long).
                  //
                  // The content is its own traversal group, and that is a
                  // correctness fix rather than a tidiness one. Tab's default
                  // policy sorts the ring by where the controls currently
                  // ARE, and it scrolls the control it moves to into view -
                  // so as soon as a dialog's content scrolls, the rows that
                  // scrolled off the top acquire smaller global y
                  // coordinates than the title row's close button and get
                  // sorted in front of it. The ring then wraps from the last
                  // action into the middle of the list instead of back to
                  // the close button, and the rows near the top are visited
                  // twice per cycle. Measured on the bulk branch delete at
                  // 10 branches: Close, b0..b9, force, Cancel, Delete, b0,
                  // b1, b2, Close - 17 stops for 14 controls. A group is
                  // sorted among its siblings by the group's own rect, which
                  // is this Flexible's box and does not move when the content
                  // inside scrolls, so the title row and the action row keep
                  // their places and the content keeps its internal reading
                  // order.
                  Flexible(
                    child: FocusTraversalGroup(
                      child: SingleChildScrollView(child: spec.content.mount()),
                    ),
                  ),
                  // Actions section. A Wrap, not a Row: a Row overflows when
                  // the buttons outgrow the dialog width (the update dialog's
                  // three actions did); wrapping onto a second end-aligned
                  // run is the M3 fallback for that case and renders
                  // identically while one line fits.
                  if (spec.actions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: MaterialMetrics.spaceL),
                    Wrap(
                      alignment: WrapAlignment.end,
                      // 8 dp between actions, the spacing M3's OverflowBar
                      // gets from AlertDialog's default buttonPadding
                      // (dialog.dart:882). The run spacing is ours: an
                      // OverflowBar stacks its overflow with no gap at all,
                      // which would leave two wrapped buttons touching.
                      spacing: MaterialMetrics.spaceS,
                      runSpacing: MaterialMetrics.spaceS,
                      children: <Widget>[
                        for (final DialogAction action in spec.actions)
                          _actionButton(context, action),
                      ],
                    ),
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

/// The full-window viewer surface, extracted from `base_viewer_dialog.dart`.
///
/// The browser extent says "something to look through" - a file tree, a
/// list, a diff - so the content FILLS the surface instead of scrolling
/// inside it, and the dialog takes the 90% frame a second window wants.
class _MaterialViewerDialogSurface extends StatelessWidget {
  const _MaterialViewerDialogSurface({required this.spec});

  /// What the dialog asks.
  final DialogSpec spec;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size available = MediaQuery.sizeOf(context);
    // ignore: avoid_dialog
    return Dialog(
      // The same 12 dp corner the ordinary dialog carries, and for the same
      // reason: see DLG-001/VIEW-001 in this package's deviation register. A
      // viewer fills 90% of the window, where Material 3's 28 dp would cut a
      // visible arc out of every corner of what is effectively a second
      // window.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MaterialMetrics.radiusL),
      ),
      child: SizedBox(
        width: available.width * 0.9,
        height: available.height * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(MaterialMetrics.spaceM),
              child: Row(
                children: <Widget>[
                  if (spec.icon != null) ...<Widget>[
                    Icon(
                      MaterialGlyphs.of(spec.icon!),
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: MaterialMetrics.spaceS),
                  ],
                  Expanded(
                    // ignore: avoid_text_with_style
                    child: Text(
                      spec.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (spec.barrierDismissible)
                    const MaterialControls().iconButton(
                      context,
                      IconButtonSpec(
                        icon: IconRole.x,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: spec.content.mount()),
            if (spec.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(MaterialMetrics.spaceM),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (int index = 0; index < spec.actions.length; index++)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: index > 0 ? MaterialMetrics.spaceS : 0,
                        ),
                        child: _actionButton(context, spec.actions[index]),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps one dialog action onto this skin's own button.
///
/// This mapping is deliberately the ONLY place a dialog role becomes an
/// emphasis and a tone, exactly as `_variantForRole` was the only place a
/// role became a `ButtonVariant`: the affirmative action is the filled
/// primary way out, a destructive one keeps the filled weight and takes the
/// danger tone, the dismissive one is the quiet text button Escape mirrors,
/// and everything else is a secondary way forward.
Widget _actionButton(BuildContext context, DialogAction action) =>
    const MaterialControls().button(
      context,
      ButtonSpec(
        label: action.label,
        // `enabled`, `isLoading` and a null callback all resolve to "not
        // invokable" - the spec's own isEnabled - and a loading action stays
        // visibly busy through the button's own isLoading rendering.
        onPressed: action.isEnabled ? action.onPressed : null,
        emphasis: switch (action.role) {
          DialogActionRole.affirmative => Emphasis.primary,
          DialogActionRole.destructive => Emphasis.primary,
          DialogActionRole.dismissive => Emphasis.quiet,
          DialogActionRole.neutral => Emphasis.secondary,
        },
        tone: action.role == DialogActionRole.destructive
            ? Tone.danger
            : Tone.accent,
        leading: action.icon,
        isLoading: action.isLoading,
      ),
    );
