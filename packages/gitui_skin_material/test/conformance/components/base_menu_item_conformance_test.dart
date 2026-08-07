/// Material 3 conformance suite for the menu family
/// (lib/shared/components/base_menu_item.dart and `BasePopupMenuButton` in
/// lib/shared/components/base_animated_widgets.dart).
///
/// The family splits into three things that are measured against two oracles:
///
///   * **`BaseMenuItem`** is a `PopupMenuItem` subclass that overrides nothing,
///     so the oracle is a real `PopupMenuItem` inside a real `PopupMenuButton`,
///     opened in the same harness. Height, inset, label role, label colour per
///     state and state layers are read off both with the same probes.
///   * **`MenuItemContent`** is the icon-and-label row the app puts *inside*
///     that item. `PopupMenuItem` has no leading-icon slot at all, so its
///     oracle is `MenuItemButton` — Material 3's own menu item with a
///     `leadingIcon` — pumped in the same harness, which is where the SDK's
///     24 dp glyph and 12 dp gap actually come from.
///   * **`BasePopupMenuButton`** is a `PopupMenuButton` with an animation style
///     and an icon size, so the menu surface it opens is measured against the
///     stock button's.
///
/// One reading note on the label role. In the Material 3 type scale
/// `titleSmall` and `labelLarge` are the same metric triple (14 / 0.1 / 1.43),
/// so [describeTextRole], which maps a style onto a role by its metrics, cannot
/// tell them apart and names whichever it reaches first — `titleSmall`. The
/// role the SDK actually asks for is `labelLarge`
/// (flutter/lib/src/material/popup_menu.dart:1847, `_PopupMenuDefaultsM3
/// .labelTextStyle`). Both sides go through the same descriptor, so the
/// comparison is unaffected; only the name in a failure message is.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_animated_widgets.dart';
import 'package:flutter_gitui/shared/components/base_menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

const String _enabled = 'Enabled entry';
const String _disabled = 'Disabled entry';

/// The Material 3 oracle for the item and the menu surface: a stock
/// `PopupMenuButton` holding stock `PopupMenuItem`s.
Widget _oracleMenu() {
  return PopupMenuButton<int>(
    icon: const Icon(Icons.more_vert),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
      const PopupMenuItem<int>(value: 1, child: Text(_enabled)),
      const PopupMenuItem<int>(
        value: 2,
        enabled: false,
        child: Text(_disabled),
      ),
    ],
  );
}

/// The component under measurement, with the same two entries.
///
/// [withContent] switches the item's child between a bare `Text` — which
/// measures `BaseMenuItem` itself, since the item then supplies the style —
/// and a `MenuItemContent`, which measures the app's icon-and-label row.
Widget _baseMenu({bool withContent = false}) {
  return BasePopupMenuButton<int>(
    icon: const Icon(Icons.more_vert),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
      BaseMenuItem<int>(
        value: 1,
        child: withContent
            ? const MenuItemContent(icon: Icons.star, label: _enabled)
            : const Text(_enabled),
      ),
      BaseMenuItem<int>(
        value: 2,
        enabled: false,
        child: withContent
            ? const MenuItemContent(icon: Icons.star, label: _disabled)
            : const Text(_disabled),
      ),
    ],
  );
}

/// Material 3's own menu item, the oracle for everything a `PopupMenuItem`
/// has no slot for: the leading glyph and the gap that follows it.
Widget _oracleItemButton() {
  return MenuItemButton(
    leadingIcon: const Icon(Icons.star),
    onPressed: () {},
    child: const Text(_enabled),
  );
}

/// Pumps [menu] and opens it, so every item measurement is taken on the
/// rendered menu rather than on the closed button.
///
/// The tree is torn down first. A conformance test pumps twice — the oracle,
/// then the component — and pumping a second app of the same shape only
/// *updates* the first one, so its Navigator keeps the route the open menu
/// lives in: the menu opened for the oracle would still be on screen, its
/// barrier would swallow the tap meant for the second button, and the second
/// measurement would silently be taken on the first menu.
Future<void> pumpOpenMenu(WidgetTester tester, Widget menu) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpConformance(tester, menu);
  await tester.tap(find.byType(PopupMenuButton<int>));
  await tester.pumpAndSettle();
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

/// The item carrying [label]. `BaseMenuItem` *is* a `PopupMenuItem`, so one
/// finder serves both sides — but it has to be a predicate finder rather than
/// `find.byType`, which matches an exact runtime type and would therefore see
/// the oracle's `PopupMenuItem<int>` and never the subclass under measurement.
Finder _item(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is PopupMenuItem<int>,
        description: 'PopupMenuItem<int> or a subclass of it',
      ),
    )
    .first;

/// The `Material` that paints the open menu's surface.
Finder _menuSurface() =>
    find.ancestor(of: _item(_enabled), matching: find.byType(Material)).first;

TextStyle _labelStyle(WidgetTester tester, String label) {
  return tester.renderObject<RenderParagraph>(find.text(label)).text.style!;
}

/// Distance from the item's leading edge to the start of its child — the menu
/// item's horizontal content padding as it really lands.
double _startInset(WidgetTester tester, String label, Finder child) {
  return tester.getRect(child).left - tester.getRect(_item(label)).left;
}

void main() {
  group('the menu surface', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final ShapeBorder? expected = tester
          .widget<Material>(_menuSurface())
          .shape;

      await pumpOpenMenu(tester, _baseMenu());

      expectConformant(
        token: 'BasePopupMenuButton.menu.shape',
        component: 'BasePopupMenuButton',
        measured: tester.widget<Material>(_menuSurface()).shape.toString(),
        expected: expected.toString(),
        unit: '',
      );
    });

    testWidgets('container colour', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        tester.widget<Material>(_menuSurface()).color!,
      );

      await pumpOpenMenu(tester, _baseMenu());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BasePopupMenuButton.menu.containerColor',
        component: 'BasePopupMenuButton',
        measured: colorRoleName(
          scheme,
          tester.widget<Material>(_menuSurface()).color!,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final double expected = tester.widget<Material>(_menuSurface()).elevation;

      await pumpOpenMenu(tester, _baseMenu());

      expectConformant(
        token: 'BasePopupMenuButton.menu.elevation',
        component: 'BasePopupMenuButton',
        measured: tester.widget<Material>(_menuSurface()).elevation,
        expected: expected,
      );
    });

    testWidgets('vertical padding around the entries', (
      WidgetTester tester,
    ) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final double expected =
          tester.getRect(_item(_enabled)).top -
          tester.getRect(_menuSurface()).top;

      await pumpOpenMenu(tester, _baseMenu());

      expectConformant(
        token: 'BasePopupMenuButton.menu.padding.vertical',
        component: 'BasePopupMenuButton',
        measured:
            tester.getRect(_item(_enabled)).top -
            tester.getRect(_menuSurface()).top,
        expected: expected,
      );
    });

    testWidgets('the button glyph (MENU-004)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleMenu());
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.more_vert),
      );

      await pumpConformance(tester, _baseMenu());

      expectConformant(
        token: 'BasePopupMenuButton.iconSize',
        component: 'BasePopupMenuButton',
        measured: effectiveIconSize(tester, find.byIcon(Icons.more_vert)),
        expected: expected,
      );
    });
  });

  group('the item itself', () {
    testWidgets('minimum height', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final double expected = tester.getRect(_item(_enabled)).height;

      await pumpOpenMenu(tester, _baseMenu());
      final double measured = tester.getRect(_item(_enabled)).height;

      expectConformant(
        token: 'BaseMenuItem.minHeight',
        component: 'BaseMenuItem',
        measured: measured,
        expected: expected,
      );
      expect(
        measured,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason:
            'a menu entry is a control: PopupMenuItem defaults its height to '
            'kMinInteractiveDimension (popup_menu.dart:279)',
      );
    });

    testWidgets('leading content inset', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final double expected = _startInset(
        tester,
        _enabled,
        find.text(_enabled),
      );

      await pumpOpenMenu(tester, _baseMenu());

      expectConformant(
        token: 'BaseMenuItem.contentPadding.start',
        component: 'BaseMenuItem',
        measured: _startInset(tester, _enabled, find.text(_enabled)),
        expected: expected,
      );
    });

    testWidgets('label role', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _labelStyle(tester, _enabled),
      );

      await pumpOpenMenu(tester, _baseMenu());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseMenuItem.labelTextStyle',
        component: 'BaseMenuItem',
        measured: describeTextRole(theme, _labelStyle(tester, _enabled)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('label colour', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _labelStyle(tester, _enabled).color!,
      );

      await pumpOpenMenu(tester, _baseMenu());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseMenuItem.labelColor',
        component: 'BaseMenuItem',
        measured: colorRoleName(scheme, _labelStyle(tester, _enabled).color!),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('disabled label colour', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _labelStyle(tester, _disabled).color!,
      );
      expect(
        expected,
        'onSurface @ 38%',
        reason:
            'M3 dims a disabled menu entry to onSurface at 38% '
            '(popup_menu.dart:1849); if that stopped holding, this test would '
            'be measuring nothing',
      );

      await pumpOpenMenu(tester, _baseMenu());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseMenuItem.disabled.labelColor',
        component: 'BaseMenuItem',
        measured: colorRoleName(scheme, _labelStyle(tester, _disabled).color!),
        expected: expected,
        unit: '',
      );
    });
  });

  group('state layers', () {
    testWidgets('hover', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final String expected = describeStateLayer(
        tester,
        await hoverStateLayer(tester, _item(_enabled), within: _menuSurface()),
      );

      await pumpOpenMenu(tester, _baseMenu());
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(tester, _item(_enabled), within: _menuSurface()),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseMenuItem.overlay.hovered',
        component: 'BaseMenuItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('press', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final String expected = describeStateLayer(
        tester,
        await pressStateLayer(tester, _item(_enabled), within: _menuSurface()),
      );

      await pumpOpenMenu(tester, _baseMenu());
      final String measured = describeStateLayer(
        tester,
        await pressStateLayer(tester, _item(_enabled), within: _menuSurface()),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseMenuItem.overlay.pressed',
        component: 'BaseMenuItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('focus', (WidgetTester tester) async {
      await pumpOpenMenu(tester, _oracleMenu());
      final String expected = describeStateLayer(
        tester,
        await focusStateLayer(tester, within: _menuSurface()),
      );

      await pumpOpenMenu(tester, _baseMenu());
      final String measured = describeStateLayer(
        tester,
        await focusStateLayer(tester, within: _menuSurface()),
      );

      expectConformant(
        token: 'BaseMenuItem.overlay.focused',
        component: 'BaseMenuItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });
  });

  group('the icon-and-label row inside the item', () {
    testWidgets('label role (MENU-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleItemButton());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _labelStyle(tester, _enabled),
      );

      await pumpOpenMenu(tester, _baseMenu(withContent: true));
      theme = _theme(tester);

      expectConformant(
        token: 'MenuItemContent.labelTextStyle',
        component: 'MenuItemContent',
        measured: describeTextRole(theme, _labelStyle(tester, _enabled)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('the disabled entry keeps the item\'s dimmed label', (
      WidgetTester tester,
    ) async {
      // The regression this guards: MenuItemContent used to spell
      // `colorScheme.onSurface` out for its label, which painted straight over
      // the onSurface-at-38% a disabled PopupMenuItem publishes, so a disabled
      // entry in an overflow menu looked exactly like an enabled one.
      await pumpOpenMenu(tester, _oracleMenu());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _labelStyle(tester, _disabled).color!,
      );

      await pumpOpenMenu(tester, _baseMenu(withContent: true));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'MenuItemContent.disabled.labelColor',
        component: 'MenuItemContent',
        measured: colorRoleName(scheme, _labelStyle(tester, _disabled).color!),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('leading glyph size (MENU-002)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleItemButton());
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.star),
      );

      await pumpOpenMenu(tester, _baseMenu(withContent: true));

      expectConformant(
        token: 'MenuItemContent.iconSize',
        component: 'MenuItemContent',
        measured: effectiveIconSize(tester, find.byIcon(Icons.star).first),
        expected: expected,
      );
    });

    testWidgets('gap between the glyph and the label (MENU-003)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleItemButton());
      final double expected =
          tester.getRect(find.text(_enabled)).left -
          tester.getRect(find.byIcon(Icons.star)).right;

      await pumpOpenMenu(tester, _baseMenu(withContent: true));

      expectConformant(
        token: 'MenuItemContent.leadingGap',
        component: 'MenuItemContent',
        measured:
            tester.getRect(find.text(_enabled)).left -
            tester.getRect(find.byIcon(Icons.star).first).right,
        expected: expected,
      );
    });
  });

  group('tap target', () {
    testWidgets('an open menu meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpOpenMenu(tester, _baseMenu(withContent: true));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
