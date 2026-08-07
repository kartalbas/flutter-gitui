/// Proves that the application's theme layer actually reaches the rebuilt
/// components — the "provably" in provably conformant (#341, definition of
/// done item 7).
///
/// ## What this suite has to establish
///
/// #341's central complaint was that the sub-theme configuration in
/// lib/shared/theme/app_theme.dart is *dead*: a shelf of tokens that arrives
/// nowhere. Item 7 makes that measurable by demanding the inverse — change a
/// token, see a component change — and #399 found the token→widget chain
/// broken in three independent places at once:
///
///   1. `ThemeData.copyWith` *substitutes* a sub-theme instead of merging into
///      it, so applying `textButtonTheme` / `elevatedButtonTheme` /
///      `outlinedButtonTheme` / `inputDecorationTheme` after `FlexThemeData`
///      had built them threw away everything `FlexSubThemesData` configured
///      for those four — including their corner radius.
///   2. `elevatedButtonRadius` could not have reached `BaseButton` in any
///      case: the component builds `FilledButton` / `OutlinedButton` /
///      `TextButton` and never an `ElevatedButton`.
///   3. `BaseButton` pinned `shape` on the widget, and `ButtonStyleButton`
///      resolves `widget.style` before `themeStyleOf(context)`, so even the
///      one token that survived the first two links (`filledButtonRadius`)
///      was inert.
///
/// All three are fixed: the four sub-themes are merged (`AppTheme._layerOn`),
/// the radii are configured from the `AppTheme.radius*` corner scale so one
/// edit moves every rung that uses it, and `BaseButton` no longer pins
/// `shape`. This suite is the proof, and it is written so that it fails —
/// naming the site and the reason — if any of the three regresses.
///
/// ## The shape of the proof
///
/// A reach claim is only worth asserting if the assertion could not also pass
/// for a component that ignores the theme entirely. Every group below is
/// therefore built from two halves:
///
///   * an **agreement** assertion, that the number the theme carries and the
///     number the component renders are the same number; and
///   * a **distinctness** guard, that feeding the theme *several different*
///     values produces correspondingly different renderings.
///
/// The agreement assertion alone is satisfiable by coincidence — a component
/// with a hard-coded 8 dp corner agrees with an 8 dp token forever. The
/// distinctness guard is what turns agreement into causation, and it is the
/// part that must be kept whenever a group is extended.
///
/// ## Why direct assertions rather than a golden diff
///
/// Both were on the table. A golden diff proves the change visually, which is
/// what the definition of done literally asks for, and the component baselines
/// do exactly that: `base_button_variants_light.png` and the twenty-odd other
/// button images are drawn from the corner the theme configures and from the
/// app's text theme, so changing either moves them.
///
/// But a golden is a poor *primary* mechanism for this particular claim,
/// because its failure output is "0.8% of pixels differ" plus three PNGs.
/// That says something changed; it does not say the token stopped reaching the
/// component, and it cannot distinguish "the corner moved" from "the label got
/// a pixel taller". The assertions here fail with the sentence a maintainer
/// needs — which token, which value the theme carries, which value the widget
/// rendered, and where the two are wired together. So the split is deliberate:
/// **the assertions are the diagnosis, the baselines are the visual evidence**.
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

/// The Material button family a [ButtonVariant] renders through, and with it
/// the sub-theme whose radius token governs that variant's corner. The
/// mapping mirrors `_baseOf` in base_button.dart; it is restated here so the
/// test measures against an independently written expectation rather than
/// against the component's own private table.
enum _ButtonFamily {
  filled,
  outlined,
  text;

  /// The sub-theme style [ButtonStyleButton] consults for this family.
  ButtonStyle? styleOf(ThemeData theme) => switch (this) {
    _ButtonFamily.filled => theme.filledButtonTheme.style,
    _ButtonFamily.outlined => theme.outlinedButtonTheme.style,
    _ButtonFamily.text => theme.textButtonTheme.style,
  };

  /// The `FlexSubThemesData` token that configures this family's corner.
  String get radiusToken => switch (this) {
    _ButtonFamily.filled => 'filledButtonRadius',
    _ButtonFamily.outlined => 'outlinedButtonRadius',
    _ButtonFamily.text => 'textButtonRadius',
  };
}

const Map<ButtonVariant, _ButtonFamily> _familyOf =
    <ButtonVariant, _ButtonFamily>{
      ButtonVariant.primary: _ButtonFamily.filled,
      ButtonVariant.danger: _ButtonFamily.filled,
      ButtonVariant.success: _ButtonFamily.filled,
      ButtonVariant.secondary: _ButtonFamily.outlined,
      ButtonVariant.dangerSecondary: _ButtonFamily.outlined,
      ButtonVariant.tertiary: _ButtonFamily.text,
      ButtonVariant.ghost: _ButtonFamily.text,
    };

void main() {
  test('every button variant is mapped to a Material family', () {
    // A variant added without an entry above would otherwise be skipped by
    // the corner assertions instead of failing them, and the new variant's
    // corner would go unmeasured.
    expect(
      _familyOf.keys.toSet(),
      ButtonVariant.values.toSet(),
      reason:
          'Add the new ButtonVariant to _familyOf, naming the Material button '
          'family it renders through, so its corner is measured against the '
          "sub-theme that governs it rather than against another family's.",
    );
  });

  group('the built theme carries every corner token it configures', () {
    // This group is the direct inverse of the characterisation test #399
    // removed. That test asserted `elevatedButtonTheme.style?.shape` was
    // null, because the sub-theme had been replaced wholesale; these assert
    // the configured radius is readable off the built ThemeData instead.
    for (final MapEntry<String, ThemeData Function()> brightness
        in <String, ThemeData Function()>{
          'light': AppTheme.lightTheme,
          'dark': AppTheme.darkTheme,
        }.entries) {
      test('every button sub-theme (${brightness.key})', () {
        final ThemeData theme = brightness.value();
        for (final MapEntry<String, ButtonStyle?> entry
            in <String, ButtonStyle?>{
              'filledButtonTheme': theme.filledButtonTheme.style,
              'elevatedButtonTheme': theme.elevatedButtonTheme.style,
              'outlinedButtonTheme': theme.outlinedButtonTheme.style,
              'textButtonTheme': theme.textButtonTheme.style,
            }.entries) {
          expect(
            _themeCorner(entry.value),
            AppTheme.radiusM,
            reason:
                'The radius app_theme.dart configures for ${entry.key} must '
                'survive into the built ThemeData. A null shape here means '
                'the sub-theme was replaced rather than merged again — see '
                'AppTheme._layerOn, which exists precisely because '
                'ThemeData.copyWith substitutes a sub-theme instead of '
                'merging into it.',
          );
        }
      });

      test('the chip and input sub-themes (${brightness.key})', () {
        final ThemeData theme = brightness.value();
        final ShapeBorder? chipShape = theme.chipTheme.shape;
        expect(
          chipShape,
          isA<RoundedRectangleBorder>(),
          reason: 'chipRadius must survive into chipTheme.',
        );
        expect(
          _cornerRadiusOf(chipShape! as RoundedRectangleBorder),
          AppTheme.radiusM,
          reason:
              'Chips carry the same control corner as buttons, so chipRadius '
              'is configured from the same rung of the corner scale.',
        );
        expect(
          theme.inputDecorationTheme.border,
          isNotNull,
          reason:
              'inputDecoratorRadius is carried by inputDecorationTheme.border. '
              'A null border means the inputDecorationTheme was replaced '
              'wholesale again instead of being extended with copyWith.',
        );
      });

      test(
        'three configured radii produce three distinct shapes (${brightness.key})',
        () {
          // The distinctness guard for the readback above. Without it, every
          // assertion in this group would also pass for a theme that stamped
          // ONE radius onto every component — which is exactly what a
          // careless `defaultRadius` would do, and it would hide the fact
          // that the per-component tokens are being ignored.
          final ThemeData theme = brightness.value();
          final Map<String, double?> corners = <String, double?>{
            'filledButtonRadius': _themeCorner(theme.filledButtonTheme.style),
            'defaultRadius (cardTheme)': _shapeCorner(theme.cardTheme.shape),
            'fabRadius': _shapeCorner(theme.floatingActionButtonTheme.shape),
          };
          expect(
            corners.values.toSet(),
            hasLength(3),
            reason:
                'app_theme.dart configures three different radii — radiusM '
                'for the controls, radiusL as the default surface corner and '
                'radiusXL for the FAB — so the built theme must carry three '
                'different corners. Identical values would mean the '
                'per-component tokens are not reaching their sub-themes at '
                'all. Corners were $corners.',
          );
        },
      );
    }
  });

  group('the corner token reaches BaseButton', () {
    testWidgets(
      'every variant and size renders the corner its own sub-theme carries',
      (WidgetTester tester) async {
        final ThemeData theme = AppTheme.lightTheme();
        for (final ButtonVariant variant in ButtonVariant.values) {
          final _ButtonFamily family = _familyOf[variant]!;
          for (final ButtonSize size in ButtonSize.values) {
            await _pump(
              tester,
              theme,
              BaseButton(
                onPressed: _noop,
                label: 'Commit',
                variant: variant,
                size: size,
              ),
            );
            expect(
              _renderedCornerRadius(tester, find.byType(BaseButton)),
              _themeCorner(family.styleOf(theme)),
              reason:
                  'BaseButton($variant, $size) builds a ${family.name} '
                  'Material button, so its corner must be the one '
                  '${family.radiusToken} configures in app_theme.dart. '
                  'A mismatch means base_button.dart started pinning `shape` '
                  'on the widget again: ButtonStyleButton resolves widget '
                  'style before themeStyleOf, so a widget-level shape makes '
                  'the token unreachable no matter what it is set to.',
            );
          }
        }
      },
    );

    testWidgets(
      'three configured corners produce three distinct rendered corners',
      (WidgetTester tester) async {
        // This is the causation half. The assertion above holds by
        // coincidence for a component that hard-codes 8 dp, because the token
        // is also 8 dp; feeding the theme corners the component could not
        // have guessed is what proves the value travels rather than
        // coincides. These are probe values, deliberately unlike any rung of
        // the AppTheme corner scale.
        const List<double> probes = <double>[0.0, 3.0, 17.0];
        final Set<double> rendered = <double>{};
        for (final double probe in probes) {
          await _pump(
            tester,
            _withButtonCorner(AppTheme.lightTheme(), probe),
            const BaseButton(onPressed: _noop, label: 'Commit'),
          );
          final double corner = _renderedCornerRadius(
            tester,
            find.byType(BaseButton),
          );
          expect(
            corner,
            probe,
            reason:
                'A BaseButton under a theme whose filledButtonTheme carries a '
                '$probe dp corner must render $probe dp. This is the token '
                'reach itself: if it fails, editing filledButtonRadius in '
                'app_theme.dart changes nothing on screen.',
          );
          rendered.add(corner);
        }
        expect(
          rendered,
          hasLength(probes.length),
          reason:
              'Three different configured corners must produce three '
              'different rendered corners; identical renderings would mean '
              'the component draws its own corner and merely happens to '
              'agree with the token. Rendered $rendered.',
        );
      },
    );

    testWidgets(
      'each variant follows its own family token, not a single shared one',
      (WidgetTester tester) async {
        // BaseButton spans three Material families and app_theme.dart
        // configures a radius for each. Moving exactly one of them must move
        // exactly the variants of that family, so an editor who changes
        // outlinedButtonRadius alone learns that the filled variants did not
        // follow — rather than assuming a corner scale that is not there.
        const double probe = 19.0;
        final ThemeData base = AppTheme.lightTheme();
        final ThemeData theme = base.copyWith(
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: base.outlinedButtonTheme.style!.copyWith(
              shape: WidgetStatePropertyAll<OutlinedBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(probe),
                ),
              ),
            ),
          ),
        );

        await _pump(
          tester,
          theme,
          const BaseButton(
            onPressed: _noop,
            label: 'Commit',
            variant: ButtonVariant.secondary,
          ),
        );
        expect(
          _renderedCornerRadius(tester, find.byType(BaseButton)),
          probe,
          reason:
              'The secondary variant builds an OutlinedButton, so it must '
              'follow outlinedButtonRadius.',
        );

        await _pump(
          tester,
          theme,
          const BaseButton(onPressed: _noop, label: 'Commit'),
        );
        expect(
          _renderedCornerRadius(tester, find.byType(BaseButton)),
          AppTheme.radiusM,
          reason:
              'The primary variant builds a FilledButton, so moving '
              'outlinedButtonRadius must leave it on filledButtonRadius. If '
              'this fails, the three families collapsed onto one shape and '
              'the theme can no longer express them separately.',
        );
      },
    );
  });

  group('BaseIconButton shares the corner but not the channel', () {
    testWidgets(
      'every variant and size renders the corner the button tokens carry',
      (WidgetTester tester) async {
        final ThemeData theme = AppTheme.lightTheme();
        for (final ButtonVariant variant in ButtonVariant.values) {
          for (final ButtonSize size in ButtonSize.values) {
            await _pump(
              tester,
              theme,
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
              _themeCorner(theme.filledButtonTheme.style),
              reason:
                  'BaseIconButton($variant, $size) must render the same '
                  'control corner as BaseButton (ICO-001 and BTN-001 are the '
                  'same 8 dp). It cannot read it from the theme: '
                  'FlexSubThemesData exposes a radius token for every button '
                  'family EXCEPT the icon button, so base_button.dart pins '
                  'AppTheme.radiusM there and app_theme.dart configures the '
                  'button radii from that same rung. If this fails because a '
                  'single button token was edited, that edit moved BaseButton '
                  'and left BaseIconButton behind — edit AppTheme.radiusM '
                  'instead, which moves both.',
            );
          }
        }
      },
    );
  });

  group('the type scale reaches the rebuilt buttons', () {
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
                'It reads it from Theme.of(context).textTheme in '
                'base_button.dart, so a mismatch means the label style '
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
                'colorScheme.primary (base_button.dart, _variantStyle), so the '
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

  group('the chip corner token agrees with what BaseFilterChip renders', () {
    // `inputDecoratorRadius` has no counterpart here on purpose: the input
    // components render AppTheme.radiusS (base_text_field.dart), a registered
    // divergence from the 8 dp the token names, so binding the two would
    // assert a value the design system has already decided against.
    testWidgets(
      'the app theme carries the chip corner BaseFilterChip renders',
      (WidgetTester tester) async {
        final ThemeData theme = AppTheme.lightTheme();
        final ShapeBorder? themeShape = theme.chipTheme.shape;
        expect(themeShape, isA<RoundedRectangleBorder>());

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
              'BaseFilterChip pins (base_filter_chip.dart) must be the same '
              'number. Unlike BaseButton the chip does pin its shape, because '
              'RawChip takes a single ShapeBorder rather than a resolvable '
              'ButtonStyle; both sides therefore read AppTheme.radiusM, and '
              'this test is what stops them drifting apart.',
        );
      },
    );
  });
}

/// Replaces the corner of all three button sub-themes with [radius], leaving
/// every other property of the app theme untouched.
///
/// This is how the suite feeds the component a corner it cannot have guessed.
/// `AppTheme.lightTheme` takes no radius parameter — the corner scale is a set
/// of compile-time constants — so the token cannot be varied through the
/// factory the way `fontSize` and `colorScheme` can. Rebuilding the sub-theme
/// styles is the equivalent: it is the same channel the configured tokens
/// travel down, carrying a different value.
ThemeData _withButtonCorner(ThemeData base, double radius) {
  final WidgetStatePropertyAll<OutlinedBorder> shape =
      WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.copyWith(shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style!.copyWith(shape: shape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style!.copyWith(shape: shape),
    ),
  );
}

/// The corner radius a resolved button sub-theme carries, or null when the
/// sub-theme carries no shape at all — the state #399 found and this suite
/// now forbids.
double? _themeCorner(ButtonStyle? style) {
  return _shapeCorner(style?.shape?.resolve(const <WidgetState>{}));
}

/// The corner radius of [shape], or null when it is absent or not a rounded
/// rectangle. Returning null rather than failing lets a caller report *which*
/// sub-theme lost its shape.
double? _shapeCorner(ShapeBorder? shape) {
  if (shape is! RoundedRectangleBorder) {
    return null;
  }
  return _cornerRadiusOf(shape);
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
      // two schemes, a corner halfway between two radii — and the failure
      // would look like the token not reaching the component when in fact the
      // transition simply had not finished. Zero makes each pump show exactly
      // the theme it was given.
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
