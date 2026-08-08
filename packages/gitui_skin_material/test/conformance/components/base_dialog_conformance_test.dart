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
/// working for every field this app's own `dialogTheme` carries, because
/// `Dialog` and `AlertDialog` read the theme **before** the defaults
/// (dialog.dart:290-297 for the surface, :818-886 for the content), so for
/// those a pumped `AlertDialog` reports the app's own value as if it were the
/// specification and the suite would be measuring this app against itself.
///
/// The rule this suite follows is therefore mechanical: **pin exactly the
/// fields `AppTheme.layeredDialogTheme` returns non-null, pump everything
/// else.** Since #416 that is seven fields, and the count is not a matter of
/// judgement — `AppTheme` configures `titleTextStyle`, `contentTextStyle` and
/// `iconColor` outright, and layering its choices onto the sub-theme
/// `FlexSubThemesData` built (rather than replacing it, which is what #416
/// fixed) lets the configured `shape`, `elevation`, `backgroundColor` and
/// `actionsPadding` through as well. Five of those seven happen to coincide
/// with the M3 default today, which is precisely why the contamination is
/// invisible unless the oracle is pinned: an oracle that agrees with the
/// specification by accident stops agreeing the moment somebody edits
/// `FlexSubThemesData`, and nothing would fail.
///
/// The pinned values come from `_DialogDefaultsM3` with source citations,
/// exactly as the BaseIconButton suite pins `_IconButtonDefaultsM3`. Colours
/// and text are pinned as *roles* (`textTheme.headlineSmall`,
/// `colorScheme.secondary`, `colorScheme.surfaceContainerHigh`) evaluated
/// against the same theme, so the app's registered type-scale deviations cancel
/// out of the comparison and only the role is measured; the corner, the
/// elevation and the action insets are pinned as literals, because a number has
/// no role to evaluate.
///
/// What keeps that list honest is the group 'the app theme cannot contaminate
/// the oracle' below: it asserts that every `dialogTheme` field the suite still
/// reads off a pumped oracle is null in the app's theme. Configure an eighth
/// field in `app_theme.dart` and that guard fails by name, instead of an oracle
/// quietly turning into a mirror.
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
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole;
import 'package:gitui_skin_material/gitui_skin_material.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

const String _title = 'Dialog title';
const String _content = 'Dialog content';
const String _first = 'Cancel';
const String _second = 'Confirm';

/// Material 3's own dialog numbers, pinned from the generated
/// `_DialogDefaultsM3` (Flutter 3.44.4
/// packages/flutter/lib/src/material/dialog.dart:1962-1998) rather than read
/// off a pumped `AlertDialog`, because this app's `dialogTheme` carries a value
/// for each of them and `Dialog`/`AlertDialog` read the theme before the
/// defaults. See the library comment for the rule and
/// `the app theme cannot contaminate the oracle` below for its guard.
///
/// The colour and text roles this app also overrides are pinned at their point
/// of use instead, because a role has to be evaluated against the theme under
/// test rather than written down as a number.
const double _m3Corner = 28.0; // dialog.dart:1967
const double _m3Elevation = 6.0; // dialog.dart:1966
const double _m3ActionsInset = 24.0; // dialog.dart:1994, left/right/bottom

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
  IconRole? icon,
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
      // Pinned rather than pumped, and since #416 it has to be: app_theme.dart
      // now layers the configured `dialogTheme` onto the built theme instead of
      // replacing it, so the theme carries the app's own 12 dp corner, and
      // `Dialog` reads the theme before the M3 defaults
      // (dialog.dart:295, `shape ?? dialogTheme.shape ?? defaults.shape`).
      // A pumped AlertDialog would therefore report 12 and measure this app
      // against itself. If the SDK moves this number, DLG-001 has to be
      // re-argued rather than silently re-measured.
      await pumpConformanceDialog(tester, _baseDialog());
      final double rendered = _cornerRadius(_surfaceMaterial(tester).shape);

      expectConformant(
        token: 'BaseDialog.shape',
        component: 'BaseDialog',
        measured: rendered,
        expected: _m3Corner,
      );

      // The anti-drift half of DLG-001, and the reason the register's rationale
      // now names two sources. Since #416 the 12 dp exists twice: BaseDialog
      // pins it on the `Dialog` widget, where a widget value beats a theme
      // value, and the merged `dialogTheme` carries the same rung of the corner
      // scale. The component's pin is what renders; this holds the theme to the
      // same number so the two cannot drift into two different corners.
      expect(
        _cornerRadius(_theme(tester).dialogTheme.shape),
        rendered,
        reason:
            'The dialog corner the app theme carries and the corner BaseDialog '
            'pins (base_dialog.dart) must be the same number. Both read '
            'AppTheme.radiusL — the component directly, the theme through '
            "FlexSubThemesData.defaultRadius — so a mismatch means one of the "
            'two was edited alone and an SDK-owned dialog would now round '
            'differently from the app\'s own.',
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      // Pinned, for the reason the library comment gives: the app's layered
      // `dialogTheme` states an elevation, `Dialog` reads
      // `elevation ?? dialogTheme.elevation ?? defaults.elevation`
      // (dialog.dart:291), and an oracle pumped under this theme would report
      // whatever app_theme.dart configured. That the two numbers coincide today
      // is what makes pinning necessary rather than optional — a coincidence
      // cannot be asserted on.
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.elevation',
        component: 'BaseDialog',
        measured: _surfaceMaterial(tester).elevation,
        expected: _m3Elevation,
      );
    });

    testWidgets('container colour', (WidgetTester tester) async {
      // Pinned as a role for the same reason as the elevation:
      // `_DialogDefaultsM3.backgroundColor` is `colorScheme.surfaceContainerHigh`
      // (dialog.dart:1979) and `Dialog` reads the theme first (dialog.dart:290),
      // so the app's configured dialog background — the same role, computed by
      // FlexColorScheme — would come back as the specification.
      await pumpConformanceDialog(tester, _baseDialog());
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseDialog.containerColor',
        component: 'BaseDialog',
        measured: colorRoleName(scheme, _surfaceMaterial(tester).color!),
        expected: colorRoleName(scheme, scheme.surfaceContainerHigh),
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

    // The two action insets are the last pair of pinned tokens, and the only
    // *padding* the app's dialogTheme reaches: AlertDialog resolves
    // `actionsPadding ?? dialogTheme.actionsPadding ?? defaults.actionsPadding`
    // (dialog.dart:884-890), while the title and content insets above are
    // AlertDialog's own arguments and never consult the theme — which is why
    // those four keep their pumped oracle and these two do not.
    testWidgets('actions trailing inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.actionsPadding.end',
        component: 'BaseDialog',
        measured: _surface(tester).right - tester.getRect(_baseActions()).right,
        expected: _m3ActionsInset,
      );
    });

    testWidgets('actions bottom inset', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseDialog.actionsPadding.bottom',
        component: 'BaseDialog',
        measured:
            _surface(tester).bottom - tester.getRect(_baseActions()).bottom,
        expected: _m3ActionsInset,
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
        _baseDialog(
          icon: IconRole.question,
          variant: DialogVariant.confirmation,
        ),
      );

      expectConformant(
        token: 'BaseDialog.icon.size',
        component: 'BaseDialog',
        measured: effectiveIconSize(
          tester,
          find.byIcon(MaterialGlyphs.of(IconRole.question)),
        ),
        expected: expected,
      );
    });

    testWidgets('colour (DLG-002)', (WidgetTester tester) async {
      await pumpConformanceDialog(
        tester,
        _baseDialog(
          icon: IconRole.question,
          variant: DialogVariant.confirmation,
        ),
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
          _iconColor(tester, find.byIcon(MaterialGlyphs.of(IconRole.question))),
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

  group('the app theme cannot contaminate the oracle', () {
    // The guard behind the pinned/pumped split, and the reason that split is a
    // rule rather than a judgement call. Every field the app's `dialogTheme`
    // carries is a field `Dialog`/`AlertDialog` prefers over `_DialogDefaultsM3`
    // (dialog.dart:266-297 and :769-890), so a pumped `AlertDialog` under this
    // app's theme reports it as the specification. The seven the app does carry
    // are pinned above. This asserts that it carries *nothing else* — because
    // the day it does, an oracle in this file silently turns into a mirror and
    // the corresponding token starts certifying itself as conformant.
    //
    // Written as an equality rather than seven null checks so it is exhaustive:
    // a field added to `DialogThemeData` by a future SDK, or newly configured
    // by `FlexSubThemesData`, fails here too rather than slipping past a
    // hand-written list.
    for (final MapEntry<String, ThemeData Function()> brightness
        in <String, ThemeData Function()>{
          'light': AppTheme.lightTheme,
          'dark': AppTheme.darkTheme,
        }.entries) {
      test('the app configures exactly the pinned seven (${brightness.key})', () {
        final DialogThemeData configured = brightness.value().dialogTheme;
        expect(
          configured,
          DialogThemeData(
            backgroundColor: configured.backgroundColor,
            elevation: configured.elevation,
            shape: configured.shape,
            actionsPadding: configured.actionsPadding,
            iconColor: configured.iconColor,
            titleTextStyle: configured.titleTextStyle,
            contentTextStyle: configured.contentTextStyle,
          ),
          reason:
              "The app's dialogTheme must carry no field beyond the seven this "
              'suite pins its oracle for. A failure names the extra field, and '
              'the fix is not to widen this expectation: pin that token from '
              '_DialogDefaultsM3 in this suite and in '
              'base_viewer_dialog_conformance_test.dart first, because until '
              'then the measurement it feeds is comparing the app against '
              'itself. The fields this protects and what each one feeds: '
              'surfaceTintColor -> the surface tint test, barrierColor -> the '
              'barrier colour test, insetPadding and constraints -> the '
              'min/max width tests (DLG-003/DLG-004), shadowColor, alignment '
              'and clipBehavior -> nothing measured here yet. Configured was '
              '$configured.',
        );
      });
    }
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
