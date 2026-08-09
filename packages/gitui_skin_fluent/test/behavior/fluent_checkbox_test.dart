/// The checkbox's feel, measured from the paint stream.
///
/// What a WinUI checkbox does that a reimplementation gets wrong: the
/// UNCHECKED well darkens through hover and press while its strong border
/// DIMS at the press (the box yields under the finger); the CHECKED box is
/// the accent that dims by opacity exactly like the accent button; and the
/// MIXED state is a bar, not a check, so partial selection never reads as
/// selection. Every pinned literal restates its source beside it,
/// independently of the constants in lib/.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_checkbox.dart';
import 'package:gitui_skin_fluent/src/controls/fluent_control_marks.dart';

import 'support/fluent_behavior_harness.dart';

// ---------------------------------------------------------------------------
// Pinned WinUI resources (fluent_ui@4.16.1 lib/src/styles/color_resources.dart
// unless noted).
// ---------------------------------------------------------------------------

// ControlAltFillColorSecondary / Tertiary / Quarternary, light theme:
// :302, :303, :304 - the unchecked well's rest / hover / press.
const Color _wellRestLight = Color(0x06000000);
const Color _wellHoverLight = Color(0x0f000000);
const Color _wellPressedLight = Color(0x18000000);

// ControlStrongStrokeColorDefault / Disabled, light theme: :320, :321.
const Color _strongStrokeLight = Color(0x72000000);
const Color _strongStrokeDimLight = Color(0x37000000);

// The Windows default accent's dark stop - the resting checked fill in a
// light theme (fluent_ui color.dart:171, brush rule color.dart:347-352).
const Color _accentRestLight = Color(0xff0066b4);

// TextOnAccentFillColorPrimary, light theme: :284 - the check's ink.
const Color _onAccentLight = Color(0xFFffffff);

// ControlAltFillColorSecondary and the strong stroke, dark theme: :215,
// :233.
const Color _wellRestDark = Color(0x19000000);
const Color _strongStrokeDark = Color(0x8bffffff);

Finder _box() => find.byType(FluentCheckboxBox);

void main() {
  group('unchecked, light', () {
    testWidgets('rests on the ControlAltFill well behind the strong stroke', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: false, onChanged: (bool? _) {})),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _wellRestLight.toARGB32(),
      );
      final List<PaintedStroke> strokes = paintedStrokes(tester, _box());
      expect(strokes, hasLength(1));
      expect(strokes.single.color.toARGB32(), _strongStrokeLight.toARGB32());
      expect(
        strokes.single.width,
        1,
        reason: 'the unchecked border is one epx (checkbox.dart:378-382)',
      );
    });

    testWidgets('hover deepens the well, press deepens it further AND dims '
        'the border', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: false, onChanged: (bool? _) {})),
      );
      await hoverOver(tester, _box());
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _wellHoverLight.toARGB32(),
        reason: 'hover moves the well to ControlAltFillColorTertiary (:303)',
      );
      final TestGesture gesture = await pressAndHold(tester, _box());
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _wellPressedLight.toARGB32(),
        reason: 'press moves the well to ControlAltFillColorQuarternary (:304)',
      );
      expect(
        paintedStrokes(tester, _box()).single.color.toARGB32(),
        _strongStrokeDimLight.toARGB32(),
        reason:
            'a pressed unchecked checkbox dims its border to the DISABLED '
            'strong stroke (checkbox.dart:378-382) - the yield under the '
            'finger',
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('draws no mark at all', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: false, onChanged: (bool? _) {})),
      );
      expect(find.byType(FluentCheckMark), findsNothing);
      expect(find.byType(FluentMixedMark), findsNothing);
    });
  });

  group('checked and mixed, light', () {
    testWidgets('checked rests on the accent under the drawn check', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: true, onChanged: (bool? _) {})),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _accentRestLight.toARGB32(),
      );
      final Finder mark = find.byType(FluentCheckMark);
      expect(mark, findsOneWidget);
      // The mark paints as a stroked path in the on-accent ink.
      final List<PaintedStroke> strokes = paintedStrokeStyle(tester, mark);
      expect(strokes, hasLength(1));
      expect(strokes.single.color.toARGB32(), _onAccentLight.toARGB32());
    });

    testWidgets('checked hover and press dim the accent by opacity, like the '
        'accent button', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: true, onChanged: (bool? _) {})),
      );
      await hoverOver(tester, _box());
      expectPaintedColor(
        singleFillOf(tester, _box()),
        // AccentFillColorSecondaryBrush: Opacity 0.9 (color.dart:358-360).
        _accentRestLight.withValues(alpha: 0.9),
      );
      final TestGesture gesture = await pressAndHold(tester, _box());
      expectPaintedColor(
        singleFillOf(tester, _box()),
        // AccentFillColorTertiaryBrush: Opacity 0.8 (color.dart:366-368).
        _accentRestLight.withValues(alpha: 0.8),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('mixed draws the bar, never the check', (
      WidgetTester tester,
    ) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: null, onChanged: (bool? _) {})),
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _accentRestLight.toARGB32(),
        reason: 'the mixed box wears the accent like the checked one',
      );
      expect(find.byType(FluentMixedMark), findsOneWidget);
      expect(find.byType(FluentCheckMark), findsNothing);
    });
  });

  group('operating it', () {
    testWidgets('the cycle is mixed -> true, true -> false, false -> true', (
      WidgetTester tester,
    ) async {
      bool? reported;
      Future<void> pump(bool? value) => pumpFluentBehavior(
        tester,
        FluentCheckbox(
          spec: ToggleSpec(
            value: value,
            onChanged: (bool? next) => reported = next,
          ),
        ),
      );
      await pump(null);
      await tester.tap(_box());
      expect(reported, isTrue, reason: 'operating a mixed control resolves it');
      await pump(true);
      await tester.tap(_box());
      expect(reported, isFalse);
      await pump(false);
      await tester.tap(_box());
      expect(reported, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('disabled means no states at all', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        const FluentCheckbox(spec: ToggleSpec(value: false, onChanged: null)),
      );
      final Color resting = singleFillOf(tester, _box());
      await hoverOver(tester, _box());
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        resting.toARGB32(),
        reason: 'a hover over a disabled checkbox changes nothing',
      );
      expect(
        paintedStrokes(tester, _box()).single.color.toARGB32(),
        _strongStrokeDimLight.toARGB32(),
        reason:
            'the disabled border is the disabled strong stroke '
            '(checkbox.dart:378-382)',
      );
    });
  });

  group('dark', () {
    testWidgets('pins the dark well and stroke', (WidgetTester tester) async {
      await pumpFluentBehavior(
        tester,
        FluentCheckbox(spec: ToggleSpec(value: false, onChanged: (bool? _) {})),
        brightness: Brightness.dark,
      );
      expect(
        singleFillOf(tester, _box()).toARGB32(),
        _wellRestDark.toARGB32(),
        reason:
            'the dark well is still a BLACK wash (color_resources.dart:215) '
            '- WinUI recesses an input below the ground on both '
            'brightnesses',
      );
      expect(
        paintedStrokes(tester, _box()).single.color.toARGB32(),
        _strongStrokeDark.toARGB32(),
      );
    });
  });
}
