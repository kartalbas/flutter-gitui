/// Material 3 conformance suite for BaseCard
/// (lib/shared/components/base_card.dart).
///
/// BaseCard is the app's **outlined card**: flat, on a tonal container,
/// behind a 1 px `outlineVariant` border. Unlike the button classes, `Card`
/// exposes no public defaults oracle (`defaultStyleOf` exists only on
/// ButtonStyleButton), so the ruler here is the real SDK widget: every token
/// is measured twice with the same probe, once on `Card.outlined` and once on
/// BaseCard, both pumped through [pumpConformance]. Fonts, device pixel ratio
/// and visual density are therefore identical on both sides and cancel out of
/// the comparison.
///
/// State layers are painted ink rather than widget properties, so they are
/// diffed out of the ink paint stream ([hoverStateLayer] and friends), the
/// same idiom Flutter's own test/material/ink_well_test.dart uses.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so a width-dependent measurement (the
/// margin probe) compares like with like.
const double _probeWidth = 300.0;

/// The Material 3 oracle: a stock outlined card with an interactive child,
/// so its state layers can be driven exactly like BaseCard's.
///
/// `Card` is banned from UI code by the design system's `avoid_card` rule.
/// Here it is not shipped UI but the ruler this suite measures against, which
/// is why the rule is suppressed at this single construction.
Widget _oracleCard({VoidCallback? onTap, Widget? child}) {
  return SizedBox(
    width: _probeWidth,
    // ignore: avoid_card
    child: Card.outlined(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 100, child: child),
      ),
    ),
  );
}

Widget _baseCard({VoidCallback? onTap, Widget? child}) {
  return SizedBox(
    width: _probeWidth,
    child: BaseCard(
      onTap: onTap,
      content: SizedBox(height: 100, child: child),
    ),
  );
}

/// The Material that paints the oracle card's visual container.
Finder _oracleContainer() =>
    find.descendant(of: find.byType(Card), matching: find.byType(Material));

/// The decorated box that paints BaseCard's visual container.
Finder _baseContainer() => find
    .descendant(of: find.byType(BaseCard), matching: find.byType(Container))
    .first;

BoxDecoration _baseDecoration(WidgetTester tester) =>
    tester.widget<Container>(_baseContainer()).decoration! as BoxDecoration;

/// Corner radius of a rounded [ShapeBorder], the only shape either side uses.
double _cornerRadius(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  fail('Expected a RoundedRectangleBorder, got $shape.');
}

/// The border side a card paints, whichever way it expresses it.
BorderSide _oracleSide(WidgetTester tester) {
  final ShapeBorder? shape = tester.widget<Material>(_oracleContainer()).shape;
  if (shape is RoundedRectangleBorder) {
    return shape.side;
  }
  fail('Expected the oracle card to carry a rounded shape, got $shape.');
}

/// Distance the painted container is inset from the widget's own layout box —
/// the card's margin. `Card` reserves it around its Material; BaseCard has no
/// wrapper, so the two boxes coincide.
double _margin(WidgetTester tester, Finder outer, Finder inner) {
  return (tester.getSize(outer).height - tester.getSize(inner).height) / 2;
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

/// The rendered style of the text that actually paints, so DefaultTextStyle
/// propagation is part of the measurement.
TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

void main() {
  group('container geometry', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = _cornerRadius(
        tester.widget<Material>(_oracleContainer()).shape,
      );

      await pumpConformance(tester, _baseCard());
      final BorderRadius? radius =
          _baseDecoration(tester).borderRadius as BorderRadius?;
      expect(radius, isNotNull, reason: 'BaseCard must round its container');

      expectConformant(
        token: 'BaseCard.shape',
        component: 'BaseCard',
        measured: radius!.topLeft.x,
        expected: expected,
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = tester
          .widget<Material>(_oracleContainer())
          .elevation;

      await pumpConformance(tester, _baseCard());
      final double measured = tester
          .widget<Material>(
            find.descendant(
              of: find.byType(BaseCard),
              matching: find.byType(Material),
            ),
          )
          .elevation;

      expectConformant(
        token: 'BaseCard.elevation',
        component: 'BaseCard',
        measured: measured,
        expected: expected,
      );
    });

    testWidgets('margin (CARD-002)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      final double expected = _margin(
        tester,
        find.byType(Card),
        _oracleContainer(),
      );

      await pumpConformance(tester, _baseCard());
      final double measured = _margin(
        tester,
        find.byType(BaseCard),
        _baseContainer(),
      );

      expectConformant(
        token: 'BaseCard.margin',
        component: 'BaseCard',
        measured: measured,
        expected: expected,
      );
    });
  });

  group('surface and outline roles', () {
    testWidgets('container color (CARD-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        tester.widget<Material>(_oracleContainer()).color!,
      );

      await pumpConformance(tester, _baseCard());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseCard.containerColor',
        component: 'BaseCard',
        measured: colorRoleName(scheme, _baseDecoration(tester).color!),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('border color and width', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard());
      ColorScheme scheme = _theme(tester).colorScheme;
      final BorderSide oracleSide = _oracleSide(tester);
      final String expectedColor = colorRoleName(scheme, oracleSide.color);
      final double expectedWidth = oracleSide.width;

      await pumpConformance(tester, _baseCard());
      scheme = _theme(tester).colorScheme;
      final BorderSide measuredSide =
          (_baseDecoration(tester).border! as Border).top;

      expectConformant(
        token: 'BaseCard.borderColor',
        component: 'BaseCard',
        measured: colorRoleName(scheme, measuredSide.color),
        expected: expectedColor,
        unit: '',
      );
      expectConformant(
        token: 'BaseCard.borderWidth',
        component: 'BaseCard',
        measured: measuredSide.width,
        expected: expectedWidth,
      );
    });
  });

  group('typography', () {
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

      await pumpConformance(tester, _baseCard(child: const Text('Typography')));
      theme = _theme(tester);

      expectConformant(
        token: 'BaseCard.contentTextStyle',
        component: 'BaseCard',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Typography')),
        expected: expected,
        unit: '',
      );
    });
  });

  group('state layers', () {
    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await hoverStateLayer(tester, find.byType(Card)),
      );

      await pumpConformance(tester, _baseCard(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(tester, find.byType(BaseCard)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseCard.overlay.hovered',
        component: 'BaseCard',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleCard(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await pressStateLayer(tester, find.byType(Card)),
      );

      await pumpConformance(tester, _baseCard(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await pressStateLayer(tester, find.byType(BaseCard)),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseCard.overlay.pressed',
        component: 'BaseCard',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('focus is the collection\'s, not the card\'s (CARD-003)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleCard(onTap: () {}));
      final String expected = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      await pumpConformance(tester, _baseCard(onTap: () {}));
      final String measured = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      expectConformant(
        token: 'BaseCard.overlay.focused',
        component: 'BaseCard',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });
  });

  group('selection treatment', () {
    testWidgets('hover stays visible on a selected card', (
      WidgetTester tester,
    ) async {
      // The regression this guards: a hover painted as a container-color swap
      // is invisible once the container carries an opaque selection color.
      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseCard(
            isSelected: true,
            onTap: () {},
            content: const SizedBox(height: 100),
          ),
        ),
      );
      expect(
        describeStateLayer(
          tester,
          await hoverStateLayer(tester, find.byType(BaseCard)),
        ),
        isNot('none'),
      );
    });

    testWidgets('a card that cannot be selected does not react', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseCard(
            isSelectable: false,
            onTap: () => taps++,
            content: const SizedBox(height: 100),
          ),
        ),
      );
      await tester.tap(find.byType(BaseCard), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      expect(
        describeStateLayer(
          tester,
          await hoverStateLayer(tester, find.byType(BaseCard)),
        ),
        'none',
      );
    });
  });

  group('tap target', () {
    testWidgets('a tappable card meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseCard(onTap: () {}));
      expect(
        tester.getSize(find.byType(BaseCard)).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
