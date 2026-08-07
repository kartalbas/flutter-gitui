/// Material 3 conformance suite for BaseListItem
/// (lib/shared/components/base_list_item.dart).
///
/// The oracle is the SDK's own `ListTile`: it has no public defaults seam, so
/// every token is measured twice with the same probe — once on a real
/// `ListTile` and once on BaseListItem, both pumped through
/// [pumpConformance]. Fonts, device pixel ratio and visual density are
/// therefore identical on both sides and cancel out of the comparison.
///
/// State layers are painted ink rather than widget properties, so they are
/// diffed out of the ink paint stream ([hoverStateLayer] and friends).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_list_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so horizontal measurements compare like
/// with like.
const double _probeWidth = 400.0;

/// Size of the leading glyph in the padding probes. It equals `ListTile`'s
/// `minLeadingWidth` (list_tile.dart:1830), so the leading slot is exactly as
/// wide as the icon on both sides and the measured gap is the real gap.
const double _leadingSize = 24.0;

/// The Material 3 oracle row.
///
/// `ListTile` is banned from UI code by the design system's `avoid_list_tile`
/// rule. Here it is not shipped UI but the ruler this suite measures against,
/// which is why the rule is suppressed at this single construction.
Widget _oracleTile({
  VoidCallback? onTap,
  Widget? title,
  bool leading = false,
  bool trailing = false,
}) {
  return SizedBox(
    width: _probeWidth,
    // ignore: avoid_list_tile
    child: ListTile(
      onTap: onTap,
      leading: leading ? const Icon(Icons.folder, size: _leadingSize) : null,
      title: title ?? const Text('Row'),
      trailing: trailing
          ? const Icon(Icons.chevron_right, size: _leadingSize)
          : null,
    ),
  );
}

Widget _baseItem({
  VoidCallback? onTap,
  Widget? content,
  bool leading = false,
  bool trailing = false,
}) {
  return SizedBox(
    width: _probeWidth,
    child: BaseListItem(
      onTap: onTap,
      leading: leading ? const Icon(Icons.folder, size: _leadingSize) : null,
      content: content ?? const Text('Row'),
      trailing: trailing
          ? const Icon(Icons.chevron_right, size: _leadingSize)
          : null,
    ),
  );
}

/// The [Ink] that paints the row's tile on either side: `ListTile` paints its
/// `tileColor` with one (list_tile.dart:999-1003) and so does BaseListItem.
Decoration _tileDecoration(WidgetTester tester, Finder row) {
  return tester
      .widget<Ink>(find.descendant(of: row, matching: find.byType(Ink)).first)
      .decoration!;
}

/// Corner radius of a tile decoration, whichever way it is expressed: a
/// BoxDecoration's borderRadius (null meaning square) or a ShapeDecoration's
/// rounded shape.
double _decorationRadius(Decoration decoration) {
  if (decoration is BoxDecoration) {
    final BorderRadiusGeometry? radius = decoration.borderRadius;
    if (radius == null) {
      return 0.0;
    }
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  if (decoration is ShapeDecoration) {
    final ShapeBorder shape = decoration.shape;
    if (shape is RoundedRectangleBorder) {
      final BorderRadiusGeometry radius = shape.borderRadius;
      if (radius is BorderRadius) {
        return radius.topLeft.x;
      }
    }
    // A plain Border is the square shape a ListTile falls back to when no
    // theme supplies one (list_tile.dart:1001), i.e. a zero corner.
    if (shape is Border || shape is BorderDirectional) {
      return 0.0;
    }
  }
  fail('Cannot read a corner radius from $decoration.');
}

/// The tile's own fill, with an unset fill reported as fully transparent so
/// both sides describe "no tile color" identically.
Color _decorationColor(Decoration decoration) {
  if (decoration is BoxDecoration) {
    return decoration.color ?? const Color(0x00000000);
  }
  if (decoration is ShapeDecoration) {
    return decoration.color ?? const Color(0x00000000);
  }
  fail('Cannot read a fill color from $decoration.');
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// Distance from the row's leading edge to the start of its title text.
double _startInset(WidgetTester tester, Finder row) {
  return tester.getTopLeft(find.text('Row')).dx - tester.getTopLeft(row).dx;
}

/// Distance from the end of the trailing widget to the row's trailing edge.
double _endInset(WidgetTester tester, Finder row) {
  return tester.getTopRight(row).dx -
      tester.getTopRight(find.byIcon(Icons.chevron_right)).dx;
}

/// Half the height the row adds on top of a content block that is taller than
/// the minimum tile height — i.e. the vertical padding that really applies.
double _verticalPadding(WidgetTester tester, Finder row, double contentHeight) {
  return (tester.getSize(row).height - contentHeight) / 2;
}

/// Gap between the leading glyph and the title.
double _leadingGap(WidgetTester tester) {
  return tester.getTopLeft(find.text('Row')).dx -
      tester.getTopRight(find.byIcon(Icons.folder)).dx;
}

/// The icon theme the row imposes on its leading slot.
Color? _leadingIconColor(WidgetTester tester) {
  return IconTheme.of(tester.element(find.byIcon(Icons.folder))).color;
}

void main() {
  group('tile geometry', () {
    testWidgets('minimum tile height', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final double expected = tester.getSize(find.byType(ListTile)).height;

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final double measured = tester.getSize(find.byType(BaseListItem)).height;

      expectConformant(
        token: 'BaseListItem.minTileHeight',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('leading content inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final double expected = _startInset(tester, find.byType(ListTile));

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final double measured = _startInset(tester, find.byType(BaseListItem));

      expectConformant(
        token: 'BaseListItem.contentPadding.start',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('trailing content inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}, trailing: true));
      final double expected = _endInset(tester, find.byType(ListTile));

      await pumpConformance(tester, _baseItem(onTap: () {}, trailing: true));
      final double measured = _endInset(tester, find.byType(BaseListItem));

      expectConformant(
        token: 'BaseListItem.contentPadding.end',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('vertical padding (LIST-001)', (WidgetTester tester) async {
      // A content block taller than the 56 dp minimum makes the minimum stop
      // binding, so what the row adds on top of it IS its vertical padding.
      const double contentHeight = 100.0;
      await pumpConformance(
        tester,
        _oracleTile(
          onTap: () {},
          title: const SizedBox(height: contentHeight),
        ),
      );
      final double expected = _verticalPadding(
        tester,
        find.byType(ListTile),
        contentHeight,
      );

      await pumpConformance(
        tester,
        _baseItem(
          onTap: () {},
          content: const SizedBox(height: contentHeight),
        ),
      );
      final double measured = _verticalPadding(
        tester,
        find.byType(BaseListItem),
        contentHeight,
      );

      expectConformant(
        token: 'BaseListItem.contentPadding.vertical',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('gap after the leading slot', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}, leading: true));
      final double expected = _leadingGap(tester);

      await pumpConformance(tester, _baseItem(onTap: () {}, leading: true));
      final double measured = _leadingGap(tester);

      expectConformant(
        token: 'BaseListItem.leadingGap',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('tile shape', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final double expected = _decorationRadius(
        _tileDecoration(tester, find.byType(ListTile)),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final double measured = _decorationRadius(
        _tileDecoration(tester, find.byType(BaseListItem)),
      );

      expectConformant(
        token: 'BaseListItem.shape',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
      );
    });
  });

  group('surface and content roles', () {
    testWidgets('resting tile color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _decorationColor(_tileDecoration(tester, find.byType(ListTile))),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseListItem.tileColor',
        component: 'BaseListItem',
        measured: colorRoleName(
          scheme,
          _decorationColor(_tileDecoration(tester, find.byType(BaseListItem))),
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('title text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, 'Row'),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      theme = _theme(tester);

      expectConformant(
        token: 'BaseListItem.titleTextStyle',
        component: 'BaseListItem',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Row')),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('leading icon color role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}, leading: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final Color? oracleColor = _leadingIconColor(tester);
      expect(oracleColor, isNotNull);
      final String expected = colorRoleName(scheme, oracleColor!);

      await pumpConformance(tester, _baseItem(onTap: () {}, leading: true));
      scheme = _theme(tester).colorScheme;
      final Color? measuredColor = _leadingIconColor(tester);
      expect(measuredColor, isNotNull);

      expectConformant(
        token: 'BaseListItem.iconColor',
        component: 'BaseListItem',
        measured: colorRoleName(scheme, measuredColor!),
        expected: expected,
        unit: '',
      );
    });
  });

  group('state layers', () {
    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await hoverStateLayer(tester, find.byType(ListTile)),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(tester, find.byType(BaseListItem)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseListItem.overlay.hovered',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await pressStateLayer(tester, find.byType(ListTile)),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await pressStateLayer(tester, find.byType(BaseListItem)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseListItem.overlay.pressed',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('focus is the collection\'s, not the row\'s (LIST-002)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleTile(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      await pumpConformance(tester, _baseItem(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      expectConformant(
        token: 'BaseListItem.overlay.focused',
        component: 'BaseListItem',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('hover stays visible on a selected row', (
      WidgetTester tester,
    ) async {
      // The regression this guards: a hover painted as a container-color swap
      // is invisible once the row carries an opaque selection color.
      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseListItem(
            isSelected: true,
            onTap: () {},
            content: const Text('Row'),
          ),
        ),
      );
      expect(
        describeStateLayer(
          tester,
          await hoverStateLayer(tester, find.byType(BaseListItem)),
        ),
        isNot('none'),
      );
    });
  });

  group('interaction', () {
    testWidgets('a row that cannot be selected does not react', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseListItem(
            isSelectable: false,
            onTap: () => taps++,
            content: const Text('Row'),
          ),
        ),
      );
      await tester.tap(find.byType(BaseListItem), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      expect(
        describeStateLayer(
          tester,
          await hoverStateLayer(tester, find.byType(BaseListItem)),
        ),
        'none',
      );
    });

    testWidgets('the row meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseItem(onTap: () {}));
      expect(
        tester.getSize(find.byType(BaseListItem)).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
