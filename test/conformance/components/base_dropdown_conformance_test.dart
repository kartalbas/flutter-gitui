/// Material 3 conformance suite for BaseDropdown
/// (lib/shared/components/base_dropdown.dart).
///
/// BaseDropdown *is* a `DropdownButtonFormField`, so the oracle is that same
/// widget carrying an `OutlineInputBorder` and nothing else, pumped through
/// [pumpConformance] and read with the same probes. What the suite measures is
/// therefore exactly the delta the component adds on top of the SDK widget:
/// the decoration it hands down.
///
/// As in the BaseTextField suite, the container, its outline and its corners
/// come out of the paint stream, because the border for the current widget
/// state is resolved inside the private `_InputDecoratorState` and is not
/// readable from any widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_dropdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so horizontal measurements compare like
/// with like.
const double _probeWidth = 320.0;

/// The single item both sides carry. One item keeps `find.text` unambiguous:
/// a dropdown button renders every item into its indexed stack.
const String _value = 'One';

/// The Material 3 oracle.
///
/// `DropdownButtonFormField` is banned from UI code by the design system's
/// `avoid_dropdown_button_form_field` rule. Here it is not shipped UI but the
/// ruler this suite measures against, which is why the rule is suppressed at
/// this single construction.
Widget _oracleDropdown({IconData? prefixIcon, String? label = 'Label'}) {
  return SizedBox(
    width: _probeWidth,
    // ignore: avoid_dropdown_button_form_field
    child: DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: 1,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        border: const OutlineInputBorder(),
      ),
      items: const <DropdownMenuItem<int>>[
        DropdownMenuItem<int>(value: 1, child: Text(_value)),
      ],
      onChanged: (int? value) {},
    ),
  );
}

Widget _baseDropdown({IconData? prefixIcon, String? label = 'Label'}) {
  return SizedBox(
    width: _probeWidth,
    child: BaseDropdown<int>(
      initialValue: 1,
      labelText: label,
      prefixIcon: prefixIcon,
      items: <BaseDropdownItem<int>>[
        BaseDropdownItem<int>(
          value: 1,
          builder: (BuildContext context) => const Text(_value),
        ),
      ],
      onChanged: (int? value) {},
    ),
  );
}

Finder _oracle() => find.byType(DropdownButtonFormField<int>);

Finder _base() => find.byType(BaseDropdown<int>);

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// Distance from the container's leading edge to the start of the selected
/// value — the horizontal content padding as it really lands.
double _startInset(WidgetTester tester, Finder field) {
  return tester.getTopLeft(find.text(_value)).dx -
      tester.getTopLeft(inputBorderPainter(field)).dx;
}

String _side(WidgetTester tester, Finder field) {
  return describeBorderSide(
    _theme(tester).colorScheme,
    inputBorderSide(tester, field),
  );
}

void main() {
  group('container geometry', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      // Measured without a label: a dropdown always carries a value, so a
      // label would always float, and `OutlineInputBorder` then draws its
      // outline as two gapped paths instead of one rounded rectangle
      // (input_border.dart, `_gapBorderPaths`) — with no corner to read.
      await pumpConformance(tester, _oracleDropdown(label: null));
      final double expected = inputCornerRadius(tester, _oracle());

      await pumpConformance(tester, _baseDropdown(label: null));

      expectConformant(
        token: 'BaseDropdown.shape',
        component: 'BaseDropdown',
        measured: inputCornerRadius(tester, _base()),
        expected: expected,
      );
    });

    testWidgets('container height', (WidgetTester tester) async {
      // The regression this guards: `isDense: true` plus a hand-written
      // content padding used to shrink the dropdown to 40 dp — under the
      // minimum interactive dimension, and 15 dp shorter than the
      // BaseTextField it stands next to in the same dialog.
      await pumpConformance(tester, _oracleDropdown());
      final double expected = inputContainerSize(tester, _oracle()).height;

      await pumpConformance(tester, _baseDropdown());
      final double measured = inputContainerSize(tester, _base()).height;

      expectConformant(
        token: 'BaseDropdown.containerHeight',
        component: 'BaseDropdown',
        measured: measured,
        expected: expected,
      );
      expect(measured, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    testWidgets('leading content inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown());
      final double expected = _startInset(tester, _oracle());

      await pumpConformance(tester, _baseDropdown());

      expectConformant(
        token: 'BaseDropdown.contentPadding.start',
        component: 'BaseDropdown',
        measured: _startInset(tester, _base()),
        expected: expected,
      );
    });
  });

  group('outline per state', () {
    testWidgets('resting', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown());
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseDropdown());

      expect(expected, isNot('none'), reason: 'the oracle must paint a border');
      expectConformant(
        token: 'BaseDropdown.enabled.border',
        component: 'BaseDropdown',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('focused', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown());
      await focusFirstWithTab(tester);
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseDropdown());
      await focusFirstWithTab(tester);

      expectConformant(
        token: 'BaseDropdown.focused.border',
        component: 'BaseDropdown',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });
  });

  group('typography', () {
    testWidgets('label text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, 'Label'),
      );

      await pumpConformance(tester, _baseDropdown());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseDropdown.labelTextStyle',
        component: 'BaseDropdown',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Label')),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('selected value text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, _value),
      );

      await pumpConformance(tester, _baseDropdown());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseDropdown.valueTextStyle',
        component: 'BaseDropdown',
        measured: describeTextRole(theme, _renderedStyle(tester, _value)),
        expected: expected,
        unit: '',
      );
    });
  });

  group('leading icon', () {
    testWidgets('prefix icon size (DROP-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleDropdown(prefixIcon: Icons.search));
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.search),
      );

      await pumpConformance(tester, _baseDropdown(prefixIcon: Icons.search));

      expectConformant(
        token: 'BaseDropdown.prefixIcon.size',
        component: 'BaseDropdown',
        measured: effectiveIconSize(tester, find.byIcon(Icons.search)),
        expected: expected,
      );
    });
  });

  group('keyboard operation', () {
    testWidgets('Tab reaches the dropdown and Enter opens its menu', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseDropdown());
      await focusFirstWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // The open menu renders a second copy of the item, in the route above
      // the field.
      expect(
        find.text(_value),
        findsAtLeast(2),
        reason: 'Enter on a focused dropdown must open its menu',
      );
    });
  });

  group('tap target', () {
    testWidgets('the dropdown meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseDropdown());
      expect(
        inputContainerSize(tester, _base()).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
