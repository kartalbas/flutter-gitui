// The date picker `showThemedDatePicker` opens must inherit the app's input
// decoration instead of falling back to the framework defaults (#400).
//
// The picker wraps its dialog in a `Theme` so it can state the colours its
// manual-entry field needs in each brightness. Building a fresh
// `InputDecorationTheme` for that - which is what it used to do - substitutes
// the sub-theme rather than merging into it, so everything AppTheme and
// FlexSubThemesData configured for input decoration was discarded inside the
// picker: the decorator's corner radius, its fill, and the family, size and
// tracking of its label and hint. `TextTheme.copyWith(bodyLarge: TextStyle(…))`
// did the same to two text roles.
//
// This never showed as a regression, because the picker rendered the same
// before #399 and after; it is only visible by asking what the picker's own
// context resolves. That is what the assertions below do, and each one is
// written so that it fails again if the merge is turned back into a
// substitution: a substituted sub-theme carries a null border and a null font
// size, and every value compared here is a configured one that is not null.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_gitui/shared/components/base_date_field.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

/// Opens the themed picker over [appTheme] and returns the theme its own
/// widgets resolve - the only place the question "did the app's configuration
/// survive into the picker" can be asked.
Future<ThemeData> _themeInsideThePicker(
  WidgetTester tester,
  ThemeData appTheme,
) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  unawaited(
    showThemedDatePicker(
      context: hostContext,
      initialDate: DateTime(2026, 1, 15),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    ),
  );
  await tester.pumpAndSettle();

  expect(
    find.byType(DatePickerDialog),
    findsOneWidget,
    reason: 'the picker did not open, so there is no theme to inspect',
  );
  return Theme.of(tester.element(find.byType(DatePickerDialog)));
}

/// The border an [InputDecorationThemeData] carries, resolved for the resting
/// state.
///
/// `FlexSubThemesData` supplies a state-resolving border, so the value in the
/// theme is both an [InputBorder] and a [WidgetStateProperty]; only the
/// resolved one has a radius to read.
InputBorder _restingBorder(InputBorder? border) {
  expect(
    border,
    isNotNull,
    reason:
        'no input border at all - either the app stopped configuring one, or '
        'the sub-theme was substituted and this is the framework default '
        '(null)',
  );
  final resolved = border!;
  if (resolved is WidgetStateProperty<InputBorder>) {
    return (resolved as WidgetStateProperty<InputBorder>).resolve(
      const <WidgetState>{},
    );
  }
  return resolved;
}

/// The corner an [InputBorder] carries, whichever of the two SDK shapes it is.
BorderRadius _radiusOf(InputBorder border) => switch (border) {
  UnderlineInputBorder() => border.borderRadius,
  OutlineInputBorder() => border.borderRadius,
  _ => fail('unexpected input border shape: ${border.runtimeType}'),
};

void main() {
  // Building the theme resolves a Google Fonts family from the asset bundle;
  // the same switch main.dart sets keeps that resolution offline.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final brightness in <(String, ThemeData Function())>[
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final name = brightness.$1;
    final buildTheme = brightness.$2;

    testWidgets(
      'the $name date picker inherits the configured input decoration',
      (tester) async {
        final appTheme = buildTheme();
        final pickerTheme = await _themeInsideThePicker(tester, appTheme);

        final app = appTheme.inputDecorationTheme;
        final picker = pickerTheme.inputDecorationTheme;

        // The corner. AppTheme configures `inputDecoratorRadius` for every
        // SDK-owned field, this one included; the framework default is no
        // border at all, which is what a substituted sub-theme leaves behind.
        final appRadius = _radiusOf(_restingBorder(app.border));
        final pickerRadius = _radiusOf(_restingBorder(picker.border));
        expect(
          pickerRadius,
          appRadius,
          reason:
              'the picker resolved a different input border from the one the '
              'app configures - the input sub-theme was substituted rather '
              'than merged (#400)',
        );
        expect(
          pickerRadius.topLeft,
          const Radius.circular(AppTheme.radiusM),
          reason:
              'the corner reaching the picker is not the one AppTheme names '
              'in inputDecoratorRadius',
        );

        // The fill, a second configured token the inline overrides never
        // mention and therefore cannot have supplied.
        expect(picker.fillColor, app.fillColor);
        expect(picker.filled, app.filled);

        // The type. The picker states a colour for these three styles on
        // purpose, so the colour may differ - nothing else may.
        expect(
          app.labelStyle?.fontSize,
          isNotNull,
          reason:
              'the app no longer sizes its input label, so this assertion has '
              'nothing left to prove',
        );
        expect(picker.labelStyle?.fontSize, app.labelStyle?.fontSize);
        expect(picker.labelStyle?.fontFamily, app.labelStyle?.fontFamily);
        expect(picker.labelStyle?.letterSpacing, app.labelStyle?.letterSpacing);
        expect(picker.hintStyle?.fontSize, app.hintStyle?.fontSize);
        expect(picker.hintStyle?.fontFamily, app.hintStyle?.fontFamily);
        expect(
          picker.floatingLabelStyle?.fontSize,
          app.floatingLabelStyle?.fontSize,
        );

        // And the helper style, which the picker says nothing about at all: it
        // must arrive unchanged rather than as null.
        expect(picker.helperStyle?.fontSize, app.helperStyle?.fontSize);
        expect(picker.helperStyle?.color, app.helperStyle?.color);

        // The overrides the picker does make still win, so merging did not
        // turn into "inherit everything and state nothing".
        expect(
          picker.hintStyle?.color,
          pickerTheme.colorScheme.onSurfaceVariant,
        );
        expect(picker.labelStyle?.color, pickerTheme.colorScheme.onSurface);
        expect(
          picker.floatingLabelStyle?.color,
          pickerTheme.colorScheme.primary,
        );
      },
    );

    testWidgets(
      'the $name date picker keeps the app type ramp for the two body roles',
      (tester) async {
        final appTheme = buildTheme();
        final pickerTheme = await _themeInsideThePicker(tester, appTheme);

        for (final role in <(String, TextStyle?, TextStyle?)>[
          (
            'bodyLarge',
            appTheme.textTheme.bodyLarge,
            pickerTheme.textTheme.bodyLarge,
          ),
          (
            'bodyMedium',
            appTheme.textTheme.bodyMedium,
            pickerTheme.textTheme.bodyMedium,
          ),
        ]) {
          final label = role.$1;
          final app = role.$2;
          final picker = role.$3;

          expect(
            app?.fontSize,
            isNotNull,
            reason: 'the app no longer sizes $label',
          );
          expect(
            picker?.fontSize,
            app?.fontSize,
            reason:
                '$label lost the app font size inside the picker, so the text '
                'role was replaced with a bare TextStyle instead of being '
                'recoloured',
          );
          expect(picker?.fontFamily, app?.fontFamily, reason: '$label family');
          expect(
            picker?.letterSpacing,
            app?.letterSpacing,
            reason: '$label tracking',
          );
          expect(picker?.height, app?.height, reason: '$label line height');
          expect(picker?.color, pickerTheme.colorScheme.onSurface);
        }
      },
    );
  }
}
