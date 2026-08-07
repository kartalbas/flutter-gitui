// The §5.0 gate of docs/SKIN-CONTRACT.md, answered with running code.
//
// Three questions could not be answered by reading, and each changes the plan
// if the answer is no:
//
//   Q1  Do `macos_ui` and `fluent_ui` co-resolve in this pub workspace without
//       moving any EXISTING application dependency? (Answered by the lockfile
//       diff, not by this file. This file only proves both libraries are
//       importable and buildable side by side in one running binary.)
//   Q2  Does `MacosWindow` + `Sidebar` + `MacosScaffold` + `ToolBar` render
//       under a NON-`MacosApp` root, on Windows, without a platform-channel
//       error? And do `showMacosAlertDialog` / `showMacosSheet` work when
//       pushed onto a Material `Navigator`?
//   Q3  Can `MacosTextField` participate in a `Form` — does it register, does
//       `Form.validate()` see it, and what must the skin do if it does not?
//
// Plus one settled side question: is `MacosSegmentedControl` a segmented
// control or a tab bar?
library;

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

/// Every platform channel `macos_ui` 2.2.2 and `macos_window_utils` 1.9.1
/// declare. Measured by grep over both packages' `lib/`:
///   macos_ui/lib/src/selectors/color_well.dart:9,10
///   macos_window_utils/lib/window_manipulator.dart:20
///   macos_window_utils/lib/ns_window_delegate_handler/…:10
const List<String> _macosChannels = <String>[
  'macos_window_utils/window_manipulator',
  'macos_window_utils/ns_window_delegate',
  'dev.groovinchip.macos_ui',
  'dev.groovinchip.macos_ui/color_panel',
];

/// Records every method call that reaches a macOS-only channel. On Windows the
/// expectation is that this stays EMPTY: both channel users guard with
/// `if (!Platform.isMacOS) return;`.
List<String> _installChannelRecorder(WidgetTester tester) {
  final List<String> calls = <String>[];
  final TestDefaultBinaryMessenger messenger =
      tester.binding.defaultBinaryMessenger;
  for (final String name in _macosChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (
      MethodCall call,
    ) async {
      calls.add('$name#${call.method}');
      return null;
    });
  }
  addTearDown(() {
    for (final String name in _macosChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  return calls;
}

Widget _macosWindowUnderMaterialRoot({
  MacosThemeData? theme,
  GlobalKey? scopeKey,
}) {
  return MaterialApp(
    // Deliberately a MATERIAL root. This is the architecture the contract
    // rests on: ONE `WidgetsApp`, three skins beneath it.
    home: MacosTheme(
      data: theme ?? MacosThemeData.light(),
      child: MacosWindow(
        key: scopeKey,
        sidebar: Sidebar(
          minWidth: 200,
          builder: (BuildContext context, ScrollController controller) =>
              SidebarItems(
                currentIndex: 0,
                onChanged: (_) {},
                scrollController: controller,
                items: const <SidebarItem>[
                  SidebarItem(label: Text('Repositories')),
                  SidebarItem(label: Text('History')),
                ],
              ),
        ),
        child: MacosScaffold(
          toolBar: ToolBar(
            title: const Text('skin_lab'),
            actions: <ToolbarItem>[
              ToolBarIconButton(
                label: 'Refresh',
                icon: const MacosIcon(CupertinoIcons.refresh),
                showLabel: false,
                onPressed: () {},
              ),
            ],
          ),
          children: <Widget>[
            ContentArea(
              builder: (BuildContext context, ScrollController controller) =>
                  const Center(child: Text('content area')),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // Q2 — does macos_ui render under a non-MacosApp root, on Windows?
  // ===========================================================================
  group('Q2 — MacosWindow under a Material root, on Windows', () {
    testWidgets(
      'MacosWindow + Sidebar + MacosScaffold + ToolBar render under a plain '
      'MaterialApp with no platform-channel traffic',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final List<String> channelCalls = _installChannelRecorder(tester);

        await tester.pumpWidget(_macosWindowUnderMaterialRoot());
        await tester.pumpAndSettle();

        // No exception of any kind, including a MissingPluginException.
        expect(tester.takeException(), isNull);

        // Every one of the four canonical shell widgets actually mounted.
        expect(find.byType(MacosWindow), findsOneWidget);
        expect(find.byType(SidebarItems), findsOneWidget);
        expect(find.byType(MacosScaffold), findsOneWidget);
        expect(find.byType(ToolBar), findsOneWidget);

        // …and painted their content.
        expect(find.text('Repositories'), findsOneWidget);
        expect(find.text('skin_lab'), findsOneWidget);
        expect(find.text('content area'), findsOneWidget);

        // The Material root is still the one and only app root.
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(MacosApp), findsNothing);

        // THE claim under test: both platform-channel users returned early.
        expect(
          channelCalls,
          isEmpty,
          reason: 'macos_ui must not touch a macOS-only channel on Windows',
        );
      },
    );

    testWidgets('the two channel listeners return safe values off-macOS', (
      WidgetTester tester,
    ) async {
      final List<String> channelCalls = _installChannelRecorder(tester);

      // window_main_state_listener.dart:43 initialises `_isMainWindow = true`
      // and :69 `if (!Platform.isMacOS) return;` leaves it there, so controls
      // render in their ACTIVE state rather than a greyed-out one.
      expect(WindowMainStateListener.instance.isMainWindow, isTrue);

      // accent_color_listener.dart:72 does the same, leaving the accent null,
      // which every call site treats as "use the theme's accent".
      expect(AccentColorListener.instance.currentAccentColor, isNull);

      expect(channelCalls, isEmpty);
    });

    testWidgets('MacosWindowScope.toggleSidebar() works off-macOS (claim C6)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final GlobalKey windowKey = GlobalKey();
      await tester.pumpWidget(
        _macosWindowUnderMaterialRoot(scopeKey: windowKey),
      );
      await tester.pumpAndSettle();

      final BuildContext scaffoldContext = tester.element(
        find.byType(MacosScaffold),
      );
      expect(MacosWindowScope.of(scaffoldContext).isSidebarShown, isTrue);

      MacosWindowScope.of(scaffoldContext).toggleSidebar();
      await tester.pumpAndSettle();

      expect(MacosWindowScope.of(scaffoldContext).isSidebarShown, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MacosTheme is MANDATORY, so chrome.wrapRoot must install it', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Same tree, minus the MacosTheme. window.dart:181 asserts.
      await tester.pumpWidget(
        MaterialApp(
          home: MacosWindow(
            sidebar: Sidebar(
              minWidth: 200,
              builder: (BuildContext c, ScrollController s) =>
                  const SizedBox.shrink(),
            ),
            child: const MacosScaffold(),
          ),
        ),
      );

      final Object? thrown = tester.takeException();
      expect(thrown, isA<FlutterError>());
      expect(
        thrown.toString(),
        contains('A MacosTheme widget is necessary to draw this layout'),
      );
    });

    testWidgets(
      'the macOS overlay helpers require MaterialLocalizations at the ROOT '
      '(§2.9 exception 1), so the claim is real',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // A WidgetsApp root: a real Navigator, but NO MaterialLocalizations.
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            pageRouteBuilder:
                <T>(RouteSettings settings, WidgetBuilder builder) =>
                    PageRouteBuilder<T>(
                      settings: settings,
                      pageBuilder: (BuildContext c, _, _) => builder(c),
                    ),
            home: MacosTheme(
              data: MacosThemeData.light(),
              child: Builder(
                builder: (BuildContext context) => Center(
                  child: GestureDetector(
                    onTap: () => showMacosAlertDialog<void>(
                      context: context,
                      builder: (BuildContext _) => const SizedBox.shrink(),
                    ),
                    child: const Text('open', textDirection: TextDirection.ltr),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();

        // macos_alert_dialog.dart:248 reads
        // `MaterialLocalizations.of(context).modalBarrierDismissLabel`
        // with no guard; showMacosSheet does the same at macos_sheet.dart:133.
        final Object? thrown = tester.takeException();
        expect(thrown, isA<FlutterError>());
        expect(thrown.toString(), contains('MaterialLocalizations'));
      },
    );

    testWidgets('macos_ui and fluent_ui render side by side in one binary', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: <Widget>[
              Expanded(
                child: MacosTheme(
                  data: MacosThemeData.light(),
                  child: const Center(
                    child: PushButton(
                      controlSize: ControlSize.large,
                      child: Text('macOS'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: fluent.FluentTheme(
                  data: fluent.FluentThemeData.light(),
                  child: Center(
                    child: fluent.Button(
                      onPressed: () {},
                      child: const Text('Fluent'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PushButton), findsOneWidget);
      expect(find.byType(fluent.Button), findsOneWidget);
    });
  });

  // ===========================================================================
  // Q2b — do the macOS overlay helpers work on a MATERIAL Navigator, and does
  //       an ancestor MacosTheme survive into the route?
  // ===========================================================================
  group('Q2b — macOS overlays on a Material Navigator', () {
    testWidgets(
      'showMacosAlertDialog pushes and renders on a Material root (with the '
      'theme re-established, i.e. what a correct skin does)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final List<String> channelCalls = _installChannelRecorder(tester);
        final MacosThemeData captured = MacosThemeData.dark();

        await tester.pumpWidget(
          MaterialApp(
            home: MacosTheme(
              data: captured,
              child: Builder(
                builder: (BuildContext context) => Center(
                  child: TextButton(
                    onPressed: () => showMacosAlertDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) => MacosTheme(
                        data: captured,
                        child: MacosAlertDialog(
                          appIcon: const FlutterLogo(size: 56),
                          title: const Text('Delete branch?'),
                          message: const Text('This cannot be undone.'),
                          primaryButton: PushButton(
                            controlSize: ControlSize.large,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Delete'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MacosAlertDialog), findsOneWidget);
        expect(find.text('Delete branch?'), findsOneWidget);
        expect(channelCalls, isEmpty);
      },
    );

    testWidgets('showMacosSheet pushes and renders on a Material root', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final MacosThemeData captured = MacosThemeData.dark();

      await tester.pumpWidget(
        MaterialApp(
          home: MacosTheme(
            data: captured,
            child: Builder(
              builder: (BuildContext context) => Center(
                child: TextButton(
                  onPressed: () => showMacosSheet<void>(
                    context: context,
                    builder: (BuildContext sheetContext) => MacosTheme(
                      data: captured,
                      child: const MacosSheet(
                        child: Center(child: Text('sheet body')),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MacosSheet), findsOneWidget);
      expect(find.text('sheet body'), findsOneWidget);
    });

    testWidgets(
      'an ancestor MacosTheme does NOT survive into a macOS route: maybeOf is '
      'NULL and of() falls back to LIGHT while the caller is DARK (§2.8)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Brightness? callerBrightness;
        MacosThemeData? maybeInsideRoute;
        Brightness? fallbackBrightness;

        await tester.pumpWidget(
          MaterialApp(
            home: MacosTheme(
              // The application is in DARK mode.
              data: MacosThemeData.dark(),
              child: Builder(
                builder: (BuildContext context) {
                  callerBrightness = MacosTheme.of(context).brightness;
                  return Center(
                    child: TextButton(
                      onPressed: () => showMacosAlertDialog<void>(
                        context: context,
                        // Deliberately NO macos_ui widget here, so that the
                        // debugCheckHasMacosTheme assertion does not fire and
                        // we can observe the RELEASE-mode outcome directly.
                        builder: (BuildContext dialogContext) => Builder(
                          builder: (BuildContext inner) {
                            maybeInsideRoute = MacosTheme.maybeOf(inner);
                            fallbackBrightness = MacosTheme.of(
                              inner,
                            ).brightness;
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // The caller really was dark…
        expect(callerBrightness, Brightness.dark);

        // …and nothing carried it across the route boundary, because
        // `_InheritedMacosTheme extends InheritedWidget` (macos_theme.dart:121)
        // rather than `InheritedTheme`, so `InheritedTheme.capture` skips it.
        expect(
          maybeInsideRoute,
          isNull,
          reason: 'macos_theme.dart:121 is InheritedWidget, not InheritedTheme',
        );

        // In RELEASE, `MacosTheme.of` silently answers the LIGHT fallback
        // (macos_theme.dart:45-49) — a dark app showing a light dialog.
        expect(fallbackBrightness, Brightness.light);
        expect(fallbackBrightness, isNot(callerBrightness));
      },
    );

    testWidgets(
      'in DEBUG the same omission is LOUD, not silent: debugCheckHasMacosTheme '
      'throws before anything renders — §2.8 overstates the silence',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MacosTheme(
              data: MacosThemeData.dark(),
              child: Builder(
                builder: (BuildContext context) => Center(
                  child: TextButton(
                    onPressed: () => showMacosAlertDialog<void>(
                      context: context,
                      // A real macos_ui widget, with NO MacosTheme in the
                      // route. This is the skin author's mistake, verbatim.
                      builder: (BuildContext dialogContext) => MacosAlertDialog(
                        appIcon: const FlutterLogo(size: 56),
                        title: const Text('title'),
                        message: const Text('message'),
                        primaryButton: PushButton(
                          controlSize: ControlSize.large,
                          onPressed: () {},
                          child: const Text('OK'),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();

        final Object? thrown = tester.takeException();
        expect(thrown, isA<FlutterError>());
        expect(
          thrown.toString(),
          contains('A MacosTheme widget is necessary to draw this layout'),
        );
        // utils.dart:21-37 — the check is `MacosTheme.maybeOf(context) == null`
        // inside an `assert`, called from macos_alert_dialog.dart:117.
      },
    );

    testWidgets(
      'the §2.8 scenario IS reachable when some OTHER MacosTheme sits above '
      'the Navigator: then it is silent in debug too',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Brightness? dialogBrightness;

        await tester.pumpWidget(
          // A LIGHT MacosTheme wrapping the whole app, hence ABOVE the
          // Navigator that MaterialApp builds…
          MacosTheme(
            data: MacosThemeData.light(),
            child: MaterialApp(
              // …and the skin's DARK one installed beneath it by wrapRoot.
              home: MacosTheme(
                data: MacosThemeData.dark(),
                child: Builder(
                  builder: (BuildContext context) => Center(
                    child: TextButton(
                      onPressed: () => showMacosAlertDialog<void>(
                        context: context,
                        builder: (BuildContext dialogContext) =>
                            MacosAlertDialog(
                              appIcon: const FlutterLogo(size: 56),
                              title: Builder(
                                builder: (BuildContext inner) {
                                  dialogBrightness = MacosTheme.of(
                                    inner,
                                  ).brightness;
                                  return const Text('title');
                                },
                              ),
                              message: const Text('message'),
                              primaryButton: PushButton(
                                controlSize: ControlSize.large,
                                onPressed: () {},
                                child: const Text('OK'),
                              ),
                            ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // No assertion: debugCheckHasMacosTheme is SATISFIED, because *a*
        // MacosTheme exists — just the wrong one.
        expect(tester.takeException(), isNull);
        expect(find.byType(MacosAlertDialog), findsOneWidget);

        // The dark app rendered a LIGHT dialog, in debug, with no complaint.
        expect(dialogBrightness, Brightness.light);
      },
    );

    testWidgets(
      'a Fluent dialog DOES keep its ancestor theme — the asymmetry that '
      'forces the SkinContentHost wrapper',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Brightness? dialogBrightness;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates:
                fluent.FluentLocalizations.localizationsDelegates,
            home: fluent.FluentTheme(
              data: fluent.FluentThemeData.dark(),
              child: Builder(
                builder: (BuildContext context) => Center(
                  child: TextButton(
                    onPressed: () => fluent.showDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) =>
                          fluent.ContentDialog(
                            title: Builder(
                              builder: (BuildContext inner) {
                                dialogBrightness = fluent.FluentTheme.of(
                                  inner,
                                ).brightness;
                                return const Text('title');
                              },
                            ),
                          ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          dialogBrightness,
          Brightness.dark,
          reason: '_FluentTheme extends InheritedTheme, so capture carries it',
        );
      },
    );

    testWidgets(
      'the §2.8 remedy works: re-establishing MacosTheme inside the route '
      'restores the caller brightness',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Brightness? dialogBrightness;
        final MacosThemeData captured = MacosThemeData.dark();

        await tester.pumpWidget(
          MaterialApp(
            home: MacosTheme(
              data: MacosThemeData.dark(),
              child: Builder(
                builder: (BuildContext context) => Center(
                  child: TextButton(
                    onPressed: () => showMacosAlertDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) => MacosTheme(
                        // This is what SkinContentHost.build does for the skin,
                        // in ONE place, so no skin author can forget it.
                        data: captured,
                        child: MacosAlertDialog(
                          appIcon: const FlutterLogo(size: 56),
                          title: Builder(
                            builder: (BuildContext inner) {
                              dialogBrightness = MacosTheme.of(
                                inner,
                              ).brightness;
                              return const Text('title');
                            },
                          ),
                          message: const Text('message'),
                          primaryButton: PushButton(
                            controlSize: ControlSize.large,
                            onPressed: () {},
                            child: const Text('OK'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(dialogBrightness, Brightness.dark);
      },
    );
  });

  // ===========================================================================
  // Q3 — does MacosTextField keep FormField registration?
  // ===========================================================================
  group('Q3 — MacosTextField and Form registration', () {
    testWidgets('CONTROL: a Material TextFormField registers and validate() '
        'sees it fail', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
          ),
        ),
      );

      // The harness works: a REGISTERED empty field makes validate() false.
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('a bare MacosTextField does NOT register: validate() returns '
        'true on an empty required field', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MacosTheme(
            data: MacosThemeData.light(),
            child: Scaffold(
              body: Form(
                key: formKey,
                // MacosTextField extends StatefulWidget (text_field.dart:201),
                // NOT FormField. It has no `validator` parameter at all, and
                // `grep -rn FormField macos_ui-2.2.2/lib` returns ZERO hits.
                child: MacosTextField(
                  controller: controller,
                  placeholder: 'Branch name',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MacosTextField), findsOneWidget);

      // Nothing registered with the Form…
      expect(find.byType(FormField<String>), findsNothing);

      // …so validate() guards NOTHING. This is exactly the defect this
      // repository has already shipped once.
      expect(
        formKey.currentState!.validate(),
        isTrue,
        reason: 'an empty, notionally-required field passed validation',
      );
    });

    testWidgets('the remedy: a FormField<String> host makes MacosTextField a '
        'first-class form participant', (WidgetTester tester) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MacosTheme(
            data: MacosThemeData.light(),
            child: Scaffold(
              body: Form(
                key: formKey,
                child: FormField<String>(
                  initialValue: '',
                  validator: (String? v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  builder: (FormFieldState<String> field) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MacosTextField(
                        controller: controller,
                        placeholder: 'Branch name',
                        onChanged: field.didChange,
                      ),
                      if (field.hasError) Text(field.errorText!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Empty → the host registered, so validate() now genuinely fails.
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      // Type into the MacosTextField; the host's value tracks it.
      // `enterText` needs the EditableText, which MacosTextField wraps.
      await tester.enterText(
        find.descendant(
          of: find.byType(MacosTextField),
          matching: find.byType(EditableText),
        ),
        'feature/x',
      );
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Required'), findsNothing);

      // And the value really reached the FormField, not just the controller.
      expect(controller.text, 'feature/x');
    });

    testWidgets('the same host drives a Material TextField too, so the wrapper '
        'can live in the API package rather than per-skin', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: FormField<String>(
                initialValue: '',
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
                builder: (FormFieldState<String> field) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(onChanged: field.didChange),
                    if (field.hasError) Text(field.errorText!),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  // ===========================================================================
  // Side question — is MacosSegmentedControl a segmented control or a tab bar?
  // ===========================================================================
  group('MacosSegmentedControl is a tab bar, not a chip group', () {
    testWidgets('it requires BOTH a List<MacosTab> and a MacosTabController, '
        'and selection flows through the controller', (
      WidgetTester tester,
    ) async {
      // Both arguments are `required` (segmented_control.dart:22-33). There is
      // no `onChanged`, no `selected` set and no value type: `MacosTab` carries
      // only `label` (String) and `active` (bool) — tab.dart:13 — so a chip
      // group over an arbitrary T cannot be expressed by this widget.
      final MacosTabController controller = MacosTabController(length: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MacosTheme(
            data: MacosThemeData.light(),
            child: Center(
              child: MacosSegmentedControl(
                controller: controller,
                tabs: const <MacosTab>[
                  MacosTab(label: 'All'),
                  MacosTab(label: 'Local'),
                  MacosTab(label: 'Remote'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MacosSegmentedControl), findsOneWidget);
      expect(find.byType(MacosTab), findsNWidgets(3));

      // Single selection only — the controller holds ONE index. There is no
      // way to express "two of three chips are on".
      expect(controller.index, 0);
      await tester.tap(find.text('Remote'));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('a MacosTabController is a ChangeNotifier with a single index, '
        'so multi-select is not expressible', (WidgetTester tester) async {
      final MacosTabController controller = MacosTabController(length: 2);
      addTearDown(controller.dispose);

      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.index = 1;
      expect(controller.index, 1);
      expect(notifications, 1);

      // `index` is a single int — the type itself forbids a selection set.
      expect(controller.index, isA<int>());
    });
  });
}
