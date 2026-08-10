/// The menu, measured under both of its anchors: WinUI's context flyout from
/// the paint stream and the route's own clock at a point, the same flyout
/// hanging off a command button's corner, plus the one loud fence the rest of
/// the overlay facet still keeps.
///
/// What a reimplementation gets wrong is what is asserted: that the menu
/// opens ON the language's clock and closes on NONE (the reference's
/// reverse duration is zero - a menu that fades away feels wrong even at
/// the right speed), that it drops IN from above rather than growing from
/// the anchor the way Material's does, that a row's hover is the subtle
/// ladder composited over the flyout surface, and that choosing pops FIRST
/// and dispatches after.
library;

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_icon_button.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_overlays.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';

import 'support/fluent_behavior_harness.dart';
import 'support/fluent_overlay_harness.dart';

const FluentResources _light = FluentResources.light();

/// Pumps the harness app and opens a menu at [at] over [entries].
Future<Future<int?>> _openMenu(
  WidgetTester tester, {
  required Offset at,
  required List<MenuEntry> entries,
  double animationScale = 1,
}) async {
  late BuildContext host;
  await pumpFluentOverlayApp(tester, (BuildContext context) {
    host = context;
    return const SizedBox.shrink();
  }, animationScale: animationScale);
  final Future<int?> chosen = Overlays.menu(host, at: at, entries: entries);
  await tester.pump();
  return chosen;
}

/// Pumps the harness app with a single anchored trigger at its centre.
Future<void> _pumpAnchor(
  WidgetTester tester, {
  bool selected = false,
  bool enabled = true,
}) async {
  await pumpFluentOverlayApp(
    tester,
    (BuildContext context) => Overlays.anchor(
      spec: MenuAnchorSpec(
        icon: IconRole.copy,
        tooltip: 'More',
        selected: selected,
        enabled: enabled,
      ),
      entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
    ),
  );
}

void main() {
  group('placement and clock', () {
    testWidgets('opens at the asked-for point, dropping in from above on the '
        'flyout transition, and stands exactly at the point once open', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(label: 'Copy', onPressed: () {}),
          MenuAction(label: 'Rename', onPressed: () {}),
        ],
      );
      // t=0: the drop-in starts 15% of the menu's own height ABOVE the
      // final position (flyout.dart:853-858) - Material's menu grows from
      // its anchor instead, so direction is the discriminating fact.
      final Finder surface = find.byType(FluentMenuSurface);
      expect(surface, findsOneWidget);
      final double openingTop = tester.getTopLeft(surface).dy;
      expect(
        openingTop,
        lessThan(200),
        reason: 'a Fluent menu slides DOWN into place from above',
      );
      // Past the 167 ms flyout transition (FluentMotion.fast).
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(surface), const Offset(300, 200));
    });

    testWidgets('clamps to the window edge at the flyout margin of 8', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(1400, 900), // Outside the 1280 x 800 surface.
        entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
      );
      await tester.pump(const Duration(milliseconds: 200));
      final Finder surface = find.byType(FluentMenuSurface);
      final Size size = tester.getSize(surface);
      expect(
        tester.getTopLeft(surface),
        Offset(1280 - size.width - 8, 800 - size.height - 8),
        reason: 'flyout.dart clamps both axes to an 8 epx margin',
      );
    });

    testWidgets('closes instantly - the reverse transition is zero, not the '
        'opening duration run backwards', (WidgetTester tester) async {
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Copy'));
      // ONE frame later the menu is gone. A skin that reused the 167 ms
      // opening duration for the exit would still be fading here.
      await tester.pump();
      expect(find.byType(FluentMenuSurface), findsNothing);
      expect(await chosen, 0);
      // Drain the pressable's 100 ms pressed-release timer.
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('a zero animation scale opens with no transition at all', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
        animationScale: 0,
      );
      // First frame, no pumping past any duration: already in place.
      expect(
        tester.getTopLeft(find.byType(FluentMenuSurface)),
        const Offset(300, 200),
      );
    });
  });

  group('choosing and dispatching', () {
    testWidgets('reports the chosen index in the ORIGINAL entry order and '
        'runs the entry after the pop', (WidgetTester tester) async {
      final List<String> happened = <String>[];
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(label: 'Copy', onPressed: () => happened.add('copy')),
          const MenuSeparator(),
          MenuAction(label: 'Rename', onPressed: () => happened.add('rename')),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Rename'));
      await tester.pump();
      // Index 2: separators count, because the caller's list is the order.
      expect(await chosen, 2);
      expect(happened, <String>['rename']);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('a checkable entry reports its fact flipped', (
      WidgetTester tester,
    ) async {
      bool? reported;
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuCheckable(
            label: 'Show ignored files',
            checked: true,
            onChanged: (bool next) => reported = next,
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Show ignored files'));
      await tester.pump();
      expect(await chosen, 0);
      expect(reported, isFalse);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('a choice entry reports being chosen, never a toggle', (
      WidgetTester tester,
    ) async {
      int chosenCount = 0;
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuChoice(
            label: 'Sort by date',
            selected: true,
            onSelect: () => chosenCount++,
          ),
          MenuChoice(label: 'Sort by name', selected: false, onSelect: () {}),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      // Choosing the one already in force is still choosing - a radio set
      // has no off.
      await tester.tap(find.text('Sort by date'));
      await tester.pump();
      expect(await chosen, 0);
      expect(chosenCount, 1);
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('a disabled entry stays visible, is not invokable, and '
        'announces its reason', (WidgetTester tester) async {
      bool invoked = false;
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(
            label: 'Push',
            onPressed: () => invoked = true,
            enabled: false,
            tooltip: 'No remote is configured',
          ),
          MenuAction(label: 'Fetch', onPressed: () {}),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Push'), findsOneWidget);
      await tester.tap(find.text('Push'));
      await tester.pump();
      expect(invoked, isFalse);
      expect(
        find.byType(FluentMenuSurface),
        findsOneWidget,
        reason: 'a disabled row must not close the menu either',
      );
      // The reason reaches the semantics tree - the registered announced-
      // not-shown tooltip gap this package carries everywhere. The row's
      // pressable is a merge boundary, so the announcement sits on the
      // row's own node above it.
      final SemanticsHandle semantics = tester.ensureSemantics();
      final Finder announced = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.tooltip == 'No remote is configured',
      );
      expect(announced, findsOneWidget);
      expect(
        tester.getSemantics(announced),
        isSemantics(tooltip: 'No remote is configured'),
      );
      semantics.dispose();
      // Close via the barrier so no timers linger.
      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();
    });
  });

  group('keyboard', () {
    testWidgets('the first choosable entry autofocuses and Enter chooses it', (
      WidgetTester tester,
    ) async {
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(label: 'Copy', onPressed: () {}, enabled: false),
          MenuAction(label: 'Rename', onPressed: () {}),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // Index 1: the disabled first entry cannot take the menu's focus.
      expect(await chosen, 1);
      // Drain the keyboard activation's 167 ms pressed flash.
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('Escape leaves with nothing chosen', (
      WidgetTester tester,
    ) async {
      final Future<int?> chosen = await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(FluentMenuSurface), findsNothing);
      expect(await chosen, isNull);
    });
  });

  group('the drawn surface', () {
    testWidgets('the box is the flyout: solid menu surface, 1px flyout '
        'stroke, 8 epx corner, the two-layer shadow, at least 118 wide', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[MenuAction(label: 'Hi', onPressed: () {})],
      );
      await tester.pump(const Duration(milliseconds: 200));
      final Finder surface = find.byType(FluentMenuSurface);

      // kFlyoutMinConstraints (flyout_content.dart:4).
      expect(tester.getSize(surface).width, greaterThanOrEqualTo(118));

      // The fills, in paint order: the two shadow layers the reference
      // derives from elevation 8 (ambient 0.13, key 0.11 - acrylic.dart:
      // 216-227), then the solid menu surface (theme.dart:461, #F9F9F9).
      final List<Color> fills = paintedFillColors(tester, surface);
      expect(fills.length, greaterThanOrEqualTo(3));
      expectPaintedColor(
        fills[0],
        const Color(0xFF000000).withValues(alpha: 0.13),
        reason: 'the ambient shadow layer',
      );
      expectPaintedColor(
        fills[1],
        const Color(0xFF000000).withValues(alpha: 0.11),
        reason: 'the key shadow layer',
      );
      expectPaintedColor(
        fills[2],
        const Color(0xFFF9F9F9),
        reason: 'the solid stand-in for the acrylic menu surface',
      );

      // The 8 epx overlay corner, read off the painted rounded rectangle
      // (flyout_content.dart:73).
      final List<RRect> rects = paintedRRects(tester, surface);
      expect(
        rects.any((RRect rect) => (rect.tlRadiusX - 8).abs() < 0.01),
        isTrue,
        reason: 'the flyout rounds at the overlay corner, 8 epx',
      );

      // The 1px flyout stroke (flyout_content.dart:74). A uniform rounded
      // border reaches the canvas as a drawDRRect ring, so the stroke
      // reader recovers its width from the two rectangles.
      final List<PaintedStroke> strokes = paintedStrokes(tester, surface);
      expect(strokes, isNotEmpty);
      expect(strokes.first.width, 1);
      expect(strokes.first.outerRadius, 8);
      expectPaintedColor(strokes.first.color, _light.surfaceStrokeColorFlyout);

      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();
    });

    testWidgets('hovering a row paints the subtle ladder over the surface - '
        'and it DARKENS, which is the direction Material gets wrong', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(label: 'Copy', onPressed: () {}),
          MenuAction(label: 'Rename', onPressed: () {}),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      final Finder row = find.ancestor(
        of: find.text('Rename'),
        matching: find.byType(AnimatedContainer),
      );
      await hoverOver(tester, find.text('Rename'));
      final List<Color> fills = paintedFillColors(tester, row);
      expect(fills, isNotEmpty);
      expectPaintedColor(
        fills.last,
        _light.subtleFillColorSecondary,
        reason: 'the hover step of the subtle ladder',
      );
      const Color menuGround = Color(0xFFF9F9F9);
      expect(
        luminanceOver(menuGround, fills.last),
        lessThan(menuGround.computeLuminance()),
        reason: 'a Fluent hover darkens the surface it sits on',
      );
      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();
    });

    testWidgets('a destructive entry takes the critical foreground, and '
        'loses it while disabled so the disabled treatment stays visible', (
      WidgetTester tester,
    ) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuAction(
            label: 'Delete branch',
            onPressed: () {},
            role: MenuActionRole.destructive,
          ),
          MenuAction(
            label: 'Force delete',
            onPressed: () {},
            role: MenuActionRole.destructive,
            enabled: false,
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      expectPaintedColor(
        renderedLabelColor(tester, 'Delete branch'),
        _light.systemFillColorCritical,
      );
      expectPaintedColor(
        renderedLabelColor(tester, 'Force delete'),
        _light.textFillColorDisabled,
      );
      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();
    });

    testWidgets('a marked menu reserves the leading gutter for every row, '
        'so words align down the menu', (WidgetTester tester) async {
      await _openMenu(
        tester,
        at: const Offset(300, 200),
        entries: <MenuEntry>[
          MenuCheckable(
            label: 'Show ignored',
            checked: true,
            onChanged: (bool _) {},
          ),
          MenuAction(label: 'Markless entry', onPressed: () {}),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getTopLeft(find.text('Show ignored')).dx,
        tester.getTopLeft(find.text('Markless entry')).dx,
        reason:
            'the icon placeholder behaviour of MenuFlyout '
            '(menu_flyout.dart:97-99,331-336)',
      );
      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();
    });
  });

  group('the popover', () {
    // A popover is not a second surface: it is the menu's surface carrying the
    // application's content. These pin the two things a caller can state about
    // it, because both are meaning rather than measurement.
    testWidgets('a popover that CONTINUES its anchor takes that width', (
      WidgetTester tester,
    ) async {
      late BuildContext anchorContext;
      await pumpFluentOverlayApp(tester, (BuildContext context) {
        anchorContext = context;
        return const SizedBox.expand();
      });
      unawaited(
        Overlays.popover<void>(
          anchorContext,
          const PopoverSpec(semanticsLabel: 'x', continuesAnchor: true),
          const ContentPort(SizedBox(width: 40, height: 40)),
        ),
      );
      await tester.pumpAndSettle();
      // The anchor fills the 1280 surface, and the content inside is 40 wide -
      // so a surface this wide can only have come from the anchor.
      expect(
        tester.getSize(find.byType(FluentFlyoutSurface)).width,
        greaterThan(1000),
      );
      Navigator.of(anchorContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('a popover that does not continue its anchor sizes itself', (
      WidgetTester tester,
    ) async {
      late BuildContext anchorContext;
      await pumpFluentOverlayApp(tester, (BuildContext context) {
        anchorContext = context;
        return const SizedBox.expand();
      });
      unawaited(
        Overlays.popover<void>(
          anchorContext,
          const PopoverSpec(semanticsLabel: 'x'),
          const ContentPort(SizedBox(width: 40, height: 40)),
        ),
      );
      await tester.pumpAndSettle();
      // The flyout's own minimum is 118, so this cannot reach the anchor's
      // width by accident.
      expect(
        tester.getSize(find.byType(FluentFlyoutSurface)).width,
        lessThan(200),
      );
      Navigator.of(anchorContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('a popover that is not barrier-dismissible survives a tap '
        'outside it', (WidgetTester tester) async {
      late BuildContext anchorContext;
      await pumpFluentOverlayApp(tester, (BuildContext context) {
        anchorContext = context;
        return const SizedBox.expand();
      });
      unawaited(
        Overlays.popover<void>(
          anchorContext,
          const PopoverSpec(
            semanticsLabel: 'sticky',
            barrierDismissible: false,
          ),
          const ContentPort(SizedBox(width: 40, height: 40)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FluentFlyoutSurface), findsOneWidget);

      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(
        find.byType(FluentFlyoutSurface),
        findsOneWidget,
        reason: 'barrierDismissible: false must keep the surface up',
      );

      Navigator.of(anchorContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();
    });
  });

  group('the anchored trigger', () {
    testWidgets('is the toolbar\'s own command button, not a second drawing, '
        'and carries the tooltip that names it', (WidgetTester tester) async {
      await _pumpAnchor(tester);
      // The discriminating fact: ONE icon button, built by the controls
      // facet. A skin that drew its own trigger here would drift from the
      // buttons beside it in the same toolbar the first time either changed.
      expect(find.byType(FluentIconButton), findsOneWidget);

      final SemanticsHandle semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byType(FluentIconButton)),
        isSemantics(tooltip: 'More', isButton: true, isEnabled: true),
      );
      semantics.dispose();
    });

    testWidgets('opens the flyout beneath its own bottom-leading corner', (
      WidgetTester tester,
    ) async {
      await _pumpAnchor(tester);
      final Offset corner = tester.getBottomLeft(find.byType(FluentIconButton));

      await tester.tap(find.byType(FluentIconButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Attached placement, `bottomLeft` (flyout.dart:788): the flyout hangs
      // off the control's lower leading corner. A point-anchored menu opened
      // at the pointer instead would land wherever the tap happened to be.
      expect(tester.getTopLeft(find.byType(FluentMenuSurface)), corner);

      await tester.tap(find.text('Copy'));
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('an ordinary anchor reports no toggled state at all', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpAnchor(tester);
      expect(
        tester.getSemantics(find.byType(FluentIconButton)),
        isSemantics(hasToggledState: false),
        reason:
            'an anchor with nothing engaged has no state to report, and '
            'saying "not pressed" about it is noise a reader must carry',
      );
      semantics.dispose();
    });

    testWidgets('an engaged anchor is announced as a toggle', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpAnchor(tester, selected: true);
      expect(
        tester.getSemantics(find.byType(FluentIconButton)),
        isSemantics(isToggled: true),
      );
      semantics.dispose();
    });

    testWidgets('a disabled anchor opens nothing', (WidgetTester tester) async {
      await _pumpAnchor(tester, enabled: false);
      await tester.tap(find.byType(FluentIconButton));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FluentMenuSurface), findsNothing);
    });
  });

  group('the fence that remains', () {
    // Was four; the popover, the anchor and the notice have landed, so it is
    // one. The count is asserted rather than described because a fence that
    // quietly stops refusing is a member that quietly started guessing.
    testWidgets('the dialog refuses loudly, naming itself', (
      WidgetTester tester,
    ) async {
      late BuildContext host;
      await pumpFluentOverlayApp(tester, (BuildContext context) {
        host = context;
        return const SizedBox.shrink();
      });
      expect(
        () => Overlays.dialog<void>(
          host,
          DialogSpec(title: 'x', content: const ContentPort(SizedBox.shrink())),
        ),
        throwsUnimplementedError,
      );
    });
  });
}
