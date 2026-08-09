/// The text box's feel, measured from the paint stream.
///
/// The Fluent signature a reimplementation gets wrong: the box is
/// TRANSLUCENT until it holds the keyboard, then goes SOLID
/// (`ControlFillColorInputActive`) - the opposite order from Material,
/// whose filled field stays filled and signals focus with its indicator -
/// and the bottom hairline THICKENS into the 2 epx accent underline
/// rather than appearing from nothing. The keyboard contract (Escape
/// empties a non-empty field and keeps focus) is the application's and is
/// asserted here because a drawn field is exactly where it would silently
/// vanish.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_fields.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_text_box.dart';

import 'support/fluent_behavior_harness.dart';

// ---------------------------------------------------------------------------
// Pinned WinUI resources (fluent_ui@4.16.1 lib/src/styles/color_resources.dart
// unless noted).
// ---------------------------------------------------------------------------

// ControlFillColorDefault / Secondary / InputActive / Disabled, light:
// :287, :288, :293, :291.
const Color _boxRestLight = Color(0xb3ffffff);
const Color _boxHoverLight = Color(0x80f9f9f9);
const Color _boxActiveLight = Color(0xFFffffff);
const Color _boxDisabledLight = Color(0x4df9f9f9);

// ControlStrongStrokeColorDefault, light: :320 - the resting hairline.
const Color _hairlineLight = Color(0x72000000);

// The accent's dark stop (color.dart:171) - the focused underline, light.
const Color _accentLight = Color(0xff0066b4);

Finder _box() => find.byType(FluentTextBox);

/// The box's own container fill: the ladder colour, told apart from the
/// underline fills by being painted first.
Color _boxFill(WidgetTester tester) => paintedFillColors(tester, _box()).first;

/// Whether [color] was painted under the box at all - how the underline is
/// found, because a one-sided border paints as a filled path.
bool _painted(WidgetTester tester, Color color) => paintedFillColors(
  tester,
  _box(),
).any((Color c) => c.toARGB32() == color.toARGB32());

void main() {
  group('the fill ladder, light', () {
    testWidgets('rests translucent over the hairline', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(label: 'Name'),
            handles: const FieldHandles(),
          ),
        ),
      );
      expect(_boxFill(tester).toARGB32(), _boxRestLight.toARGB32());
      expect(
        _painted(tester, _hairlineLight),
        isTrue,
        reason:
            'the resting bottom hairline is ControlStrongStrokeColorDefault '
            '(text_box.dart:1571-1581)',
      );
      expect(_painted(tester, _accentLight), isFalse);
    });

    testWidgets('hover moves to ControlFillColorSecondary', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(label: 'Name'),
            handles: const FieldHandles(),
          ),
        ),
      );
      await hoverOver(tester, _box());
      expect(_boxFill(tester).toARGB32(), _boxHoverLight.toARGB32());
    });

    testWidgets('taking the keyboard goes SOLID under the accent underline', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(label: 'Name'),
            handles: const FieldHandles(),
          ),
        ),
      );
      await tester.tap(_box());
      await tester.pumpAndSettle();
      expect(
        _boxFill(tester).toARGB32(),
        _boxActiveLight.toARGB32(),
        reason:
            'a Fluent text box goes SOLID while it holds the keyboard '
            '(ControlFillColorInputActive, text_box.dart:1436-1448)',
      );
      expect(
        _painted(tester, _accentLight),
        isTrue,
        reason:
            'the focused underline is the 2 epx accent '
            '(text_box.dart:1557-1570)',
      );
      expect(_painted(tester, _hairlineLight), isFalse);
    });

    testWidgets('disabled paints the disabled fill and NO underline', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(label: 'Name', enabled: false),
            handles: const FieldHandles(),
          ),
        ),
      );
      expect(_boxFill(tester).toARGB32(), _boxDisabledLight.toARGB32());
      expect(_painted(tester, _hairlineLight), isFalse);
      expect(_painted(tester, _accentLight), isFalse);
    });
  });

  group('words', () {
    testWidgets('label above, hint inside while empty, helper and error '
        'below', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(
              label: 'Branch name',
              hint: 'feature/...',
              helper: 'Letters, digits, dashes',
              error: 'Already exists',
            ),
            handles: const FieldHandles(),
          ),
        ),
      );
      expect(find.text('Branch name'), findsOneWidget);
      expect(find.text('feature/...'), findsOneWidget);
      expect(find.text('Letters, digits, dashes'), findsOneWidget);
      expect(find.text('Already exists'), findsOneWidget);
    });

    testWidgets('typing consumes the hint and reports each change', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: FieldSpec(
              label: 'Name',
              hint: 'type here',
              onChanged: reported.add,
            ),
            handles: const FieldHandles(),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.pump();
      expect(reported, contains('abc'));
      expect(find.text('type here'), findsNothing);
    });
  });

  group('the Escape ladder', () {
    testWidgets('Escape empties a non-empty field and reports it', (
      WidgetTester tester,
    ) async {
      final List<String> reported = <String>[];
      final TextEditingController controller = TextEditingController(
        text: 'wip',
      );
      addTearDown(controller.dispose);
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: FieldSpec(label: 'Name', onChanged: reported.add),
            handles: FieldHandles(controller: controller),
          ),
        ),
      );
      await tester.tap(_box());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(reported, contains(''));
    });

    testWidgets('escapeClears false leaves Escape alone', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(
        text: 'token',
      );
      addTearDown(controller.dispose);
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(label: 'Confirm', escapeClears: false),
            handles: FieldHandles(controller: controller),
          ),
        ),
      );
      await tester.tap(_box());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, 'token');
    });
  });

  group('affordances', () {
    testWidgets('clear appears only with text, empties on press', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(
              label: 'Filter',
              suffix: FieldClearAffordance(),
            ),
            handles: FieldHandles(controller: controller),
          ),
        ),
      );
      expect(find.byType(FluentFieldAffordance), findsNothing);
      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.pump();
      expect(find.byType(FluentFieldAffordance), findsOneWidget);
      await tester.tap(find.byType(FluentFieldAffordance));
      await tester.pump();
      expect(controller.text, isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('reveal flips a password field between hidden and shown', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        SizedBox(
          width: 240,
          child: FluentTextField(
            spec: const FieldSpec(
              label: 'Token',
              purpose: FieldPurpose.password,
              suffix: FieldRevealAffordance(),
            ),
            handles: const FieldHandles(initialValue: 'secret'),
          ),
        ),
      );
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byType(FluentFieldAffordance));
      await tester.pumpAndSettle();
      expect(editable().obscureText, isFalse);
    });
  });
}
