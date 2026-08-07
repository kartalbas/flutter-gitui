/// Proves that the application's theme layer actually reaches the rebuilt
/// components — the "provably" in provably conformant (#341, definition of
/// done item 7).
///
/// ## The finding this suite encodes
///
/// The original defect was that `FlexSubThemesData` in
/// lib/shared/theme/app_theme.dart configured a shelf of component tokens that
/// never arrived anywhere, because the `Base*` components hand-painted
/// themselves out of `Material` + `InkWell` + `Container` and inherited no
/// Material 3 defaults at all. The definition of done asks for the inverse
/// demonstration: change a token, see a golden move.
///
/// Measuring the current tree rather than assuming, three things are true —
/// each verified by a test below:
///
/// 1. **`elevatedButtonRadius`, `outlinedButtonRadius` and `textButtonRadius`
///    are discarded before any widget can see them.** `FlexThemeData` turns
///    them into `elevatedButtonTheme` / `outlinedButtonTheme` /
///    `textButtonTheme`, and `app_theme.dart:69-77` then *replaces* all three
///    `…ThemeData` objects wholesale with `…ButtonThemeData(style:
///    …styleFrom(textStyle: …))`. `copyWith` on `ThemeData` substitutes a
///    sub-theme, it does not merge into it, so the shape those tokens produced
///    is gone from the built `ThemeData`. The same happens to
///    `inputDecoratorRadius` at `app_theme.dart:78-88`. This is asserted
///    directly in `the app theme discards …` below, so the day it is fixed the
///    assertion fails and this comment gets corrected instead of rotting.
///
/// 2. **`filledButtonRadius` survives into the theme but still does not reach
///    `BaseButton`.** `ButtonStyleButton` resolves every property as
///    `widget.style ?? themeStyleOf(context) ?? defaultStyleOf(context)`, and
///    `BaseButton` pins `shape` on the widget (base_button.dart:321-325) to the
///    `AppTheme.radiusM` control corner, deliberately — the pin is what keeps
///    the registered BTN-001 deviation deterministic under an app theme that
///    also carries FlexColorScheme radii and a comfortable visual density.
///    Widget style wins, so the sub-theme value is inert.
///
/// 3. **What *does* reach the rebuilt buttons is `textTheme` and
///    `colorScheme`.** `BaseButton` reads `Theme.of(context).textTheme` for its
///    label role (base_button.dart:287-305) and `Theme.of(context).colorScheme`
///    for every variant's container and foreground (`_variantStyle`,
///    base_button.dart:165-230). Both are configured in `app_theme.dart` —
///    `textTheme: _getTextTheme(fontFamily, fontSize)` and the `FlexScheme` the
///    colour setting maps onto — and both are parameters of
///    `AppTheme.lightTheme`, so a test can change them and watch the rendering
///    follow.
///
/// ## Why direct assertions rather than a golden diff
///
/// Both were on the table. A golden diff proves the change visually, which is
/// what the definition of done literally asks for, and the component baselines
/// do exactly that: `base_button_variants_light.png` and the twenty-odd other
/// button images are all rendered from `AppTheme.radiusM` and the app's text
/// theme, so changing either moves them.
///
/// But a golden is a poor *primary* mechanism for this particular claim,
/// because its failure output is "0.8% of pixels differ" plus three PNGs.
/// That says something changed; it does not say the token stopped reaching the
/// component, and it cannot distinguish "the corner moved" from "the label got
/// a pixel taller". The assertions here fail with the sentence a maintainer
/// needs — which token, which value the theme carries, which value the widget
/// rendered, and where the two are wired together. So the split is deliberate:
/// **the assertions are the diagnosis, the baselines are the visual evidence**,
/// and this file names the baselines that move so nobody has to guess.
///
/// These tests are not goldens and carry no platform guard: they measure
/// resolved values, not rasterised pixels, so they run everywhere.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_filter_chip.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  group('theme tokens that reach the rebuilt buttons', () {
    testWidgets(
      "BaseButton's label follows the theme's label roles at every font-size "
      'setting',
      (WidgetTester tester) async {
        final Map<AppFontSize, double> renderedMediumSizes =
            <AppFontSize, double>{};

        for (final AppFontSize setting in AppFontSize.values) {
          final ThemeData theme = AppTheme.lightTheme(fontSize: setting);

          await _pump(
            tester,
            theme,
            const BaseButton(onPressed: _noop, label: 'Commit'),
          );
          final double medium = _renderedLabelSize(tester, 'Commit');
          expect(
            medium,
            theme.textTheme.labelLarge!.fontSize,
            reason:
                'A medium BaseButton must render the theme\'s labelLarge role. '
                'It reads it from Theme.of(context).textTheme at '
                'base_button.dart:293-298, so a mismatch means the label style '
                'stopped following the app theme.',
          );
          renderedMediumSizes[setting] = medium;

          await _pump(
            tester,
            theme,
            const BaseButton(
              onPressed: _noop,
              label: 'Commit',
              size: ButtonSize.small,
            ),
          );
          expect(
            _renderedLabelSize(tester, 'Commit'),
            theme.textTheme.labelMedium!.fontSize,
            reason:
                'A small BaseButton must render the theme\'s labelMedium role '
                '(registered BTN-003).',
          );
        }

        // Without this the assertions above would also hold for a component
        // that ignores the theme entirely and happens to be compared against
        // a theme that never changes. Four distinct rendered sizes for four
        // settings is what makes the token demonstrably live.
        expect(
          renderedMediumSizes.values.toSet(),
          hasLength(AppFontSize.values.length),
          reason:
              'Each font-size setting must produce a distinct rendered button '
              'label size; identical sizes would mean the setting never '
              'reaches the button. Sizes were $renderedMediumSizes.',
        );
      },
    );

    testWidgets(
      "BaseButton's container follows the theme's colorScheme.primary",
      (WidgetTester tester) async {
        final Set<int> renderedFills = <int>{};

        for (final AppColorScheme scheme in <AppColorScheme>[
          AppColorScheme.deepPurple,
          AppColorScheme.blue,
          AppColorScheme.green,
        ]) {
          final ThemeData theme = AppTheme.lightTheme(colorScheme: scheme);
          await _pump(
            tester,
            theme,
            const BaseButton(onPressed: _noop, label: 'Commit'),
          );
          final Color fill = _container(tester, find.byType(BaseButton)).color!;
          expect(
            fill.toARGB32(),
            theme.colorScheme.primary.toARGB32(),
            reason:
                'The primary variant fills its container with '
                'colorScheme.primary (base_button.dart:175-181), so the '
                'rendered fill must follow the theme\'s colour scheme.',
          );
          renderedFills.add(fill.toARGB32());
        }

        expect(
          renderedFills,
          hasLength(3),
          reason:
              'Three colour schemes must render three distinct button fills; '
              'identical fills would mean the scheme never reaches the button.',
        );
      },
    );
  });

  group('the shared control corner is a token, not a literal', () {
    testWidgets('every BaseButton variant and size renders AppTheme.radiusM', (
      WidgetTester tester,
    ) async {
      for (final ButtonVariant variant in ButtonVariant.values) {
        for (final ButtonSize size in ButtonSize.values) {
          await _pump(
            tester,
            AppTheme.lightTheme(),
            BaseButton(
              onPressed: _noop,
              label: 'Commit',
              variant: variant,
              size: size,
            ),
          );
          expect(
            _renderedCornerRadius(tester, find.byType(BaseButton)),
            AppTheme.radiusM,
            reason:
                'BaseButton($variant, $size) must render the shared control '
                'corner AppTheme.radiusM (BTN-001). This is the token the '
                'button baselines are drawn from: changing AppTheme.radiusM '
                'moves this assertion and every base_button_* and '
                'base_icon_button_* golden with it.',
          );
        }
      }
    });

    testWidgets(
      'every BaseIconButton variant and size renders AppTheme.radiusM',
      (WidgetTester tester) async {
        for (final ButtonVariant variant in ButtonVariant.values) {
          for (final ButtonSize size in ButtonSize.values) {
            await _pump(
              tester,
              AppTheme.lightTheme(),
              BaseIconButton(
                onPressed: _noop,
                icon: PhosphorIconsRegular.trash,
                tooltip: 'Delete',
                variant: variant,
                size: size,
              ),
            );
            expect(
              _renderedCornerRadius(tester, find.byType(BaseIconButton)),
              AppTheme.radiusM,
              reason:
                  'BaseIconButton($variant, $size) must render the shared '
                  'control corner AppTheme.radiusM (ICO-001).',
            );
          }
        }
      },
    );
  });

  group('sub-theme radius tokens agree with what the components render', () {
    // The tokens configured in FlexSubThemesData that describe a corner a
    // Base component also draws. If one of them is edited in the expectation
    // that the UI follows, these tests are what says otherwise — with the
    // reason, instead of the edit silently doing nothing.
    //
    // `inputDecoratorRadius` is deliberately absent: the input components
    // render AppTheme.radiusS (base_text_field.dart:319-323), a registered
    // divergence from the 8 dp the token names, so binding the two here would
    // assert a value the design system has already decided against.

    testWidgets(
      'the app theme carries the filled-button corner BaseButton renders',
      (WidgetTester tester) async {
        final ThemeData theme = AppTheme.lightTheme();
        final OutlinedBorder? themeShape = theme.filledButtonTheme.style?.shape
            ?.resolve(const <WidgetState>{});
        expect(
          themeShape,
          isA<RoundedRectangleBorder>(),
          reason:
              'FlexSubThemesData.filledButtonRadius (app_theme.dart:35) is '
              'expected to survive into filledButtonTheme as a rounded shape.',
        );

        await _pump(
          tester,
          theme,
          const BaseButton(onPressed: _noop, label: 'Commit'),
        );
        expect(
          _cornerRadiusOf(themeShape! as RoundedRectangleBorder),
          _renderedCornerRadius(tester, find.byType(BaseButton)),
          reason:
              'The corner the app theme configures for filled buttons and the '
              'corner BaseButton actually renders must be the same number. '
              'They are wired together only by convention: BaseButton pins its '
              'shape on the widget (base_button.dart:321-325) and widget style '
              'beats themeStyleOf, so the sub-theme value is inert. If this '
              'fails because filledButtonRadius was changed, the change had no '
              'visible effect — either change AppTheme.radiusM instead, or '
              'remove the widget-level pin so the sub-theme reaches the '
              'button.',
        );
      },
    );

    testWidgets(
      'the app theme carries the chip corner BaseFilterChip renders',
      (WidgetTester tester) async {
        final ThemeData theme = AppTheme.lightTheme();
        final ShapeBorder? themeShape = theme.chipTheme.shape;
        expect(
          themeShape,
          isA<RoundedRectangleBorder>(),
          reason:
              'FlexSubThemesData.chipRadius (app_theme.dart:41) is expected to '
              'survive into chipTheme as a rounded shape.',
        );

        await _pump(
          tester,
          theme,
          BaseFilterChip(
            label: 'Modified',
            selected: false,
            onSelected: (bool _) {},
          ),
        );
        final RoundedRectangleBorder rendered =
            tester.widget<RawChip>(find.byType(RawChip)).shape!
                as RoundedRectangleBorder;
        expect(
          _cornerRadiusOf(themeShape! as RoundedRectangleBorder),
          _cornerRadiusOf(rendered),
          reason:
              'The corner the app theme configures for chips and the corner '
              'BaseFilterChip pins (base_filter_chip.dart:11) must be the same '
              'number, for the same reason as the filled button above.',
        );
      },
    );

    test(
      'the app theme discards the elevated, outlined, text and input radii',
      () {
        // This is a characterisation of a known defect, kept as an executable
        // assertion rather than as a comment so it cannot rot: `app_theme.dart`
        // replaces four sub-themes wholesale after FlexColorScheme built them,
        // which throws away the radius each of those tokens produced. The day
        // the replacement is turned into a merge, this test fails and both the
        // library comment above and the tokens themselves get revisited.
        final ThemeData theme = AppTheme.lightTheme();
        expect(
          theme.elevatedButtonTheme.style?.shape,
          isNull,
          reason:
              'elevatedButtonRadius (app_theme.dart:34) is discarded by the '
              'elevatedButtonTheme replacement at app_theme.dart:72-74. If a '
              'shape is present now, the replacement was fixed: wire the token '
              'to the component it should govern and update this suite.',
        );
        expect(
          theme.outlinedButtonTheme.style?.shape,
          isNull,
          reason:
              'outlinedButtonRadius (app_theme.dart:36) is discarded by the '
              'outlinedButtonTheme replacement at app_theme.dart:75-77.',
        );
        expect(
          theme.textButtonTheme.style?.shape,
          isNull,
          reason:
              'textButtonRadius (app_theme.dart:37) is discarded by the '
              'textButtonTheme replacement at app_theme.dart:69-71.',
        );
        expect(
          theme.inputDecorationTheme.border,
          isNull,
          reason:
              'inputDecoratorRadius (app_theme.dart:38) is discarded by the '
              'inputDecorationTheme replacement at app_theme.dart:78-88.',
        );
      },
    );
  });
}

/// Pumps [child] under an explicitly supplied [theme].
///
/// The shared `pumpConformance` harness builds the theme itself, which is
/// exactly what this suite must not do: the point here is to vary a theme
/// token and watch the rendering follow.
Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      // Every test here pumps the same tree several times with a different
      // theme each time, and `MaterialApp` cross-fades a theme change through
      // `AnimatedTheme` over 200 ms by default. Measuring one frame after the
      // swap would therefore read a *lerped* theme — a colour halfway between
      // two schemes, a font size halfway between two settings — and the
      // failure would look like the token not reaching the component when in
      // fact the transition simply had not finished. Zero makes each pump show
      // exactly the theme it was given.
      themeAnimationDuration: Duration.zero,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  // The button's own implicit animations need the same treatment for the same
  // reason: `ButtonStyleButton` wraps its label in an `AnimatedDefaultTextStyle`
  // and its container in an animated `Material`, both running for
  // `kThemeChangeDuration` (200 ms). Re-pumping the same widget type with a new
  // style updates the element in place, so those animations start from the
  // previous frame's values and one pump would measure the midpoint. 300 ms is
  // past the end of every one of them; nothing in this suite animates
  // indefinitely, so the pump terminates.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The `Material` that paints a button's visual container.
///
/// Searched below [of] rather than globally, because the `MaterialApp` and the
/// `Scaffold` each contribute a `Material` of their own that has nothing to do
/// with the component being measured.
Material _container(WidgetTester tester, Finder of) {
  return tester.widget<Material>(
    find.descendant(of: of, matching: find.byType(Material)).first,
  );
}

/// The corner radius the button's container actually paints with.
double _renderedCornerRadius(WidgetTester tester, Finder of) {
  final ShapeBorder? shape = _container(tester, of).shape;
  if (shape is RoundedRectangleBorder) {
    return _cornerRadiusOf(shape);
  }
  fail(
    'The button container carries no rounded shape; cannot measure its '
    'corner radius (shape was $shape).',
  );
}

double _cornerRadiusOf(RoundedRectangleBorder shape) {
  final BorderRadiusGeometry radius = shape.borderRadius;
  if (radius is BorderRadius) {
    return radius.topLeft.x;
  }
  fail('Unsupported border radius geometry: $radius');
}

/// The font size of the label that actually paints, so `DefaultTextStyle`
/// propagation from the button style is part of the measurement rather than
/// something the test assumes.
double _renderedLabelSize(WidgetTester tester, String label) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(label),
  );
  final double? size = paragraph.text.style?.fontSize;
  if (size == null) {
    fail('The rendered label "$label" carries no font size.');
  }
  return size;
}

/// A callback that does nothing; nothing in this suite fires one.
void _noop() {}
