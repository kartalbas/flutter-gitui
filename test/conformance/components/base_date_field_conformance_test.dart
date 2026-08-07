/// Material 3 conformance suite for BaseDateField
/// (lib/shared/components/base_date_field.dart).
///
/// Material 3 has no "date field" component of its own: the docked date entry
/// it specifies is a **text field** whose value happens to be a date, and
/// BaseDateField is built exactly that way — an `InputDecorator` with an
/// `OutlineInputBorder` around a value. The oracle is therefore the same one
/// the BaseTextField suite uses, a real `TextField` carrying an
/// `OutlineInputBorder`, pumped through [pumpConformance] and read with the
/// same probes, so both app components are held to one ruler.
///
/// The consequence that matters most here is the state language. A text field
/// indicates hover by darkening its outline and focus by drawing it in
/// `primary` at 2 dp (input_decorator.dart:5995); it paints no ink at all. A
/// component that wraps the same field in an `InkWell` therefore paints a
/// *second* indication on top of the first — which is what the overlay tokens
/// below pin down.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_date_field.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so horizontal measurements compare like
/// with like.
const double _probeWidth = 320.0;

/// The date both sides display, and its rendered form.
final DateTime _date = DateTime(2020, 1, 2);
const String _formatted = '2020-01-02';

/// The Material 3 oracle: the SDK text field the component is a specialisation
/// of, with the same value and the same kind of trailing glyph.
///
/// `TextField` is banned from UI code by the design system's `avoid_text_field`
/// rule. Here it is not shipped UI but the ruler this suite measures against,
/// which is why the rule is suppressed at this single construction.
Widget _oracleField({TextEditingController? controller, bool suffix = false}) {
  return SizedBox(
    width: _probeWidth,
    // ignore: avoid_text_field
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Date',
        border: const OutlineInputBorder(),
        suffixIcon: suffix ? const Icon(Icons.calendar_today) : null,
      ),
    ),
  );
}

Widget _baseField({DateTime? value}) {
  return SizedBox(
    width: _probeWidth,
    child: BaseDateField(
      label: 'Date',
      value: value,
      onChanged: (DateTime? picked) {},
    ),
  );
}

/// A controller carrying the rendered date, so the oracle floats its label and
/// fills its value slot exactly like a date field that has a value.
TextEditingController _valueController() {
  final TextEditingController controller = TextEditingController(
    text: _formatted,
  );
  addTearDown(controller.dispose);
  return controller;
}

Finder _oracle() => find.byType(TextField);

Finder _base() => find.byType(BaseDateField);

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

String _side(WidgetTester tester, Finder field) {
  return describeBorderSide(
    _theme(tester).colorScheme,
    inputBorderSide(tester, field),
  );
}

void main() {
  group('container geometry', () {
    testWidgets('corner radius', (WidgetTester tester) async {
      // Measured on the empty field: an inline label leaves the outline as one
      // rounded rectangle, where a floating one splits it into gapped paths
      // with no readable corner.
      await pumpConformance(tester, _oracleField());
      final double expected = inputCornerRadius(tester, _oracle());

      await pumpConformance(tester, _baseField());

      expectConformant(
        token: 'BaseDateField.shape',
        component: 'BaseDateField',
        measured: inputCornerRadius(tester, _base()),
        expected: expected,
      );
    });

    testWidgets('container height with and without a value', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        _oracleField(controller: _valueController()),
      );
      final double expected = inputContainerSize(tester, _oracle()).height;

      await pumpConformance(tester, _baseField(value: _date));
      final double measured = inputContainerSize(tester, _base()).height;

      expectConformant(
        token: 'BaseDateField.containerHeight',
        component: 'BaseDateField',
        measured: measured,
        expected: expected,
      );
      expect(measured, greaterThanOrEqualTo(kMinInteractiveDimension));

      // The empty field must not be a different height from the filled one, or
      // picking a date would make the dialog around it jump.
      await pumpConformance(tester, _baseField());
      expect(inputContainerSize(tester, _base()).height, measured);
    });

    testWidgets('leading content inset', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        _oracleField(controller: _valueController()),
      );
      final double expected =
          tester.getTopLeft(find.byType(EditableText)).dx -
          tester.getTopLeft(inputBorderPainter(_oracle())).dx;

      await pumpConformance(tester, _baseField(value: _date));
      final double measured =
          tester.getTopLeft(find.text(_formatted)).dx -
          tester.getTopLeft(inputBorderPainter(_base())).dx;

      expectConformant(
        token: 'BaseDateField.contentPadding.start',
        component: 'BaseDateField',
        measured: measured,
        expected: expected,
      );
    });
  });

  group('outline per state', () {
    testWidgets('resting', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseField());

      expect(expected, isNot('none'), reason: 'the oracle must paint a border');
      expectConformant(
        token: 'BaseDateField.enabled.border',
        component: 'BaseDateField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('hovered', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      final String resting = _side(tester, _oracle());
      final String expected = await whileHovering(
        tester,
        _oracle(),
        () => _side(tester, _oracle()),
      );
      expect(
        expected,
        isNot(resting),
        reason:
            'the oracle must change its outline under the pointer, otherwise '
            'this test proves nothing',
      );

      await pumpConformance(tester, _baseField());
      final String measured = await whileHovering(
        tester,
        _base(),
        () => _side(tester, _base()),
      );

      expectConformant(
        token: 'BaseDateField.hovered.border',
        component: 'BaseDateField',
        measured: measured,
        expected: expected,
        unit: '',
      );
    });

    testWidgets('focused', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      await focusFirstWithTab(tester);
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseField());
      await focusFirstWithTab(tester);

      expectConformant(
        token: 'BaseDateField.focused.border',
        component: 'BaseDateField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });
  });

  group('typography', () {
    testWidgets('value text role', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        _oracleField(controller: _valueController()),
      );
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        tester.widget<EditableText>(find.byType(EditableText)).style,
      );

      await pumpConformance(tester, _baseField(value: _date));
      theme = _theme(tester);

      expectConformant(
        token: 'BaseDateField.valueTextStyle',
        component: 'BaseDateField',
        measured: describeTextRole(
          theme,
          tester
              .renderObject<RenderParagraph>(find.text(_formatted))
              .text
              .style,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('label text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        tester.renderObject<RenderParagraph>(find.text('Date')).text.style,
      );

      await pumpConformance(tester, _baseField());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseDateField.labelTextStyle',
        component: 'BaseDateField',
        measured: describeTextRole(
          theme,
          tester.renderObject<RenderParagraph>(find.text('Date')).text.style,
        ),
        expected: expected,
        unit: '',
      );
    });
  });

  group('trailing icon', () {
    testWidgets('suffix icon size (DATE-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(suffix: true));
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.calendar_today),
      );

      await pumpConformance(tester, _baseField());

      expectConformant(
        token: 'BaseDateField.suffixIcon.size',
        component: 'BaseDateField',
        measured: effectiveIconSize(
          tester,
          find.byIcon(PhosphorIconsRegular.calendar),
        ),
        expected: expected,
      );
    });
  });

  group('state indication', () {
    testWidgets('the field adds no ink affordance of its own', (
      WidgetTester tester,
    ) async {
      // A text field indicates hover, focus and error entirely through its
      // outline; it has no ink layer. Wrapping this one in an InkWell — which
      // is what it used to be — put a second, differently shaped indication on
      // top of the first, drawn as a square behind the rounded field because
      // the ink was never told the field's shape.
      //
      // This is asserted structurally rather than as a state-layer token: the
      // ink probe diffs everything painted under the enclosing Material, and
      // on a real TextField that diff also contains the blinking caret, which
      // a picked field can never have.
      await pumpConformance(tester, _baseField());
      expect(
        find.descendant(of: _base(), matching: find.byType(InkResponse)),
        findsNothing,
        reason:
            'the outline carries hover and focus; an ink layer would be the '
            'second affordance for the same job',
      );
    });
  });

  group('keyboard operation', () {
    testWidgets('Tab reaches the field and Enter opens the picker', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _baseField());
      await focusFirstWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        find.byType(DatePickerDialog),
        findsOneWidget,
        reason:
            'a field a keyboard user can reach but not operate is an '
            'unfinished field',
      );
    });

    testWidgets('Space opens the picker too', (WidgetTester tester) async {
      await pumpConformance(tester, _baseField());
      await focusFirstWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('tap target', () {
    testWidgets('the field meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseField(value: _date));
      expect(
        inputContainerSize(tester, _base()).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
