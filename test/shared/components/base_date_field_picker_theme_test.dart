// The date picker a user opens from a `BaseDateField` must inherit the input
// decoration in force instead of falling back to the framework defaults (#400).
//
// The picker wraps its dialog in a `Theme` so it can state the colours its
// manual-entry field needs in each brightness. Building a fresh
// `InputDecorationTheme` for that - which is what it used to do - substitutes
// the sub-theme rather than merging into it, so everything the theme configured
// for input decoration was discarded inside the picker: the decorator's corner
// radius, its fill, and the family, size and tracking of its label and hint.
// `TextTheme.copyWith(bodyLarge: TextStyle(…))` did the same to two text roles.
//
// This never showed as a regression, because the picker rendered the same
// before #399 and after; it is only visible by asking what the picker's own
// context resolves. That is what the assertions below do, and each one is
// written so that it fails again if the merge is turned back into a
// substitution: a substituted sub-theme carries a null border and a null font
// size, and every value compared here is a configured one that is not null.
//
// ## Why it opens the field instead of calling a function (#249, P2)
//
// The function this used to call, `showThemedDatePicker`, lived in
// `base_date_field.dart`. With P2 the picker moved into the Material skin
// (`packages/gitui_skin_material/lib/src/facets/material_controls.dart`,
// reached from `controls.dateField`), and the copy left behind in `lib/` had no
// callers - so this file was measuring a function the application never runs.
// A guard that protects a dead copy of the code under test is the #400 defect
// happening to the #400 test: the skin's picker could have been rewritten back
// into a substitution with every assertion here still green. It now opens a
// real `BaseDateField` and inspects the picker that actually appears, and the
// dead copy is gone.
//
// It names `MaterialSkin` explicitly rather than taking whichever skin a run
// was parameterised with: the subject is Material's own `showDatePicker` and
// the sub-theme it resolves, which is a statement about one design language.
// The whole file moves into that language's package when the overlay seam
// lands (P4) and the picker stops being reachable from application code at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_date_field.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

/// The theme the field renders under, and the theme the picker it opened
/// resolves - the only place the question "did the configuration survive into
/// the picker" can be asked.
///
/// The first is read below the skin scope, which is where the field lives, so
/// it is whatever `chrome.wrapRoot` installed rather than a `ThemeData` this
/// file built for itself. That is deliberate: the comparison has to be between
/// what the application renders and what the picker inherited from it, and a
/// theme constructed here would be neither.
Future<(ThemeData host, ThemeData picker)> _openThePicker(
  WidgetTester tester,
  Brightness brightness,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // The field's hint is the application's own translated sentence, so the
      // delegates have to be present or it fails on a null AppLocalizations
      // rather than on anything this file is about.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: brightness == Brightness.light
          ? ThemeMode.light
          : ThemeMode.dark,
      // The skin, installed where `main.dart` installs it. Its request is
      // pinned at the values `AppTheme`'s own defaults resolve to, so the
      // theme under measurement is the one the application ships.
      builder: (BuildContext context, Widget? child) => SkinScope.install(
        skin: const MaterialSkin(),
        request: SkinRequest(
          brightness: brightness,
          accentSeed: 0,
          textScale: 1,
          animationScale: 1,
          monoFamily: 'JetBrains Mono',
          uiFamily: 'Inter',
        ),
        dialogKeyboardHost:
            (BuildContext context, DialogSpec spec, Widget surface) =>
                DialogKeyboardHost(
                  barrierDismissible: spec.barrierDismissible,
                  onSubmit: spec.onSubmit,
                  child: surface,
                ),
        app: ContentPort(child ?? const SizedBox.shrink()),
      ),
      home: Scaffold(
        body: Center(
          child: BaseDateField(
            label: 'Created after',
            value: DateTime(2026, 1, 15),
            onChanged: _ignoreTheAnswer,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final ThemeData host = Theme.of(tester.element(find.byType(BaseDateField)));

  // Opened the way a user opens it: by tapping the field.
  await tester.tap(find.byType(BaseDateField));
  await tester.pumpAndSettle();

  expect(
    find.byType(DatePickerDialog),
    findsOneWidget,
    reason:
        'tapping the date field did not open a picker, so there is no theme '
        'to inspect - the field is no longer reaching the member that owns it',
  );
  return (host, Theme.of(tester.element(find.byType(DatePickerDialog))));
}

/// The field under test reports its answer to nobody; the picker's theme is
/// the whole subject here.
void _ignoreTheAnswer(DateTime? value) {}

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
        'no input border at all - either the skin stopped configuring one, or '
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

  for (final brightness in <(String, Brightness)>[
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    final name = brightness.$1;
    final value = brightness.$2;

    testWidgets(
      'the $name date picker inherits the configured input decoration',
      (tester) async {
        final (hostTheme, pickerTheme) = await _openThePicker(tester, value);

        final app = hostTheme.inputDecorationTheme;
        final picker = pickerTheme.inputDecorationTheme;

        // The corner. The theme configures `inputDecoratorRadius` for every
        // SDK-owned field, this one included; the framework default is no
        // border at all, which is what a substituted sub-theme leaves behind.
        final appRadius = _radiusOf(_restingBorder(app.border));
        final pickerRadius = _radiusOf(_restingBorder(picker.border));
        expect(
          pickerRadius,
          appRadius,
          reason:
              'the picker resolved a different input border from the one the '
              'field renders under - the input sub-theme was substituted '
              'rather than merged (#400)',
        );
        expect(
          pickerRadius.topLeft,
          const Radius.circular(MaterialMetrics.radiusM),
          reason:
              'the corner reaching the picker is not the one this skin names '
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
              'the skin no longer sizes its input label, so this assertion has '
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
      'the $name date picker keeps the type ramp for the two body roles',
      (tester) async {
        final (hostTheme, pickerTheme) = await _openThePicker(tester, value);

        for (final role in <(String, TextStyle?, TextStyle?)>[
          (
            'bodyLarge',
            hostTheme.textTheme.bodyLarge,
            pickerTheme.textTheme.bodyLarge,
          ),
          (
            'bodyMedium',
            hostTheme.textTheme.bodyMedium,
            pickerTheme.textTheme.bodyMedium,
          ),
        ]) {
          final label = role.$1;
          final app = role.$2;
          final picker = role.$3;

          expect(
            app?.fontSize,
            isNotNull,
            reason: 'the skin no longer sizes $label',
          );
          expect(
            picker?.fontSize,
            app?.fontSize,
            reason:
                '$label lost the font size inside the picker, so the text '
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
