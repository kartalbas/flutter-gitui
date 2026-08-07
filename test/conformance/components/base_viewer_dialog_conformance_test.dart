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
/// Where the app's own `dialogTheme` overrides an M3 default — `titleTextStyle`,
/// `contentTextStyle` and `iconColor` (lib/shared/theme/app_theme.dart:70-78 in
/// the light theme, :184-192 in the dark one) — a pumped `AlertDialog` stops
/// being an M3 oracle and reports the app's override instead. Those tokens are
/// pinned from the generated
/// `_DialogDefaultsM3` (flutter/lib/src/material/dialog.dart:1954-1998) with
/// citations, exactly as in the BaseDialog suite.
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
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected = _cornerRadius(_surfaceMaterial(tester).shape);

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.shape',
        component: 'BaseViewerDialog',
        measured: _cornerRadius(_surfaceMaterial(tester).shape),
        expected: expected,
      );
    });

    testWidgets('elevation', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected = _surfaceMaterial(tester).elevation;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.elevation',
        component: 'BaseViewerDialog',
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
        token: 'BaseViewerDialog.containerColor',
        component: 'BaseViewerDialog',
        measured: colorRoleName(scheme, _surfaceMaterial(tester).color!),
        expected: expected,
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

    testWidgets('actions trailing inset (VIEW-005)', (
      WidgetTester tester,
    ) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          _surface(tester).right - tester.getRect(_lastOracleAction()).right;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.actionsPadding.end',
        component: 'BaseViewerDialog',
        measured:
            _surface(tester).right - tester.getRect(_lastBaseAction()).right,
        expected: expected,
      );
    });

    testWidgets('actions bottom inset (VIEW-006)', (WidgetTester tester) async {
      await pumpConformanceDialog(tester, _oracleDialog());
      final double expected =
          _surface(tester).bottom - tester.getRect(_lastOracleAction()).bottom;

      await pumpConformanceDialog(tester, _baseDialog());

      expectConformant(
        token: 'BaseViewerDialog.actionsPadding.bottom',
        component: 'BaseViewerDialog',
        measured:
            _surface(tester).bottom - tester.getRect(_lastBaseAction()).bottom,
        expected: expected,
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
