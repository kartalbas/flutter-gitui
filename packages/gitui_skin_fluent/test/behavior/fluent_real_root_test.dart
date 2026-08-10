/// The skin under its own REAL chrome, which is the one thing every other
/// suite in this package cannot measure.
///
/// The behaviour harness supplies a stand-in `wrapRoot` on purpose: the real
/// one paints the language's page ground, and a ground inside the finder
/// would turn every fill those suites read off the paint stream into a
/// measurement of the ground. The cost of that stand-in is a blind spot
/// exactly the shape of #446 - a defect that lives IN `wrapRoot` and only
/// shows when it is re-established inside a route. This file is the suite
/// that pays for it, by composing the real `FluentSkin` the way `main.dart`
/// composes a skin and opening overlays against it.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_overlays.dart';
import 'package:gitui_skin_fluent/src/fluent_resources.dart';
import 'package:gitui_skin_fluent/src/fluent_skin.dart';

const FluentResources _light = FluentResources.light();

/// Every page ground painted above [of], with the size it covers.
List<(Color, Size)> _groundsAbove(WidgetTester tester, Finder of) {
  final List<(Color, Size)> grounds = <(Color, Size)>[];
  for (final Element element
      in find.ancestor(of: of, matching: find.byType(ColoredBox)).evaluate()) {
    final ColoredBox box = element.widget as ColoredBox;
    if (box.color != _light.solidBackgroundFillColorBase) continue;
    grounds.add((box.color, (element.renderObject! as RenderBox).size));
  }
  return grounds;
}

/// Pumps the real skin the way `main.dart` composes one, and hands back a
/// context inside the page.
Future<BuildContext> _pumpRealRoot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late BuildContext page;
  await tester.pumpWidget(
    WidgetsApp(
      color: _light.solidBackgroundFillColorBase,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? navigator) => SkinScope.install(
        skin: const FluentSkin(),
        request: const SkinRequest(
          brightness: Brightness.light,
          accentSeed: 0,
          textScale: 1,
          codeScale: 1,
          animationScale: 1,
          monoFamily: '',
          uiFamily: '',
        ),
        dialogKeyboardHost:
            (BuildContext context, DialogSpec spec, Widget surface) => surface,
        app: ContentPort(navigator ?? const SizedBox.shrink()),
      ),
      onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => Builder(
              builder: (BuildContext inner) {
                page = inner;
                return const Center(child: Text('the application'));
              },
            ),
      ),
    ),
  );
  await tester.pump();
  return page;
}

void main() {
  testWidgets('the page itself stands on the language\'s ground', (
    WidgetTester tester,
  ) async {
    await _pumpRealRoot(tester);
    expect(
      _groundsAbove(tester, find.text('the application')),
      hasLength(1),
      reason:
          'the root establishment paints SolidBackgroundFillColorBase '
          'once, because this skin\'s fills are translucent and composite '
          'over it',
    );
  });

  testWidgets('a flyout opened over that page paints NO second ground - the '
      'barrier is transparent so the application stays readable (#446)', (
    WidgetTester tester,
  ) async {
    final BuildContext page = await _pumpRealRoot(tester);
    Overlays.menu(
      page,
      at: const Offset(300, 200),
      entries: <MenuEntry>[MenuAction(label: 'Copy', onPressed: () {})],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FluentMenuSurface), findsOneWidget);
    // One ground, and it is the page's own - the route's re-established root
    // adds none. Before the fix there were two, both 1280x800, the second
    // sitting between the transparent barrier and the menu.
    expect(
      _groundsAbove(tester, find.byType(FluentMenuSurface)),
      hasLength(1),
      reason:
          'a re-established root inside an overlay already has a page '
          'under it',
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('and neither does a dialog, whose own smoke is what darkens '
      'the page', (WidgetTester tester) async {
    final BuildContext page = await _pumpRealRoot(tester);
    Overlays.dialog<void>(
      page,
      const DialogSpec(
        title: 'Delete branch',
        content: ContentPort(SizedBox(width: 80, height: 40)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      _groundsAbove(tester, find.byKey(FluentDialogSurface.surfaceKey)),
      hasLength(1),
      reason:
          'the dialog is read through the route\'s 0x8A000000 barrier, '
          'not through an opaque repaint of the page',
    );
  });
}
