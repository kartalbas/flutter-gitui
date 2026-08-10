import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import '../controls/fluent_control_marks.dart';
import '../controls/fluent_pressable.dart';
import '../fluent_focus_ring.dart';
import '../fluent_geometry.dart';
import '../fluent_ink.dart';
import '../fluent_motion.dart';
import '../fluent_resources.dart';
import '../fluent_theme.dart';
import '../fluent_typography.dart';

/// Things that appear on top, the Fluent way - one member at a time.
///
/// **This facet is registered but not yet whole.** [presentMenu] - the
/// point-anchored menu, WinUI's context flyout - is implemented and
/// behaviour-tested; the other four members throw an [UnimplementedError]
/// naming themselves, exactly the fence the skin's own class doc demands: a
/// loud refusal keeps a gap honest, where quietly rendering another
/// language's overlay would be the substitution failure pointed inward.
///
/// **On the point anchor, because the finding has been asked for from four
/// directions now:** a bare `Offset` does NOT force Fluent into anything
/// unnatural for THIS member. The context menu is the one overlay whose
/// anchor genuinely is a point - the pointer at the moment of the secondary
/// click - and WinUI itself opens a context `MenuFlyout` at exactly that
/// point: the reference's `FlyoutController.showFlyout` takes a bare
/// `position` for it and resolves placement around the point with edge
/// clamping (fluent_ui@4.16.1 lib/src/controls/flyouts/flyout.dart:795,
/// 493-516). What a point CANNOT express - a flyout attached to a control's
/// edge, placed by the language's own placement resolution, matching the
/// control's width - is precisely what the contract has since grown
/// `menuAnchor` and `presentPopover` for, so the missing word P5 predicted
/// is no longer missing; it is those members' word, and they remain fenced
/// here only because they are another slice's work, not because the
/// contract cannot say them.
final class FluentOverlays implements SkinOverlays {
  /// Builds the overlay facet.
  const FluentOverlays();

  /// Not yet: the dialog is the ContentDialog idiom and lands with its own
  /// slice, beside `chrome.dialogSurface` - the two halves of one surface.
  @override
  Future<T?> presentDialog<T>(
    BuildContext context,
    DialogSpec spec,
    SkinContentHost host,
  ) => throw UnimplementedError(
    'FluentOverlays.presentDialog is not implemented yet: the ContentDialog '
    'route (smoke layer, 250 ms open) lands with the dialog slice, beside '
    'chrome.dialogSurface.',
  );

  /// Offers the entries at the asked-for point: the WinUI context menu.
  ///
  /// The route is this skin's own, mirroring the reference's flyout route
  /// half by half:
  ///
  ///  * transparent barrier (flyout.dart:1029, `barrierColor ??
  ///    Colors.transparent`) that still dismisses on an outside click;
  ///  * opens over [FluentMotion.fast] - the flyout default
  ///    (flyout.dart:807, `transitionDuration ??=
  ///    theme.fastAnimationDuration`) - resolved through
  ///    `FluentMotionDurations` so the user's motion preference scales it;
  ///  * closes INSTANTLY (flyout.dart:792, `reverseTransitionDuration =
  ///    Duration.zero`): a Windows menu leaves the moment it is told to;
  ///  * drops in from above by 15% of its own height while it opens
  ///    (flyout.dart:853-858, the default transition for bottom
  ///    placements), on the linear curve the reference defaults to
  ///    (flyout.dart:794);
  ///  * Escape dismisses with nothing chosen (flyout.dart:779,
  ///    `dismissWithEsc` defaulting true).
  ///
  /// The chosen entry is dispatched where its row is built, POP FIRST: the
  /// reference's own item pops its route and then invokes
  /// (menu_flyout.dart:344-347), so an entry that opens a dialog opens it
  /// against a navigator this menu has already left.
  ///
  /// Keyboard: the first choosable entry autofocuses - XAML moves focus
  /// into a menu flyout when it opens ("Flyouts... focus moves into the
  /// flyout") - the platform's default bindings move it with the arrows and
  /// activate with Enter or Space through the pressable's own intents.
  @override
  Future<int?> presentMenu(
    BuildContext context, {
    required Offset at,
    required SkinMenuHost host,
  }) => Navigator.of(context, rootNavigator: true).push<int>(
    _FluentMenuRoute<int>(
      // A literal, not a translation: a skin package owns no translations
      // (the application does), and the widgets layer publishes no dismiss
      // label of its own - the same recorded answer the blueprint's barrier
      // gives. WinUI's light-dismiss layer itself is unnamed.
      barrierLabel: 'Dismiss',
      transitionDuration: FluentMotionDurations.resolve(
        context,
        MotionRole.feedback,
      ),
      pageBuilder:
          (
            BuildContext routeContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => host.build(
            routeContext,
            (BuildContext inner, List<MenuEntry> entries) => _Dismissible(
              child: CustomSingleChildLayout(
                delegate: _FluentFlyoutPlacement(at: at),
                child: FluentMenuSurface(entries: entries),
              ),
            ),
          ),
    ),
  );

  /// Not yet: the anchored trigger is the icon-button-plus-flyout pair -
  /// the language's own placement resolution against a control's edge -
  /// and lands with its own slice.
  @override
  Widget menuAnchor(
    BuildContext context,
    MenuAnchorSpec spec,
    SkinMenuHost host,
  ) => throw UnimplementedError(
    'FluentOverlays.menuAnchor is not implemented yet: the anchored trigger '
    '(FluentIconButton opening a MenuFlyout with Fluent placement '
    'resolution) lands with its own slice. presentMenu already carries the '
    'menu surface it will open.',
  );

  /// The plain Flyout: the same surface the menu opens on, carrying the
  /// application's own content instead of rows.
  ///
  /// It reuses [_FluentMenuRoute] and [_FluentFlyoutPlacement] rather than
  /// growing a second arrangement, because a popover and a menu ARE one thing
  /// in this language - `FlyoutController.showFlyout` opens both at a position
  /// and clamps both to the same 8 epx margin (flyout.dart:493-516, 787). The
  /// only difference is what stands on the surface.
  ///
  /// The anchor is measured here rather than passed in, because the member's
  /// `context` IS the anchor's: a control that opens a suggestion list should
  /// not also have to report where it is.
  @override
  Future<T?> presentPopover<T>(
    BuildContext context,
    PopoverSpec spec,
    SkinContentHost host,
  ) {
    Offset at = Offset.zero;
    double? anchorWidth;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      at = renderObject.localToGlobal(Offset(0, renderObject.size.height));
      anchorWidth = renderObject.size.width;
    }
    // `continuesAnchor` is a statement of RELATIONSHIP, not of width, and
    // this is the skin deciding what that relationship means: a list that
    // continues its field takes the field's measure, so the two read as one
    // control rather than as a surface that happens to be nearby.
    final double? matchWidth = spec.continuesAnchor ? anchorWidth : null;

    return Navigator.of(context, rootNavigator: true).push<T>(
      _FluentMenuRoute<T>(
        barrierDismissible: spec.barrierDismissible,
        barrierLabel: spec.semanticsLabel,
        // The overlay this replaces appeared the moment it was inserted, and
        // a suggestion list that fades in lags the typing that opened it.
        transitionDuration: Duration.zero,
        pageBuilder:
            (
              BuildContext routeContext,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => host.build(
              routeContext,
              // Everything the skin puts around the content - the anchoring,
              // the surface, the dismiss handling - is applied inside the
              // host's own fence, so none of it is attributed to the
              // application and the content resumes at its own boundary.
              frame: (BuildContext inner, Widget content) => _Dismissible(
                child: CustomSingleChildLayout(
                  delegate: _FluentFlyoutPlacement(at: at),
                  child: Semantics(
                    container: true,
                    label: spec.semanticsLabel,
                    child: FluentFlyoutSurface(
                      width: matchWidth,
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  /// Not yet: the notice is the InfoBar idiom and lands with its own slice.
  @override
  NoticeHandle notify(BuildContext context, SkinNoticeHost host) =>
      throw UnimplementedError(
        'FluentOverlays.notify is not implemented yet: the InfoBar strip '
        'lands with its own slice.',
      );
}

/// The menu's route: a dialog route with the flyout's asymmetric clock.
///
/// Opening takes the flyout's transition (passed in, already scaled by the
/// user's motion preference); closing takes no time at all, which is the
/// reference's own default (flyout.dart:792) and half of why a Windows menu
/// feels like a menu - it arrives, it never lingers.
final class _FluentMenuRoute<T> extends RawDialogRoute<T> {
  _FluentMenuRoute({
    required super.pageBuilder,
    required super.transitionDuration,
    super.barrierLabel,
    // A menu is always light-dismissible; a popover says whether it is, and
    // the two share this route because the language opens them the same way.
    super.barrierDismissible = true,
  }) : super(
         // flyout.dart:1029: the flyout barrier is transparent - a menu
         // does not smoke the application behind it.
         barrierColor: const Color(0x00000000),
         transitionBuilder: _dropIn,
       );

  /// flyout.dart:792: `reverseTransitionDuration = Duration.zero`.
  @override
  Duration get reverseTransitionDuration => Duration.zero;

  /// The default transition for bottom placements: a slide from 15% above
  /// the final position (flyout.dart:853-858), on the reference's default
  /// linear curve (flyout.dart:794) - the animation itself is the route's
  /// curve, unmodified.
  static Widget _dropIn(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}

/// Closes its route with nothing chosen when the user asks to leave.
///
/// The platform's default shortcut map already turns Escape into a
/// [DismissIntent]; this widget is the action that answers it
/// (flyout.dart:779, `dismissWithEsc` defaulting true), placed above the
/// overlay's focused content so the intent resolves here rather than
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

/// Keeps the menu at its asked-for point, moved just enough to stay inside
/// the window.
///
/// The essential half of the reference's flyout placement for a point
/// target: `bottomLeft` at the point, with both axes clamped to an 8 epx
/// margin from the root's edges (flyout.dart:787 `margin = 8.0`; the
/// clamps, flyout.dart:493-516). The reference additionally lets `auto`
/// placement flip a target-attached flyout to the other side of its target;
/// a POINT has no sides, so near an edge the reference and this delegate
/// converge on the same clamped position. The child is constrained inside
/// the margins so a menu taller than the window scrolls inside its own
/// surface instead of leaving it.
class _FluentFlyoutPlacement extends SingleChildLayoutDelegate {
  const _FluentFlyoutPlacement({required this.at});

  /// Where the user asked for the menu.
  final Offset at;

  /// flyout.dart:787: the flyout's margin to the root bounds.
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - 2 * _margin,
          constraints.maxHeight - 2 * _margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // flyout.dart:493-516, clampHorizontal / clampVertical.
    final double maxX = size.width - childSize.width - _margin;
    final double maxY = size.height - childSize.height - _margin;
    return Offset(
      at.dx.clamp(_margin, maxX < _margin ? _margin : maxX),
      at.dy.clamp(_margin, maxY < _margin ? _margin : maxY),
    );
  }

  @override
  bool shouldRelayout(covariant _FluentFlyoutPlacement oldDelegate) =>
      oldDelegate.at != at;
}

/// The menu surface: the WinUI MenuFlyout, drawn.
///
/// Anatomy from the reference, part by part:
///
///  * the box: the solid menu surface (`FluentThemeData.menuColor`,
///    `FluentInk.menuSurface`) inside the flyout stroke
///    (`SurfaceStrokeColorFlyout`) at the 8 epx overlay corner
///    (flyout_content.dart:72-75), casting the flyout's elevation-8 shadow
///    pair (`FluentInk.depth` at `Elevation.overlay`,
///    flyout_content.dart:21);
///  * at least 118 epx wide (`kFlyoutMinConstraints`,
///    flyout_content.dart:4 - the reference's own "eyeballed value from
///    Windows Home 11"), sized to its widest row (`IntrinsicWidth`,
///    menu_flyout.dart:104);
///  * 2 epx of vertical breathing room (`kDefaultMenuPadding`,
///    menu_flyout.dart:7), each item in a 4/2 margin
///    (`kDefaultMenuItemMargin`, menu_flyout.dart:10-13);
///  * rows scroll inside the surface when the menu outgrows the window
///    (menu_flyout.dart:113-115).
///
/// Public within the package (never exported) so the behaviour suite can
/// find the surface and measure it - the same visibility every drawn
/// control in `controls/` has.
/// The surface a flyout stands on: the fill, the stroke, the 8 epx corner and
/// the overlay shadow, with nothing said about what is on it.
///
/// Extracted so the menu and the popover cannot disagree. They are one surface
/// in this language — `FlyoutController.showFlyout` opens both — and drawing it
/// twice would be two chances to drift, which is the defect the whole contract
/// exists to end, arriving inside a single skin.
final class FluentFlyoutSurface extends StatelessWidget {
  /// Draws the flyout surface around [child].
  const FluentFlyoutSurface({super.key, required this.child, this.width});

  /// What stands on the surface.
  final Widget child;

  /// The anchor's width, when the caller said this surface CONTINUES its
  /// anchor. Null lets the content size itself.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    final FluentDepth depth = FluentInk.depth(theme, Elevation.overlay);
    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: depth.fill,
        borderRadius: BorderRadius.circular(FluentGeometry.overlayCornerRadius),
        border: Border.all(color: depth.stroke),
        boxShadow: depth.shadows(FluentInk.shadowInk(theme.brightness)),
      ),
      child: ConstrainedBox(
        // kFlyoutMinConstraints, flyout_content.dart:4.
        constraints: const BoxConstraints(minWidth: 118),
        child: child,
      ),
    );
    return width == null ? surface : SizedBox(width: width, child: surface);
  }
}

final class FluentMenuSurface extends StatelessWidget {
  /// Draws the menu over [entries].
  const FluentMenuSurface({super.key, required this.entries});

  /// The entries, in the application's order - which is the order whose
  /// index the route reports back.
  final List<MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    // The leading gutter is reserved for EVERY row as soon as any row has a
    // leading mark, so words align down the menu - the reference's icon
    // placeholder behaviour (menu_flyout.dart:97-99,122,331-336). A
    // checkable or a choice row always owns the slot: its mark IS the
    // state.
    final bool hasLeading = entries.any(
      (MenuEntry entry) => switch (entry) {
        final MenuAction action => action.icon != null,
        MenuCheckable() || MenuChoice() => true,
        MenuSeparator() || MenuSection() => false,
      },
    );
    bool autofocusGiven = false;
    final List<Widget> rows = <Widget>[];
    for (int index = 0; index < entries.length; index++) {
      switch (entries[index]) {
        case MenuSeparator():
          rows.add(const _FluentMenuSeparator());
        case final MenuSection section:
          rows.add(_FluentMenuSection(label: section.label));
        case final MenuAction action:
          final bool enabled = action.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _FluentMenuRow(
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              reserveLeading: hasLeading,
              // An [IconRole] mark waits on the registered glyph table; the
              // slot is reserved so the words never move when it lands.
              leading: null,
              label: action.label,
              destructive: action.role == MenuActionRole.destructive,
              tooltip: action.tooltip,
              dispatch: enabled ? () => action.onPressed!() : null,
            ),
          );
        case final MenuCheckable checkable:
          final bool enabled = checkable.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _FluentMenuRow(
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              reserveLeading: hasLeading,
              checked: checkable.checked,
              // ToggleMenuFlyoutItem leads with the CheckMark glyph at 12
              // when its fact holds, and with the empty slot when it does
              // not (menu_flyout.dart:409).
              leading: checkable.checked
                  ? const _MenuLeadingMark(kind: _LeadingMark.check)
                  : null,
              label: checkable.label,
              dispatch: enabled
                  ? () => checkable.onChanged!(!checkable.checked)
                  : null,
            ),
          );
        case final MenuChoice choice:
          final bool enabled = choice.isEnabled;
          final bool autofocus = enabled && !autofocusGiven;
          autofocusGiven = autofocusGiven || autofocus;
          rows.add(
            _FluentMenuRow(
              index: index,
              enabled: enabled,
              autofocus: autofocus,
              reserveLeading: hasLeading,
              chosen: choice.selected,
              // RadioMenuFlyoutItem leads with the RadioBullet glyph at 12
              // on the row in force (menu_flyout.dart:453-458).
              leading: choice.selected
                  ? const _MenuLeadingMark(kind: _LeadingMark.bullet)
                  : null,
              label: choice.label,
              dispatch: enabled ? () => choice.onSelect!() : null,
            ),
          );
      }
    }
    return Semantics(
      role: SemanticsRole.menu,
      explicitChildNodes: true,
      // The surface itself is [FluentFlyoutSurface]: a menu and a popover
      // stand on one surface in this language, so it is drawn once.
      child: FluentFlyoutSurface(
        child: IntrinsicWidth(
          child: Padding(
            // kDefaultMenuPadding, menu_flyout.dart:7.
            padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
            child: SingleChildScrollView(
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
}

/// Which drawn mark leads a row.
enum _LeadingMark { check, bullet }

/// The leading state mark, drawn into the 16 epx slot at the glyph's own 12.
class _MenuLeadingMark extends StatelessWidget {
  const _MenuLeadingMark({required this.kind});

  final _LeadingMark kind;

  @override
  Widget build(BuildContext context) {
    // The mark takes the row's current foreground, published through the
    // ambient icon treatment by the row below.
    final Color color =
        IconTheme.of(context).color ??
        FluentTheme.of(context).resources.textFillColorPrimary;
    return switch (kind) {
      _LeadingMark.check => FluentCheckMark(color: color),
      _LeadingMark.bullet => _FluentRadioBullet(color: color),
    };
  }
}

/// The bullet of a one-of-N menu row in force: the `RadioBullet` glyph's
/// geometry - a filled dot centred in the 12 epx glyph box
/// (menu_flyout.dart:453-458 draws `FluentIcons.radio_bullet` at 12).
///
/// Private to the menu rather than added to `fluent_control_marks.dart`:
/// the radio GROUP control draws its own knob as part of its own anatomy,
/// and this dot has exactly one consumer - the row it marks.
class _FluentRadioBullet extends StatelessWidget {
  const _FluentRadioBullet({required this.color});

  /// The ink of the dot.
  final Color color;

  /// The glyph box, shared with the check (menu_flyout.dart:455, size 12).
  static const double _size = 12;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(_size),
    painter: _DotPainter(color: color),
  );
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The dot fills the middle half of its box - the reading of the Segoe
    // glyph at 12 epx, the same judgement-of-a-glyph the check mark's
    // stroke width records.
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) => oldDelegate.color != color;
}

/// A rule between two groups of entries: the language's divider, full
/// bleed, with the separator's own 5 epx of air below it
/// (`MenuFlyoutSeparator`, menu_flyout.dart:371-378 - a Divider with its
/// end margins zeroed, padded only at the bottom).
class _FluentMenuSeparator extends StatelessWidget {
  const _FluentMenuSeparator();

  @override
  Widget build(BuildContext context) => Padding(
    // kDefaultMenuItemMargin (menu_flyout.dart:10-13) around the item, plus
    // the separator's own bottom 5 (menu_flyout.dart:373).
    padding: const EdgeInsetsDirectional.only(
      start: 4,
      end: 4,
      top: 2,
      bottom: 7,
    ),
    child: Container(
      // divider.dart:188, thickness 1.
      height: 1,
      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
    ),
  );
}

/// A heading naming the run of entries below it.
///
/// WinUI's menu flyout publishes no section-header item, so this is the
/// skin's own composition from the language's supporting-text vocabulary:
/// the caption step in the secondary colour - the treatment the reference
/// gives every supporting line (its ListTile subtitle,
/// surfaces/list_tile.dart:311) - at the row's own inset, not invokable and
/// not focusable.
class _FluentMenuSection extends StatelessWidget {
  const _FluentMenuSection({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    // The item margin (menu_flyout.dart:10-13) plus the row's own content
    // inset (flyout_content.dart:222-227), so the heading aligns with the
    // words of the rows it names.
    padding: const EdgeInsetsDirectional.only(
      start: 14,
      end: 12,
      top: 6,
      bottom: 2,
    ),
    child: Text(
      label,
      style: FluentTypeResolution.styleOf(context, TextRole.detail).copyWith(
        color: FluentTheme.of(context).resources.textFillColorSecondary,
      ),
    ),
  );
}

/// One choosable row: the FlyoutListTile, drawn.
///
/// Anatomy from the reference (flyout_content.dart:188-296):
///
///  * content padding 10/4/8/4 start/top/end/bottom (:222-227), corner 4
///    (:200), inside the 4/2 item margin (menu_flyout.dart:10-13);
///  * the subtle ladder answers the pointer: transparent at rest,
///    `SubtleFillColorSecondary` hovered, `Tertiary` pressed
///    (`uncheckedInputColor` with `transparentWhenNone`, :213-219 via
///    buttons/theme.dart:364-380), animated over the container step;
///  * a leading mark sits in a 16 epx slot with 10 after it (:231-237),
///    reserved for every row once any row is marked;
///  * the words are the body step tightened by the flyout's own
///    -0.15 letter spacing (:242-247), ended 10 before the trailing edge
///    (:240-241);
///  * keyboard focus wears the two-stroke rectangle outside the row
///    (:284-290, `renderOutside: true`).
///
/// This skin's own judgements, named: a DESTRUCTIVE row's words and mark
/// take `SystemFillColorCritical` - the language's critical foreground,
/// the severity the contract's own vocabulary doc expects Fluent to answer
/// destruction with - and the tint is dropped while the row is disabled so
/// the disabled treatment stays visible. The tooltip - most importantly a
/// disabled row's reason - is announced to the semantics tree, the same
/// registered flyout gap every tooltip in this package carries.
class _FluentMenuRow extends StatelessWidget {
  const _FluentMenuRow({
    required this.index,
    required this.enabled,
    required this.autofocus,
    required this.reserveLeading,
    required this.leading,
    required this.label,
    required this.dispatch,
    this.destructive = false,
    this.checked,
    this.chosen,
    this.tooltip,
  });

  /// The row's position in the ORIGINAL entry list - what the route pops.
  final int index;

  /// Whether the row may be invoked right now.
  final bool enabled;

  /// Whether this row takes focus when the menu opens.
  final bool autofocus;

  /// Whether the leading slot is reserved even when this row has no mark.
  final bool reserveLeading;

  /// The drawn state mark, or null for an empty (possibly reserved) slot.
  final Widget? leading;

  /// The row's words.
  final String label;

  /// Runs the entry after the route has popped. Null while disabled.
  final VoidCallback? dispatch;

  /// Whether this row destroys something.
  final bool destructive;

  /// A checkable row's fact, for the semantics tree; null on other rows.
  final bool? checked;

  /// A one-of-N row's state, for the semantics tree; null on other rows.
  final bool? chosen;

  /// The longer explanation - the REASON while the row is unavailable.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final FluentResources res = FluentTheme.of(context).resources;
    return Semantics(
      role: SemanticsRole.menuItem,
      tooltip: tooltip,
      checked: checked,
      selected: chosen,
      child: FluentPressable(
        onPressed: dispatch == null
            ? null
            : () {
                // Pop first, then run - the reference's own order
                // (menu_flyout.dart:344-347), so an entry that opens
                // another overlay opens it against a navigator this menu
                // has already left. The index is the caller's answer.
                Navigator.of(context).pop(index);
                dispatch!();
              },
        autofocus: autofocus,
        builder: (BuildContext context, Set<WidgetState> states) {
          // flyout_content.dart:213-219: the subtle ladder,
          // transparent-when-none; a disabled row rests transparent.
          final Color fill = states.contains(WidgetState.pressed)
              ? res.subtleFillColorTertiary
              : states.contains(WidgetState.hovered)
              ? res.subtleFillColorSecondary
              : res.subtleFillColorTransparent;
          final Color foreground = states.contains(WidgetState.disabled)
              ? res.textFillColorDisabled
              : destructive
              ? res.systemFillColorCritical
              : res.textFillColorPrimary;
          return Padding(
            // kDefaultMenuItemMargin, menu_flyout.dart:10-13 - which is
            // also the room the focus rectangle stands off into.
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            child: FluentFocusRing(
              focused: states.contains(WidgetState.focused),
              child: AnimatedContainer(
                duration: FluentMotion.faster,
                curve: FluentMotion.curve,
                decoration: BoxDecoration(
                  color: fill,
                  // flyout_content.dart:200.
                  borderRadius: BorderRadius.circular(
                    FluentGeometry.controlCornerRadius,
                  ),
                ),
                // flyout_content.dart:222-227.
                padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 8, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (leading != null || reserveLeading)
                      Padding(
                        // The 10 after the mark's slot,
                        // flyout_content.dart:233.
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            // The slot's glyph extent,
                            // flyout_content.dart:235.
                            size: FluentMetrics.glyphNormal,
                            color: foreground,
                          ),
                          child: SizedBox.square(
                            dimension: FluentMetrics.glyphNormal,
                            child: leading == null
                                ? null
                                : Center(child: leading),
                          ),
                        ),
                      ),
                    Flexible(
                      child: Padding(
                        // The 10 before the trailing edge,
                        // flyout_content.dart:240-241.
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: Text(
                          label,
                          style:
                              FluentTypeResolution.styleOf(
                                context,
                                TextRole.control,
                              ).copyWith(
                                color: foreground,
                                // flyout_content.dart:245: the flyout
                                // tile's own tightening.
                                letterSpacing: -0.15,
                              ),
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
