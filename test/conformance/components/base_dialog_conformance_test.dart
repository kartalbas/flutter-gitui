/// Material 3 conformance suite for BaseDialog
/// (lib/shared/components/base_dialog.dart).
///
/// A dialog is not a widget in a box: its surface colour, elevation, corner,
/// minimum and maximum width and its barrier are all decided by `Dialog`'s
/// defaults resolution inside a route. Both sides are therefore pushed with
/// `showDialog` through [pumpConformanceDialog] and read with the same probes —
/// the oracle being a real `AlertDialog`, which is `Dialog` plus Material 3's
/// own title/content/actions layout.
///
/// ## Where the oracle has to be pinned instead of pumped
///
/// `Dialog` has no `defaultStyleOf` seam (`defaultStyleOf` exists only on
/// `ButtonStyleButton`), so the generated `_DialogDefaultsM3`
/// (flutter/lib/src/material/dialog.dart:1954-1998) is reached by pumping the
/// SDK widget. That works for every token the app leaves alone — and stops
/// working for the three this app's own `dialogTheme` overrides. `AppTheme`
/// configures `titleTextStyle`, `contentTextStyle` and `iconColor`
/// (lib/shared/theme/app_theme.dart:70-78 in the light theme, :184-192 in the
/// dark one), and `Dialog`/`AlertDialog` read the theme **before** the
/// defaults, so a pumped `AlertDialog` reports the app's override rather than
/// the M3 value and would measure this app against itself.
///
/// Those three tokens are therefore pinned from `_DialogDefaultsM3` with source
/// citations, exactly as the BaseIconButton suite pins `_IconButtonDefaultsM3`.
/// They are pinned as *roles* (`textTheme.headlineSmall`, `colorScheme
/// .secondary`) evaluated against the same theme, so the app's registered
/// type-scale deviations cancel out of the comparison and only the role is
/// measured.
///
/// Worth recording while reading this: BaseDialog renders its title with
/// `HeadlineSmallLabel`, which *conforms* to M3 — and therefore silently
/// contradicts the app's own `dialogTheme.titleTextStyle` of `titleLarge`,
/// which no dialog in the app ever reads. That is the #399 family of defects
/// (a configured sub-theme that reaches no widget) and belongs to
/// `app_theme.dart`, not here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

const String _title = 'Dialog title';
const String _content = 'Dialog content';
const String _first = 'Cancel';
const String _second = 'Confirm';

/// The Material 3 oracle: a stock `AlertDialog`.
///
/// `AlertDialog` is banned from UI code by the design system's
/// `avoid_alert_dialog` rule. Here it is not shipped UI but the ruler this
/// suite measures against, which is why the rule is suppressed at this single
/// construction — as is `avoid_text_button` for the stock actions, whose
/// geometry is what M3's action row is defined in terms of.
Widget _oracleDialog({
  IconData? icon,
  bool withActions = true,
  Widget? content,
}) {
  // ignore: avoid_alert_dialog
  return AlertDialog(
    icon: icon == null ? null : Icon(icon),
    title: const Text(_title),
    content: content ?? const Text(_content),
    actions: withActions
        ? <Widget>[
            // ignore: avoid_text_button
            TextButton(onPressed: () {}, child: const Text(_first)),
            // ignore: avoid_text_button
            TextButton(onPressed: () {}, child: const Text(_second)),
          ]
        : null,
  );
}

/// The component under measurement.
///
/// `barrierDismissible: false` is the default here so the title row holds
/// nothing but the title. BaseDialog puts a close button in that row, which
/// makes the row taller than its text and would turn every padding measured
/// from the title into a measurement of the close button's height instead. The
/// close button is measured on its own, in the tap-target group below.
Widget _baseDialog({
  IconData? icon,
  DialogVariant variant = DialogVariant.normal,
  bool withActions = true,
  Widget? content,
  bool barrierDismissible = false,
}) {
  return BaseDialog(
    title: _title,
    icon: icon,
    variant: variant,
    barrierDismissible: barrierDismissible,
    content: content ?? const Text(_content),
    actions: withActions
        ? <DialogAction>[
            DialogAction(
              label: _first,
              role: DialogActionRole.dismissive,
              onPressed: () {},
            ),
            DialogAction(
              label: _second,
              role: DialogActionRole.affirmative,
              onPressed: () {},
            ),
          ]
        : null,
  );
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

Rect _surface(WidgetTester tester) => tester.getRect(dialogSurface());

Material _surfaceMaterial(WidgetTester tester) =>
    tester.widget<Material>(dialogSurface());

/// Corner radius of the dialog surface, whichever rounded shape it carries.
double _cornerRadius(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  fail('Expected the dialog surface to carry a rounded shape, got $shape.');
}

/// The box the action row occupies. M3 lays its actions out in an
/// `OverflowBar`; BaseDialog uses a `Wrap` so a row of actions too wide for the
/// dialog falls onto a second run instead of overflowing. Both boxes are the
/// action region itself, which is what every action-padding token measures.
Finder _oracleActions() => find.byType(OverflowBar);

Finder _baseActions() => find.byType(Wrap);

/// Where the actions sit across the dialog: measured against the dialog
/// surface, so the answer is the one a user sees rather than the one the
/// action region's own box implies.
String _actionsAlignment(WidgetTester tester, Finder first, Finder last) {
  return describeRowAlignment(
    _surface(tester),
    tester.getRect(first),
    tester.getRect(last),
  );
}

/// The rendered style of the text that actually paints, so DefaultTextStyle
/// propagation is part of the measurement.
TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// The size an icon really renders at, and the colour it really renders in:
/// the oracle leaves both to the ambient `IconTheme` that `AlertDialog`
/// installs, the component sets them explicitly, and both have to be described
/// the same way to be comparable.
Color _iconColor(WidgetTester tester, Finder finder) {
  final Icon icon = tester.widget<Icon>(finder);
  return icon.color ?? IconTheme.of(tester.element(finder)).color!;
}

void main() {
  group('the dialog surface', () {
    testWidgets('corner radius (DLG-001)', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected = _cornerRadius(_surfaceMaterial(tester).shape);
      expect(
        expected,
        28.0,
        reason:
            'the M3 dialog corner is 28 dp '
            '(dialog.dart:1961, _DialogDefaultsM3.shape); if the SDK moved, '
            'DLG-001 has to be re-argued rather than silently re-measured',
      );

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.shape',
        component: 'BaseDialog',
        measured: _cornerRadius(_surfaceMaterial(tester).shape),
        expected: expected,
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected = _surfaceMaterial(tester).elevation;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.elevation',
        component: 'BaseDialog',
        measured: _surfaceMaterial(tester).elevation,
        expected: expected,
      );
    });

    testWidgets('container colour', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _surfaceMaterial(tester).color!,
      );

      await pumpConformanceDialog(tester, _baseDialog());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseDialog.containerColor',
        component: 'BaseDialog',
        measured: colorRoleName(scheme, _surfaceMaterial(tester).color!),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('surface tint', (WidgetTester tester) async {
      // M3 turned the elevation tint off for dialogs and expresses depth with
      // the tonal container colour instead (dialog.dart:1981). A component that
      // re-enabled it would paint a second, elevation-dependent tint on top of
      // surfaceContainerHigh.
      await pumpConformanceDialog(tester, _oracleDialog());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _surfaceMaterial(tester).surfaceTintColor!,
      );

      await pumpConformanceDialog(tester, _baseDialog());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseDialog.surfaceTintColor',
        component: 'BaseDialog',
        measured: colorRoleName(
          scheme,
          _surfaceMaterial(tester).surfaceTintColor!,
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('barrier colour', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(scheme, barrierColor(tester));

      await pumpConformanceDialog(tester, _baseDialog());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseDialog.barrierColor',
        component: 'BaseDialog',
        measured: colorRoleName(scheme, barrierColor(tester)),
        expected: expected,
        unit: '',
      );
    });
  });

  group('typography', () {
    testWidgets('title role', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());
      final ThemeData theme = _theme(tester);
      // Pinned, not pumped: the app's dialogTheme overrides this token, so a
      // pumped AlertDialog reports titleLarge rather than M3's headlineSmall
      // (see the library comment).
      final String expected = describeTextRole(
        theme,
        theme.textTheme.headlineSmall,
      );

      expectConformant(
        token: 'BaseDialog.titleTextStyle',
        component: 'BaseDialog',
        measured: describeTextRole(theme, _renderedStyle(tester, _title)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('content role', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());
      final ThemeData theme = _theme(tester);
      // Pinned for the same reason as the title, even though this app's
      // dialogTheme happens to configure the very role M3 specifies.
      final String expected = describeTextRole(
        theme,
        theme.textTheme.bodyMedium,
      );

      expectConformant(
        token: 'BaseDialog.contentTextStyle',
        component: 'BaseDialog',
        measured: describeTextRole(theme, _renderedStyle(tester, _content)),
        expected: expected,
        unit: '',
      );
    });
  });

  group('padding', () {
    testWidgets('title top inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.text(_title)).top - _surface(tester).top;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.titlePadding.top',
        component: 'BaseDialog',
        measured: tester.getRect(find.text(_title)).top - _surface(tester).top,
        expected: expected,
      );
    });

    testWidgets('content leading inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.text(_content)).left - _surface(tester).left;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.contentPadding.start',
        component: 'BaseDialog',
        measured:
            tester.getRect(find.text(_content)).left - _surface(tester).left,
        expected: expected,
      );
    });

    testWidgets('gap between the title and the content', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.text(_content)).top -
          tester.getRect(find.text(_title)).bottom;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.titleToContentGap',
        component: 'BaseDialog',
        measured:
            tester.getRect(find.text(_content)).top -
            tester.getRect(find.text(_title)).bottom,
        expected: expected,
      );
    });

    testWidgets('gap between the content and the actions', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(_oracleActions()).top -
          tester.getRect(find.text(_content)).bottom;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.contentToActionsGap',
        component: 'BaseDialog',
        measured:
            tester.getRect(_baseActions()).top -
            tester.getRect(find.text(_content)).bottom,
        expected: expected,
      );
    });

    testWidgets('actions trailing inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          _surface(tester).right - tester.getRect(_oracleActions()).right;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.actionsPadding.end',
        component: 'BaseDialog',
        measured: _surface(tester).right - tester.getRect(_baseActions()).right,
        expected: expected,
      );
    });

    testWidgets('actions bottom inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          _surface(tester).bottom - tester.getRect(_oracleActions()).bottom;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.actionsPadding.bottom',
        component: 'BaseDialog',
        measured:
            _surface(tester).bottom - tester.getRect(_baseActions()).bottom,
        expected: expected,
      );
    });
  });

  group('the action row', () {
    testWidgets('spacing between two actions', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.widgetWithText(TextButton, _second)).left -
          tester.getRect(find.widgetWithText(TextButton, _first)).right;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.actionsSpacing',
        component: 'BaseDialog',
        measured:
            tester.getRect(find.widgetWithText(BaseButton, _second)).left -
            tester.getRect(find.widgetWithText(BaseButton, _first)).right,
        expected: expected,
      );
    });

    testWidgets('alignment inside the action region', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final String expected = _actionsAlignment(
        tester,
        find.widgetWithText(TextButton, _first),
        find.widgetWithText(TextButton, _second),
      );

      await pumpConformanceDialog(tester, _baseDialog());

      expect(
        expected,
        'end',
        reason: 'M3 end-aligns dialog actions (dialog.dart:891)',
      );
      expectConformant(
        token: 'BaseDialog.actionsAlignment',
        component: 'BaseDialog',
        measured: _actionsAlignment(
          tester,
          find.widgetWithText(BaseButton, _first),
          find.widgetWithText(BaseButton, _second),
        ),
        expected: expected,
        unit: '',
      );
    });
  });

  group('the variant icon', () {
    testWidgets('size', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog(icon: Icons.help));
      final double expected = effectiveIconSize(
        tester,
        find.byIcon(Icons.help),
      );

      await pumpConformanceDialog(
        tester,
        _baseDialog(icon: Icons.help, variant: DialogVariant.confirmation),
      );

      expectConformant(
        token: 'BaseDialog.icon.size',
        component: 'BaseDialog',
        measured: effectiveIconSize(tester, find.byIcon(Icons.help)),
        expected: expected,
      );
    });

    testWidgets('colour (DLG-002)', (WidgetTester tester) async {
      await pumpConformanceDialog(
        tester,
        _baseDialog(icon: Icons.help, variant: DialogVariant.confirmation),
      );
      final ThemeData theme = _theme(tester);
      // Pinned: the app's dialogTheme.iconColor overrides this token too, so
      // a pumped AlertDialog would report the app's own primary back at us.
      final String expected = colorRoleName(
        theme.colorScheme,
        theme.colorScheme.secondary,
      );

      expectConformant(
        token: 'BaseDialog.icon.color',
        component: 'BaseDialog',
        measured: colorRoleName(
          theme.colorScheme,
          _iconColor(tester, find.byIcon(Icons.help)),
        ),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('the destructive variant draws its icon in error', (
      WidgetTester tester,
    ) async {
      // Not a token: this is the reason DLG-002 exists, and it has to keep
      // holding for the registered rationale to stay true.
      await pumpConformanceDialog(
        tester,
        _baseDialog(variant: DialogVariant.destructive),
      );
      final ThemeData theme = _theme(tester);
      expect(
        colorRoleName(
          theme.colorScheme,
          _iconColor(tester, find.byType(Icon).first),
        ),
        'error',
      );
    });
  });

  group('width behaviour', () {
    testWidgets('a dialog with minimal content (DLG-003)', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(
        tester,
        _oracleDialog(withActions: false, content: const Text('.')),
      );
      final double expected = _surface(tester).width;

      await pumpConformanceDialog(
        tester,
        _baseDialog(withActions: false, content: const Text('.')),
      );

      expectConformant(
        token: 'BaseDialog.minWidth',
        component: 'BaseDialog',
        measured: _surface(tester).width,
        expected: expected,
      );
    });

    testWidgets('a dialog whose content wants to be very wide (DLG-004)', (
      WidgetTester tester,
    ) async {
      const Widget wide = SizedBox(width: 3000, height: 20);
      await pumpConformanceDialog(
        tester,
        _oracleDialog(withActions: false, content: wide),
      );
      final double expected = _surface(tester).width;
      expect(
        expected,
        kConformanceSurface.width - 80,
        reason:
            'M3 caps a dialog at the viewport less its 40 dp inset padding on '
            'each side (dialog.dart:32, _defaultInsetPadding)',
      );

      await pumpConformanceDialog(
        tester,
        _baseDialog(withActions: false, content: wide),
      );

      expectConformant(
        token: 'BaseDialog.maxWidth',
        component: 'BaseDialog',
        measured: _surface(tester).width,
        expected: expected,
      );
    });

    testWidgets('the caller-declared maxWidth is what the dialog renders at', (
      WidgetTester tester,
    ) async {
      // Ties the measured width to the parameter it comes from, so the fixed
      // width DLG-003/DLG-004 register cannot drift into a different number
      // while both entries still pass.
      await pumpConformanceDialog(
        tester,
        const BaseDialog(
          title: _title,
          maxWidth: 420,
          barrierDismissible: false,
          content: Text(_content),
        ),
      );
      expect(_surface(tester).width, 420);
    });
  });

  group('tap target', () {
    testWidgets('the close button meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformanceDialog(
        tester,
        _baseDialog(barrierDismissible: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('the app corner token really drives the shape', () {
    testWidgets('the dialog rounds to AppTheme.radiusL', (
      WidgetTester tester,
    ) async {
      // Ties the registered 12 dp corner to the token it comes from, so a
      // change to the token cannot pass unnoticed as "still deviating by the
      // registered amount".
      await pumpConformanceDialog(tester, _baseDialog());
      expect(
        _cornerRadius(_surfaceMaterial(tester).shape),
        closeTo(AppTheme.radiusL, 0.01),
      );
    });
  });
}
