/// Material 3 conformance suite for BaseButton
/// (lib/shared/components/base_button.dart).
///
/// BaseButton maps its variants onto the three Material button classes —
/// FilledButton, OutlinedButton and TextButton — so the oracles are those
/// classes' `defaultStyleOf` (m3FilledButtonDefaults and friends in the
/// harness). Geometry is measured on the **Material** box, the visual
/// container, never on the widget box: the padded tap target inflates the
/// layout box to >= 48 dp while the container stays 32/40/48.
///
/// Every measured token goes through `expectConformant`, so the six
/// BTN-001..BTN-006 entries in docs/deviation_register.yaml must keep
/// matching what the component really renders, and the conforming tokens
/// must match the oracle without an entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// The Material that paints the button's visual container. Both the old and
/// the rebuilt implementation have exactly one Material inside BaseButton.
Finder _containerFinder() {
  return find.descendant(
    of: find.byType(BaseButton),
    matching: find.byType(Material),
  );
}

Size _containerBox(WidgetTester tester) => tester.getSize(_containerFinder());

Material _container(WidgetTester tester) =>
    tester.widget<Material>(_containerFinder());

/// Reads the container's corner radius from its Material, accepting both a
/// rounded shape (ButtonStyleButton) and a raw borderRadius.
double _containerCornerRadius(WidgetTester tester) {
  final Material material = _container(tester);
  final ShapeBorder? shape = material.shape;
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  final BorderRadiusGeometry? borderRadius = material.borderRadius;
  if (borderRadius is BorderRadius) {
    return borderRadius.topLeft.x;
  }
  fail(
    'BaseButton\'s Material carries neither a rounded shape nor a '
    'borderRadius; cannot measure the corner radius.',
  );
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(BaseButton)));

/// The rendered label's TextStyle, taken from the paragraph that actually
/// paints, so DefaultTextStyle propagation is part of the measurement.
TextStyle? _renderedLabelStyle(WidgetTester tester, String label) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(label),
  );
  return paragraph.text.style;
}

/// Maps a rendered TextStyle onto one of the three label roles, the only
/// roles a Material 3 button label may use.
///
/// The harness's generic `describeTextRole` cannot be used here: this app's
/// titleSmall and labelLarge share the identical metric triple
/// (14 / 0.1 / 1.43), so a generic lookup reports a button label as
/// titleSmall and the register could never document labelLarge. Restricting
/// the candidates to the label roles keeps the mapping unambiguous.
String _labelRoleOf(ThemeData theme, TextStyle? style) {
  if (style == null) {
    return 'no explicit style (inherits DefaultTextStyle)';
  }
  final Map<String, TextStyle?> roles = <String, TextStyle?>{
    'labelLarge': theme.textTheme.labelLarge,
    'labelMedium': theme.textTheme.labelMedium,
    'labelSmall': theme.textTheme.labelSmall,
  };
  bool same(double? a, double? b) =>
      a == null || b == null ? a == b : (a - b).abs() < 0.01;
  for (final MapEntry<String, TextStyle?> role in roles.entries) {
    final TextStyle? candidate = role.value;
    if (candidate == null) {
      continue;
    }
    if (same(candidate.fontSize, style.fontSize) &&
        same(candidate.letterSpacing, style.letterSpacing) &&
        same(candidate.height, style.height)) {
      return role.key;
    }
  }
  return 'no label role (fontSize ${style.fontSize}, '
      'letterSpacing ${style.letterSpacing}, height ${style.height})';
}

/// The ink color a state layer is painted with: the overlay color quantised
/// to the 8-bit alpha the InkHighlight animation ends on.
Color _paintedInk(Color overlay) =>
    overlay.withAlpha((overlay.a * 255.0).round());

void main() {
  group('variant to Material class mapping', () {
    const Map<ButtonVariant, Type> mapping = <ButtonVariant, Type>{
      ButtonVariant.primary: FilledButton,
      ButtonVariant.danger: FilledButton,
      ButtonVariant.success: FilledButton,
      ButtonVariant.secondary: OutlinedButton,
      ButtonVariant.dangerSecondary: OutlinedButton,
      ButtonVariant.tertiary: TextButton,
      ButtonVariant.ghost: TextButton,
    };

    for (final MapEntry<ButtonVariant, Type> entry in mapping.entries) {
      testWidgets('${entry.key.name} builds a ${entry.value}', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseButton(label: 'Map', variant: entry.key, onPressed: () {}),
        );
        expect(
          find.descendant(
            of: find.byType(BaseButton),
            matching: find.byType(entry.value),
          ),
          findsOneWidget,
        );
      });
    }
  });

  group('container geometry (Material box)', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('container height (${size.name})', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseButton(label: 'Height', size: size, onPressed: () {}),
        );
        final ButtonStyle oracle = m3FilledButtonDefaults(tester);
        expectConformant(
          token: 'BaseButton.${size.name}.containerHeight',
          component: 'BaseButton.${size.name}',
          measured: _containerBox(tester).height,
          expected: oracle.minimumSize!.resolve(const <WidgetState>{})!.height,
        );
      });
    }

    testWidgets('minimum width (medium)', (WidgetTester tester) async {
      // A one-character label keeps the content narrower than the minimum,
      // so the measured width IS the minimum width.
      await pumpConformance(tester, BaseButton(label: 'X', onPressed: () {}));
      final ButtonStyle oracle = m3FilledButtonDefaults(tester);
      expectConformant(
        token: 'BaseButton.medium.minimumWidth',
        component: 'BaseButton.medium',
        measured: _containerBox(tester).width,
        expected: oracle.minimumSize!.resolve(const <WidgetState>{})!.width,
      );
    });

    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Shape', onPressed: () {}),
      );
      final ButtonStyle oracle = m3FilledButtonDefaults(tester);
      expectConformant(
        token: 'BaseButton.shape',
        component: 'BaseButton',
        measured: _containerCornerRadius(tester),
        expected: m3CornerRadius(
          oracle.shape!.resolve(const <WidgetState>{})!,
          containerHeight: oracle.minimumSize!
              .resolve(const <WidgetState>{})!
              .height,
        ),
      );
    });
  });

  group('label typography', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('label text role (${size.name})', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseButton(label: 'Typography', size: size, onPressed: () {}),
        );
        final ThemeData theme = _theme(tester);
        final TextStyle? oracleStyle = m3FilledButtonDefaults(
          tester,
        ).textStyle!.resolve(const <WidgetState>{});
        expectConformant(
          token: 'BaseButton.${size.name}.labelTextStyle',
          component: 'BaseButton.${size.name}',
          measured: _labelRoleOf(
            theme,
            _renderedLabelStyle(tester, 'Typography'),
          ),
          expected: _labelRoleOf(theme, oracleStyle),
          unit: '',
        );
      });
    }
  });

  group('icon size', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('leading icon size (${size.name})', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseButton(
            label: 'Icon',
            size: size,
            leadingIcon: IconRole.plus,
            onPressed: () {},
          ),
        );
        final ButtonStyle oracle = m3FilledButtonDefaults(tester);
        expectConformant(
          token: 'BaseButton.${size.name}.iconSize',
          component: 'BaseButton.${size.name}',
          measured: tester
              .getSize(find.byIcon(MaterialGlyphs.of(IconRole.plus)))
              .height,
          expected: oracle.iconSize!.resolve(const <WidgetState>{})!,
        );
      });
    }

    testWidgets('trailing icon gets the same size as the leading icon', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Both',
          leadingIcon: IconRole.plus,
          trailingIcon: IconRole.caretRight,
          onPressed: () {},
        ),
      );
      expect(
        tester.getSize(find.byIcon(MaterialGlyphs.of(IconRole.caretRight))),
        tester.getSize(find.byIcon(MaterialGlyphs.of(IconRole.plus))),
      );
    });
  });

  group('foreground color roles', () {
    testWidgets('tertiary adopts the primary-colored M3 text button', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Tertiary',
          variant: ButtonVariant.tertiary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color measured = tester
          .widget<TextButton>(find.byType(TextButton))
          .style!
          .foregroundColor!
          .resolve(const <WidgetState>{})!;
      final Color oracle = m3TextButtonDefaults(
        tester,
      ).foregroundColor!.resolve(const <WidgetState>{})!;
      expectConformant(
        token: 'BaseButton.tertiary.foregroundRole',
        component: 'BaseButton.tertiary',
        measured: colorRoleName(scheme, measured),
        expected: colorRoleName(scheme, oracle),
        unit: '',
      );
    });

    testWidgets('ghost stays neutral (BTN-006)', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Ghost',
          variant: ButtonVariant.ghost,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color measured = tester
          .widget<TextButton>(find.byType(TextButton))
          .style!
          .foregroundColor!
          .resolve(const <WidgetState>{})!;
      final Color oracle = m3TextButtonDefaults(
        tester,
      ).foregroundColor!.resolve(const <WidgetState>{})!;
      expectConformant(
        token: 'BaseButton.ghost.foregroundRole',
        component: 'BaseButton.ghost',
        measured: colorRoleName(scheme, measured),
        expected: colorRoleName(scheme, oracle),
        unit: '',
      );
    });
  });

  group('semantic variant colors', () {
    testWidgets('danger fills with the error roles', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Danger',
          variant: ButtonVariant.danger,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(
        style.backgroundColor!.resolve(const <WidgetState>{}),
        scheme.error,
      );
      expect(
        style.foregroundColor!.resolve(const <WidgetState>{}),
        scheme.onError,
      );
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('success fills with gitColors.added (${brightness.name})', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseButton(
            label: 'Success',
            variant: ButtonVariant.success,
            onPressed: () {},
          ),
          brightness: brightness,
        );
        final GitSemanticColors gitColors = brightness == Brightness.light
            ? GitSemanticColors.light
            : GitSemanticColors.dark;
        final ButtonStyle style = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!;
        expect(
          style.backgroundColor!.resolve(const <WidgetState>{}),
          gitColors.added,
        );
        expect(
          style.foregroundColor!.resolve(const <WidgetState>{}),
          GitSemanticColors.foregroundOn(gitColors.added),
        );
      });
    }

    testWidgets('secondary keeps the stock outlined silhouette', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Secondary',
          variant: ButtonVariant.secondary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(
        style.foregroundColor!.resolve(const <WidgetState>{}),
        scheme.primary,
      );
      // The border is deliberately NOT pinned at the widget, so the M3
      // default side applies: outline enabled, primary focused, and
      // onSurface at 12% disabled. The rendered Material carries it.
      final ShapeBorder shape = _container(tester).shape!;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape as RoundedRectangleBorder).side.color,
        m3OutlinedButtonDefaults(
          tester,
        ).side!.resolve(const <WidgetState>{})!.color,
      );
    });

    testWidgets('dangerSecondary outlines with error, disabled border stays '
        'M3', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Remove',
          variant: ButtonVariant.dangerSecondary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(
        style.foregroundColor!.resolve(const <WidgetState>{}),
        scheme.error,
      );
      expect(style.side!.resolve(const <WidgetState>{})!.color, scheme.error);
      // The error tint must never survive into the disabled treatment.
      expect(
        style.side!.resolve(const <WidgetState>{WidgetState.disabled})!.color,
        scheme.onSurface.withValues(alpha: 0.12),
      );
    });
  });

  group('disabled state', () {
    testWidgets('disabled container and foreground use the M3 treatment', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Disabled', isDisabled: true, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle oracle = m3FilledButtonDefaults(tester);
      expectConformant(
        token: 'BaseButton.disabled.containerColor',
        component: 'BaseButton.disabled',
        measured: colorRoleName(scheme, _container(tester).color!),
        expected: colorRoleName(
          scheme,
          oracle.backgroundColor!.resolve(const <WidgetState>{
            WidgetState.disabled,
          })!,
        ),
        unit: '',
      );
      expectConformant(
        token: 'BaseButton.disabled.foregroundColor',
        component: 'BaseButton.disabled',
        measured: colorRoleName(
          scheme,
          _renderedLabelStyle(tester, 'Disabled')!.color!,
        ),
        expected: colorRoleName(
          scheme,
          oracle.foregroundColor!.resolve(const <WidgetState>{
            WidgetState.disabled,
          })!,
        ),
        unit: '',
      );
    });

    testWidgets('a disabled button does not fire onPressed', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Disabled',
          isDisabled: true,
          onPressed: () => pressed++,
        ),
      );
      await tester.tap(find.byType(BaseButton), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
    });
  });

  group('state layers', () {
    testWidgets('configured overlay matches the M3 opacities', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Overlay', onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      final ButtonStyle oracle = m3FilledButtonDefaults(tester);
      const Map<String, WidgetState> states = <String, WidgetState>{
        'pressed': WidgetState.pressed,
        'hovered': WidgetState.hovered,
        'focused': WidgetState.focused,
      };
      for (final MapEntry<String, WidgetState> entry in states.entries) {
        expectConformant(
          token: 'BaseButton.overlay.${entry.key}',
          component: 'BaseButton',
          measured: colorRoleName(
            scheme,
            style.overlayColor!.resolve(<WidgetState>{entry.value})!,
          ),
          expected: colorRoleName(
            scheme,
            oracle.overlayColor!.resolve(<WidgetState>{entry.value})!,
          ),
          unit: '',
        );
      }
    });

    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Hover', onPressed: () {}),
      );
      final Color overlay = m3FilledButtonDefaults(
        tester,
      ).overlayColor!.resolve(const <WidgetState>{WidgetState.hovered})!;
      await hoverOver(tester, find.byType(BaseButton));
      expect(inkFeatures(tester), paints..rect(color: _paintedInk(overlay)));
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Press', onPressed: () {}),
      );
      final Color overlay = m3FilledButtonDefaults(
        tester,
      ).overlayColor!.resolve(const <WidgetState>{WidgetState.pressed})!;
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(BaseButton),
      );
      // pressAndHold's pump only starts the highlight's fade-in ticker (its
      // first tick is at elapsed zero); one more pump completes the fade.
      await tester.pump(const Duration(milliseconds: 200));
      // The splash (InkSparkle) paints its own shader rect before the
      // pressed highlight; the first unconstrained rect step consumes it.
      expect(
        inkFeatures(tester),
        paints
          ..rect()
          ..rect(color: _paintedInk(overlay)),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('keyboard operation', () {
    testWidgets('focus overlay paints after Tab reaches the button', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Focus', onPressed: () {}),
      );
      final Color overlay = m3FilledButtonDefaults(
        tester,
      ).overlayColor!.resolve(const <WidgetState>{WidgetState.focused})!;
      await focusFirstWithTab(tester);
      expect(
        tester.binding.focusManager.primaryFocus,
        isNotNull,
        reason: 'Tab must move focus onto the button',
      );
      expect(
        inkFeatures(tester),
        paints..rect(color: _paintedInk(overlay)),
        reason: 'the focused button must paint the M3 focus state layer',
      );
    });

    testWidgets('Enter and Space each fire onPressed', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await pumpConformance(
        tester,
        BaseButton(label: 'Confirm', onPressed: () => pressed++),
      );
      await focusFirstWithTab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(pressed, 1, reason: 'Enter must activate the focused button');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(pressed, 2, reason: 'Space must activate the focused button');
    });
  });

  group('tap targets', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('meets the Android tap target guideline (${size.name})', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpConformance(
          tester,
          BaseButton(label: 'Target', size: size, onPressed: () {}),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('small keeps its compact container inside a 48 dp hit area', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'S', size: ButtonSize.small, onPressed: () {}),
      );
      final Size layoutBox = tester.getSize(find.byType(BaseButton));
      expect(layoutBox.height, greaterThanOrEqualTo(48.0));
      expect(layoutBox.width, greaterThanOrEqualTo(48.0));
      expect(_containerBox(tester).height, lessThan(layoutBox.height));
    });
  });

  group('loading state', () {
    testWidgets('loading disables the button and paints the spinner in the '
        'disabled foreground', (WidgetTester tester) async {
      int pressed = 0;
      await pumpConformance(
        tester,
        BaseButton(
          label: 'Loading',
          isLoading: true,
          onPressed: () => pressed++,
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(BaseButton), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
      final ColorScheme scheme = _theme(tester).colorScheme;
      final CircularProgressIndicator spinner = tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
      expect(
        spinner.valueColor?.value,
        scheme.onSurface.withValues(alpha: 0.38),
      );
      expect(find.text('Loading'), findsOneWidget);
    });
  });

  group('full width', () {
    testWidgets('fullWidth stretches the layout box to the parent width', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseButton(label: 'Wide', fullWidth: true, onPressed: () {}),
      );
      expect(
        tester.getSize(find.byType(BaseButton)).width,
        kConformanceSurface.width,
      );
    });
  });
}
