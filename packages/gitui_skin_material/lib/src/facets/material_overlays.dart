import 'package:flutter/material.dart' hide MaterialType;
// `SemanticsRole` is not re-exported by material.dart; the menu surface below
// states the enclosing menu role its `PopupMenuItem` rows require.
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../material_glyphs.dart';
import '../material_ink.dart';
import '../material_theme.dart';
import 'material_controls.dart';

/// Things that appear on top, the Material way.
///
/// Four members, extracted from `BaseDialog.show` (`presentDialog`), the
/// `showMenu` sites and `materialMenuEntries` in `base_menu_item.dart`
/// (`presentMenu`), the `OverlayEntry` popover in `searchable_dropdown.dart`
/// (`presentPopover`) and the whole of `notification_service.dart` (`notify`).
///
/// One rule runs through all four: **each member renders its host's `build`
/// and nothing else.** The host re-establishes the scope and the root
/// treatment inside the route, so an overlay is drawn by the same skin, in the
/// same brightness, as the surface that opened it. Material happens to
/// survive skipping that seam - its `Theme` is an `InheritedTheme` and
/// `showDialog` captures it - but this facet is also the extraction the next
/// skin author reads, and the one language that cannot survive the skip fails
/// silently, which is the whole reason the hosts exist.
///
/// **The keyboard contract is deliberately absent here.** Escape-cancels,
/// Enter-submits, the multiline-editable exception and the tier-three
/// destructive withholding all live in the application's `DialogKeyboardHost`,
/// which the API package composes between this facet's route and
/// `chrome.dialogSurface` before [presentDialog] ever sees the host. A skin
/// cannot weaken what it never receives - that is what lets the two dialog
/// sweeps keep their expectations unchanged under every skin.
final class MaterialOverlays implements SkinOverlays {
  /// Builds the overlay facet.
  const MaterialOverlays();

  /// Takes the application away until the user answers, on Material's own
  /// dialog route.
  ///
  /// The extraction of `BaseDialog.show`: `showDialog` with the spec's
  /// barrier behaviour, and the host as the entire page. Everything visual -
  /// the surface, the corner, the padding - is `chrome.dialogSurface`'s,
  /// already composed into the host; everything the user can do with the
  /// keyboard is the application's, composed in the same place. This member
  /// owns only the route, which is exactly the three-layer split
  /// `docs/SKIN-CONTRACT.md` §2.8 demands.
  @override
  Future<T?> presentDialog<T>(
    BuildContext context,
    DialogRouteSpec route,
    SkinContentHost host,
  ) => showDialog<T>(
    context: context,
    barrierDismissible: route.barrierDismissible,
    builder: (BuildContext routeContext) => host.build(routeContext),
  );

  /// Offers the entries at the asked-for point and reports the chosen index.
  ///
  /// Material's own `showMenu` cannot carry a host: it takes its entries as
  /// an eager list at the call site, and the entries are deliberately
  /// reachable only from inside the host's `build` - so this member pushes an
  /// equivalent route of its own and renders the menu surface from Material's
  /// menu vocabulary inside it: the ambient `popupMenuTheme` for elevation,
  /// colour and shape, `PopupMenuItem`-shaped rows, and the SDK's own menu
  /// measurements (112..280 logical pixels in 56-pixel steps, 8-pixel
  /// vertical padding and screen margin - popup_menu.dart's `_kMenu*`
  /// constants).
  ///
  /// The chosen entry is dispatched AFTER the route has completed, which is
  /// the order every call site in the application relies on today: a menu
  /// entry's callback routinely opens a dialog, and dispatching after the pop
  /// means it opens against a navigator the menu has already left
  /// (`history_screen.dart` documents exactly this around its `showMenu`).
  /// The dispatcher is captured where the rows are built, because that is the
  /// only place the entries exist.
  @override
  Future<int?> presentMenu(
    BuildContext context, {
    required Offset at,
    required SkinMenuHost host,
  }) async {
    void Function(int index)? dispatch;
    final int? chosen = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).menuDismissLabel,
      barrierColor: const Color(0x00000000),
      // The application opened every menu with its standard animation
      // (`BasePopupMenuButton` set `popUpAnimationStyle` from
      // `getStandardAnimation`), and the general route's default transition
      // is a fade, so the timing survives the extraction even though the
      // grow-from-anchor shape does not - that shape lives inside Material's
      // private `_PopupMenuRoute` and is recorded below as the one thing this
      // member approximates.
      transitionDuration: MaterialMotionDurations.resolve(
        context,
        MotionRole.transition,
      ),
      pageBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => host.build(routeContext, (
            BuildContext inner,
            List<MenuEntry> entries,
          ) {
            dispatch = (int index) => _dispatchEntry(entries[index]);
            return _MaterialMenuPage(at: at, entries: entries);
          }),
    );
    if (chosen != null) dispatch?.call(chosen);
    return chosen;
  }

  /// Runs the entry the user chose. A separator and a section have nothing to
  /// invoke and can never be chosen, so they are ignored rather than treated
  /// as an error - the same tolerance `dispatchMenuEntry` had.
  static void _dispatchEntry(MenuEntry entry) {
    switch (entry) {
      case final MenuAction action:
        action.onPressed?.call();
      case final MenuCheckable checkable:
        checkable.onChanged?.call(!checkable.checked);
      case final MenuChoice choice:
        choice.onSelect?.call();
      case MenuSeparator() || MenuSection():
        break;
    }
  }

  /// Builds the control that offers the host's choices, anchored to itself.
  ///
  /// Material's answer is its own icon button - the same member, so the
  /// anchor carries the ink, the state layers, the tooltip obligation and the
  /// selected treatment (solid glyph, primary tint) every other mark-only
  /// control has - opening the menu at its own bottom-start corner, which is
  /// where M3's `MenuAnchor` places an anchored menu. The measuring that
  /// fourteen application call sites used to perform lives in [_openBelow]
  /// now, on this side of the seam.
  @override
  Widget menuAnchor(
    BuildContext context,
    MenuAnchorSpec spec,
    SkinMenuHost host,
  ) => Builder(
    builder: (BuildContext anchorContext) =>
        const MaterialControls().iconButton(
          anchorContext,
          IconButtonSpec(
            icon: spec.icon,
            tooltip: spec.tooltip,
            tone: spec.tone,
            scale: spec.scale,
            // Only an ENGAGED anchor is announced as a toggle; an ordinary
            // one has no state to report, which is what null means there.
            selected: spec.selected ? true : null,
            badgeCount: spec.badgeCount,
            onPressed: spec.enabled
                ? () => _openBelow(anchorContext, host)
                : null,
          ),
        ),
  );

  /// Opens the host's menu at the bottom-start corner of the control built at
  /// [anchorContext].
  Future<int?> _openBelow(BuildContext anchorContext, SkinMenuHost host) {
    Offset at = Offset.zero;
    final RenderObject? renderObject = anchorContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      at = renderObject.localToGlobal(Offset(0, renderObject.size.height));
    }
    return presentMenu(anchorContext, at: at, host: host);
  }

  /// Attaches the host's content to the control the user just operated.
  ///
  /// The extraction of the suggestion overlay in `searchable_dropdown.dart`:
  /// a `Material` at the menu elevation with the field corner
  /// (`radiusM`), opened directly under the anchor and - when the popover
  /// continues its anchor - matched to the anchor's measured width, which is
  /// the one fact about the relationship the application states. The route
  /// replaces the screen-local `OverlayEntry` plumbing (the `LayerLink`, the
  /// `CompositedTransformFollower`, the manual dismissal) with a real modal
  /// route, so clicking outside and pressing Escape both close it without the
  /// anchor having to manage either.
  @override
  Future<T?> presentPopover<T>(
    BuildContext context,
    PopoverSpec spec,
    SkinContentHost host,
  ) {
    Offset? at;
    double? anchorWidth;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      at = renderObject.localToGlobal(Offset(0, renderObject.size.height));
      anchorWidth = renderObject.size.width;
    }
    final bool matchAnchor = spec.continuesAnchor && anchorWidth != null;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: spec.barrierDismissible,
      barrierLabel: spec.semanticsLabel,
      barrierColor: const Color(0x00000000),
      // The overlay this replaces appeared the moment it was inserted, so
      // the route does too.
      transitionDuration: Duration.zero,
      pageBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => host.build(
            routeContext,
            // The frame is everything the SKIN puts around the application's
            // content - the anchoring, the surface, the dismiss handling. It
            // is applied inside the host's own fence, so none of it is
            // attributed to the application, and the content resumes at its
            // own boundary inside it.
            frame: (BuildContext inner, Widget content) {
              final Widget surface = Semantics(
                container: true,
                label: spec.semanticsLabel,
                child: Material(
                  elevation: MaterialMetrics.elevationRaised,
                  borderRadius: BorderRadius.circular(MaterialMetrics.radiusM),
                  clipBehavior: Clip.antiAlias,
                  child: matchAnchor
                      ? SizedBox(width: anchorWidth, child: content)
                      : content,
                ),
              );
              return _Dismissible(
                child: Stack(
                  children: <Widget>[
                    if (at == null)
                      Center(child: surface)
                    else
                      Positioned(left: at.dx, top: at.dy, child: surface),
                  ],
                ),
              );
            },
          ),
    );
  }

  /// Tells the user something happened, without taking the application away.
  ///
  /// The extraction of `notification_service.dart`, and the one member whose
  /// extraction cannot be a literal move: a `SnackBar`'s background colour
  /// and inline buttons are constructor arguments, but everything the notice
  /// SAYS - including its tone - is reachable only from inside the host's
  /// `build`. So the `SnackBar` shell here carries only what the lifetime
  /// decides (the duration, the floating behaviour, the queue handling), is
  /// itself painted transparent, and the tone-coloured surface is drawn by
  /// [_MaterialNoticeSurface] inside the host, where the spec is legal.
  ///
  /// What the lifetime decides is exactly what the service's four methods
  /// decided: a brief notice auto-dismisses after two seconds, and a
  /// persistent one sets the service's 365-day never-auto-dismiss duration,
  /// floats, and carries the explicit dismiss affordance, because a notice
  /// that must be read may only be taken away deliberately.
  @override
  NoticeHandle notify(BuildContext context, SkinNoticeHost host) {
    // ScaffoldMessenger queues snackbars: a still-visible error, which never
    // auto-dismisses, would otherwise keep this one hidden indefinitely. The
    // messenger is resolved now rather than in a callback, because the notice
    // outlives this context.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final bool persistent = host.lifetime == NoticeLifetime.persistent;
    late final _MaterialNoticeHandle handle;
    final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller =
        messenger.showSnackBar(
          SnackBar(
            // The shell is transparent and unpadded because the tone colour
            // may only be resolved inside the host; the visible pill is the
            // notice surface's.
            backgroundColor: const Color(0x00000000),
            elevation: 0,
            padding: EdgeInsets.zero,
            behavior: persistent
                ? SnackBarBehavior.floating
                : SnackBarBehavior.fixed,
            duration: persistent
                ? const Duration(days: 365) // Never auto-dismiss.
                : const Duration(seconds: 2),
            content: host.build(
              context,
              (BuildContext inner, NoticeSpec spec) => _MaterialNoticeSurface(
                spec: spec,
                onDismiss: persistent ? () => handle.dismiss() : null,
              ),
            ),
          ),
        );
    handle = _MaterialNoticeHandle(controller);
    return handle;
  }
}

/// Closes its route with nothing chosen when the user asks to leave.
///
/// The platform's default shortcut map already turns Escape into a
/// [DismissIntent]; this widget is the action that answers it, placed above
/// the overlay's focused content so the intent resolves here rather than
/// falling through to whatever is beneath the barrier.
class _Dismissible extends StatelessWidget {
  const _Dismissible({required this.child});

  /// The overlay content being guarded.
  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (DismissIntent _) {
          Navigator.of(context).pop();
          return null;
        },
      ),
    },
    child: child,
  );
}

/// The menu page: the surface, positioned and clamped to the window.
class _MaterialMenuPage extends StatelessWidget {
  const _MaterialMenuPage({required this.at, required this.entries});

  /// Where the user asked for the menu.
  final Offset at;

  /// The entries, in the application's order.
  final List<MenuEntry> entries;

  @override
  Widget build(BuildContext context) => _Dismissible(
    child: CustomSingleChildLayout(
      delegate: _MenuLayoutDelegate(at),
      child: _MaterialMenuSurface(entries: entries),
    ),
  );
}

/// Keeps the menu at its asked-for point, moved just enough to stay on
/// screen.
///
/// Material's own `_PopupMenuRouteLayout` additionally grows the menu towards
/// whichever half of the screen has more room; this delegate keeps the
/// essential half of that behaviour - the menu never renders off-window and
/// never touches an edge, `_kMenuScreenPadding` at 8 - which is the half the
/// application's menus actually exercise on a desktop-sized window.
class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _MenuLayoutDelegate(this.at);

  /// Where the user asked for the menu.
  final Offset at;

  /// The SDK's own margin between a menu and the window edge.
  static const double _screenPadding = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - 2 * _screenPadding,
          constraints.maxHeight - 2 * _screenPadding,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double dx = at.dx;
    double dy = at.dy;
    if (dx + childSize.width > size.width - _screenPadding) {
      dx = size.width - _screenPadding - childSize.width;
    }
    if (dy + childSize.height > size.height - _screenPadding) {
      dy = size.height - _screenPadding - childSize.height;
    }
    if (dx < _screenPadding) dx = _screenPadding;
    if (dy < _screenPadding) dy = _screenPadding;
    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _MenuLayoutDelegate oldDelegate) =>
      oldDelegate.at != at;
}

/// The menu surface: the ambient menu theme around Material-shaped rows.
///
/// The row rendering is the extraction of `materialMenuEntries` in
/// `base_menu_item.dart`, entry kind by entry kind, and the surface metrics
/// are the SDK's own (popup_menu.dart: minimum width 112, maximum 280, width
/// stepped at 56, 8 vertical padding).
class _MaterialMenuSurface extends StatelessWidget {
  const _MaterialMenuSurface({required this.entries});

  /// The entries, in the application's order.
  final List<MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PopupMenuThemeData menuTheme = theme.popupMenuTheme;
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < entries.length; index++) {
      final MenuEntry entry = entries[index];
      switch (entry) {
        case MenuSeparator():
          rows.add(const PopupMenuDivider());
        case final MenuSection section:
          // The extraction of the hand-styled header in
          // quick_settings_menu.dart: a non-invokable row holding a small
          // label in the muted role, naming the run of entries below it.
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MaterialMetrics.spaceM,
                vertical: MaterialMetrics.spaceXS,
              ),
              // ignore: avoid_text_with_style
              child: Text(
                section.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        case final MenuAction action:
          final bool enabled = action.isEnabled;
          // The destructive tint is dropped while the entry is unavailable,
          // so the disabled treatment `PopupMenuItem` resolves for its label
          // (onSurface at 38%, popup_menu.dart:1847-1852) is the one that
          // shows. A spelled-out `error` would paint straight over it and a
          // disabled destructive entry would look exactly like an invokable
          // one.
          final bool emphasiseAsDestructive =
              action.role == MenuActionRole.destructive && enabled;
          final Color? accent = emphasiseAsDestructive
              ? theme.colorScheme.error
              : null;
          rows.add(
            _row(
              index: index,
              enabled: enabled,
              tooltip: action.tooltip,
              child: _rowContent(
                context,
                icon: action.icon == null
                    ? null
                    : MaterialGlyphs.of(action.icon!),
                label: action.label,
                iconColor: accent,
                labelColor: accent,
              ),
            ),
          );
        case final MenuCheckable checkable:
          final bool enabled = checkable.isEnabled;
          // The extraction of `MenuItemContentWithCheck`: the row leads with
          // its glyph, carries its fact in the primary colour and semibold
          // weight while it holds, and trails a check mark - the three
          // hand-built checked entries all share exactly this shape.
          final Color primary = theme.colorScheme.primary;
          rows.add(
            _row(
              index: index,
              enabled: enabled,
              child: Row(
                children: <Widget>[
                  if (checkable.icon != null) ...<Widget>[
                    Icon(
                      MaterialGlyphs.of(checkable.icon!),
                      size: MaterialMetrics.iconS,
                      color: checkable.checked ? primary : null,
                    ),
                    const SizedBox(width: MaterialMetrics.spaceS),
                  ],
                  Expanded(
                    // ignore: avoid_text_with_style
                    child: Text(
                      checkable.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: checkable.checked
                            ? primary
                            : DefaultTextStyle.of(context).style.color,
                        fontWeight: checkable.checked
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (checkable.checked) ...<Widget>[
                    const SizedBox(width: MaterialMetrics.spaceS),
                    Icon(
                      MaterialGlyphs.of(IconRole.check),
                      size: MaterialMetrics.iconS,
                      color: primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        case final MenuChoice choice:
          final bool enabled = choice.isEnabled;
          // The one-of-N row: the same shape as a checked fact - the row in
          // force carries its words in the primary colour at semibold with a
          // trailing check - because a single check that MOVES between rows
          // is how Material's own menus state a one-of-N (M3 keeps the radio
          // dot for settings surfaces, not menus). The entry's own mark, when
          // it has one, LEADS: it qualifies the choice ("this one sorts
          // ascending"), and a qualifier reads before the words it qualifies.
          final Color primary = theme.colorScheme.primary;
          rows.add(
            _row(
              index: index,
              enabled: enabled,
              child: Row(
                children: <Widget>[
                  if (choice.icon != null) ...<Widget>[
                    Icon(
                      MaterialGlyphs.of(choice.icon!),
                      size: MaterialMetrics.iconS,
                      color: choice.selected ? primary : null,
                    ),
                    const SizedBox(width: MaterialMetrics.spaceS),
                  ],
                  Expanded(
                    // ignore: avoid_text_with_style
                    child: Text(
                      choice.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: choice.selected
                            ? primary
                            : DefaultTextStyle.of(context).style.color,
                        fontWeight: choice.selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (choice.selected) ...<Widget>[
                    const SizedBox(width: MaterialMetrics.spaceS),
                    Icon(
                      MaterialGlyphs.of(IconRole.check),
                      size: MaterialMetrics.iconS,
                      color: primary,
                    ),
                  ],
                ],
              ),
            ),
          );
      }
    }
    // The rows are `PopupMenuItem`s, and a `PopupMenuItem` publishes
    // `SemanticsRole.menuItem` (popup_menu.dart:479). Flutter validates that
    // role: a menu item with no `SemanticsRole.menu` ancestor raises "A menu
    // item must be a child of a menu or a menu bar"
    // (semantics.dart:_semanticsMenuItem). Material's own `_PopupMenu` states
    // the enclosing role at popup_menu.dart:766; this surface replaces that
    // widget, so it has to state it too. Without it every menu opened through
    // this member throws the moment semantics are on - which is every widget
    // test, and every user running a screen reader.
    return Semantics(
      role: SemanticsRole.menu,
      explicitChildNodes: true,
      child: Material(
        elevation: menuTheme.elevation ?? MaterialMetrics.elevationRaised,
        color: menuTheme.color,
        shape: menuTheme.shape,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          // The SDK's own menu measurements: two width steps minimum, five
          // maximum, at 56 logical pixels a step.
          constraints: const BoxConstraints(minWidth: 112, maxWidth: 280),
          child: IntrinsicWidth(
            stepWidth: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MaterialMetrics.spaceS,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One choosable row: a Material menu item that pops the route with the
  /// row's index in the ORIGINAL entry list - separators included - which is
  /// the position the caller hears back and the dispatcher runs.
  ///
  /// `PopupMenuItem` is the canonical row: it carries the 48-pixel menu row
  /// height, the ink, the focus treatment and the disabled label resolution,
  /// and its own tap handler already pops the enclosing route with the value.
  /// Keyboard reachability is the route's, exactly as it is for `showMenu`:
  /// the arrows move focus across the rows through the platform's default
  /// directional traversal, Enter and Space activate the focused row's ink,
  /// and Escape resolves to [_Dismissible]. No row autofocuses, because
  /// Material's own menus do not - a menu opens under the pointer and the
  /// keyboard user arrows into it.
  Widget _row({
    required int index,
    required bool enabled,
    required Widget child,
    String? tooltip,
  }) {
    // The tooltip wraps the CONTENT rather than the item, so the reason a
    // disabled entry cannot be used is readable exactly where the overflow
    // bar's hand-built menu put it - over the row, disabled or not.
    final Widget content = tooltip == null
        ? child
        : Tooltip(message: tooltip, child: child);
    return PopupMenuItem<int>(value: index, enabled: enabled, child: content);
  }

  /// The extraction of `MenuItemContent`: glyph, gap, label, with the label
  /// taking the colour the enclosing menu item already published through its
  /// `DefaultTextStyle`. That distinction is the whole point: `PopupMenuItem`
  /// resolves its label colour per widget state and hands a DISABLED item
  /// `onSurface` at 38% (popup_menu.dart:1847-1852), and a content widget
  /// that spells `onSurface` out again paints straight over it - which is why
  /// a disabled entry in an overflow menu used to look exactly like an
  /// enabled one.
  ///
  /// A null [icon] renders words alone with no reserved gutter: Material's
  /// own menus mix marked and markless rows freely (`MenuItemButton` reserves
  /// nothing for an absent `leadingIcon`), so the alignment answer here is
  /// the SDK's.
  Widget _rowContent(
    BuildContext context, {
    required IconData? icon,
    required String label,
    Color? iconColor,
    Color? labelColor,
  }) => Row(
    children: <Widget>[
      if (icon != null) ...<Widget>[
        Icon(icon, size: MaterialMetrics.iconS, color: iconColor),
        const SizedBox(width: MaterialMetrics.spaceS),
      ],
      Expanded(
        // ignore: avoid_text_with_style
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: labelColor ?? DefaultTextStyle.of(context).style.color,
          ),
        ),
      ),
    ],
  );
}

/// The notice surface: the tone-coloured pill the transparent shell hosts.
///
/// The extraction of the four `NotificationService` bodies into one widget
/// driven by the spec: the tone decides the fill exactly as the four methods
/// did (success and info on `primary`, danger on `error`, warning on
/// `secondary`), the icon and the message share a row with the message capped
/// at three ellipsised lines, the actions render inline exactly where the
/// service put its copy and open-logs buttons, and a persistent notice closes
/// itself through the same affordance the service's DISMISS action offered.
class _MaterialNoticeSurface extends StatelessWidget {
  const _MaterialNoticeSurface({required this.spec, required this.onDismiss});

  /// What the notice says and offers.
  final NoticeSpec spec;

  /// How the user takes a persistent notice away, or null for a brief one,
  /// which takes itself away.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (spec.tone.name) {
      'danger' => (colors.error, colors.onError),
      'warning' => (colors.secondary, colors.onSecondary),
      // Success and info both rode on `primary` in the service, and `neutral`
      // takes the same fill rather than inventing a fourth.
      _ => (colors.primary, colors.onPrimary),
    };
    final String message = spec.body == null
        ? spec.title
        : '${spec.title}\n${spec.body}';
    return Material(
      color: background,
      // The floating snackbar's own corner; a fixed one is clipped square by
      // the shell anyway.
      borderRadius: BorderRadius.circular(MaterialMetrics.radiusS),
      child: Padding(
        // The SDK's own snackbar content metrics: 16 horizontal, 14 vertical
        // (snack_bar.dart's padding and `_singleLineVerticalPadding`).
        padding: const EdgeInsets.symmetric(
          horizontal: MaterialMetrics.spaceM,
          vertical: 14,
        ),
        child: Row(
          children: <Widget>[
            if (spec.icon != null) ...<Widget>[
              Icon(MaterialGlyphs.of(spec.icon!), color: foreground),
              const SizedBox(width: MaterialMetrics.spaceS),
            ],
            Expanded(
              // ignore: avoid_text_with_style
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground),
              ),
            ),
            // The raw TextButton is deliberate on both actions below, and
            // the app-wide ban is lifted for the same reason the service
            // itself rode on `SnackBarAction`: a notice action sits on a
            // tone-coloured fill no `Base*` variant was designed against,
            // and the canonical text button with an explicit foreground is
            // exactly what Material's own snackbar action resolves to.
            for (final NoticeAction action in spec.actions) ...<Widget>[
              const SizedBox(width: MaterialMetrics.spaceS),
              Tooltip(
                message: action.tooltip,
                // ignore: avoid_text_button
                child: TextButton(
                  onPressed: action.onPressed,
                  style: TextButton.styleFrom(foregroundColor: foreground),
                  child: action.icon != null
                      ? Icon(
                          MaterialGlyphs.of(action.icon!),
                          size: MaterialMetrics.iconM,
                          color: foreground,
                        )
                      // ignore: avoid_text_with_style
                      : Text(action.label),
                ),
              ),
            ],
            if (onDismiss != null) ...<Widget>[
              const SizedBox(width: MaterialMetrics.spaceS),
              // ignore: avoid_text_button
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(foregroundColor: foreground),
                // The service's own affordance, verbatim: it never went
                // through translations, because a notice can outlive the
                // locale-carrying context it was opened from.
                // ignore: avoid_text_with_style
                child: const Text('DISMISS'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two things a live notice can do, and nothing else.
///
/// Backed by the controller `showSnackBar` returns - the handle the service
/// used to discard, which is why `notify` returning void would have been a
/// regression against shipped behaviour.
final class _MaterialNoticeHandle implements NoticeHandle {
  _MaterialNoticeHandle(this._controller) {
    _controller.closed.whenComplete(() => _showing = false);
  }

  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _controller;
  bool _showing = true;

  @override
  void dismiss() {
    if (!_showing) return;
    _showing = false;
    _controller.close();
  }

  @override
  bool get isShowing => _showing;
}
