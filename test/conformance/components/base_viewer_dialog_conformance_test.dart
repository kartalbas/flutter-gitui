/// Material 3 conformance suite for BaseViewerDialog
/// (lib/shared/components/base_viewer_dialog.dart).
///
/// The viewer is the app's second dialog shape: a fixed fraction of the window
/// holding a diff, a table or a PDF, with a header bar instead of a title
/// block and an edge-to-edge content area. It is measured against the same
/// oracle as BaseDialog — a real `AlertDialog` pushed with `showDialog` through
/// [pumpConformanceDialog] — because both are a `Dialog`, and `Dialog` is where
/// Material 3 puts the surface, the corner, the widths and the barrier.
///
/// Measuring the two dialog components against one oracle is deliberate: it is
/// the only way the register can show which of their differences are shared
/// decisions (the 12 dp corner) and which belong to the viewer alone (the
/// chrome-minimal 16 dp header and the edge-to-edge content).
///
/// Where the app's own `dialogTheme` carries a field, a pumped `AlertDialog`
/// stops being an M3 oracle and reports the app's own value instead, because
/// `Dialog` and `AlertDialog` read the theme before `_DialogDefaultsM3`
/// (dialog.dart:290-297 and :886). Since #416 that is seven fields:
/// `titleTextStyle`, `contentTextStyle` and `iconColor`, which `AppTheme`
/// configures outright, plus `shape`, `elevation`, `backgroundColor` and
/// `actionsPadding`, which reach the built theme now that the app layers its
/// choices onto the configured sub-theme rather than replacing it.
///
/// All seven are pinned from the generated `_DialogDefaultsM3`
/// (flutter/lib/src/material/dialog.dart:1954-1998) with citations, exactly as
/// in the BaseDialog suite, and that list is held to seven by that suite's
/// group 'the app theme cannot contaminate the oracle' — it fails if
/// `AppTheme.layeredDialogTheme` ever starts carrying an eighth, which is the
/// event that would turn one of the oracles still pumped below into a mirror.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/components/base_viewer_dialog.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

const String _title = 'Viewer title';
const String _content = 'Viewer content';
const String _first = 'Copy';
const String _second = 'Close';

/// Material 3's own dialog numbers, pinned from the generated
/// `_DialogDefaultsM3` (Flutter 3.44.4
/// packages/flutter/lib/src/material/dialog.dart:1962-1998) for the reason the
/// library comment gives. The same three the BaseDialog suite pins, restated
/// here rather than shared, so each suite names the specification it measures
/// against instead of borrowing another file's idea of it.
const double _m3Corner = 28.0; // dialog.dart:1967
const double _m3Elevation = 6.0; // dialog.dart:1966
const double _m3ActionsInset = 24.0; // dialog.dart:1994, left/right/bottom

/// The Material 3 oracle. `AlertDialog` is banned from UI code by the design
/// system's `avoid_alert_dialog` rule; here it is not shipped UI but the ruler
/// this suite measures against, which is why the rule — and `avoid_text_button`
/// for its stock actions — is suppressed at this single construction.
Widget _oracleDialog({bool withActions = true, Widget? content}) {
  // ignore: avoid_alert_dialog
  return AlertDialog(
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

Widget _baseDialog({bool withActions = true, Widget? content}) {
  return BaseViewerDialog(
    title: _title,
    content: content ?? const Text(_content),
    actions: withActions
        ? <Widget>[
            BaseButton(
              label: _first,
              variant: ButtonVariant.tertiary,
              onPressed: () {},
            ),
            BaseButton(label: _second, onPressed: () {}),
          ]
        : null,
  );
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)));

Rect _surface(WidgetTester tester) => tester.getRect(dialogSurface());

Material _surfaceMaterial(WidgetTester tester) =>
    tester.widget<Material>(dialogSurface());

double _cornerRadius(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    final BorderRadiusGeometry radius = shape.borderRadius;
    if (radius is BorderRadius) {
      return radius.topLeft.x;
    }
  }
  fail('Expected the dialog surface to carry a rounded shape, got $shape.');
}

TextStyle? _renderedStyle(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(find.text(text)).text.style;
}

/// The action row's insets are read off the last action rather than off a
/// container: M3 wraps its actions in an `OverflowBar` and the viewer in a
/// padded `Row`, and the last action's trailing and bottom edges coincide with
/// the region's on both, which makes the two directly comparable.
Finder _lastOracleAction() => find.widgetWithText(TextButton, _second);

Finder _lastBaseAction() => find.widgetWithText(BaseButton, _second);

void main() {
  group('the dialog surface', () {
    testWidgets('corner radius (VIEW-001)', (WidgetTester tester) async {
      // Pinned rather than pumped, for the reason spelled out in the BaseDialog
      // suite: since #416 the app's merged `dialogTheme` carries its own 12 dp
      // corner and `Dialog` reads the theme before the M3 defaults
      // (dialog.dart:295, `shape ?? dialogTheme.shape ?? defaults.shape`), so
      // the oracle would report the app's value back.
      await pumpConformanceDialog(tester, _baseDialog());
      final double rendered = _cornerRadius(_surfaceMaterial(tester).shape);

      expectConformant(
        token: 'BaseViewerDialog.shape',
        component: 'BaseViewerDialog',
        measured: rendered,
        expected: _m3Corner,
      );

      // The two dialog components must agree, which is half of VIEW-001's
      // argument, and both must agree with the theme that now carries the same
      // corner. Binding the viewer to the theme binds it to BaseDialog as well,
      // since base_dialog_conformance_test.dart makes the same assertion.
      expect(
        _cornerRadius(_theme(tester).dialogTheme.shape),
        rendered,
        reason:
            'The dialog corner the app theme carries and the corner '
            'BaseViewerDialog pins (base_viewer_dialog.dart) must be the same '
            'number; both read AppTheme.radiusL.',
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      // Pinned: `Dialog` resolves
      // `elevation ?? dialogTheme.elevation ?? defaults.elevation`
      // (dialog.dart:291) and the app's dialogTheme states one, so an oracle
      // pumped under this theme would report app_theme.dart's number as the
      // specification.
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.elevation',
        component: 'BaseViewerDialog',
        measured: _surfaceMaterial(tester).elevation,
        expected: _m3Elevation,
      );
    });

    testWidgets('container colour', (WidgetTester tester) async {
      // Pinned as a role: `_DialogDefaultsM3.backgroundColor` is
      // `colorScheme.surfaceContainerHigh` (dialog.dart:1979), and the theme
      // the oracle would read carries the app's own dialog background.
      await pumpConformanceDialog(tester, _baseDialog());
      final ColorScheme scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseViewerDialog.containerColor',
        component: 'BaseViewerDialog',
        measured: colorRoleName(scheme, _surfaceMaterial(tester).color!),
        expected: colorRoleName(scheme, scheme.surfaceContainerHigh),
        unit: '',
      );
    });

    testWidgets('surface tint', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      ColorScheme scheme = _theme(tester).colorScheme;
      final String expected = colorRoleName(
        scheme,
        _surfaceMaterial(tester).surfaceTintColor!,
      );

      await pumpConformanceDialog(tester, _baseDialog());
      scheme = _theme(tester).colorScheme;

      expectConformant(
        token: 'BaseViewerDialog.surfaceTintColor',
        component: 'BaseViewerDialog',
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
        token: 'BaseViewerDialog.barrierColor',
        component: 'BaseViewerDialog',
        measured: colorRoleName(scheme, barrierColor(tester)),
        expected: expected,
        unit: '',
      );
    });
  });

  group('typography', () {
    testWidgets('title role (VIEW-002)', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());
      final ThemeData theme = _theme(tester);
      // Pinned, not pumped: the app's dialogTheme overrides this token, so a
      // pumped AlertDialog reports titleLarge rather than M3's headlineSmall.
      final String expected = describeTextRole(
        theme,
        theme.textTheme.headlineSmall,
      );

      expectConformant(
        token: 'BaseViewerDialog.titleTextStyle',
        component: 'BaseViewerDialog',
        measured: describeTextRole(theme, _renderedStyle(tester, _title)),
        expected: expected,
        unit: '',
      );
    });

    testWidgets('content role', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());
      final ThemeData theme = _theme(tester);
      final String expected = describeTextRole(
        theme,
        theme.textTheme.bodyMedium,
      );

      expectConformant(
        token: 'BaseViewerDialog.contentTextStyle',
        component: 'BaseViewerDialog',
        measured: describeTextRole(theme, _renderedStyle(tester, _content)),
        expected: expected,
        unit: '',
      );
    });
  });

  group('padding', () {
    testWidgets('header leading inset (VIEW-003)', (WidgetTester tester) async {
      // Only the leading inset is comparable. The viewer's header row also
      // holds a close button, which makes the row taller than its title and
      // would turn a *top* inset measured from the title into a measurement of
      // that button's height instead.
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.text(_title)).left - _surface(tester).left;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.headerPadding.start',
        component: 'BaseViewerDialog',
        measured:
            tester.getRect(find.text(_title)).left - _surface(tester).left,
        expected: expected,
      );
    });

    testWidgets('content leading inset (VIEW-004)', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(find.text(_content)).left - _surface(tester).left;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.contentPadding.start',
        component: 'BaseViewerDialog',
        measured:
            tester.getRect(find.text(_content)).left - _surface(tester).left,
        expected: expected,
      );
    });

    // Pinned, unlike the header and content insets above: AlertDialog resolves
    // `actionsPadding ?? dialogTheme.actionsPadding ?? defaults.actionsPadding`
    // (dialog.dart:884-890) and the app's dialogTheme states one, whereas its
    // title and content padding are AlertDialog's own arguments and never
    // consult the theme. VIEW-005 and VIEW-006 record 24.0 as the spec value,
    // so `expectConformant` cross-checks this pin against the register too.
    testWidgets('actions trailing inset (VIEW-005)', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.actionsPadding.end',
        component: 'BaseViewerDialog',
        measured:
            _surface(tester).right - tester.getRect(_lastBaseAction()).right,
        expected: _m3ActionsInset,
      );
    });

    testWidgets('actions bottom inset (VIEW-006)', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.actionsPadding.bottom',
        component: 'BaseViewerDialog',
        measured:
            _surface(tester).bottom - tester.getRect(_lastBaseAction()).bottom,
        expected: _m3ActionsInset,
      );
    });
  });

  group('the action row', () {
    testWidgets('spacing between two actions', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          tester.getRect(_lastOracleAction()).left -
          tester.getRect(find.widgetWithText(TextButton, _first)).right;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.actionsSpacing',
        component: 'BaseViewerDialog',
        measured:
            tester.getRect(_lastBaseAction()).left -
            tester.getRect(find.widgetWithText(BaseButton, _first)).right,
        expected: expected,
      );
    });

    testWidgets('alignment across the dialog', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final String expected = describeRowAlignment(
        _surface(tester),
        tester.getRect(find.widgetWithText(TextButton, _first)),
        tester.getRect(_lastOracleAction()),
      );

      await pumpConformanceDialog(tester, _baseDialog());

      expect(
        expected,
        'end',
        reason: 'M3 end-aligns dialog actions (dialog.dart:891)',
      );
      expectConformant(
        token: 'BaseViewerDialog.actionsAlignment',
        component: 'BaseViewerDialog',
        measured: describeRowAlignment(
          _surface(tester),
          tester.getRect(find.widgetWithText(BaseButton, _first)),
          tester.getRect(_lastBaseAction()),
        ),
        expected: expected,
        unit: '',
      );
    });
  });

  group('width behaviour', () {
    testWidgets('a viewer with minimal content (VIEW-007)', (
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
        token: 'BaseViewerDialog.minWidth',
        component: 'BaseViewerDialog',
        measured: _surface(tester).width,
        expected: expected,
      );
    });

    testWidgets('a viewer whose content wants to be very wide (VIEW-008)', (
      WidgetTester tester,
    ) async {
      const Widget wide = SizedBox(width: 3000, height: 20);
      await pumpConformanceDialog(
        tester,
        _oracleDialog(withActions: false, content: wide),
      );
      final double expected = _surface(tester).width;

      await pumpConformanceDialog(
        tester,
        _baseDialog(withActions: false, content: wide),
      );

      expectConformant(
        token: 'BaseViewerDialog.maxWidth',
        component: 'BaseViewerDialog',
        measured: _surface(tester).width,
        expected: expected,
      );
    });

    testWidgets('the declared factors are what the viewer renders at', (
      WidgetTester tester,
    ) async {
      // Ties the registered widths to the parameters they come from, so the
      // fixed fraction cannot drift into a different number while VIEW-007 and
      // VIEW-008 still pass.
      await pumpConformanceDialog(
        tester,
        const BaseViewerDialog(
          title: _title,
          widthFactor: 0.5,
          heightFactor: 0.25,
          content: Text(_content),
        ),
      );
      expect(_surface(tester).width, kConformanceSurface.width * 0.5);
      expect(_surface(tester).height, kConformanceSurface.height * 0.25);
    });
  });

  group('tap target', () {
    testWidgets('the close button meets the tap target guideline', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConformanceDialog(tester, _baseDialog());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('the app corner token really drives the shape', () {
    testWidgets('the viewer rounds to AppTheme.radiusL', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _baseDialog());
      expect(
        _cornerRadius(_surfaceMaterial(tester).shape),
        closeTo(AppTheme.radiusL, 0.01),
      );
    });
  });
}
