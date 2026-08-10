/// The overlay half of the behaviour harness: a real `SkinScope` over a real
/// navigator, so `Overlays.menu` can be driven exactly the way the
/// application drives it.
///
/// An overlay member cannot be measured the way a control is, because its
/// entries are reachable only through a host and a host is constructable
/// only by the API package's own `Overlays` door - which requires a
/// [SkinScope], whose installation calls `chrome.wrapRoot`. The real Fluent
/// chrome is another slice's work and still throws, so this harness supplies
/// the one thing the overlay members need from it: a chrome whose `wrapRoot`
/// installs exactly what the real one will install for them - the request
/// scope, the theme, and the page's default text treatment - and whose other
/// members keep the same loud fence the skin itself keeps. Every facet the
/// harness skin answers with is the REAL Fluent facet, so what the suite
/// measures is the skin, not the harness.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/fluent_request_scope.dart';
import 'package:gitui_skin_fluent/src/fluent_skin.dart';
import 'package:gitui_skin_fluent/src/fluent_theme.dart';
import 'package:gitui_skin_fluent/src/fluent_typography.dart';

import 'fluent_behavior_harness.dart';

/// The user's choices as this suite pins them. Empty families keep the type
/// resolution on the language's own faces, so no font is fetched and a
/// measured size is the ramp's.
SkinRequest fluentOverlayRequest(
  Brightness brightness, {
  double animationScale = 1,
}) => SkinRequest(
  brightness: brightness,
  accentSeed: 0,
  textScale: 1,
  codeScale: 1,
  animationScale: animationScale,
  monoFamily: '',
  uiFamily: '',
);

/// The skin under measurement: Fluent's real facets behind a harness chrome.
final class FluentOverlayHarnessSkin implements Skin {
  /// Builds the harness skin.
  const FluentOverlayHarnessSkin();

  static const FluentSkin _real = FluentSkin();

  @override
  String get id => _real.id;

  @override
  String get nameKey => _real.nameKey;

  @override
  bool get isInstrument => _real.isInstrument;

  @override
  SkinRootClaims get rootClaims => _real.rootClaims;

  /// The one substitution: `wrapRoot` works, everything else stays fenced.
  @override
  SkinChrome get chrome => const _HarnessChrome();

  @override
  SkinControls get controls => _real.controls;

  @override
  SkinSurfaces get surfaces => _real.surfaces;

  @override
  SkinType get type => _real.type;

  @override
  SkinLayout get layout => _real.layout;

  @override
  SkinMotion get motion => _real.motion;

  @override
  SkinOverlays get overlays => _real.overlays;
}

/// What the real Fluent chrome's `wrapRoot` will install for the overlay
/// members, and nothing else: the request, the theme, and the page's
/// default text treatment (the ramp's body step in the primary text fill,
/// which is what the reference's own theme stamps as its default).
final class _HarnessChrome implements SkinChrome {
  const _HarnessChrome();

  @override
  Widget wrapRoot(
    BuildContext context, {
    required Widget child,
    required SkinRequest request,
  }) {
    final FluentThemeData data = request.brightness == Brightness.dark
        ? const FluentThemeData.dark()
        : const FluentThemeData.light();
    return FluentRequestScope(
      request: request,
      child: FluentTheme(
        data: data,
        child: DefaultTextStyle(
          style: FluentTypeRamp.body.copyWith(
            color: data.resources.textFillColorPrimary,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget shell(BuildContext context, ShellSpec spec) =>
      throw UnimplementedError('The harness chrome only wraps the root.');

  @override
  Widget screen(BuildContext context, ScreenSpec spec) =>
      throw UnimplementedError('The harness chrome only wraps the root.');

  @override
  Widget dialogSurface(BuildContext context, DialogSpec spec) =>
      throw UnimplementedError('The harness chrome only wraps the root.');
}

/// Pumps [screen] as the home page of a bare [WidgetsApp] with a real
/// navigator, under an installed [SkinScope] carrying
/// [FluentOverlayHarnessSkin] - the same composition `main.dart` gives the
/// application, minus everything that is not needed to open an overlay.
Future<void> pumpFluentOverlayApp(
  WidgetTester tester,
  WidgetBuilder screen, {
  Brightness brightness = Brightness.light,
  double animationScale = 1,
}) async {
  tester.view.physicalSize = kFluentBehaviorSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The same measurement precondition pumpFluentBehavior documents: desktop
  // rests in the traditional highlight mode, and only that mode delivers
  // hover and focus highlights.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  final FluentThemeData data = brightness == Brightness.dark
      ? const FluentThemeData.dark()
      : const FluentThemeData.light();
  final SkinRequest request = fluentOverlayRequest(
    brightness,
    animationScale: animationScale,
  );
  await tester.pumpWidget(
    WidgetsApp(
      color: data.resources.solidBackgroundFillColorBase,
      debugShowCheckedModeBanner: false,
      // The scope sits above the navigator, exactly as it does in the
      // application, so a route pushed by an overlay member finds it - and
      // the host still re-establishes it inside the route, which is the
      // behaviour under test.
      builder: (BuildContext context, Widget? navigator) => SkinScope.install(
        skin: const FluentOverlayHarnessSkin(),
        request: request,
        // The application's dialog keyboard contract is the application's;
        // the overlay suite here never presents a dialog, so the identity
        // host keeps the seam visible without inventing behaviour.
        dialogKeyboardHost:
            (BuildContext context, DialogSpec spec, Widget surface) => surface,
        app: ContentPort(
          ColoredBox(
            color: data.resources.solidBackgroundFillColorBase,
            child: navigator ?? const SizedBox.shrink(),
          ),
        ),
      ),
      onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => Center(child: Builder(builder: screen)),
      ),
    ),
  );
  await tester.pump();
}
