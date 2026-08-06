/// Material 3 conformance suite for BaseIconButton
/// (lib/shared/components/base_button.dart).
///
/// BaseIconButton maps its variants onto the Material icon button
/// constructors — [IconButton], [IconButton.filled] and
/// [IconButton.outlined]. Unlike the text buttons, IconButton exposes no
/// public `defaultStyleOf` seam (harness note, conformance_harness.dart),
/// so the oracle values are pinned constants cited from the generated
/// `_IconButtonDefaultsM3` in Flutter 3.44.4
/// packages/flutter/lib/src/material/icon_button.dart. Geometry is measured
/// on the **Material** box, the visual container, never on the widget box:
/// the padded tap target inflates the layout box to >= 48 dp while the
/// container stays 32/40/48.
///
/// Every measured token goes through `expectConformant`, so the five
/// ICO-001..ICO-005 entries in docs/deviation_register.yaml must keep
/// matching what the component really renders, and the conforming tokens
/// must match the oracle without an entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

/// M3 standard icon button container: `_IconButtonDefaultsM3.minimumSize`,
/// Size(40.0, 40.0) (icon_button.dart:1128); with the 8 dp default padding
/// (:1124) around the 24 dp glyph this is also the rendered container.
const double _m3ContainerSize = 40.0;

/// M3 icon size: `_IconButtonDefaultsM3.iconSize`, 24.0
/// (icon_button.dart:1138).
const double _m3IconSize = 24.0;

/// M3 shape: `_IconButtonDefaultsM3.shape`, StadiumBorder()
/// (icon_button.dart:1146) — 20.0 dp at the 40 dp reference container.
const double _m3CornerRadius = _m3ContainerSize / 2;

/// M3 standard foreground: onSurfaceVariant
/// (`_IconButtonDefaultsM3.foregroundColor`, icon_button.dart:1082).
Color _m3Foreground(ColorScheme scheme) => scheme.onSurfaceVariant;

/// M3 standard overlay: onSurfaceVariant at pressed 10% / hovered 8% /
/// focused 10% (`_IconButtonDefaultsM3.overlayColor`,
/// icon_button.dart:1099-1107).
Color _m3Overlay(ColorScheme scheme, WidgetState state) {
  final double alpha = switch (state) {
    WidgetState.hovered => 0.08,
    _ => 0.10,
  };
  return scheme.onSurfaceVariant.withValues(alpha: alpha);
}

/// M3 disabled foreground: onSurface at 38%
/// (`_IconButtonDefaultsM3.foregroundColor`, icon_button.dart:1077).
Color _m3DisabledForeground(ColorScheme scheme) =>
    scheme.onSurface.withValues(alpha: 0.38);

/// M3 disabled filled container: onSurface at 12%
/// (`_FilledIconButtonDefaultsM3.backgroundColor`, icon_button.dart:1190).
Color _m3DisabledContainer(ColorScheme scheme) =>
    scheme.onSurface.withValues(alpha: 0.12);

/// M3 standard and outlined container: Colors.transparent
/// (`_IconButtonDefaultsM3.backgroundColor`, icon_button.dart:1071).
const Color _m3TransparentContainer = Color(0x00000000);

/// The Material that paints the button's visual container; ButtonStyleButton
/// builds exactly one inside BaseIconButton.
Finder _containerFinder() {
  return find.descendant(
    of: find.byType(BaseIconButton),
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
    'BaseIconButton\'s Material carries neither a rounded shape nor a '
    'borderRadius; cannot measure the corner radius.',
  );
}

/// The border the container renders, resolved into its Material shape.
BorderSide _containerSide(WidgetTester tester) {
  final ShapeBorder shape = _container(tester).shape!;
  return (shape as RoundedRectangleBorder).side;
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(BaseIconButton)));

/// The rendered glyph's color, taken from the RichText the Icon paints, so
/// the style's IconTheme propagation is part of the measurement.
Color? _renderedIconColor(WidgetTester tester, IconData icon) {
  final RichText glyph = tester.widget<RichText>(
    find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
  );
  return glyph.text.style?.color;
}

/// The style the rebuilt component hands to its IconButton.
ButtonStyle _style(WidgetTester tester) =>
    tester.widget<IconButton>(find.byType(IconButton)).style!;

/// The ink color a state layer is painted with: the overlay color quantised
/// to the 8-bit alpha the InkHighlight animation ends on.
Color _paintedInk(Color overlay) =>
    overlay.withAlpha((overlay.a * 255.0).round());

void main() {
  group('variant to icon button treatment mapping', () {
    testWidgets('every variant renders through IconButton', (
      WidgetTester tester,
    ) async {
      for (final ButtonVariant variant in ButtonVariant.values) {
        await pumpConformance(
          tester,
          BaseIconButton(icon: Icons.add, variant: variant, onPressed: () {}),
        );
        expect(
          find.descendant(
            of: find.byType(BaseIconButton),
            matching: find.byType(IconButton),
          ),
          findsOneWidget,
          reason: '${variant.name} must build a Material IconButton',
        );
      }
    });

    testWidgets('primary renders the filled treatment (primary/onPrimary)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.add,
          variant: ButtonVariant.primary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(_container(tester).color, scheme.primary);
      expect(_renderedIconColor(tester, Icons.add), scheme.onPrimary);
    });

    testWidgets('danger fills with the error roles', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.delete,
          variant: ButtonVariant.danger,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(_container(tester).color, scheme.error);
      expect(_renderedIconColor(tester, Icons.delete), scheme.onError);
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('success fills with gitColors.added (${brightness.name})', (
        WidgetTester tester,
      ) async {
        await pumpConformance(
          tester,
          BaseIconButton(
            icon: Icons.check,
            variant: ButtonVariant.success,
            onPressed: () {},
          ),
          brightness: brightness,
        );
        final GitSemanticColors gitColors = brightness == Brightness.light
            ? GitSemanticColors.light
            : GitSemanticColors.dark;
        expect(_container(tester).color, gitColors.added);
        expect(
          _renderedIconColor(tester, Icons.check),
          GitSemanticColors.foregroundOn(gitColors.added),
        );
      });
    }

    testWidgets('secondary renders the outlined treatment with the M3 '
        'outline side', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.edit,
          variant: ButtonVariant.secondary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(_container(tester).color, _m3TransparentContainer);
      // The border is deliberately not pinned: the M3 default side of the
      // outlined icon button already does the right thing per state
      // (outline enabled, onSurface at 12% disabled; icon_button.dart:1561).
      expect(_containerSide(tester).color, scheme.outline);
      expect(_renderedIconColor(tester, Icons.edit), scheme.onSurfaceVariant);
    });

    testWidgets('dangerSecondary outlines with error, disabled border stays '
        'M3', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.close,
          variant: ButtonVariant.dangerSecondary,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(_container(tester).color, _m3TransparentContainer);
      expect(_containerSide(tester).color, scheme.error);
      expect(_renderedIconColor(tester, Icons.close), scheme.error);
      // The error tint must never survive into the disabled treatment.
      expect(
        _style(
          tester,
        ).side!.resolve(const <WidgetState>{WidgetState.disabled})!.color,
        scheme.onSurface.withValues(alpha: 0.12),
      );
    });

    testWidgets('tertiary and ghost render the standard chrome-less '
        'treatment', (WidgetTester tester) async {
      for (final ButtonVariant variant in <ButtonVariant>[
        ButtonVariant.tertiary,
        ButtonVariant.ghost,
      ]) {
        await pumpConformance(
          tester,
          BaseIconButton(icon: Icons.menu, variant: variant, onPressed: () {}),
        );
        final ColorScheme scheme = _theme(tester).colorScheme;
        expect(
          _container(tester).color,
          _m3TransparentContainer,
          reason: '${variant.name} must not paint a container',
        );
        expect(
          _containerSide(tester),
          BorderSide.none,
          reason: '${variant.name} must not carry a border',
        );
        expect(
          _renderedIconColor(tester, Icons.menu),
          _m3Foreground(scheme),
          reason: '${variant.name} must use the stock standard foreground',
        );
      }
    });
  });

  group('container geometry (Material box)', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('container size (${size.name})', (WidgetTester tester) async {
        await pumpConformance(
          tester,
          BaseIconButton(icon: Icons.add, size: size, onPressed: () {}),
        );
        final Size box = _containerBox(tester);
        expect(box.width, box.height, reason: 'the container must be square');
        expectConformant(
          token: 'BaseIconButton.${size.name}.containerSize',
          component: 'BaseIconButton.${size.name}',
          measured: box.height,
          expected: _m3ContainerSize,
        );
      });
    }

    testWidgets('corner radius', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      expectConformant(
        token: 'BaseIconButton.shape',
        component: 'BaseIconButton',
        measured: _containerCornerRadius(tester),
        expected: _m3CornerRadius,
      );
    });
  });

  group('icon size', () {
    for (final ButtonSize size in ButtonSize.values) {
      testWidgets('glyph size (${size.name})', (WidgetTester tester) async {
        await pumpConformance(
          tester,
          BaseIconButton(icon: Icons.add, size: size, onPressed: () {}),
        );
        expectConformant(
          token: 'BaseIconButton.${size.name}.iconSize',
          component: 'BaseIconButton.${size.name}',
          measured: tester.getSize(find.byIcon(Icons.add)).height,
          expected: _m3IconSize,
        );
      });
    }
  });

  group('foreground color role', () {
    testWidgets('the default ghost adopts the standard onSurfaceVariant '
        'foreground', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color measured = _style(
        tester,
      ).foregroundColor!.resolve(const <WidgetState>{})!;
      expectConformant(
        token: 'BaseIconButton.standard.foregroundRole',
        component: 'BaseIconButton.standard',
        measured: colorRoleName(scheme, measured),
        expected: colorRoleName(scheme, _m3Foreground(scheme)),
        unit: '',
      );
      expect(_renderedIconColor(tester, Icons.add), measured);
    });
  });

  group('iconColor override', () {
    testWidgets('iconColor overrides the enabled glyph only, not the state '
        'layers', (WidgetTester tester) async {
      const Color override = Color(0xFFFFC107);
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.star, iconColor: override, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(_renderedIconColor(tester, Icons.star), override);
      // The overlay keeps deriving from the variant foreground with the M3
      // opacities, so the override never changes the button chrome. Both
      // sides go through colorRoleName because styleFrom quantises the
      // overlay alpha to 8 bit while the oracle carries the exact fraction.
      expect(
        colorRoleName(
          scheme,
          _style(
            tester,
          ).overlayColor!.resolve(const <WidgetState>{WidgetState.hovered})!,
        ),
        colorRoleName(scheme, _m3Overlay(scheme, WidgetState.hovered)),
      );
    });

    testWidgets('iconColor is ignored while disabled', (
      WidgetTester tester,
    ) async {
      const Color override = Color(0xFFFFC107);
      await pumpConformance(
        tester,
        const BaseIconButton(
          icon: Icons.star,
          iconColor: override,
          onPressed: null,
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expect(
        _renderedIconColor(tester, Icons.star),
        _m3DisabledForeground(scheme),
        reason: 'the override tint must never survive into disabled',
      );
    });
  });

  group('disabled state', () {
    testWidgets('disabled container and foreground use the M3 treatment', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.add,
          variant: ButtonVariant.primary,
          isDisabled: true,
          onPressed: () {},
        ),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      expectConformant(
        token: 'BaseIconButton.disabled.containerColor',
        component: 'BaseIconButton.disabled',
        measured: colorRoleName(scheme, _container(tester).color!),
        expected: colorRoleName(scheme, _m3DisabledContainer(scheme)),
        unit: '',
      );
      expectConformant(
        token: 'BaseIconButton.disabled.foregroundColor',
        component: 'BaseIconButton.disabled',
        measured: colorRoleName(scheme, _renderedIconColor(tester, Icons.add)!),
        expected: colorRoleName(scheme, _m3DisabledForeground(scheme)),
        unit: '',
      );
    });

    testWidgets('a disabled button does not fire onPressed', (
      WidgetTester tester,
    ) async {
      int pressed = 0;
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.add,
          isDisabled: true,
          onPressed: () => pressed++,
        ),
      );
      await tester.tap(find.byType(BaseIconButton), warnIfMissed: false);
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
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final ButtonStyle style = _style(tester);
      const Map<String, WidgetState> states = <String, WidgetState>{
        'pressed': WidgetState.pressed,
        'hovered': WidgetState.hovered,
        'focused': WidgetState.focused,
      };
      for (final MapEntry<String, WidgetState> entry in states.entries) {
        expectConformant(
          token: 'BaseIconButton.overlay.${entry.key}',
          component: 'BaseIconButton',
          measured: colorRoleName(
            scheme,
            style.overlayColor!.resolve(<WidgetState>{entry.value})!,
          ),
          expected: colorRoleName(scheme, _m3Overlay(scheme, entry.value)),
          unit: '',
        );
      }
    });

    testWidgets('hover paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color overlay = _m3Overlay(scheme, WidgetState.hovered);
      await hoverOver(tester, find.byType(BaseIconButton));
      expect(inkFeatures(tester), paints..rect(color: _paintedInk(overlay)));
    });

    testWidgets('press paints the M3 state layer', (WidgetTester tester) async {
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color overlay = _m3Overlay(scheme, WidgetState.pressed);
      final TestGesture gesture = await pressAndHold(
        tester,
        find.byType(BaseIconButton),
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
        BaseIconButton(icon: Icons.add, onPressed: () {}),
      );
      final ColorScheme scheme = _theme(tester).colorScheme;
      final Color overlay = _m3Overlay(scheme, WidgetState.focused);
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
        BaseIconButton(icon: Icons.add, onPressed: () => pressed++),
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
          BaseIconButton(
            icon: Icons.add,
            tooltip: 'Add',
            size: size,
            onPressed: () {},
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('the tooltip labels the tap target', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformance(
        tester,
        BaseIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () {}),
      );
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.byTooltip('Add'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('small keeps its compact container inside a 48 dp hit area', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        BaseIconButton(
          icon: Icons.add,
          size: ButtonSize.small,
          onPressed: () {},
        ),
      );
      final Size layoutBox = tester.getSize(find.byType(BaseIconButton));
      expect(layoutBox.height, greaterThanOrEqualTo(48.0));
      expect(layoutBox.width, greaterThanOrEqualTo(48.0));
      expect(_containerBox(tester).height, lessThan(layoutBox.height));
    });
  });
}
