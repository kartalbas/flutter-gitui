/// Material 3 conformance suite for BasePanel
/// (lib/shared/components/base_panel.dart).
///
/// A panel is two Material 3 components stacked: an **elevated card** for the
/// container and an **expansion-tile header** for the title row. Neither
/// exposes a public defaults seam, so both oracles are the real SDK widgets —
/// `Card` and `ExpansionTile` — pumped through [pumpConformance] and read
/// with the same probes as BasePanel, which makes fonts, device pixel ratio
/// and visual density cancel out of every comparison.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_panel.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so horizontal measurements compare like
/// with like.
const double _probeWidth = 400.0;

/// The Material 3 container oracle.
///
/// `Card` is banned from UI code by the design system's `avoid_card` rule.
/// Here it is not shipped UI but the ruler this suite measures against, which
/// is why the rule is suppressed at this single construction.
Widget _oracleCard({bool outlined = false, Widget? child}) {
  final Widget body = SizedBox(height: 100, child: child);
  return SizedBox(
    width: _probeWidth,
    child: outlined
        // ignore: avoid_card
        ? Card.outlined(child: body)
        // ignore: avoid_card
        : Card(child: body),
  );
}

/// The Material 3 header oracle: an expansion tile builds its header from a
/// `ListTile`, which is what carries the M3 header geometry and colors.
Widget _oracleHeader({bool expanded = true}) {
  return SizedBox(
    width: _probeWidth,
    child: ExpansionTile(
      title: const Text('Panel'),
      initiallyExpanded: expanded,
      children: const <Widget>[SizedBox(height: 50)],
    ),
  );
}

Widget _basePanel({
  bool isCollapsible = true,
  bool initiallyExpanded = true,
  bool hasBorder = false,
  Widget? content,
}) {
  return SizedBox(
    width: _probeWidth,
    child: BasePanel(
      title: const Text('Panel'),
      isCollapsible: isCollapsible,
      initiallyExpanded: initiallyExpanded,
      hasBorder: hasBorder,
      content: content ?? const SizedBox(height: 100),
    ),
  );
}

/// The Material that paints a panel's or a card's visual container.
Finder _containerOf(Type widgetType) => find
    .descendant(of: find.byType(widgetType), matching: find.byType(Material))
    .first;

/// The header row, the single Tab-stop-bearing InkWell at the top of either
/// side.
Finder _headerOf(Type widgetType) => find
    .descendant(of: find.byType(widgetType), matching: find.byType(InkWell))
    .first;

/// Corner radius a Material rounds to, whichever way it expresses it: a
/// rounded `shape` (what `Card` uses) or a plain `borderRadius`.
double _materialRadius(WidgetTester tester, Finder finder) {
  final Material material = tester.widget<Material>(finder);
  final ShapeBorder? shape = material.shape;
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  final BorderRadiusGeometry? borderRadius = material.borderRadius;
  if (borderRadius is BorderRadius) {
    return borderRadius.topLeft.x;
  }
  fail('Cannot read a corner radius from $material.');
}

/// The border side a card paints around its container.
BorderSide _cardSide(WidgetTester tester) {
  final ShapeBorder? shape = tester.widget<Material>(_containerOf(Card)).shape;
  if (shape is RoundedRectangleBorder) {
    return shape.side;
  }
  fail('Expected the oracle card to carry a rounded shape, got $shape.');
}

/// Distance the painted container is inset from the widget's own layout box.
double _margin(WidgetTester tester, Finder outer, Finder inner) {
  return (tester.getSize(outer).height - tester.getSize(inner).height) / 2;
}

/// The color an icon really renders in: its own, or the one its IconTheme
/// hands down. Both sides go through this, so an explicitly colored icon and
/// a theme-colored one are described the same way.
Color _effectiveIconColor(WidgetTester tester, Finder finder) {
  final Icon icon = tester.widget<Icon>(finder);
  return icon.color ?? IconTheme.of(tester.element(finder)).color!;
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

double _headerStartInset(WidgetTester tester, Finder header) {
  return tester.getRect(find.text('Panel')).left - tester.getRect(header).left;
}

/// Insets are read from the axis-aligned rect rather than from a named
/// corner: an ExpansionTile turns its caret through half a rotation while
/// expanded, which swaps that widget's corners in global coordinates.
double _headerEndInset(WidgetTester tester, Finder header, Finder trailing) {
  return tester.getRect(header).right - tester.getRect(trailing).right;
}

void main() {
  group('container geometry', () {
    testWidgets('elevation', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = tester
          .widget<Material>(_containerOf(Card))
          .elevation;

      await pumpConformance(tester, _basePanel());
      final double measured = tester
          .widget<Material>(_containerOf(BasePanel))
          .elevation;

      expectConformant(
        token: 'BasePanel.elevation',
        component: 'BasePanel',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = _materialRadius(tester, _containerOf(Card));

      await pumpConformance(tester, _basePanel());
      final double measured = _materialRadius(tester, _containerOf(BasePanel));

      expectConformant(
        token: 'BasePanel.shape',
        component: 'BasePanel',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('margin (PANEL-002)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = _margin(
        tester,
        find.byType(Card),
        _containerOf(Card),
      );

      await pumpConformance(tester, _basePanel());
      final double measured = _margin(
        tester,
        find.byType(BasePanel),
        _containerOf(BasePanel),
      );

      expectConformant(
        token: 'BasePanel.margin',
        component: 'BasePanel',
        measured: measured,
        expected: expected,
      );
    });
  });

  group('surface and outline roles', () {
    testWidgets('container color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        tester.widget<Material>(_containerOf(Card)).color!,
      );

      await pumpConformance(tester, _basePanel());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BasePanel.containerColor',
        component: 'BasePanel',
        measured: colorRoleName(
          scheme,
          tester.widget<Material>(_containerOf(BasePanel)).color!,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('border color when the panel is outlined', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleCard(outlined: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(scheme, _cardSide(tester).color);

      await pumpConformance(tester, _basePanel(hasBorder: true));
      scheme = _theme(tester).colorScheme;
      final BoxDecoration decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(BasePanel),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      expectConformant(
        token: 'BasePanel.borderColor',
        component: 'BasePanel',
        measured: colorRoleName(
          scheme,
          (decoration.border! as Border).top.color,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('content text role', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        _oracleCard(child: const Text('Typography')),
      );
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, 'Typography'),
      );

      await pumpConformance(
        tester,
        _basePanel(content: const Text('Typography')),
      );
      theme = _theme(tester);

      expectConformant(
        token: 'BasePanel.contentTextStyle',
        component: 'BasePanel',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Typography')),
        expected: expected,
        unit: '',
      );
    });
  });

  group('header geometry', () {
    testWidgets('minimum header height', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      final double expected = tester.getSize(find.byType(ListTile)).height;

      await pumpConformance(tester, _basePanel());
      final double measured = tester.getSize(_headerOf(BasePanel)).height;

      expectConformant(
        token: 'BasePanel.header.minTileHeight',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('title inset (PANEL-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      final double expected = _headerStartInset(tester, find.byType(ListTile));

      await pumpConformance(tester, _basePanel());
      final double measured = _headerStartInset(tester, _headerOf(BasePanel));

      expectConformant(
        token: 'BasePanel.header.contentPadding.start',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('caret inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      final double expected = _headerEndInset(
        tester,
        find.byType(ListTile),
        find.byIcon(Icons.expand_more),
      );

      await pumpConformance(tester, _basePanel());
      final double measured = _headerEndInset(
        tester,
        _headerOf(BasePanel),
        find.byIcon(PhosphorIconsRegular.caretUp),
      );

      expectConformant(
        token: 'BasePanel.header.contentPadding.end',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('title text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, 'Panel'),
      );

      await pumpConformance(tester, _basePanel());
      theme = _theme(tester);

      expectConformant(
        token: 'BasePanel.header.titleTextStyle',
        component: 'BasePanel.header',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Panel')),
        expected: expected,
        unit: '',
      );
    });
  });

  group('caret colors', () {
    testWidgets('collapsed caret role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader(expanded: false));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _effectiveIconColor(tester, find.byIcon(Icons.expand_more)),
      );

      await pumpConformance(tester, _basePanel(initiallyExpanded: false));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BasePanel.collapsedIconColor',
        component: 'BasePanel',
        measured: colorRoleName(
          scheme,
          _effectiveIconColor(
            tester,
            find.byIcon(PhosphorIconsRegular.caretDown),
          ),
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('expanded caret role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _effectiveIconColor(tester, find.byIcon(Icons.expand_more)),
      );

      await pumpConformance(tester, _basePanel());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BasePanel.expandedIconColor',
        component: 'BasePanel',
        measured: colorRoleName(
          scheme,
          _effectiveIconColor(
            tester,
            find.byIcon(PhosphorIconsRegular.caretUp),
          ),
        ),
        expected: expected,
        unit: '',
      );
    });
  });

  group('header state layers', () {
    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      final String expected = describeStateLayer(
        tester,
        await hoverStateLayer(tester, find.byType(ListTile)),
      );

      await pumpConformance(tester, _basePanel());
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(tester, _headerOf(BasePanel)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BasePanel.header.overlay.hovered',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleHeader());
      final String expected = describeStateLayer(
        tester,
        await pressStateLayer(tester, find.byType(ListTile)),
      );

      await pumpConformance(tester, _basePanel());
      final String measured = describeStateLayer(
        tester,
        await pressStateLayer(tester, _headerOf(BasePanel)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BasePanel.header.overlay.pressed',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('Tab reaches the header and paints the focus layer', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleHeader());
      final String expected = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      await pumpConformance(tester, _basePanel());
      final String measured = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BasePanel.header.overlay.focused',
        component: 'BasePanel.header',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });
  });

  group('keyboard operation', () {
    testWidgets('Enter and Space each toggle a collapsible panel', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _basePanel());
      expect(find.byIcon(PhosphorIconsRegular.caretUp), findsOneWidget);

      await focusFirstWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(PhosphorIconsRegular.caretDown),
        findsOneWidget,
        reason: 'Enter must collapse the focused panel',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(PhosphorIconsRegular.caretUp),
        findsOneWidget,
        reason: 'Space must expand it again',
      );
    });

    testWidgets('a panel that cannot collapse is not a Tab stop', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _basePanel(isCollapsible: false));
      expect(describeStateLayer(tester, await focusStateLayer(tester)), 'none');
    });
  });

  group('tap target', () {
    testWidgets('the header meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _basePanel());
      expect(
        tester.getSize(_headerOf(BasePanel)).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
