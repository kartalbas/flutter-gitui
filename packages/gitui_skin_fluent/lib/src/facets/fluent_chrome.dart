import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_button.dart';
import '../controls/fluent_checkbox.dart';
import '../controls/fluent_control_marks.dart';
import '../controls/fluent_icon_button.dart';
import '../controls/fluent_info_badge.dart';
import '../controls/fluent_pressable.dart';
import '../controls/fluent_progress.dart';
import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_request_scope.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';
import 'fluent_surfaces.dart';

/// The frame: the root, the shell, the screens and the dialog surface - the
/// Fluent way, drawn by this package with no widget library underneath.
///
/// This facet is where Fluent disagrees with Material hardest, which is why
/// it is the contract's sharpest test. Three of those disagreements are this
/// file's whole shape:
///
///  * **Fluent has no app bar.** The window is a NavigationView - one pane
///    owning the destinations, the toggle and the identity together
///    (fluent_ui@4.16.1 lib/src/controls/navigation/navigation_view/) - and
///    a screen is a `PageHeader` over content (controls/layout/page.dart),
///    not a toolbar-bearing bar of its own.
///  * **The dialog's affirmative action sits on the LEFT**, stretched to
///    equal width with every other action across the surface. [FluentDialogSurface]
///    derives that order from [DialogAction.role] alone, exactly as
///    `DialogSpec.actions`' doc promises a differently-arranged language
///    will - list position never decides.
///  * **Depth is layers, not shadows.** The pane sits on the window ground
///    and the content on a layer fill one step off it
///    (`LayerOnAcrylicFillColorDefault`, the reference's own
///    `scaffoldBackgroundColor`, styles/theme.dart:456) - no rule is drawn
///    between them.
///
/// Wherever the frame contains a thing another facet already owns - a
/// banner, a button, a progress mark - it renders it through that facet
/// rather than sketching a second version, because two renderings of one
/// spec inside one skin is the same defect as two affordances for one job:
/// the banner is `FluentSurfaces.banner`'s, the dialog actions are
/// `FluentButton`s, the progress reports are the controls facet's own bar
/// and ring.
///
/// **The registered gaps this facet inherits or adds**, reported rather
/// than hidden:
///
///  * **No glyph table yet** (the package-wide decision `FluentButton`'s doc
///    registers): every [IconRole] slot - a destination's mark, a toolbar
///    action's, a dialog's title mark - reserves its exact box on the
///    Fluent icon ramp and draws nothing in it.
///  * **The anchored trigger is not implemented yet**: a `ToolbarMenuEntry`
///    routes through `Overlays.anchor`, the contract's own front door, and
///    under this skin that door reaches `FluentOverlays.menuAnchor`, which
///    still refuses loudly. Probing the member and rendering some other
///    trigger here would hide the remaining work, which is the one thing a
///    fence must never do. (A PICKER's list already works: its press goes
///    through `Overlays.menu`, and `presentMenu` is real.) The same gap is
///    why this bar's overflow answer is interim: WinUI's CommandBar sheds
///    into a "more" flyout - an anchored trigger - so until that member
///    lands the strip scrolls instead, keeping every entry and every
///    priority reachable. `ToolbarGroup.priority` therefore has nothing to
///    decide yet - a bar that does not shed has no shedding order - and
///    that is written here rather than the field being silently dropped.
///  * **The words this skin owns are English.** The hamburger's accessible
///    name, the clear-selection tooltip and the aside's hide affordance are
///    the skin's OWN controls, and this package ships no localisation
///    bundle yet; `SkinRootClaims.localizationsDelegates` is the declared
///    door for one, the day these few words earn it.
///  * **A theme change cuts rather than dissolves.** The reference
///    cross-fades through `AnimatedFluentTheme` (fluent_app.dart:467-469);
///    lerping the whole WinUI resource dictionary is deferred, and the cut
///    is registered here rather than approximated badly.
final class FluentChrome implements SkinChrome {
  /// Builds the frame facet.
  const FluentChrome();

  /// Installs Fluent's own scopes and the window ground, built from the
  /// user's request.
  ///
  /// The composition is the reference's own root treatment, member for
  /// member: the theme scope carrying the WinUI resource dictionary for the
  /// requested brightness, then the icon default (black on light, white on
  /// dark, at 18 - styles/theme.dart:474-475), then the ambient text
  /// default (`typography.body`, which the reference stamps with
  /// `textFillColorPrimary`; theme.dart:77-79 and :464-467). The ground is
  /// `SolidBackgroundFillColorBase` - the solid stand-in the reference
  /// installs as `micaBackgroundColor` (theme.dart:460) - because this
  /// skin's control fills are translucent and only composite correctly
  /// over the ground the language itself specifies.
  ///
  /// **The ground is painted by the OUTERMOST establishment only** (#446).
  /// This member is not called once: `SkinEnvelope._establish` re-runs it
  /// inside every overlay route, which is what makes an overlay carry the
  /// same skin and the same brightness as the surface that opened it. A
  /// ground painted there too would sit between a flyout's deliberately
  /// transparent barrier and the flyout itself, covering the application
  /// the user is supposed to still be reading - measured as two full-window
  /// `#F3F3F3` boxes above an open menu. The two cases are told apart
  /// without a contract change: at the application root there is no ancestor
  /// [FluentRequestScope], and inside a re-established route there always
  /// is. Neither other skin is affected, because neither paints a ground
  /// here at all.
  ///
  /// Where each of the request's seven fields goes:
  ///
  ///  * `brightness` picks the resource dictionary here;
  ///  * `textScale`, `codeScale`, `monoFamily` and `uiFamily` ride
  ///    [FluentRequestScope] into `FluentTypeResolution`, which every text
  ///    in this package resolves through - the ambient style below
  ///    included;
  ///  * `animationScale` rides the same scope for the motion facet's
  ///    `FluentMotionDurations` to consume;
  ///  * `accentSeed` is deliberately not consumed, and that is this
  ///    language's own answer rather than an omission: the contract's doc
  ///    for the field names "a system accent it prefers instead" as one of
  ///    the answers a skin may give, and a Windows application takes the
  ///    system accent rather than branding its chrome - so this skin keeps
  ///    the Windows default swatch (`FluentAccent.windowsDefault`) whatever
  ///    the seed says.
  @override
  Widget wrapRoot(
    BuildContext context, {
    required Widget child,
    required SkinRequest request,
  }) {
    final FluentThemeData data = request.brightness == Brightness.dark
        ? const FluentThemeData.dark()
        : const FluentThemeData.light();
    final FluentResources res = data.resources;
    final bool isPage = FluentRequestScope.maybeOf(context) == null;
    return FluentRequestScope(
      request: request,
      child: FluentTheme(
        data: data,
        child: _Ground(
          color: isPage ? res.solidBackgroundFillColorBase : null,
          child: IconTheme(
            // The reference's own icon default: black in light, white in
            // dark, size 18 (styles/theme.dart:474-475).
            data: IconThemeData(
              color: data.brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : const Color(0xFF000000),
              size: 18,
            ),
            child: Builder(
              builder: (BuildContext inner) => DefaultTextStyle(
                // The ambient style the reference installs under its theme
                // (theme.dart:79): body, in the primary text fill the
                // reference stamps onto every typography step
                // (theme.dart:464-467) - resolved through the type door so
                // the user's family and scale reach it.
                style: FluentTypeResolution.styleOf(
                  inner,
                  TextRole.body,
                ).copyWith(color: res.textFillColorPrimary),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The whole application window: the NavigationView idiom.
  @override
  Widget shell(BuildContext context, ShellSpec spec) => FluentShell(spec: spec);

  /// One screen inside the shell: the PageHeader idiom.
  @override
  Widget screen(BuildContext context, ScreenSpec spec) =>
      FluentScreen(spec: spec);

  /// The inside of a dialog: the ContentDialog idiom.
  ///
  /// Only the surface. The route belongs to `overlays.presentDialog` - which
  /// is also where `DialogSpec.barrierDismissible` is consumed, so nothing
  /// here reads it and, deliberately, nothing here draws a close mark:
  /// WinUI's ContentDialog has no title-bar X, its ways out are its
  /// actions and Escape. `DialogSpec.onSubmit` belongs to the application's
  /// own dialog keyboard host, already wrapped around this widget by the
  /// time it builds, which is why nothing here handles a key.
  @override
  Widget dialogSurface(BuildContext context, DialogSpec spec) =>
      spec.extent == DialogExtent.browser
      ? FluentViewerDialogSurface(spec: spec)
      : FluentDialogSurface(spec: spec);
}

/// The page ground, or nothing at all.
///
/// A [ColoredBox] when this establishment is the page's, and a plain
/// pass-through when it is an overlay route's re-establishment - see
/// [FluentChrome.wrapRoot] and #446. A widget rather than a conditional at the
/// call site so the subtree keeps ONE shape in both cases: swapping a
/// `ColoredBox` in and out of the middle of the root would remount everything
/// below it the first time an overlay opened.
final class _Ground extends StatelessWidget {
  const _Ground({required this.color, required this.child});

  /// The ground to paint, or null to paint none.
  final Color? color;

  /// The root treatment below it.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      color == null ? child : ColoredBox(color: color!, child: child);
}

// ---------------------------------------------------------------------------
// The shell: the NavigationView.
// ---------------------------------------------------------------------------

/// The window: a navigation pane, a command strip, the content layer, the
/// log region, the status line and the two progress reports.
///
/// Stateful for exactly one reason, and it is the same one as Material's
/// shell with the opposite canon behind it: when the application leaves
/// `ShellSpec.density` null it is saying "this skin owns its own display
/// mode", and Fluent's NavigationView DOES ship its own toggle - the
/// hamburger - so this skin keeps the open/compact fact itself, which is
/// precisely the case `NavigationDensity`'s doc names for this language.
final class FluentShell extends StatefulWidget {
  /// Draws [spec] as the window.
  const FluentShell({super.key, required this.spec});

  /// What the window contains.
  final ShellSpec spec;

  /// The navigation pane region, for tests that measure its width.
  static const ValueKey<String> paneKey = ValueKey<String>('fluent.shell.pane');

  /// The content layer, for tests that measure its fill.
  static const ValueKey<String> contentKey = ValueKey<String>(
    'fluent.shell.content',
  );

  /// The hamburger, for tests that drive the display mode.
  static const ValueKey<String> paneToggleKey = ValueKey<String>(
    'fluent.shell.paneToggle',
  );

  /// The open pane's width: 320 epx
  /// (fluent_ui@4.16.1 navigation_view/pane.dart:7,
  /// `kOpenNavigationPaneWidth`).
  static const double openPaneWidth = 320;

  /// The compact pane's width: 50 epx (pane.dart:4,
  /// `kCompactNavigationPaneWidth`).
  static const double compactPaneWidth = 50;

  @override
  State<FluentShell> createState() => _FluentShellState();
}

class _FluentShellState extends State<FluentShell> {
  /// The display mode this skin keeps when the application declares none.
  bool _ownOpen = true;

  ShellSpec get spec => widget.spec;

  NavigationDensity get _density =>
      spec.density ??
      (_ownOpen ? NavigationDensity.full : NavigationDensity.condensed);

  bool get _showsToggle =>
      spec.density == null || spec.onDensityChanged != null;

  /// Routes one pane through the application's keyboard structure, or
  /// returns it bare when the application installed none.
  Widget _hosted(ShellPane pane, Widget contents) =>
      spec.paneHost?.call(pane, contents) ?? contents;

  void _toggleDensity() {
    // The hamburger walks open <-> compact, which is what WinUI's own pane
    // toggle does in left display mode; from the application-stated hidden
    // state it restores the full pane, because a toggle that could not
    // bring back what it hides would be a dead end.
    final NavigationDensity next = switch (_density) {
      NavigationDensity.full => NavigationDensity.condensed,
      NavigationDensity.condensed => NavigationDensity.full,
      NavigationDensity.hidden => NavigationDensity.full,
    };
    spec.onDensityChanged?.call(next);
    if (spec.density == null) {
      setState(() => _ownOpen = next == NavigationDensity.full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final ShellAside? aside = spec.aside;
    final BlockingProgressSpec? blocking = spec.blocking;
    final NavigationDensity density = _density;
    final bool hidden = density == NavigationDensity.hidden;

    // The arrangement is the NavigationView's: pane beside a column of
    // command strip over content, the log docked at the trailing edge, the
    // status line along the bottom. WHICH regions exist is what the spec's
    // own data says - destinations make a pane, groups make a strip, a
    // visible aside makes the log - and every one passes through the
    // application's [ShellSpec.paneHost], so the F6 / Tab order the
    // application installs there survives this arrangement unchanged.
    final Widget shell = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // At NavigationDensity.hidden the navigation itself is off screen -
        // that is what the value means - but the hamburger survives in a
        // compact strip when anyone can act on it, because a toggle that
        // vanished with the thing it restores could never bring it back.
        if (spec.destinations.isNotEmpty && (!hidden || _showsToggle))
          _hosted(ShellPane.rail, _pane(context, density)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (spec.toolbar.isNotEmpty)
                _hosted(
                  ShellPane.toolbar,
                  fluentCommandStrip(context, spec.toolbar),
                ),
              Expanded(
                child: _hosted(ShellPane.content, _contentLayer(context, res)),
              ),
              if (spec.status != null) _statusLine(context, spec.status!),
            ],
          ),
        ),
        if (aside != null && aside.visible)
          _hosted(ShellPane.log, _FluentAside(aside: aside)),
      ],
    );
    if (blocking == null) return shell;
    // An operation the user must wait for is a LAYER under this skin - the
    // slot exists exactly because route-versus-layer is the skin's
    // decision - and the barrier is WinUI's own dialog smoke
    // (SmokeFillColorDefault, 30% black on either brightness).
    return Stack(
      children: <Widget>[
        shell,
        ModalBarrier(dismissible: false, color: res.smokeFillColorDefault),
        Center(child: _FluentBlockingCard(spec: blocking)),
      ],
    );
  }

  /// The navigation pane: the hamburger, the identity, the destinations.
  ///
  /// The pane sits directly on the window ground and animates between its
  /// two published widths at the fast step on the standard curve - the tier
  /// the reference feeds its pane theme (styles/theme.dart:479-482,
  /// `animationDuration: fastAnimationDuration`).
  Widget _pane(BuildContext context, NavigationDensity density) {
    final bool open = density == NavigationDensity.full;
    final bool hidden = density == NavigationDensity.hidden;
    return AnimatedContainer(
      key: FluentShell.paneKey,
      duration: FluentMotion.fast,
      curve: FluentMotion.curve,
      width: open ? FluentShell.openPaneWidth : FluentShell.compactPaneWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_showsToggle) _paneToggle(context, density),
          if (!hidden) _identity(context, open: open),
          if (!hidden)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (int i = 0; i < spec.destinations.length; i++)
                    _destination(context, i, open: open),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The hamburger: the pane's own display-mode control, which is why the
  /// application never draws a second one. Drawn only when this skin owns
  /// the mode or the application asked to hear about changes.
  Widget _paneToggle(BuildContext context, NavigationDensity density) {
    // The skin's own words, English until this package earns a
    // localisation bundle - see the facet doc's registered gaps.
    final String label = switch (density) {
      NavigationDensity.full => 'Collapse navigation',
      NavigationDensity.condensed => 'Expand navigation',
      NavigationDensity.hidden => 'Show navigation',
    };
    return KeyedSubtree(
      key: FluentShell.paneToggleKey,
      child: _PaneTile(
        selected: false,
        onPressed: _toggleDensity,
        semanticsLabel: label,
        open: false,
        label: null,
        badgeCount: null,
      ),
    );
  }

  /// Who the application is: the raster mark Windows shows for an app, and
  /// its name while the pane has room for words.
  Widget _identity(BuildContext context, {required bool open}) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Padding(
      // The pane's item margin (pane_items.dart:370-371) around the
      // header's own vertical inset (navigation_view/theme.dart:225,
      // `headerPadding: vertical 8`).
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 8,
      ),
      child: () {
        final Widget mark = Semantics(
          image: true,
          label: spec.identity.name,
          child: SizedBox.square(
            // The raster at the standard WinUI glyph step
            // (FluentMetrics.glyphNormal), the step every pane mark
            // takes.
            dimension: FluentMetrics.glyphNormal,
            child: Image(image: spec.identity.appIcon),
          ),
        );
        if (!open) return Center(child: mark);
        // Laid out at the open content width and clipped while the pane
        // animates towards it - the same guard the destinations' tile
        // carries, and the reason the mark's x never moves between modes.
        return FittedBox(
          fit: BoxFit.none,
          alignment: AlignmentDirectional.centerStart,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: FluentShell.openPaneWidth - 12,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  child: mark,
                ),
                Expanded(
                  child: Text(
                    spec.identity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTypeResolution.styleOf(
                      context,
                      TextRole.sectionTitle,
                    ).copyWith(color: res.textFillColorPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      }(),
    );
  }

  /// One destination of the pane.
  Widget _destination(BuildContext context, int index, {required bool open}) {
    final ShellDestination destination = spec.destinations[index];
    return _PaneTile(
      selected: index == spec.selectedIndex,
      onPressed: () => spec.onSelect(index),
      // The label survives condensation as the accessible name, so
      // reducing the navigation to glyphs never reduces what a screen
      // reader hears.
      semanticsLabel: destination.label,
      open: open,
      label: destination.label,
      badgeCount: destination.badgeCount,
    );
  }

  /// The content layer: the selected destination's body, the window banner
  /// and the non-blocking activity report, one layer off the window ground.
  Widget _contentLayer(BuildContext context, FluentResources res) {
    final ActivitySpec? activity = spec.activity;
    return ColoredBox(
      key: FluentShell.contentKey,
      // The reference's scaffoldBackgroundColor, painted by the
      // NavigationView body (styles/theme.dart:456,
      // navigation_view/body.dart:82-83) - the layer that separates content
      // from pane without a drawn line.
      color: res.layerOnAcrylicFillColorDefault,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The banner is part of what the user is working on, not part
              // of the strip above it, so Tab and F6 treat them as one
              // pane. Rendered through the surfaces facet - the one owner
              // of BannerSpec in this skin.
              if (spec.banner != null)
                const FluentSurfaces().banner(context, spec.banner!),
              Expanded(child: _content()),
            ],
          ),
          // A background operation must never steal input or layout: the
          // page-top ProgressBar the ActivitySpec doc names for this
          // language, floating over the content's top edge.
          if (activity != null)
            Align(
              alignment: Alignment.topCenter,
              child: _FluentActivityLine(spec: activity),
            ),
        ],
      ),
    );
  }

  /// The selected destination's body, mounted through its port.
  Widget _content() {
    if (spec.destinations.isEmpty) return const SizedBox.shrink();
    final int index = spec.selectedIndex.clamp(0, spec.destinations.length - 1);
    return spec.destinations[index].body().mount();
  }

  /// The standing status line along the bottom, on the window ground.
  ///
  /// Windows has no status-bar canon, so the arrangement is this skin's
  /// own: the caption step in the tone's ink, the detail one step quieter
  /// beside it, a subtle press treatment when the application gave it
  /// something to do.
  Widget _statusLine(BuildContext context, ShellStatus status) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final Color ink = FluentInk.foreground(theme, status.tone);
    final Widget row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        // The ordinary reading inset horizontally, the hairline vertically:
        // the line's density is its point (FluentSpacing).
        horizontal: FluentMetrics.spaceM,
        vertical: FluentMetrics.spaceXXS,
      ),
      child: Row(
        children: <Widget>[
          if (status.icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: FluentMetrics.spaceS,
              ),
              // The inline mark slot at the compact glyph step, held empty
              // until the Fluent glyph table lands.
              child: IconTheme.merge(
                data: IconThemeData(
                  color: ink,
                  size: FluentMetrics.glyphCompact,
                ),
                child: const SizedBox.square(
                  dimension: FluentMetrics.glyphCompact,
                ),
              ),
            ),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.micro,
              ).copyWith(color: ink),
            ),
          ),
          if (status.detail != null) ...<Widget>[
            const SizedBox(width: FluentMetrics.spaceS),
            Flexible(
              child: Text(
                status.detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FluentTypeResolution.styleOf(
                  context,
                  TextRole.micro,
                ).copyWith(color: res.textFillColorSecondary),
              ),
            ),
          ],
        ],
      ),
    );
    final VoidCallback? onTap = status.onTap;
    if (onTap == null) return row;
    return FluentPressable(
      onPressed: onTap,
      semanticsLabel: status.label,
      builder: (BuildContext context, Set<WidgetState> states) =>
          FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: ColoredBox(
              // The subtle ladder, the treatment of everything quietly
              // operable in this language (navigation_view/theme.dart:4-21).
              color: states.contains(WidgetState.pressed)
                  ? res.subtleFillColorTertiary
                  : states.contains(WidgetState.hovered)
                  ? res.subtleFillColorSecondary
                  : res.subtleFillColorTransparent,
              child: row,
            ),
          ),
    );
  }
}

/// One tile of the navigation pane: a destination, or the hamburger.
///
/// Anatomy from the reference's PaneItem (fluent_ui@4.16.1
/// navigation_view/pane_items.dart): a 6 epx horizontal margin (:370-371)
/// around a 40 epx-minimum tile (view.dart:12, `kPaneItemMinHeight`) at the
/// control corner (:395), the mark inset 12 (theme.dart:224), the words in
/// body ending 10 before the edge (theme.dart:223), the count riding as an
/// InfoBadge (:316-320).
///
/// The states are the subtle ladder (theme.dart:4-21,
/// `kDefaultPaneItemColor`), with the one twist that says "you are here"
/// without a colour of its own: a SELECTED tile rests on the hover fill and
/// hovers on the pressed fill (pane_items.dart:381-390). The selection's
/// loud half is the pill - a 3 epx accent stadium standing 10 in from
/// either end of the tile's start edge (indicators.dart:186-208
/// `StickyNavigationIndicator` defaults, :375-379 its decoration;
/// highlightColor styles/theme.dart:483). The pill appears in place rather
/// than travelling from the previously selected item - the sticky stretch
/// is registered follow-up work, not imitated badly.
final class _PaneTile extends StatelessWidget {
  const _PaneTile({
    required this.selected,
    required this.onPressed,
    required this.semanticsLabel,
    required this.open,
    required this.label,
    required this.badgeCount,
  });

  final bool selected;
  final VoidCallback onPressed;
  final String semanticsLabel;
  final bool open;
  final String? label;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    return Semantics(
      selected: selected,
      child: FluentPressable(
        onPressed: onPressed,
        semanticsLabel: semanticsLabel,
        builder: (BuildContext context, Set<WidgetState> states) {
          final bool active =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed);
          // Selected rests one rung up the ladder (pane_items.dart:381-390);
          // unselected walks it plainly (theme.dart:4-21).
          final Color fill = selected
              ? (active
                    ? res.subtleFillColorTertiary
                    : res.subtleFillColorSecondary)
              : states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered)
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;

          // The mark slot at the standard glyph step, held empty until the
          // Fluent glyph table lands - the registered gap, not a decision
          // of this tile.
          final Widget glyphSlot = SizedBox.square(
            dimension: FluentMetrics.glyphNormal,
          );

          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: FluentMotion.faster,
                    curve: FluentMotion.curve,
                    constraints: const BoxConstraints(minHeight: 40),
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(
                        FluentGeometry.controlCornerRadius,
                      ),
                    ),
                    child: open
                        // The open row is laid out at the OPEN pane's own
                        // content width and clipped while the pane
                        // animates towards it - the reference wraps its
                        // expanded row in a ClipRect for the same frames
                        // (pane_items.dart:303-305), and holding the
                        // layout width fixed is what keeps the mark's x
                        // constant between modes, which is why WinUI's
                        // compact icon sits where the open icon was.
                        ? FittedBox(
                            fit: BoxFit.none,
                            alignment: AlignmentDirectional.centerStart,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              // The open pane minus the tile's two 6 epx
                              // margins.
                              width: FluentShell.openPaneWidth - 12,
                              child: Row(
                                children: <Widget>[
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal: 12,
                                        ),
                                    child: glyphSlot,
                                  ),
                                  Expanded(
                                    child: Text(
                                      label ?? '',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style:
                                          FluentTypeResolution.styleOf(
                                            context,
                                            TextRole.body,
                                          ).copyWith(
                                            color: res.textFillColorPrimary,
                                          ),
                                    ),
                                  ),
                                  if (badgeCount != null)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: FluentInfoBadgePill(
                                        count: badgeCount!,
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          )
                        // Compact: the mark centred alone, the count riding
                        // its corner (pane_items.dart:278-295).
                        : Center(
                            child: badgeCount == null
                                ? glyphSlot
                                : FluentInfoBadgeRider(
                                    count: badgeCount!,
                                    child: glyphSlot,
                                  ),
                          ),
                  ),
                  if (selected)
                    PositionedDirectional(
                      start: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: theme.accent.defaultBrushFor(theme.brightness),
                          borderRadius: BorderRadius.circular(
                            FluentGeometry.stadiumRadius,
                          ),
                        ),
                      ),
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

/// The command-log region, docked at the trailing edge at the pane's own
/// published width - the one side-region width this language states
/// (pane.dart:7).
final class _FluentAside extends StatelessWidget {
  const _FluentAside({required this.aside});

  final ShellAside aside;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return SizedBox(
      width: FluentShell.openPaneWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: res.dividerStrokeColorDefault,
              width: FluentGeometry.strokeWidth,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: FluentMetrics.spaceM,
                vertical: FluentMetrics.spaceSNudge,
              ),
              child: Row(
                spacing: FluentMetrics.spaceS,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      aside.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // The pane's own section-header treatment: bodyStrong
                      // in the secondary ink (navigation_view/
                      // theme.dart:184-186, `itemHeaderTextStyle`).
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.sectionTitle,
                      ).copyWith(color: res.textFillColorSecondary),
                    ),
                  ),
                  for (final ToolbarActionEntry action in aside.actions)
                    _CommandButton(action: action),
                  if (aside.onVisibilityChanged != null)
                    FluentIconButton(
                      spec: IconButtonSpec(
                        icon: IconRole.x,
                        // The skin's own words - the registered English gap.
                        tooltip: 'Hide ${aside.title}',
                        scale: ControlScale.compact,
                        onPressed: () => aside.onVisibilityChanged!(false),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: aside.content.mount()),
          ],
        ),
      ),
    );
  }
}

/// The thin non-blocking activity report: the page-top ProgressBar the
/// `ActivitySpec` doc names for this language, with the operation's words
/// on a resting card beneath it.
final class _FluentActivityLine extends StatelessWidget {
  const _FluentActivityLine({required this.spec});

  final ActivitySpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final int? currentStep = spec.currentStep;
    final int? totalSteps = spec.totalSteps;
    final bool showsCount =
        !spec.indeterminate &&
        currentStep != null &&
        totalSteps != null &&
        totalSteps > 0;
    final String caption = showsCount
        ? '${spec.operation} ($currentStep/$totalSteps)'
        : spec.operation;
    final FluentDepth depth = FluentInk.depth(theme, Elevation.resting);
    final Widget chip = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FluentMetrics.spaceM,
        vertical: FluentMetrics.spaceXXS,
      ),
      decoration: BoxDecoration(
        color: depth.fill,
        border: Border.all(
          color: depth.stroke,
          width: FluentGeometry.strokeWidth,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(FluentGeometry.controlCornerRadius),
        ),
      ),
      child: Text(
        caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FluentTypeResolution.styleOf(
          context,
          TextRole.micro,
        ).copyWith(color: res.textFillColorSecondary),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The line itself must not swallow clicks meant for the content it
        // floats over; only the caption is a target.
        SizedBox(
          width: double.infinity,
          child: IgnorePointer(
            child: FluentProgressBar(
              fraction: showsCount ? currentStep / totalSteps : null,
            ),
          ),
        ),
        if (spec.operation.isNotEmpty)
          spec.onShowDetail == null
              ? chip
              : FluentPressable(
                  onPressed: spec.onShowDetail,
                  semanticsLabel: caption,
                  builder: (BuildContext context, Set<WidgetState> states) =>
                      FluentFocusRing(
                        focused: states.contains(WidgetState.focused),
                        child: chip,
                      ),
                ),
      ],
    );
  }
}

/// The operation the user must wait for: the ContentDialog-with-a-
/// ProgressRing the `BlockingProgressSpec` doc names for this language,
/// drawn as a layer under the smoke.
final class _FluentBlockingCard extends StatelessWidget {
  const _FluentBlockingCard({required this.spec});

  final BlockingProgressSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final FluentDepth depth = FluentInk.depth(theme, Elevation.overlay);
    final double? fraction = spec.fraction;
    return Container(
      // The ContentDialog's published width (content_dialog.dart:11-14).
      constraints: const BoxConstraints(maxWidth: 368),
      padding: const EdgeInsetsDirectional.all(FluentMetrics.spaceXL),
      decoration: BoxDecoration(
        color: depth.fill,
        borderRadius: BorderRadius.circular(FluentGeometry.overlayCornerRadius),
        border: Border.all(
          color: depth.stroke,
          width: FluentGeometry.strokeWidth,
        ),
        boxShadow: depth.shadows(FluentInk.shadowInk(theme.brightness)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            spec.operation,
            // The ContentDialog's title treatment (content_dialog.dart:508).
            style: FluentTypeResolution.chromeStyleOf(
              context,
              FluentTypeRamp.title,
            ).copyWith(color: res.textFillColorPrimary),
          ),
          // The title's published gap to what follows
          // (content_dialog.dart:499).
          const SizedBox(height: 12),
          if (fraction == null)
            Center(child: FluentProgressRing(fraction: null))
          else
            FluentProgressBar(fraction: fraction),
          if (spec.currentStep != null && spec.totalSteps != null) ...<Widget>[
            const SizedBox(height: FluentMetrics.spaceS),
            Text(
              '${spec.currentStep} / ${spec.totalSteps}',
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.detail,
              ).copyWith(color: res.textFillColorSecondary),
            ),
          ],
          if (spec.detail != null) ...<Widget>[
            const SizedBox(height: FluentMetrics.spaceS),
            Text(
              spec.detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FluentTypeResolution.styleOf(
                context,
                TextRole.detail,
              ).copyWith(color: res.textFillColorSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The screen: the PageHeader.
// ---------------------------------------------------------------------------

/// One screen: a PageHeader over content, because Fluent has no app bar.
///
/// The header is the reference's own arrangement (fluent_ui@4.16.1
/// controls/layout/page.dart:269-299): the title in the Title ramp step
/// (:279) with the screen's commands aligned to the end (:283-292), 18
/// under it (:270) and the page gutter beside it
/// (`kPageDefaultVerticalPadding` = 24, :5). The screen's primary actions
/// wear the accent - "what this screen is for" IS the emphasis, and the
/// accent button is the one louder control this language has - and the
/// selection strip sits at the TOP, under the header, because Fluent's
/// commands live at the top of the content where Material's batch bar went
/// to the bottom.
final class FluentScreen extends StatelessWidget {
  /// Draws [spec] as a screen.
  const FluentScreen({super.key, required this.spec});

  /// What the screen contains.
  final ScreenSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    final SelectionBarSpec? selectionBar = spec.selectionBar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          // The page gutter on either side and above, the published 18
          // below (page.dart:5, :270).
          padding: const EdgeInsetsDirectional.only(
            start: 24,
            end: 24,
            top: 24,
            bottom: 18,
          ),
          child: Row(
            spacing: FluentMetrics.spaceL,
            children: <Widget>[
              Expanded(
                child: Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTypeResolution.chromeStyleOf(
                    context,
                    FluentTypeRamp.title,
                  ).copyWith(color: res.textFillColorPrimary),
                ),
              ),
              for (final ToolbarGroup group in spec.toolbar)
                for (final ToolbarEntry entry in group.entries)
                  fluentCommandEntry(context, entry),
              for (final ToolbarActionEntry action in spec.primaryActions)
                FluentButton(
                  spec: ButtonSpec(
                    label: action.label,
                    onPressed: action.onPressed,
                    emphasis: Emphasis.primary,
                    tone: action.tone,
                    leading: action.icon,
                    tooltip: action.tooltip,
                  ),
                ),
            ],
          ),
        ),
        if (selectionBar != null) _FluentSelectionStrip(spec: selectionBar),
        // Through the surfaces facet, the one owner of BannerSpec.
        if (spec.banner != null)
          const FluentSurfaces().banner(context, spec.banner!),
        Expanded(child: spec.body.mount()),
        if (spec.footer != null) spec.footer!.mount(),
      ],
    );
  }
}

/// The batch strip shown while things are multi-selected: the
/// CommandBar-plus-InfoBar hybrid the `SelectionBarSpec` doc names for this
/// language - the count as the attention badge, the ways out as buttons, at
/// the top where Fluent's commands live.
final class _FluentSelectionStrip extends StatelessWidget {
  const _FluentSelectionStrip({required this.spec});

  final SelectionBarSpec spec;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: res.dividerStrokeColorDefault,
            width: FluentGeometry.strokeWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: FluentMetrics.spaceM,
          vertical: FluentMetrics.spaceSNudge,
        ),
        child: Row(
          spacing: FluentMetrics.spaceS,
          children: <Widget>[
            FluentInfoBadgePill(count: spec.selectedCount),
            FluentIconButton(
              spec: IconButtonSpec(
                icon: IconRole.x,
                // The skin's own words - the registered English gap.
                tooltip: 'Clear selection',
                scale: ControlScale.compact,
                onPressed: spec.onClear,
              ),
            ),
            const Spacer(),
            for (final ToolbarGroup group in spec.actions)
              for (final ToolbarEntry entry in group.entries)
                if (entry is ToolbarActionEntry)
                  FluentButton(
                    spec: ButtonSpec(
                      label: entry.label,
                      onPressed: entry.onPressed,
                      emphasis: entry.emphasis,
                      // What the batch action MEANS travels with it (#442);
                      // the button's rendering of tones beyond
                      // accent/neutral is that member's registered gap.
                      tone: entry.tone,
                      leading: entry.icon,
                      tooltip: entry.tooltip,
                      scale: ControlScale.compact,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The command strip: the CommandBar idiom, shared by the shell and the
// screen header.
// ---------------------------------------------------------------------------

/// A whole action strip: its groups in reading order, scrolling when the
/// window is narrower than the strip.
///
/// Scrolling is the interim overflow answer while WinUI's real one - the
/// CommandBar's "more" flyout - stands behind the overlays facet's fence;
/// see the facet doc's registered gaps for why `ToolbarGroup.priority` has
/// nothing to decide until then. Entry gaps come from the contract's own
/// distance vocabulary: members of one group at `Proximity.grouped`, two
/// groups at `Proximity.separate` - the vocabulary's doc names a toolbar's
/// actions as the grouped rung's own example.
Widget fluentCommandStrip(BuildContext context, List<ToolbarGroup> groups) =>
    Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FluentMetrics.spaceM,
        vertical: FluentMetrics.spaceSNudge,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: FluentSpacing.gap(Proximity.separate),
          children: <Widget>[
            for (final ToolbarGroup group in groups)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: FluentSpacing.gap(Proximity.grouped),
                children: <Widget>[
                  for (final ToolbarEntry entry in group.entries)
                    fluentCommandEntry(context, entry),
                ],
              ),
          ],
        ),
      ),
    );

/// One entry of an action strip, in whichever of its five kinds.
Widget fluentCommandEntry(BuildContext context, ToolbarEntry entry) {
  switch (entry) {
    case ToolbarSeparatorEntry():
      // The language's own Divider fill (the reference's
      // `DividerThemeData.standard`: thickness 1, the divider resource),
      // spanning the neighbouring buttons' boxes - the 16 glyph plus its
      // 8 padding either side.
      return Container(
        width: FluentGeometry.strokeWidth,
        height: FluentMetrics.glyphNormal + 2 * FluentIconButton.slotPadding,
        color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
      );
    case final ToolbarActionEntry action:
      return _CommandButton(action: action);
    case final ToolbarPickerEntry picker:
      return _CommandPicker(picker: picker);
    case final ToolbarMenuEntry menu:
      // Through `Overlays.anchor`, the contract's own front door, exactly
      // as the other two chromes mount it - which plants the
      // `SkinMenuAnchor` identity the keyboard instruments read. Under
      // this skin the anchor is built by `overlays.menuAnchor`, so until
      // the overlays slice lands this entry stands behind that facet's
      // fence: a loud UnimplementedError naming the missing facet, never
      // a quietly different menu drawn here.
      return Overlays.anchor(
        spec: MenuAnchorSpec(
          icon: menu.icon,
          tooltip: menu.tooltip,
          badgeCount: menu.badgeCount,
          enabled: menu.entries.isNotEmpty,
        ),
        entries: menu.entries,
      );
    case final ToolbarChoiceEntry choice:
      // "The same subject, shown a different way" in a bar is this
      // language's CommandBar toggle set - the contract's own sentence for
      // Fluent on `ToolbarChoiceEntry` - one toggle button per option, the
      // chosen one wearing WinUI's checked-input treatment. NOT
      // `controls.choiceGroup`: that member is this skin's radio group,
      // and radios in a command strip would be Material's chip answer
      // wearing a Fluent name.
      //
      // Through `withSpec` and not through `choice.spec`: the switch
      // matched at the bound, and the spec's callback only survives at the
      // type the application declared it with. See
      // `ToolbarChoiceEntry.withSpec`.
      return choice.withSpec(
        <S>(ChoiceGroupSpec<S> spec) => _commandToggleSet<S>(context, spec),
      );
  }
}

/// A row of toggle buttons over one [ChoiceGroupSpec]: the CommandBar
/// toggle set.
Widget _commandToggleSet<T>(BuildContext context, ChoiceGroupSpec<T> spec) =>
    Semantics(
      label: spec.label,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // Two halves of one control sit at the hairline rung.
        spacing: FluentSpacing.gap(Proximity.hairline),
        children: <Widget>[
          for (final ChoiceOption<T> option in spec.options)
            _CommandToggle(
              label: option.label,
              hasIcon: option.icon != null,
              tooltip: option.tooltip ?? option.label,
              selected: option.value == spec.selected,
              onPressed: option.enabled
                  ? () => spec.onSelected(option.value)
                  : null,
            ),
        ],
      ),
    );

/// One action of the strip: the CommandBarButton's anatomy - the 16 epx
/// mark, a 10 gap, the words in body (fluent_ui@4.16.1
/// surfaces/commandbar.dart:671-682) - on the subtle ladder at the icon
/// button's 8 epx padding and control corner (commandbar.dart:661-669
/// resolves the same `uncheckedInputColor` ladder;
/// buttons/icon_button.dart:113-133).
///
/// [ToolbarActionEntry.emphasis] deliberately does not change the
/// treatment: the language's own CommandBarButton has no emphasis axis -
/// every command in a Fluent bar is subtle - so the collapse is Fluent's
/// statement, recorded here. The tone still inks the words, an unavailable
/// action stays visible with its reason announced, and the count rides as
/// the InfoBadge.
final class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.action});

  final ToolbarActionEntry action;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool disabled = action.onPressed == null;
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      // Announced, not shown: the overlays-facet gap every tooltip in this
      // package carries.
      tooltip: action.tooltip,
      child: FluentPressable(
        onPressed: action.onPressed,
        semanticsLabel: action.label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fill = states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered)
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;
          final Color foreground = disabled
              ? res.textFillColorDisabled
              : FluentInk.foreground(theme, action.tone);
          final Widget box = AnimatedContainer(
            duration: FluentMotion.faster,
            curve: FluentMotion.curve,
            padding: const EdgeInsets.all(FluentIconButton.slotPadding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(
                FluentGeometry.controlCornerRadius,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // The mark slot at the CommandBar's 16 (commandbar.dart:676),
                // empty until the glyph table lands.
                IconTheme.merge(
                  data: IconThemeData(
                    color: foreground,
                    size: FluentMetrics.glyphNormal,
                  ),
                  child: const SizedBox.square(
                    dimension: FluentMetrics.glyphNormal,
                  ),
                ),
                // The published gap between mark and words
                // (commandbar.dart:679).
                const SizedBox(width: 10),
                Text(
                  action.label,
                  style: FluentTypeResolution.styleOf(
                    context,
                    TextRole.control,
                  ).copyWith(color: foreground),
                ),
              ],
            ),
          );
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: action.badgeCount == null
                ? box
                : FluentInfoBadgeRider(count: action.badgeCount!, child: box),
          );
        },
      ),
    );
  }
}

/// One toggle of a CommandBar toggle set: subtle at rest, WinUI's
/// checked-input accent when chosen (fluent_ui@4.16.1
/// inputs/toggle_button.dart:162-169 via [fluentCheckedInputColor];
/// on-accent foreground per buttons/filled_button.dart:113-123).
final class _CommandToggle extends StatelessWidget {
  const _CommandToggle({
    required this.label,
    required this.hasIcon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool hasIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool disabled = onPressed == null;
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      selected: selected,
      tooltip: tooltip,
      child: FluentPressable(
        onPressed: onPressed,
        semanticsLabel: label,
        builder: (BuildContext context, Set<WidgetState> states) {
          final Color fill;
          final Color foreground;
          if (selected) {
            fill = fluentCheckedInputColor(theme, states);
            foreground = states.contains(WidgetState.pressed)
                ? res.textOnAccentFillColorSecondary
                : states.contains(WidgetState.disabled)
                ? res.textOnAccentFillColorDisabled
                : res.textOnAccentFillColorPrimary;
          } else {
            fill = states.contains(WidgetState.pressed)
                ? res.subtleFillColorTertiary
                : states.contains(WidgetState.hovered)
                ? res.subtleFillColorSecondary
                : res.subtleFillColorTransparent;
            foreground = disabled
                ? res.textFillColorDisabled
                : res.textFillColorPrimary;
          }
          return FluentFocusRing(
            focused: states.contains(WidgetState.focused),
            child: AnimatedContainer(
              duration: FluentMotion.faster,
              curve: FluentMotion.curve,
              padding: const EdgeInsets.all(FluentIconButton.slotPadding),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(
                  FluentGeometry.controlCornerRadius,
                ),
              ),
              // A segment shows its mark when it has one - its words carry
              // the meaning only when it does not, which is the same
              // arrangement the reference's command bar makes
              // (commandbar.dart:653-656).
              child: hasIcon
                  ? IconTheme.merge(
                      data: IconThemeData(
                        color: foreground,
                        size: FluentMetrics.glyphNormal,
                      ),
                      child: const SizedBox.square(
                        dimension: FluentMetrics.glyphNormal,
                      ),
                    )
                  : Text(
                      label,
                      style: FluentTypeResolution.styleOf(
                        context,
                        TextRole.control,
                      ).copyWith(color: foreground),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// A picker: the control that NAMES the thing the other commands act on,
/// drawn as this language's drop-down - the subtle box carrying the mark,
/// the current name and the closed chevron (the combo box's own mark,
/// `FluentChevron`).
///
/// Pressing it opens the entries through `Overlays.menu`, the contract's
/// own front door - so under this skin the press stands behind the
/// overlays facet's fence until that slice lands, while the picker itself
/// renders and names its subject either way.
final class _CommandPicker extends StatelessWidget {
  const _CommandPicker({required this.picker});

  final ToolbarPickerEntry picker;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentResources res = theme.resources;
    final bool hasChoices = picker.entries.isNotEmpty;
    final String value = picker.value.isEmpty
        ? (picker.emptyLabel ?? '')
        : picker.value;
    return Semantics(
      container: true,
      button: true,
      enabled: hasChoices,
      tooltip: picker.tooltip ?? picker.label,
      child: Builder(
        builder: (BuildContext anchorContext) => FluentPressable(
          onPressed: hasChoices
              ? () {
                  final RenderObject? renderObject = anchorContext
                      .findRenderObject();
                  Offset at = Offset.zero;
                  if (renderObject is RenderBox && renderObject.hasSize) {
                    at = renderObject.localToGlobal(
                      Offset(0, renderObject.size.height),
                    );
                  }
                  unawaited(
                    Overlays.menu(
                      anchorContext,
                      at: at,
                      entries: picker.entries,
                    ),
                  );
                }
              : null,
          semanticsLabel: picker.label,
          builder: (BuildContext context, Set<WidgetState> states) {
            final Color fill = states.contains(WidgetState.pressed)
                ? res.subtleFillColorTertiary
                : states.contains(WidgetState.hovered)
                ? res.subtleFillColorSecondary
                : res.subtleFillColorTransparent;
            final Color foreground = hasChoices
                ? res.textFillColorPrimary
                : res.textFillColorDisabled;
            return FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                padding: const EdgeInsets.all(FluentIconButton.slotPadding),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(
                    FluentGeometry.controlCornerRadius,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconTheme.merge(
                      data: IconThemeData(
                        color: foreground,
                        size: FluentMetrics.glyphNormal,
                      ),
                      child: const SizedBox.square(
                        dimension: FluentMetrics.glyphNormal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluentTypeResolution.styleOf(
                          context,
                          TextRole.control,
                        ).copyWith(color: foreground),
                      ),
                    ),
                    const SizedBox(width: FluentMetrics.spaceS),
                    // The combo box's closed chevron, at its compact mark
                    // size (fluent_control_marks.dart).
                    FluentChevron(color: foreground),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The dialog surface: the ContentDialog.
// ---------------------------------------------------------------------------

/// The Fluent dialog action order: derived from the ROLES, never from the
/// list, which is the arrangement `DialogSpec.actions`' doc promises a
/// differently-ordered language will make.
///
/// The affirmative - the one action a language may single out as its
/// default - comes FIRST, because WinUI lays its ContentDialog out primary
/// / secondary / close, left to right: the published dialog guidance's own
/// examples put the accent action leftmost and Cancel last, and the delete
/// dialog the reference cites as its cover image
/// (content_dialog.dart:22, `dialog_rs2_delete_file.png`) reads Delete
/// first, Cancel last. Destructive actions follow, then the neutral ways
/// forward, and the dismissive way out sits LAST - the mirror image of
/// Material's end-aligned order, produced from the same list. Within one
/// role the application's order stands, by construction.
List<DialogAction> fluentDialogActionOrder(List<DialogAction> actions) =>
    <DialogAction>[
      for (final DialogAction action in actions)
        if (action.role == DialogActionRole.affirmative) action,
      for (final DialogAction action in actions)
        if (action.role == DialogActionRole.destructive) action,
      for (final DialogAction action in actions)
        if (action.role == DialogActionRole.neutral) action,
      for (final DialogAction action in actions)
        if (action.role == DialogActionRole.dismissive) action,
    ];

/// Maps one dialog action onto this skin's own button.
///
/// This mapping is deliberately the ONLY place a dialog role becomes an
/// emphasis and a tone, and it is Fluent's own: the affirmative action is
/// the accent (filled) button and every other way out is a STANDARD
/// button - not a quiet one, because WinUI's ContentDialog knows no text
/// button; Cancel wears the standard fill and outline. A destructive
/// action stays a standard button whose words carry the danger - the
/// reference's own delete dialog says "Delete" in an ordinary button - and
/// the danger tone travels with it for the day the button member answers
/// tones beyond accent/neutral (its registered gap). A dialog with no
/// affirmative action therefore singles out NO default: nothing wears the
/// accent, which is exactly the withholding the contract's
/// destructive-dialog arrangement expects.
ButtonSpec _dialogActionButton(DialogAction action, {required bool fillWidth}) {
  return ButtonSpec(
    label: action.label,
    // `enabled`, `isLoading` and a null callback all resolve to "not
    // invokable" - the spec's own isEnabled - and a loading action stays
    // visibly busy through the button's own isLoading rendering.
    onPressed: action.isEnabled ? action.onPressed : null,
    emphasis: action.role == DialogActionRole.affirmative
        ? Emphasis.primary
        : Emphasis.secondary,
    tone: action.role == DialogActionRole.destructive
        ? Tone.danger
        : Tone.accent,
    leading: action.icon,
    isLoading: action.isLoading,
    fillWidth: fillWidth,
  );
}

/// The two-region ContentDialog surface: the content on the menu-surface
/// fill, the action strip on the window ground beneath it.
///
/// Structure and metrics from the reference (fluent_ui@4.16.1
/// flyouts/content_dialog.dart) with two divergences in the published
/// specification's favour, both named:
///
///  * the surface rounds at the OVERLAY corner, 8 - WinUI's
///    `OverlayCornerRadius`, the pair `FluentGeometry` declares with the
///    control corner - where the reference writes 12 (:495);
///  * the shadow is this skin's own overlay depth (`FluentInk.depth`, the
///    design-kit two-layer shadow) where the reference reaches for
///    Flutter's Material elevation table (`kElevationToShadow[6]`, :496) -
///    Material's ramp wearing a Fluent name. The 1px flyout stroke rides
///    in from the same depth grammar, because a dialog that skipped it
///    would be a second overlay treatment inside one skin.
///
/// Kept from the reference, line for line: the 368 x 756 constraint the
/// Windows guidelines give a dialog (:11-14), the 20 padding of both
/// regions (:498, :506), the title's Title step and its 12 to the content
/// (:508, :499), the action strip on `micaBackgroundColor` - the window
/// ground, `SolidBackgroundFillColorBase` (:501-505, styles/theme.dart:460)
/// - the 10 between actions (:500), actions stretched to EQUAL WIDTH
/// filling the surface (:147-161), and a single action keeping its own
/// width at the end (:141-145).
///
/// `DialogExtent.alert` and `DialogExtent.form` BOTH land on this one
/// surface, and that collapse is the language's own statement rather than
/// a rounding: Fluent publishes exactly one dialog surface with one width,
/// the same one-size posture as its one control height - the extent doc's
/// macOS example (an alert pinned at 260) pointing the other way. The
/// browser extent alone diverges, in [FluentViewerDialogSurface].
final class FluentDialogSurface extends StatelessWidget {
  /// Draws [spec]'s surface.
  const FluentDialogSurface({super.key, required this.spec});

  /// What the dialog asks.
  final DialogSpec spec;

  /// The outer decorated surface, for tests that read its paint.
  static const ValueKey<String> surfaceKey = ValueKey<String>(
    'fluent.dialog.surface',
  );

  /// The action strip, for tests that read its paint.
  static const ValueKey<String> actionsKey = ValueKey<String>(
    'fluent.dialog.actions',
  );

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Size available = MediaQuery.sizeOf(context);
    return Align(
      child: _dialogShell(
        context,
        key: surfaceKey,
        // The published constraint (content_dialog.dart:11-14), with the
        // height additionally bowing to a small window.
        constraints: BoxConstraints(
          maxWidth: 368,
          maxHeight: math.min(756, available.height * 0.9),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Flexible(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(FluentMetrics.spaceXL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 12),
                      child: _dialogTitle(context, theme, spec),
                    ),
                    // The content is its own traversal group so Tab's
                    // spatial sort cannot interleave scrolled-away rows
                    // with the action strip - the group is sorted by its
                    // own unmoving rect, and the content keeps its
                    // internal reading order.
                    Flexible(
                      child: FocusTraversalGroup(
                        child: SingleChildScrollView(
                          child: spec.content.mount(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (spec.actions.isNotEmpty)
              _dialogActionStrip(context, theme, spec.actions),
          ],
        ),
      ),
    );
  }
}

/// The full-window viewer surface: the browser extent's answer.
///
/// "Something to look through" - a file tree, a list, a diff - has no
/// Windows dialog canon at all: WinUI's one published dialog is the 368
/// ContentDialog, and a file's worth of content does not fit a sentence's
/// surface. So this skin gives the browser extent the 90% frame the
/// application has always given its viewers, wearing the same two-region
/// ContentDialog dress - the one decision on this surface that is the
/// skin's own rather than the reference's, recorded here.
final class FluentViewerDialogSurface extends StatelessWidget {
  /// Draws [spec]'s surface.
  const FluentViewerDialogSurface({super.key, required this.spec});

  /// What the dialog asks.
  final DialogSpec spec;

  /// The outer decorated surface, for tests that read its geometry.
  static const ValueKey<String> surfaceKey = ValueKey<String>(
    'fluent.dialog.viewer',
  );

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final Size available = MediaQuery.sizeOf(context);
    return Align(
      child: _dialogShell(
        context,
        key: surfaceKey,
        constraints: BoxConstraints.tight(
          Size(available.width * 0.9, available.height * 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              // The dialog's 20 on three sides, the title's published 12
              // to what follows (content_dialog.dart:498-499).
              padding: const EdgeInsetsDirectional.only(
                start: FluentMetrics.spaceXL,
                end: FluentMetrics.spaceXL,
                top: FluentMetrics.spaceXL,
                bottom: 12,
              ),
              child: _dialogTitle(context, theme, spec),
            ),
            Expanded(child: spec.content.mount()),
            if (spec.actions.isNotEmpty)
              _dialogActionStrip(context, theme, spec.actions),
          ],
        ),
      ),
    );
  }
}

/// The decorated dialog box both surfaces share: the menu-surface fill,
/// the overlay corner, the flyout stroke and the design-kit shadow -
/// `FluentInk.depth`'s one overlay answer.
///
/// The stroke rides in a `foregroundDecoration` so the action strip's own
/// ground can meet the surface's edge without overpainting the outline.
Widget _dialogShell(
  BuildContext context, {
  required Key key,
  required BoxConstraints constraints,
  required Widget child,
}) {
  final FluentThemeData theme = FluentTheme.of(context);
  final FluentDepth depth = FluentInk.depth(theme, Elevation.overlay);
  final BorderRadius corner = BorderRadius.circular(
    FluentGeometry.overlayCornerRadius,
  );
  return Container(
    key: key,
    constraints: constraints,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: depth.fill,
      borderRadius: corner,
      boxShadow: depth.shadows(FluentInk.shadowInk(theme.brightness)),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: corner,
      border: Border.all(
        color: depth.stroke,
        width: FluentGeometry.strokeWidth,
      ),
    ),
    child: child,
  );
}

/// The dialog's first line: the optional mark, then the title in the Title
/// step (content_dialog.dart:508).
///
/// `DialogSpec.tone` rides the MARK alone, which is Fluent's own posture:
/// the InfoBar colours its severity mark and leaves its words in the
/// primary ink (surfaces/info_bar.dart:378-381, :614-625), and the
/// language's own delete dialog carries no red anywhere - a destructive
/// dialog says its danger in words. With no mark stated the tone therefore
/// has nothing to colour, and that absence is the language's answer rather
/// than a dropped parameter.
Widget _dialogTitle(
  BuildContext context,
  FluentThemeData theme,
  DialogSpec spec,
) {
  final FluentResources res = theme.resources;
  return Row(
    children: <Widget>[
      if (spec.icon != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: FluentMetrics.spaceS),
          // The mark slot at the prominent glyph step, in the tone's ink -
          // held empty until the Fluent glyph table lands.
          child: IconTheme.merge(
            data: IconThemeData(
              color: FluentInk.foreground(theme, spec.tone),
              size: FluentMetrics.glyphProminent,
            ),
            child: const SizedBox.square(
              dimension: FluentMetrics.glyphProminent,
            ),
          ),
        ),
      Flexible(
        child: Text(
          spec.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FluentTypeResolution.chromeStyleOf(
            context,
            FluentTypeRamp.title,
          ).copyWith(color: res.textFillColorPrimary),
        ),
      ),
    ],
  );
}

/// The action strip: the window ground under the menu surface, 20 padding,
/// the actions in role-derived order - one action end-aligned at its own
/// width, several stretched EQUAL across the surface with 10 between them
/// (content_dialog.dart:141-161, :500-506).
///
/// One correction to the reference's letter, in its evident intent's
/// favour: the checkout puts each gap INSIDE its action's Expanded half
/// (:151-158), which hands the last action ten more pixels than every
/// other - visibly unequal at two actions. WinUI divides the command space
/// into truly equal columns with the spacing BETWEEN them, so the gaps
/// here are the Row's own, outside the equal shares.
Widget _dialogActionStrip(
  BuildContext context,
  FluentThemeData theme,
  List<DialogAction> actions,
) {
  final List<DialogAction> ordered = fluentDialogActionOrder(actions);
  return Container(
    key: FluentDialogSurface.actionsKey,
    // micaBackgroundColor := SolidBackgroundFillColorBase
    // (content_dialog.dart:501-505, styles/theme.dart:460).
    color: theme.resources.solidBackgroundFillColorBase,
    padding: const EdgeInsetsDirectional.all(FluentMetrics.spaceXL),
    child: ordered.length == 1
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FluentButton(
              spec: _dialogActionButton(ordered.single, fillWidth: false),
            ),
          )
        : Row(
            // The published 10 between actions (content_dialog.dart:500).
            spacing: 10,
            children: <Widget>[
              for (final DialogAction action in ordered)
                Expanded(
                  child: FluentButton(
                    spec: _dialogActionButton(action, fillWidth: true),
                  ),
                ),
            ],
          ),
  );
}
