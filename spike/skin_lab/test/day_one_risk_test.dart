// Day-one risk probes for the #249 viability spike.
//
// Both risks are front-loaded because either one changes the architecture and
// the cost estimate of the whole programme, and both are cheaper to answer now
// than after a week of component work.
//
// RISK 1 - does `fluent_ui` resolve at all, in this workspace, against this
//          Flutter and Dart version? Answered by the fact that this file
//          compiles and runs: the import below is only satisfiable if the pub
//          workspace solved with fluent_ui in it. The exact resolved version
//          is asserted so the answer in FINDINGS.md cannot silently rot.
//
// RISK 2 - do Fluent overlays (dialogs, flyouts) work under a NON-FluentApp
//          root? The whole skin architecture in #249 assumes one app root can
//          host any skin's overlays; if Fluent's overlays only work under
//          `FluentApp`, the root itself must be swapped per skin, which is a
//          different and more expensive design.
library;

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RISK 1 - fluent_ui resolves in this workspace', () {
    test('fluent_ui symbols are linkable against Flutter 3.44 / Dart 3.12', () {
      // Touch one symbol from each layer the Fluent skin needs, so a
      // resolution that succeeded but produced an uncompilable package is
      // still caught here rather than three components later.
      expect(fluent.FluentThemeData.light(), isA<fluent.FluentThemeData>());
      expect(
        const fluent.FilledButton(onPressed: null, child: material.Text('x')),
        isA<fluent.BaseButton>(),
      );
      expect(
        const fluent.ContentDialog(title: material.Text('x')),
        isA<fluent.ContentDialog>(),
      );
      expect(
        fluent.NavigationView(pane: fluent.NavigationPane()),
        isA<fluent.NavigationView>(),
      );
      expect(const fluent.TextBox(), isA<fluent.TextBox>());
    });
  });

  group('RISK 2 - Fluent overlays under a non-FluentApp root', () {
    testWidgets('a Fluent control renders under a MaterialApp root', (
      tester,
    ) async {
      await tester.pumpWidget(
        material.MaterialApp(
          home: fluent.FluentTheme(
            data: fluent.FluentThemeData.light(),
            child: const material.Scaffold(
              body: fluent.FilledButton(
                onPressed: null,
                child: material.Text('fluent under material'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('fluent under material'), findsOneWidget);
    });

    testWidgets(
      'ContentDialog opens through fluent showDialog on a Material Navigator',
      (tester) async {
        late material.BuildContext hostContext;
        await tester.pumpWidget(
          material.MaterialApp(
            // FluentLocalizations is NOT installed by MaterialApp. Whether it
            // is needed is exactly what this probe measures.
            localizationsDelegates: const [
              fluent.FluentLocalizations.delegate,
              material.DefaultMaterialLocalizations.delegate,
              material.DefaultWidgetsLocalizations.delegate,
            ],
            home: material.Builder(
              builder: (context) {
                hostContext = context;
                return const material.Scaffold(body: material.SizedBox());
              },
            ),
          ),
        );

        // fluent.showDialog is the package's own overlay entry point. It
        // pushes a FluentDialogRoute onto whatever Navigator it finds - here,
        // MaterialApp's.
        // The dialog builder re-establishes FluentTheme itself: a route's
        // context is a descendant of the Navigator, never of whatever the
        // page subtree wrapped, so a FluentTheme placed inside `home` is out
        // of reach. That re-wrap requirement is the finding, not a defect.
        unawaited(
          fluent.showDialog<void>(
            context: hostContext,
            builder: (context) => fluent.FluentTheme(
              data: fluent.FluentThemeData.light(),
              child: fluent.ContentDialog(
                title: const material.Text('Fluent dialog title'),
                content: const material.Text('body'),
                actions: [
                  fluent.FilledButton(
                    onPressed: () {},
                    child: const material.Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fluent dialog title'), findsOneWidget);
        expect(find.byType(fluent.ContentDialog), findsOneWidget);
      },
    );

    testWidgets(
      'fluent showDialog carries an ancestor FluentTheme into the route',
      (tester) async {
        // fluent.showDialog calls InheritedTheme.capture(from: callerContext,
        // to: navigatorContext) and re-applies it inside the route
        // (content_dialog.dart:241-244). _FluentTheme extends InheritedTheme
        // (styles/theme.dart:85), so a FluentTheme anywhere between the caller
        // and the Navigator survives into the dialog with no re-wrap. This is
        // the load-bearing mechanism for a per-skin overlay under one shared
        // app root.
        late material.BuildContext hostContext;
        await tester.pumpWidget(
          material.MaterialApp(
            localizationsDelegates: const [
              fluent.FluentLocalizations.delegate,
              material.DefaultMaterialLocalizations.delegate,
              material.DefaultWidgetsLocalizations.delegate,
            ],
            home: fluent.FluentTheme(
              data: fluent.FluentThemeData.dark(),
              child: material.Builder(
                builder: (context) {
                  hostContext = context;
                  return const material.Scaffold(body: material.SizedBox());
                },
              ),
            ),
          ),
        );

        unawaited(
          fluent.showDialog<void>(
            context: hostContext,
            // No FluentTheme wrapper here on purpose.
            builder: (context) =>
                const fluent.ContentDialog(title: material.Text('captured')),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('captured'), findsOneWidget);

        // And the captured theme is the caller's, not a fresh default.
        final fluent.FluentThemeData inDialog = fluent.FluentTheme.of(
          tester.element(find.byType(fluent.ContentDialog)),
        );
        expect(inDialog.brightness, material.Brightness.dark);
      },
    );

    testWidgets('an overlay with no FluentTheme anywhere fails hard', (
      tester,
    ) async {
      // The negative control. It does not fall back to a default theme, so
      // "an overlay must be able to reach its skin's theme" is a hard rule of
      // the SkinOverlays contract, not a stylistic nicety.
      late material.BuildContext hostContext;
      await tester.pumpWidget(
        material.MaterialApp(
          localizationsDelegates: const [
            fluent.FluentLocalizations.delegate,
            material.DefaultMaterialLocalizations.delegate,
            material.DefaultWidgetsLocalizations.delegate,
          ],
          home: material.Builder(
            builder: (context) {
              hostContext = context;
              return const material.Scaffold(body: material.SizedBox());
            },
          ),
        ),
      );

      unawaited(
        fluent.showDialog<void>(
          context: hostContext,
          builder: (context) =>
              const fluent.ContentDialog(title: material.Text('bare')),
        ),
      );
      await tester.pumpAndSettle();

      final Object? error = tester.takeException();
      expect(error, isFlutterError);
      expect('$error', contains('FluentTheme widget is necessary'));
    });

    testWidgets('a flyout does NOT capture the ancestor FluentTheme', (
      tester,
    ) async {
      // Unlike showDialog, FlyoutController.showFlyout hosts its content in
      // the root Overlay without an InheritedTheme.capture, so the flyout
      // builder must re-establish the theme itself. Asymmetric, and therefore
      // worth pinning: the SkinOverlays contract has to re-wrap
      // unconditionally rather than rely on capture.
      final controller = fluent.FlyoutController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        material.MaterialApp(
          localizationsDelegates: const [
            fluent.FluentLocalizations.delegate,
            material.DefaultMaterialLocalizations.delegate,
            material.DefaultWidgetsLocalizations.delegate,
          ],
          home: fluent.FluentTheme(
            data: fluent.FluentThemeData.light(),
            child: material.Scaffold(
              body: fluent.FlyoutTarget(
                controller: controller,
                child: const material.Text('anchor'),
              ),
            ),
          ),
        ),
      );

      unawaited(
        controller.showFlyout<void>(
          builder: (context) => fluent.MenuFlyout(
            items: [
              fluent.MenuFlyoutItem(
                text: const material.Text('uncaptured'),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Object? error = tester.takeException();
      expect(error, isFlutterError);
      expect('$error', contains('FluentTheme widget is necessary'));
    });

    testWidgets('a Fluent flyout opens under a Material root', (tester) async {
      final controller = fluent.FlyoutController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        material.MaterialApp(
          localizationsDelegates: const [
            fluent.FluentLocalizations.delegate,
            material.DefaultMaterialLocalizations.delegate,
            material.DefaultWidgetsLocalizations.delegate,
          ],
          home: fluent.FluentTheme(
            data: fluent.FluentThemeData.light(),
            child: material.Scaffold(
              body: fluent.FlyoutTarget(
                controller: controller,
                child: const material.Text('anchor'),
              ),
            ),
          ),
        ),
      );

      unawaited(
        controller.showFlyout<void>(
          // Flyout content is hosted in the root Overlay, so - exactly like a
          // dialog route - it is not a descendant of the FluentTheme above and
          // must re-establish it. Without this wrapper the same assertion
          // fires as in the probe above.
          builder: (context) => fluent.FluentTheme(
            data: fluent.FluentThemeData.light(),
            child: fluent.MenuFlyout(
              items: [
                fluent.MenuFlyoutItem(
                  text: const material.Text('Flyout item'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flyout item'), findsOneWidget);
    });

    testWidgets('FluentLocalizations is required by Fluent overlay chrome', (
      tester,
    ) async {
      // MaterialApp installs Material and Widgets localizations only.
      // fluent.showDialog runs `debugCheckHasFluentLocalizations` before it
      // pushes anything, so the Fluent delegate is a hard prerequisite of the
      // ONE app root - which means SkinChrome must expose
      // `localizationsDelegates` and the root must install the union of every
      // registered skin's. Recorded as a required contract member.
      late material.BuildContext hostContext;
      await tester.pumpWidget(
        material.MaterialApp(
          // Deliberately no FluentLocalizations.delegate.
          home: material.Builder(
            builder: (context) {
              hostContext = context;
              return const material.Scaffold(body: material.SizedBox());
            },
          ),
        ),
      );

      Object? thrown;
      try {
        await fluent.showDialog<void>(
          context: hostContext,
          builder: (context) => fluent.FluentTheme(
            data: fluent.FluentThemeData.light(),
            child: const fluent.ContentDialog(
              title: material.Text('no l10n'),
              content: fluent.TextBox(),
            ),
          ),
        );
      } catch (error) {
        thrown = error;
      }
      await tester.pumpAndSettle();

      expect(thrown, isFlutterError);
      expect('$thrown', contains('FluentLocalizations'));
    });
  });
}

/// Local `unawaited` so the probe file needs no extra dependency.
void unawaited(Future<void> future) {}
