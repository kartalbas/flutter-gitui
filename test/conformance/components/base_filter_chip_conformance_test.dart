/// Material 3 conformance suite for the chip family
/// (lib/shared/components/base_filter_chip.dart): BaseFilterChip,
/// BaseChoiceGroup and BaseActionChip.
///
/// Each of the three is measured against the SDK class it is built on —
/// `FilterChip`, `ChoiceChip` and `ActionChip` — pumped through
/// [pumpConformance] and read with the same probes, so fonts, device pixel
/// ratio and visual density are identical on both sides and cancel out.
///
/// The single-choice component is a *group* now, so its oracle comparison is
/// made through a group holding exactly one option: the group is what the app
/// constructs, the chip inside it is what Material draws, and one option is
/// what makes the two directly comparable to a lone `ChoiceChip`. The token
/// ids stay `BaseChoiceChip.*` — that is the name the checked-in
/// `test/conformance/support/token_manifest.dart` and the CHIP-003 entry in
/// `docs/deviation_register.yaml` give this element, and `expectConformant`
/// rejects any token those files do not list.
///
/// A chip paints its container as an `Ink` with a `ShapeDecoration`
/// (Flutter 3.44.4 packages/flutter/lib/src/material/chip.dart:1432-1438), so
/// its shape, outline and fill are all read from that one decoration —
/// including on the oracle, which passes none of them and lets the generated
/// defaults resolve.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_filter_chip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

const String _label = 'Chip';

/// The M3 oracles.
///
/// `FilterChip`, `ChoiceChip` and `ActionChip` are banned from UI code by the
/// design system's `avoid_filter_chip`, `avoid_choice_chip` and
/// `avoid_action_chip` rules. Here they are not shipped UI but the rulers this
/// suite measures against, which is why the rules are suppressed at these
/// constructions.
Widget _oracleFilterChip({bool selected = false, bool icon = false}) {
  // ignore: avoid_filter_chip
  return FilterChip(
    selected: selected,
    onSelected: (bool value) {},
    label: const Text(_label),
    avatar: icon ? const Icon(Icons.star) : null,
  );
}

Widget _oracleChoiceChip({bool selected = false}) {
  // ignore: avoid_choice_chip
  return ChoiceChip(
    selected: selected,
    onSelected: (bool value) {},
    label: const Text(_label),
  );
}

Widget _oracleActionChip() {
  // ignore: avoid_action_chip
  return ActionChip(onPressed: () {}, label: const Text(_label));
}

Widget _baseFilterChip({bool selected = false, bool icon = false}) {
  return BaseFilterChip(
    label: _label,
    selected: selected,
    icon: icon ? Icons.star : null,
    onSelected: (bool value) {},
  );
}

/// A single-option [BaseChoiceGroup], which is how the app's single-choice
/// component now renders one chip. `selected: null` is the group's
/// "nothing chosen yet" state and is what makes the unselected case
/// expressible without a second option changing the geometry being measured.
Widget _baseChoiceChip({bool selected = false}) {
  return BaseChoiceGroup<int>(
    options: const <ChoiceOption<int>>[
      ChoiceOption<int>(value: 0, label: _label),
    ],
    selected: selected ? 0 : null,
    onSelected: (int value) {},
  );
}

Widget _baseActionChip() {
  return BaseActionChip(label: _label, onPressed: () {});
}

/// Every chip, ours and the SDK's, renders through one `RawChip`, which is the
/// box whose geometry both sides are compared on.
Finder _chip() => find.byType(RawChip);

/// The `Ink` that paints the chip's container.
ShapeDecoration _decoration(WidgetTester tester) {
  return tester
          .widget<Ink>(
            find.descendant(of: _chip(), matching: find.byType(Ink)).first,
          )
          .decoration!
      as ShapeDecoration;
}

RoundedRectangleBorder _shape(WidgetTester tester) {
  final ShapeBorder shape = _decoration(tester).shape;
  if (shape is RoundedRectangleBorder) {
    return shape;
  }
  fail('Expected a RoundedRectangleBorder chip shape, got $shape.');
}

/// The chip's fill, with an unset fill reported as fully transparent so both
/// sides describe "no container color" identically.
Color _fill(WidgetTester tester) =>
    _decoration(tester).color ?? const Color(0x00000000);

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// Distance from the chip's leading edge to the start of its label.
double _labelInset(WidgetTester tester) {
  return tester.getTopLeft(find.text(_label)).dx -
      tester.getTopLeft(_chip()).dx;
}

/// Gap between the leading glyph and the label.
double _avatarGap(WidgetTester tester) {
  return tester.getTopLeft(find.text(_label)).dx -
      tester.getTopRight(find.byIcon(Icons.star)).dx;
}

void main() {
  group('BaseFilterChip geometry', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      final double expected =
          (_shape(tester).borderRadius as BorderRadius).topLeft.x;

      await pumpConformance(tester, _baseFilterChip());

      expectConformant(
        token: 'BaseFilterChip.shape',
        component: 'BaseFilterChip',
        measured: (_shape(tester).borderRadius as BorderRadius).topLeft.x,
        expected: expected,
      );
    });

    testWidgets('container height', (WidgetTester tester) async {
      // The regression this guards: forcing `MaterialTapTargetSize.shrinkWrap`
      // and `VisualDensity.compact` used to shrink the chip's box to 30 dp,
      // 18 dp under the M3 chip and well under the minimum interactive
      // dimension — while the app's own icon buttons keep the padded tap
      // target and only shrink what is painted.
      await pumpConformance(tester, _oracleFilterChip());
      final double expected = tester.getSize(_chip()).height;

      await pumpConformance(tester, _baseFilterChip());
      final double measured = tester.getSize(_chip()).height;

      expectConformant(
        token: 'BaseFilterChip.containerHeight',
        component: 'BaseFilterChip',
        measured: measured,
        expected: expected,
      );
      expect(measured, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    testWidgets('label inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      final double expected = _labelInset(tester);

      await pumpConformance(tester, _baseFilterChip());

      expectConformant(
        token: 'BaseFilterChip.labelInset',
        component: 'BaseFilterChip',
        measured: _labelInset(tester),
        expected: expected,
      );
    });

    testWidgets('leading glyph size and gap', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip(icon: true));
      final double expectedSize = effectiveIconSize(
        tester,
        find.byIcon(Icons.star),
      );
      final double expectedGap = _avatarGap(tester);

      await pumpConformance(tester, _baseFilterChip(icon: true));

      expectConformant(
        token: 'BaseFilterChip.avatar.size',
        component: 'BaseFilterChip',
        measured: effectiveIconSize(tester, find.byIcon(Icons.star)),
        expected: expectedSize,
      );
      expectConformant(
        token: 'BaseFilterChip.avatarGap',
        component: 'BaseFilterChip',
        measured: _avatarGap(tester),
        expected: expectedGap,
      );
    });
  });

  group('BaseFilterChip container and outline', () {
    testWidgets('unselected outline', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = describeBorderSide(scheme, _shape(tester).side);

      await pumpConformance(tester, _baseFilterChip());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.unselected.border',
        component: 'BaseFilterChip',
        measured: describeBorderSide(scheme, _shape(tester).side),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('selected outline (CHIP-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip(selected: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = describeBorderSide(scheme, _shape(tester).side);

      await pumpConformance(tester, _baseFilterChip(selected: true));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.selected.border',
        component: 'BaseFilterChip',
        measured: describeBorderSide(scheme, _shape(tester).side),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('unselected container color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(scheme, _fill(tester));

      await pumpConformance(tester, _baseFilterChip());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.unselected.containerColor',
        component: 'BaseFilterChip',
        measured: colorRoleName(scheme, _fill(tester)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('selected container color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip(selected: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(scheme, _fill(tester));

      await pumpConformance(tester, _baseFilterChip(selected: true));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.selected.containerColor',
        component: 'BaseFilterChip',
        measured: colorRoleName(scheme, _fill(tester)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('width added by selection (CHIP-002)', (
      WidgetTester tester,
    ) async {
      // The checkmark is painted by the chip's render object, not built as a
      // widget, so it is measured by what it costs: the width selecting a chip
      // adds. M3 slides a check in front of the label and the chip grows by
      // 20 dp; ours keeps one width, which is why a filter bar does not reflow
      // when the user toggles a filter.
      // Each selected pump is settled: a chip animates its selection over
      // 195 ms (chip.dart, `_kSelectDuration`), and re-pumping the same widget
      // type updates the existing element rather than rebuilding it, so the
      // checkmark would still be half a frame wide.
      await pumpConformance(tester, _oracleFilterChip());
      final double oracleUnselected = tester.getSize(_chip()).width;
      await pumpConformance(tester, _oracleFilterChip(selected: true));
      await tester.pumpAndSettle();
      final double expected = tester.getSize(_chip()).width - oracleUnselected;

      await pumpConformance(tester, _baseFilterChip());
      final double baseUnselected = tester.getSize(_chip()).width;
      await pumpConformance(tester, _baseFilterChip(selected: true));
      await tester.pumpAndSettle();
      final double measured = tester.getSize(_chip()).width - baseUnselected;

      expect(
        expected,
        greaterThan(0),
        reason: 'the oracle must widen when it shows its checkmark',
      );
      expectConformant(
        token: 'BaseFilterChip.selected.widthDelta',
        component: 'BaseFilterChip',
        measured: measured,
        expected: expected,
      );
    });
  });

  group('BaseFilterChip typography', () {
    testWidgets('label text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, _label),
      );

      await pumpConformance(tester, _baseFilterChip());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseFilterChip.labelTextStyle',
        component: 'BaseFilterChip',
        measured: describeTextRole(theme, _renderedStyle(tester, _label)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('unselected label color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _renderedStyle(tester, _label)!.color!,
      );

      await pumpConformance(tester, _baseFilterChip());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.unselected.labelColor',
        component: 'BaseFilterChip',
        measured: colorRoleName(scheme, _renderedStyle(tester, _label)!.color!),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('selected label color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip(selected: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _renderedStyle(tester, _label)!.color!,
      );

      await pumpConformance(tester, _baseFilterChip(selected: true));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseFilterChip.selected.labelColor',
        component: 'BaseFilterChip',
        measured: colorRoleName(scheme, _renderedStyle(tester, _label)!.color!),
        expected: expected,
        unit: '',
      );
    });
  });

  group('BaseFilterChip state layers', () {
    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      final String expected = describeStateLayer(
        tester,
        await hoverStateLayer(tester, _chip()),
      );

      await pumpConformance(tester, _baseFilterChip());
      final String measured = describeStateLayer(
        tester,
        await hoverStateLayer(tester, _chip()),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseFilterChip.overlay.hovered',
        component: 'BaseFilterChip',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleFilterChip());
      final String expected = describeStateLayer(
        tester,
        await pressStateLayer(tester, _chip()),
      );

      await pumpConformance(tester, _baseFilterChip());
      final String measured = describeStateLayer(
        tester,
        await pressStateLayer(tester, _chip()),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseFilterChip.overlay.pressed',
        component: 'BaseFilterChip',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('Tab reaches the chip and paints the focus layer', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleFilterChip());
      final String expected = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      await pumpConformance(tester, _baseFilterChip());
      final String measured = describeStateLayer(
        tester,
        await focusStateLayer(tester),
      );

      expect(expected, isNot('none'), reason: 'the oracle must paint a layer');
      expectConformant(
        token: 'BaseFilterChip.overlay.focused',
        component: 'BaseFilterChip',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });
  });

  group('BaseChoiceGroup, measured on the chip Material draws per option', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleChoiceChip());
      final double expected =
          (_shape(tester).borderRadius as BorderRadius).topLeft.x;

      await pumpConformance(tester, _baseChoiceChip());

      expectConformant(
        token: 'BaseChoiceChip.shape',
        component: 'BaseChoiceChip',
        measured: (_shape(tester).borderRadius as BorderRadius).topLeft.x,
        expected: expected,
      );
    });

    testWidgets('container height', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleChoiceChip());
      final double expected = tester.getSize(_chip()).height;

      await pumpConformance(tester, _baseChoiceChip());
      final double measured = tester.getSize(_chip()).height;

      expectConformant(
        token: 'BaseChoiceChip.containerHeight',
        component: 'BaseChoiceChip',
        measured: measured,
        expected: expected,
      );
      expect(measured, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    testWidgets('label text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleChoiceChip());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, _label),
      );

      await pumpConformance(tester, _baseChoiceChip());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseChoiceChip.labelTextStyle',
        component: 'BaseChoiceChip',
        measured: describeTextRole(theme, _renderedStyle(tester, _label)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('selected outline (CHIP-003)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleChoiceChip(selected: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = describeBorderSide(scheme, _shape(tester).side);

      await pumpConformance(tester, _baseChoiceChip(selected: true));
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseChoiceChip.selected.border',
        component: 'BaseChoiceChip',
        measured: describeBorderSide(scheme, _shape(tester).side),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('it is a choice chip, not a filter chip', (
      WidgetTester tester,
    ) async {
      // Single-select is what M3 calls a choice chip. A skin that maps this
      // component onto another design language has to be told which of the two
      // it is, and the only place that information lives is the class it
      // builds.
      await pumpConformance(tester, _baseChoiceChip());
      expect(find.byType(ChoiceChip), findsOneWidget);
    });

    testWidgets('it renders one chip per option', (WidgetTester tester) async {
      // The group is the component; the chips are what Material makes of it.
      // This is the assertion that fails if the group ever stops rendering the
      // options it was given, which the per-option measurements above cannot
      // see because they only ever pump one option.
      await pumpConformance(
        tester,
        BaseChoiceGroup<int>(
          options: const <ChoiceOption<int>>[
            ChoiceOption<int>(value: 0, label: 'one'),
            ChoiceOption<int>(value: 1, label: 'two'),
            ChoiceOption<int>(value: 2, label: 'three'),
          ],
          selected: 1,
          onSelected: (int value) {},
        ),
      );
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .map((ChoiceChip chip) => chip.selected)
            .toList(),
        <bool>[false, true, false],
        reason: 'exactly the option whose value equals `selected` is chosen',
      );
    });

    testWidgets('re-choosing the chosen option reports nothing', (
      WidgetTester tester,
    ) async {
      // A chip reports the state it would flip to, so tapping the chosen
      // option arrives as `false`. "Exactly one" is what the group promises,
      // and there is no gesture that would restore the choice afterwards, so
      // the group must swallow that report rather than pass on a de-selection
      // its callers would each have to filter out again.
      final List<int> chosen = <int>[];
      await pumpConformance(
        tester,
        BaseChoiceGroup<int>(
          options: const <ChoiceOption<int>>[
            ChoiceOption<int>(value: 0, label: 'one'),
            ChoiceOption<int>(value: 1, label: 'two'),
          ],
          selected: 0,
          onSelected: chosen.add,
        ),
      );

      await tester.tap(find.text('one'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);

      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(chosen, <int>[1]);
    });
  });

  group('BaseActionChip', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleActionChip());
      final double expected =
          (_shape(tester).borderRadius as BorderRadius).topLeft.x;

      await pumpConformance(tester, _baseActionChip());

      expectConformant(
        token: 'BaseActionChip.shape',
        component: 'BaseActionChip',
        measured: (_shape(tester).borderRadius as BorderRadius).topLeft.x,
        expected: expected,
      );
    });

    testWidgets('container height', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleActionChip());
      final double expected = tester.getSize(_chip()).height;

      await pumpConformance(tester, _baseActionChip());
      final double measured = tester.getSize(_chip()).height;

      expectConformant(
        token: 'BaseActionChip.containerHeight',
        component: 'BaseActionChip',
        measured: measured,
        expected: expected,
      );
      expect(measured, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    testWidgets('label text role and color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleActionChip());
      ThemeData theme = _theme(tester);
      final TextStyle? oracleLabel = _renderedStyle(tester, _label);
      final String expectedRole = describeTextRole(theme, oracleLabel);
      final String expectedColor = colorRoleName(
        theme.colorScheme,
        oracleLabel!.color!,
      );

      await pumpConformance(tester, _baseActionChip());
      theme = _theme(tester);
      final TextStyle? measuredLabel = _renderedStyle(tester, _label);

      expectConformant(
        token: 'BaseActionChip.labelTextStyle',
        component: 'BaseActionChip',
        measured: describeTextRole(theme, measuredLabel),
        expected: expectedRole,
        unit: '',
      );
      expectConformant(
        token: 'BaseActionChip.labelColor',
        component: 'BaseActionChip',
        measured: colorRoleName(theme.colorScheme, measuredLabel!.color!),
        expected: expectedColor,
        unit: '',
      );
    });
  });

  group('tap target', () {
    testWidgets('every chip in the family meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(
        tester,
        Wrap(
          children: <Widget>[
            _baseFilterChip(),
            _baseChoiceChip(),
            _baseActionChip(),
          ],
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
