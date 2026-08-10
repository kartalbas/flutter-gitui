/// The dialog ROUTE, measured - not the surface inside it, which is
/// `chrome.dialogSurface`'s and has its own suite.
///
/// What a reimplementation gets wrong is what is asserted here: that a dialog
/// takes the application AWAY behind the reference's smoke rather than
/// leaving it readable the way a flyout does, that it arrives on the fast
/// step while settling inward rather than only fading the way a Material
/// dialog does, that the keyboard is inside it the moment it opens, and that
/// whether the barrier dismisses is the application's word and not this
/// skin's.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';

import 'support/fluent_overlay_harness.dart';

/// Pumps the harness app and opens a dialog over [content].
Future<Future<bool?>> _openDialog(
  WidgetTester tester, {
  bool barrierDismissible = false,
  Widget content = const SizedBox(width: 80, height: 40),
  List<DialogAction> actions = const <DialogAction>[],
}) async {
  late BuildContext host;
  await pumpFluentOverlayApp(tester, (BuildContext context) {
    host = context;
    return const SizedBox.expand();
  });
  final Future<bool?> answered = Overlays.dialog<bool>(
    host,
    DialogSpec(
      title: 'Delete branch',
      content: ContentPort(content),
      actions: actions,
      barrierDismissible: barrierDismissible,
    ),
  );
  await tester.pump();
  return answered;
}

/// The dialog surface as it is PAINTED, which is where a scale transition
/// shows: the layout box it wraps keeps its shape throughout.
double _paintedWidth(WidgetTester tester) =>
    tester.getRect(find.byKey(FluentDialogSurface.surfaceKey)).width;

/// How far the route's own fade has got.
double _fadeOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(FluentDialogSurface.surfaceKey),
            matching: find.byType(FadeTransition),
          )
          .last,
    )
    .opacity
    .value;

/// The barrier's own colour, read off the route's modal barrier.
Color _barrierColor(WidgetTester tester) => tester
    .widget<ModalBarrier>(
      find.byWidgetPredicate(
        (Widget widget) => widget is ModalBarrier && widget.color != null,
      ),
    )
    .color!;

void main() {
  group('the barrier', () {
    testWidgets('smokes the application at the reference\'s own value - a '
        'dialog takes the page away where a flyout leaves it readable', (
      WidgetTester tester,
    ) async {
      await _openDialog(tester);
      await tester.pump(const Duration(milliseconds: 200));
      // content_dialog.dart:241. The menu route's barrier is 0x00000000 in
      // the same package: the two overlays disagree on purpose.
      expect(_barrierColor(tester), const Color(0x8A000000));
    });

    testWidgets('does not dismiss unless the application said it may', (
      WidgetTester tester,
    ) async {
      await _openDialog(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FluentDialogSurface), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(
        find.byType(FluentDialogSurface),
        findsOneWidget,
        reason:
            'the reference defaults to a modal dialog, and the spec here '
            'says nothing else',
      );
    });

    testWidgets('dismisses when it did', (WidgetTester tester) async {
      final Future<bool?> answered = await _openDialog(
        tester,
        barrierDismissible: true,
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(FluentDialogSurface), findsNothing);
      await answered;
    });
  });

  group('the entrance', () {
    testWidgets('settles inward while it fades in - a Material dialog only '
        'fades', (WidgetTester tester) async {
      await _openDialog(tester);
      // One frame in, the scale is still at its opening 1.0. Measured off
      // the PAINTED rectangle, not the layout size: a ScaleTransition moves
      // the transform, and the box it wraps never changes shape.
      final double opening = _paintedWidth(tester);
      final double opacity = _fadeOpacity(tester);

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _paintedWidth(tester),
        lessThan(opening),
        reason:
            'the ContentDialog settles inward as it arrives '
            '(content_dialog.dart:337-353)',
      );
      expect(
        _fadeOpacity(tester),
        greaterThan(opacity),
        reason: 'and it fades in while it does',
      );
      expect(_fadeOpacity(tester), 1.0);
    });

    testWidgets('opens on the fast step, so nothing moves past 167 ms', (
      WidgetTester tester,
    ) async {
      await _openDialog(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final double midway = _paintedWidth(tester);

      await tester.pump(const Duration(milliseconds: 70));
      final double settled = _paintedWidth(tester);
      expect(settled, lessThan(midway));

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        _paintedWidth(tester),
        settled,
        reason: 'theme.dart:441 pins fastAnimationDuration at 167 ms',
      );
    });

    testWidgets('a zero animation scale opens with no transition at all', (
      WidgetTester tester,
    ) async {
      late BuildContext host;
      await pumpFluentOverlayApp(tester, (BuildContext context) {
        host = context;
        return const SizedBox.expand();
      }, animationScale: 0);
      unawaited(
        Overlays.dialog<bool>(
          host,
          const DialogSpec(
            title: 'Delete branch',
            content: ContentPort(SizedBox(width: 80, height: 40)),
          ),
        ),
      );
      await tester.pump();
      // First frame, no pumping past any duration: already settled and
      // already opaque.
      final double first = _paintedWidth(tester);
      expect(_fadeOpacity(tester), 1.0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(_paintedWidth(tester), first);
    });
  });

  group('the keyboard', () {
    testWidgets('is inside the dialog the moment it opens', (
      WidgetTester tester,
    ) async {
      final FocusNode inside = FocusNode();
      addTearDown(inside.dispose);
      await _openDialog(
        tester,
        content: Focus(focusNode: inside, child: const SizedBox.shrink()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final FocusScopeNode scope = FocusScope.of(
        tester.element(find.byType(FluentDialogSurface)),
      );
      expect(
        scope.hasFocus,
        isTrue,
        reason:
            'content_dialog.dart:330 autofocuses the dialog\'s own scope, '
            'so the keyboard never stays behind on the page',
      );
    });
  });
}
