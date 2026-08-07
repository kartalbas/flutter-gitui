/// Material 3 conformance suite for the badge family
/// (lib/shared/components/base_badge.dart).
///
/// The oracle is a real `Badge`, pumped through [pumpConformance] and read with
/// the same probes as each component. `Badge` has no `defaultStyleOf` seam
/// (`defaultStyleOf` exists only on `ButtonStyleButton`), so the generated
/// `_BadgeDefaultsM3` (flutter/lib/src/material/badge.dart:484-517) is reached
/// by measuring the widget it configures.
///
/// Material 3 has exactly one badge and this app has four, which is the
/// deviation every entry below is a consequence of:
///
///   * **`BaseBadge`** is a status pill — "ahead 3", "conflict", "draft" —
///     placed inline in toolbars and rows. It is the furthest from M3's badge
///     and carries the most registered differences.
///   * **`BaseNumericBadge`** is the count badge, the closest analogue of M3's
///     labelled badge, and conforms on colour.
///   * **`BaseIconBadge`** delegates to the SDK `Badge`, so its alignment and
///     offset are M3's by construction — which is exactly what the two
///     placement tokens below prove rather than assume.
///   * **`BaseDotBadge`** is M3's unlabelled small badge.
///
/// One naming note. [colorRoleName] names a colour after the first scheme role
/// carrying that exact value, and in this app's scheme `onError` and
/// `onPrimary` are the same white, so M3's `onError` is reported as
/// `onPrimary`. The measurement is unaffected — both sides go through the same
/// descriptor — but a register entry reading `spec_value: onPrimary` means
/// "M3's onError, under a scheme where the two coincide".
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_badge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Two characters, so the label is always wider than the badge's own minimum
/// width and every horizontal measurement is padding rather than a floor.
const String _label = '12';

/// The child a placement measurement is taken against, sized so the badge has
/// something unambiguous to hang off.
const Key _hostKey = Key('the widget the badge marks');
const Widget _host = SizedBox(
  key: _hostKey,
  width: 40,
  height: 40,
  child: Icon(Icons.circle),
);

/// The Material 3 oracle. `Badge` is banned from UI code by the design system's
/// `avoid_badge` rule; here it is not shipped UI but the ruler this suite
/// measures against, which is why the rule is suppressed at each construction.
Widget _oracleBadge() {
  // ignore: avoid_badge
  return const Badge(label: Text(_label));
}

Widget _oracleOverlayBadge() {
  // ignore: avoid_badge
  return const Badge(label: Text('4'), child: _host);
}

Widget _oracleDotBadge() {
  // ignore: avoid_badge
  return const Badge();
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

/// The decorated box a badge paints its container with. All four components and
/// the oracle express it as the single `Container` under their own root.
Finder _container(Finder badge) =>
    find.descendant(of: badge, matching: find.byType(Container)).first;

/// The container's fill colour, whichever decoration class carries it.
Color _containerColor(WidgetTester tester, Finder badge) {
  final Decoration? decoration = tester
      .widget<Container>(_container(badge))
      .decoration;
  if (decoration is ShapeDecoration) {
    return decoration.color!;
  }
  if (decoration is BoxDecoration) {
    return decoration.color!;
  }
  fail('Expected the badge container to carry a decoration, got $decoration.');
}

/// The container's shape as a comparable descriptor.
///
/// M3 draws its badge with a `StadiumBorder` and the app with a corner radius
/// or a `BoxShape`, so the two can only be compared by what they *render*: a
/// radius of at least half the height is a fully rounded end, which is what a
/// stadium is, and a fully rounded square is a circle however it was spelled.
/// Anything less rounded is reported in dp.
String _describeShape(WidgetTester tester, Finder badge) {
  final Decoration? decoration = tester
      .widget<Container>(_container(badge))
      .decoration;
  final Size size = tester.getSize(_container(badge));
  final String round = (size.width - size.height).abs() < 0.01
      ? 'circle'
      : 'stadium';
  if (decoration is ShapeDecoration) {
    final ShapeBorder shape = decoration.shape;
    if (shape is StadiumBorder || shape is CircleBorder) {
      return round;
    }
    return shape.toString();
  }
  if (decoration is BoxDecoration) {
    if (decoration.shape == BoxShape.circle) {
      return round;
    }
    final BorderRadiusGeometry? radius = decoration.borderRadius;
    if (radius is BorderRadius) {
      final double corner = radius.topLeft.x;
      return corner >= size.height / 2 - 0.01 ? round : '$corner dp';
    }
  }
  fail('Expected a describable badge shape, got $decoration.');
}

TextStyle _labelStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style!;
}

/// Horizontal padding as it really lands: half the difference between the
/// container and the label it holds, so a centred label reports the inset on
/// either side.
double _horizontalPadding(WidgetTester tester, Finder badge, String text) {
  return (tester.getSize(_container(badge)).width -
          tester.getSize(find.text(text)).width) /
      2;
}

/// Where an overlay badge sits relative to the widget it marks, as the corner
/// it hugs.
String _corner(Rect child, Rect badge) {
  final String vertical = badge.center.dy < child.center.dy ? 'top' : 'bottom';
  final String horizontal = badge.center.dx < child.center.dx ? 'Start' : 'End';
  return '$vertical$horizontal';
}

/// The badge's displacement from the marked widget's own top-left corner. Both
/// sides mark the identical host widget, so the two numbers are directly
/// comparable and describe alignment and offset together.
String _placement(WidgetTester tester) {
  final Rect child = tester.getRect(find.byKey(_hostKey));
  final Rect badge = tester.getRect(_container(find.byType(Badge)));
  return 'Offset(${badge.left - child.left}, ${badge.top - child.top})';
}

void main() {
  group('BaseBadge, the status pill', () {
    testWidgets('container height (BADGE-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      final double expected = tester.getSize(find.byType(Badge)).height;
      expect(
        expected,
        16.0,
        reason:
            'M3 gives a labelled badge a fixed largeSize of 16 dp '
            '(badge.dart:495); if the SDK moved, BADGE-001 has to be re-argued',
      );

      await pumpConformance(tester, const BaseBadge(label: _label));

      expectConformant(
        token: 'BaseBadge.containerHeight',
        component: 'BaseBadge',
        measured: tester.getSize(find.byType(BaseBadge)).height,
        expected: expected,
      );
    });

    testWidgets('shape', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      final String expected = _describeShape(tester, find.byType(Badge));

      await pumpConformance(tester, const BaseBadge(label: _label));

      expect(expected, 'stadium', reason: 'M3 badges are stadium-shaped');
      expectConformant(
        token: 'BaseBadge.shape',
        component: 'BaseBadge',
        measured: _describeShape(tester, find.byType(BaseBadge)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('horizontal padding (BADGE-002)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      final double expected = _horizontalPadding(
        tester,
        find.byType(Badge),
        _label,
      );

      await pumpConformance(tester, const BaseBadge(label: _label));

      expectConformant(
        token: 'BaseBadge.padding.horizontal',
        component: 'BaseBadge',
        measured: _horizontalPadding(tester, find.byType(BaseBadge), _label),
        expected: expected,
      );
    });

    testWidgets('label size (BADGE-003)', (WidgetTester tester) async {
      // Measured as a size rather than through describeTextRole, because the
      // badge's three sizes step the label off the type scale's own steps: the
      // style is labelSmall's, with the size replaced per badge size. The role
      // it is derived from is asserted separately, below.
      await pumpConformance(tester, _oracleBadge());
      final double expected = _labelStyle(tester, _label).fontSize!;

      await pumpConformance(tester, const BaseBadge(label: _label));

      expectConformant(
        token: 'BaseBadge.labelFontSize',
        component: 'BaseBadge',
        measured: _labelStyle(tester, _label).fontSize!,
        expected: expected,
      );
    });

    testWidgets('the label keeps the labelSmall role it is stepped from', (
      WidgetTester tester,
    ) async {
      // What makes BADGE-003 a step rather than an invented style: the letter
      // spacing and the line-height ratio are still labelSmall's, so the badge
      // label remains that role at a size of its own, the same way the app's
      // font-size setting scales every role.
      await pumpConformance(tester, const BaseBadge(label: _label));
      final TextStyle labelSmall = _theme(tester).textTheme.labelSmall!;
      final TextStyle measured = _labelStyle(tester, _label);
      expect(measured.letterSpacing, labelSmall.letterSpacing);
      expect(measured.height, labelSmall.height);
    });

    testWidgets('container colour (BADGE-004)', (WidgetTester tester) async {
      // The danger variant is the fair comparison: M3's badge has exactly one
      // colour pair, and it is the error pair this variant means.
      await pumpConformance(tester, _oracleBadge());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _containerColor(tester, find.byType(Badge)),
      );

      await pumpConformance(
        tester,
        const BaseBadge(label: _label, variant: BadgeVariant.danger),
      );
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseBadge.danger.containerColor',
        component: 'BaseBadge',
        measured: colorRoleName(
          scheme,
          _containerColor(tester, find.byType(BaseBadge)),
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('label colour (BADGE-005)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _labelStyle(tester, _label).color!,
      );

      await pumpConformance(
        tester,
        const BaseBadge(label: _label, variant: BadgeVariant.danger),
      );
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseBadge.danger.labelColor',
        component: 'BaseBadge',
        measured: colorRoleName(scheme, _labelStyle(tester, _label).color!),
        expected: expected,
        unit: '',
      );
    });
  });

  group('BaseNumericBadge, the count', () {
    testWidgets('container height (BADGE-006)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      final double expected = tester.getSize(find.byType(Badge)).height;

      await pumpConformance(tester, const BaseNumericBadge(count: 12));

      expectConformant(
        token: 'BaseNumericBadge.containerHeight',
        component: 'BaseNumericBadge',
        measured: tester.getSize(find.byType(BaseNumericBadge)).height,
        expected: expected,
      );
    });

    testWidgets('shape', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      final String expected = _describeShape(tester, find.byType(Badge));

      await pumpConformance(tester, const BaseNumericBadge(count: 12));

      expectConformant(
        token: 'BaseNumericBadge.shape',
        component: 'BaseNumericBadge',
        measured: _describeShape(tester, find.byType(BaseNumericBadge)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('container and label colour', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expectedContainer = colorRoleName(
        scheme,
        _containerColor(tester, find.byType(Badge)),
      );
      final String expectedLabel = colorRoleName(
        scheme,
        _labelStyle(tester, _label).color!,
      );

      await pumpConformance(
        tester,
        const BaseNumericBadge(count: 12, variant: BadgeVariant.danger),
      );
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseNumericBadge.danger.containerColor',
        component: 'BaseNumericBadge',
        measured: colorRoleName(
          scheme,
          _containerColor(tester, find.byType(BaseNumericBadge)),
        ),
        expected: expectedContainer,
        unit: '',
      );
      expectConformant(
        token: 'BaseNumericBadge.danger.labelColor',
        component: 'BaseNumericBadge',
        measured: colorRoleName(scheme, _labelStyle(tester, _label).color!),
        expected: expectedLabel,
        unit: '',
      );
    });

    testWidgets('label role (BADGE-007)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleBadge());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _labelStyle(tester, _label),
      );

      await pumpConformance(tester, const BaseNumericBadge(count: 12));
      theme = _theme(tester);

      expectConformant(
        token: 'BaseNumericBadge.labelTextStyle',
        component: 'BaseNumericBadge',
        measured: describeTextRole(theme, _labelStyle(tester, _label)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('it hugs its label inside a bounded box', (
      WidgetTester tester,
    ) async {
      // The regression this guards: the badge centred its label with a plain
      // `Center`, which expands to whatever maximum it is offered, so in any
      // bounded parent — a SizedBox, a table cell, a Center — a 20 dp count
      // badge grew to the size of the box.
      await pumpConformance(
        tester,
        const SizedBox(
          width: 400,
          height: 200,
          child: Center(child: BaseNumericBadge(count: 12)),
        ),
      );
      expect(tester.getSize(find.byType(BaseNumericBadge)).width, lessThan(60));
      expect(tester.getSize(find.byType(BaseNumericBadge)).height, 20);
    });
  });

  group('BaseIconBadge, the overlay', () {
    testWidgets('the corner it hugs', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleOverlayBadge());
      final String expected = _corner(
        tester.getRect(find.byKey(_hostKey)),
        tester.getRect(_container(find.byType(Badge))),
      );

      await pumpConformance(
        tester,
        const BaseIconBadge(count: 4, child: _host),
      );

      expect(expected, 'topEnd', reason: 'M3 anchors a badge to the top end');
      expectConformant(
        token: 'BaseIconBadge.alignment',
        component: 'BaseIconBadge',
        measured: _corner(
          tester.getRect(find.byKey(_hostKey)),
          tester.getRect(_container(find.byType(Badge))),
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('its displacement from the marked widget', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleOverlayBadge());
      final String expected = _placement(tester);

      await pumpConformance(
        tester,
        const BaseIconBadge(count: 4, child: _host),
      );

      expectConformant(
        token: 'BaseIconBadge.offset',
        component: 'BaseIconBadge',
        measured: _placement(tester),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('label role (BADGE-008)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleOverlayBadge());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(theme, _labelStyle(tester, '4'));

      await pumpConformance(
        tester,
        const BaseIconBadge(count: 4, child: _host),
      );
      theme = _theme(tester);

      expectConformant(
        token: 'BaseIconBadge.labelTextStyle',
        component: 'BaseIconBadge',
        measured: describeTextRole(theme, _labelStyle(tester, '4')),
        expected: expected,
        unit: '',
      );
    });
  });

  group('BaseDotBadge, the unlabelled marker', () {
    testWidgets('size (BADGE-009)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDotBadge());
      final double expected = tester.getSize(find.byType(Badge)).height;
      expect(
        expected,
        6.0,
        reason:
            'M3 gives an unlabelled badge a smallSize of 6 dp '
            '(badge.dart:494)',
      );

      await pumpConformance(tester, const BaseDotBadge());

      expectConformant(
        token: 'BaseDotBadge.size',
        component: 'BaseDotBadge',
        measured: tester.getSize(find.byType(BaseDotBadge)).height,
        expected: expected,
      );
    });

    testWidgets('shape', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDotBadge());
      final String expected = _describeShape(tester, find.byType(Badge));

      await pumpConformance(tester, const BaseDotBadge());

      expectConformant(
        token: 'BaseDotBadge.shape',
        component: 'BaseDotBadge',
        measured: _describeShape(tester, find.byType(BaseDotBadge)),
        expected: expected,
        unit: '',
      );
    });
  });
}
