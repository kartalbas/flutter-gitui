/// Material 3 conformance suite for BaseTextField
/// (lib/shared/components/base_text_field.dart).
///
/// `TextFieldVariant` names the role a field plays — `bordered`,
/// `emphasized` — rather than the Material class that draws it, so this suite
/// is what pins each role to a Material rendering: `bordered` to an
/// `OutlineInputBorder` and `emphasized` to a filled box. The ruler is
/// therefore the SDK widget in that same configuration: a real `TextField`
/// pumped through [pumpConformance] and read with the same probes as
/// BaseTextField. Fonts, device pixel ratio and visual density are identical
/// on both sides and cancel out of every comparison.
///
/// BaseTextField is a façade over `controls.textField` now, so what this suite
/// measures is the skin's field reached through the application's own
/// component — which is the only rendering the application can ever get.
///
/// The token ids for the emphasized role are still spelled
/// `BaseTextField.filled.*`. A token id names the *measured Material
/// property*, and the property being measured really is the fill, the fill's
/// bottom corner and the filled box's active indicator; the ids also have to
/// keep matching `test/conformance/support/token_manifest.dart` and the
/// `FIELD-002` / `FIELD-003` entries in `docs/deviation_register.yaml`
/// verbatim, or `expectConformant` rejects them as unlisted.
///
/// Neither `InputDecorator` nor `TextField` exposes a defaults seam
/// (`defaultStyleOf` exists only on `ButtonStyleButton`), and the border for
/// the current widget state is resolved deep inside the private
/// `_InputDecoratorState` — reading `decoration.enabledBorder` would compare
/// what each side *asked for*, which is null on the oracle. The container, its
/// outline and its corners are therefore measured out of the paint stream
/// ([inputBorderSide], [inputCornerRadius]), the same way the state-layer
/// probes read painted ink.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// Width both sides are laid out at, so horizontal measurements compare like
/// with like.
const double _probeWidth = 320.0;

/// The Material 3 oracle.
///
/// `TextField` is banned from UI code by the design system's `avoid_text_field`
/// rule. Here it is not shipped UI but the ruler this suite measures against,
/// which is why the rule is suppressed at this single construction.
Widget _oracleField({
  String? label = 'Label',
  String? hint,
  String? helper,
  String? error,
  bool enabled = true,
  bool filled = false,
  IconData? prefixIcon,
}) {
  return SizedBox(
    width: _probeWidth,
    // ignore: avoid_text_field
    child: TextField(
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: error,
        filled: filled ? true : null,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        border: filled
            ? const UnderlineInputBorder()
            : const OutlineInputBorder(),
      ),
    ),
  );
}

Widget _baseField({
  String? label = 'Label',
  String? hint,
  String? helper,
  String? error,
  bool enabled = true,
  TextFieldVariant variant = TextFieldVariant.bordered,
  IconRole? prefixIcon,
}) {
  return SizedBox(
    width: _probeWidth,
    child: BaseTextField(
      label: label,
      hintText: hint,
      helperText: helper,
      errorText: error,
      enabled: enabled,
      variant: variant,
      prefixIcon: prefixIcon,
    ),
  );
}

Finder _oracle() => find.byType(TextField);

Finder _base() => find.byType(BaseTextField);

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// Distance from the container's leading edge to the start of the text the
/// user types — the horizontal content padding as it really lands.
double _startInset(WidgetTester tester, Finder field) {
  return tester.getTopLeft(find.byType(EditableText)).dx -
      tester.getTopLeft(inputBorderPainter(field)).dx;
}

/// Distance from the top of the container to the top of that same text.
double _topInset(WidgetTester tester, Finder field) {
  return tester.getTopLeft(find.byType(EditableText)).dy -
      tester.getTopLeft(inputBorderPainter(field)).dy;
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
      await pumpConformance(tester, _oracleField());
      final double expected = inputCornerRadius(tester, _oracle());

      await pumpConformance(tester, _baseField());

      expectConformant(
        token: 'BaseTextField.shape',
        component: 'BaseTextField',
        measured: inputCornerRadius(tester, _base()),
        expected: expected,
      );
    });

    testWidgets('container height', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      final double expected = inputContainerSize(tester, _oracle()).height;

      await pumpConformance(tester, _baseField());
      final double measured = inputContainerSize(tester, _base()).height;

      expectConformant(
        token: 'BaseTextField.containerHeight',
        component: 'BaseTextField',
        measured: measured,
        expected: expected,
      );
      expect(
        measured,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason:
            'a field the user clicks into must reach the minimum interactive '
            'dimension; InputDecorator guarantees it at '
            'input_decorator.dart:1331 unless a caller asks for a dense field',
      );
    });

    testWidgets('leading content inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      final double expected = _startInset(tester, _oracle());

      await pumpConformance(tester, _baseField());

      expectConformant(
        token: 'BaseTextField.contentPadding.start',
        component: 'BaseTextField',
        measured: _startInset(tester, _base()),
        expected: expected,
      );
    });

    testWidgets('top content inset', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      final double expected = _topInset(tester, _oracle());

      await pumpConformance(tester, _baseField());

      expectConformant(
        token: 'BaseTextField.contentPadding.top',
        component: 'BaseTextField',
        measured: _topInset(tester, _base()),
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
        token: 'BaseTextField.enabled.border',
        component: 'BaseTextField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('hovered', (WidgetTester tester) async {
      // M3 darkens the outline under the pointer (outlineBorder, hovered ->
      // onSurface, input_decorator.dart:6009-6011). A field that spells out its
      // own enabledBorder loses that indication silently, because the
      // spelled-out border also wins while hovered.
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
        token: 'BaseTextField.hovered.border',
        component: 'BaseTextField',
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
        token: 'BaseTextField.focused.border',
        component: 'BaseTextField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('error', (WidgetTester tester) async {
      // M3 keeps the 2 dp weight for the focused state; an unfocused field in
      // error draws a 1 dp error outline (input_decorator.dart:6001-6004).
      await pumpConformance(tester, _oracleField(error: 'Invalid'));
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseField(error: 'Invalid'));

      expectConformant(
        token: 'BaseTextField.error.border',
        component: 'BaseTextField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('disabled', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(enabled: false));
      final String expected = _side(tester, _oracle());

      await pumpConformance(tester, _baseField(enabled: false));

      expectConformant(
        token: 'BaseTextField.disabled.border',
        component: 'BaseTextField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });
  });

  group('typography', () {
    testWidgets('input text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField());
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        tester.widget<EditableText>(find.byType(EditableText)).style,
      );

      await pumpConformance(tester, _baseField());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseTextField.inputTextStyle',
        component: 'BaseTextField',
        measured: describeTextRole(
          theme,
          tester.widget<EditableText>(find.byType(EditableText)).style,
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
        _renderedStyle(tester, 'Label'),
      );

      await pumpConformance(tester, _baseField());
      theme = _theme(tester);

      expectConformant(
        token: 'BaseTextField.labelTextStyle',
        component: 'BaseTextField',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Label')),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('hint text role and color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(label: null, hint: 'Hint'));
      ThemeData theme = _theme(tester);
      final TextStyle? oracleHint = _renderedStyle(tester, 'Hint');
      final String expectedRole = describeTextRole(theme, oracleHint);
      final String expectedColor = colorRoleName(
        theme.colorScheme,
        oracleHint!.color!,
      );

      await pumpConformance(tester, _baseField(label: null, hint: 'Hint'));
      theme = _theme(tester);
      final TextStyle? measuredHint = _renderedStyle(tester, 'Hint');

      expectConformant(
        token: 'BaseTextField.hintTextStyle',
        component: 'BaseTextField',
        measured: describeTextRole(theme, measuredHint),
        expected: expectedRole,
        unit: '',
      );
      expectConformant(
        token: 'BaseTextField.hintColor',
        component: 'BaseTextField',
        measured: colorRoleName(theme.colorScheme, measuredHint!.color!),
        expected: expectedColor,
        unit: '',
      );
    });

    testWidgets('helper text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(helper: 'Helper'));
      ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        _renderedStyle(tester, 'Helper'),
      );

      await pumpConformance(tester, _baseField(helper: 'Helper'));
      theme = _theme(tester);

      expectConformant(
        token: 'BaseTextField.helperTextStyle',
        component: 'BaseTextField',
        measured: describeTextRole(theme, _renderedStyle(tester, 'Helper')),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('error text role', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(error: 'Invalid'));
      ThemeData theme = _theme(tester);
      final TextStyle? oracleError = _renderedStyle(tester, 'Invalid');
      final String expected =
          '${describeTextRole(theme, oracleError)} in '
          '${colorRoleName(theme.colorScheme, oracleError!.color!)}';

      await pumpConformance(tester, _baseField(error: 'Invalid'));
      theme = _theme(tester);
      final TextStyle? measuredError = _renderedStyle(tester, 'Invalid');

      expectConformant(
        token: 'BaseTextField.errorTextStyle',
        component: 'BaseTextField',
        measured:
            '${describeTextRole(theme, measuredError)} in '
            '${colorRoleName(theme.colorScheme, measuredError!.color!)}',
        expected: expected,
        unit: '',
      );
    });
  });

  group('leading icon', () {
    testWidgets('prefix icon size (FIELD-001)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(prefixIcon: Icons.search));
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.search),
      );

      await pumpConformance(
        tester,
        _baseField(prefixIcon: IconRole.magnifyingGlass),
      );

      expectConformant(
        token: 'BaseTextField.prefixIcon.size',
        component: 'BaseTextField',
        measured: effectiveIconSize(
          tester,
          find.byIcon(MaterialGlyphs.of(IconRole.magnifyingGlass)),
        ),
        expected: expected,
      );
    });
  });

  group('the emphasized variant, which Material renders as a filled box', () {
    testWidgets('fill color', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(filled: true));
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        paintedFillColors(tester, inputBorderPainter(_oracle())).first,
      );

      await pumpConformance(
        tester,
        _baseField(variant: TextFieldVariant.emphasized),
      );
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseTextField.filled.fillColor',
        component: 'BaseTextField',
        measured: colorRoleName(
          scheme,
          paintedFillColors(tester, inputBorderPainter(_base())).first,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('bottom corner radius (FIELD-002)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(tester, _oracleField(filled: true));
      final double expected = inputBottomCornerRadius(tester, _oracle());

      await pumpConformance(
        tester,
        _baseField(variant: TextFieldVariant.emphasized),
      );

      expectConformant(
        token: 'BaseTextField.filled.bottomCornerRadius',
        component: 'BaseTextField',
        measured: inputBottomCornerRadius(tester, _base()),
        expected: expected,
      );
    });

    testWidgets('active indicator (FIELD-003)', (WidgetTester tester) async {
      await pumpConformance(tester, _oracleField(filled: true));
      final String expected = _side(tester, _oracle());

      await pumpConformance(
        tester,
        _baseField(variant: TextFieldVariant.emphasized),
      );

      expectConformant(
        token: 'BaseTextField.filled.activeIndicator',
        component: 'BaseTextField',
        measured: _side(tester, _base()),
        expected: expected,
        unit: '',
      );
    });
  });

  group('the roles the contract can carry', () {
    test('there are exactly two, and no receding third', () {
      // This stood as a `minimal` group measuring that the underline variant
      // got the same M3 side as the outlined one. The rung is gone with the
      // field's move behind `controls.textField`: `FieldPurpose` carries only
      // the values for which a language reaches for a DIFFERENT canonical
      // widget, and "the field recedes to its writing line" is not one of
      // them - macOS and Fluent 2 give a text field one appearance each, so
      // the rung named a Material rendering and nothing else. No screen in
      // `lib/` ever asked for it. Pinned here rather than dropped silently:
      // re-adding a rung the contract cannot carry would put this component
      // back to hand-painting one variant while the others are drawn behind
      // the seam, which is exactly what the corner retirement ended.
      expect(TextFieldVariant.values, <TextFieldVariant>[
        TextFieldVariant.bordered,
        TextFieldVariant.emphasized,
      ]);
    });
  });

  group('the internally created controller', () {
    testWidgets('initialValue seeds it', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        const SizedBox(
          width: _probeWidth,
          child: BaseTextField(label: 'Label', initialValue: 'seeded'),
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'seeded',
      );
    });

    testWidgets('it survives being replaced by a caller-owned controller', (
      WidgetTester tester,
    ) async {
      // The regression this guards: swapping a controller in used to leave the
      // internally created one attached and undisposed, and disposing on
      // `widget.controller == null` alone would then have disposed the wrong
      // one. Both controllers must stay usable across the swap.
      final TextEditingController owned = TextEditingController(text: 'mine');
      addTearDown(owned.dispose);

      await pumpConformance(
        tester,
        const SizedBox(
          width: _probeWidth,
          child: BaseTextField(label: 'Label', initialValue: 'seeded'),
        ),
      );
      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseTextField(label: 'Label', controller: owned),
        ),
      );

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'mine',
      );
      owned.text = 'edited';
      await tester.pump();
      expect(find.text('edited'), findsOneWidget);
    });

    testWidgets('the text survives losing a caller-owned controller', (
      WidgetTester tester,
    ) async {
      // The other direction of the swap, and the one that loses user input.
      // A caller that stops supplying a controller is changing who owns the
      // text, not asking for what the user typed to be discarded -- but the
      // replacement used to be seeded from initialValue, so the typing went
      // away and the field silently reverted to the value it opened with.
      final TextEditingController owned = TextEditingController(text: 'mine');
      addTearDown(owned.dispose);

      await pumpConformance(
        tester,
        SizedBox(
          width: _probeWidth,
          child: BaseTextField(label: 'Label', controller: owned),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'typed by the user');
      await pumpConformance(
        tester,
        const SizedBox(
          width: _probeWidth,
          child: BaseTextField(label: 'Label', initialValue: 'seeded'),
        ),
      );

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'typed by the user',
      );
      expect(find.text('seeded'), findsNothing);
    });

    testWidgets('a controller and an initialValue together are rejected', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      expect(
        () => BaseTextField(controller: controller, initialValue: 'seeded'),
        throwsAssertionError,
      );
    });
  });

  group('keyboard operation', () {
    testWidgets('Escape clears a non-empty field and keeps focus there', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        const SizedBox(
          width: _probeWidth,
          child: BaseTextField(
            label: 'Label',
            initialValue: 'text',
            autofocus: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
        reason:
            'correcting a typo must not throw the keyboard out of the field',
      );
    });
  });

  group('tap target', () {
    testWidgets('the field meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(tester, _baseField());
      expect(
        inputContainerSize(tester, _base()).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('the skin\'s corner token really drives the shape', () {
    testWidgets('the field rounds to MaterialMetrics.radiusS', (
      WidgetTester tester,
    ) async {
      // Ties the measured corner to the token it comes from, so a change to
      // the token cannot pass unnoticed as "still conformant". The token is
      // this SKIN's now: the application stated a field's corner five times
      // over until the field moved behind `controls.textField`, and a corner
      // is the one thing three design languages answer differently and all
      // three are right (Material 4, Fluent 4, macOS 6).
      await pumpConformance(tester, _baseField());
      expect(
        inputCornerRadius(tester, _base()),
        closeTo(MaterialMetrics.radiusS, 0.01),
      );
    });
  });
}
