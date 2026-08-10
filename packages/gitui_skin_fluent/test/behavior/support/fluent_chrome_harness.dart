/// The chrome half of the behaviour harness: pumps a tree the way the
/// application root does - through `FluentChrome.wrapRoot` - so that what
/// the shell, screen and dialog tests measure is the frame's real
/// composition (theme scope, request scope, ground, ambient text and icon
/// defaults) and never a hand-assembled stand-in.
///
/// It deliberately does NOT reuse `pumpFluentBehavior`: that helper
/// installs the theme and ground itself, which is right for a control
/// measured in isolation and wrong for the facet whose JOB those
/// installations are - a wrapRoot bug would be invisible under a harness
/// that quietly re-does wrapRoot's work.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_fluent/src/facets/fluent_chrome.dart';

import 'fluent_behavior_harness.dart' show kFluentBehaviorSurface;

/// A 1x1 transparent PNG, for the `AppIdentity.appIcon` slot: an
/// `ImageProvider` is required by the spec and a test needs SOME raster.
final Uint8List kTransparentPngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// A request with the neutral settings a desktop rests in. Families are
/// empty so the language's own faces answer, exactly as `styleOf`'s
/// fallback documents.
SkinRequest chromeRequest({
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) => SkinRequest(
  brightness: brightness,
  accentSeed: 0xFF2196F3,
  textScale: textScale,
  codeScale: 1.0,
  animationScale: 1.0,
  monoFamily: '',
  uiFamily: '',
);

/// Pumps [builder]'s widget under the chrome's own root treatment, inside
/// a bare [WidgetsApp] - the same plumbing-only host the control harness
/// documents, with the theme, ground and ambient defaults coming from
/// `wrapRoot` itself.
Future<void> pumpFluentChrome(
  WidgetTester tester,
  WidgetBuilder builder, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = kFluentBehaviorSurface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The desktop resting highlight mode, for the same measured reason the
  // control harness pins it: hover and keyboard-focus highlights only
  // arrive in traditional mode.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  final SkinRequest request = chromeRequest(
    brightness: brightness,
    textScale: textScale,
  );
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? navigator) =>
          const FluentChrome().wrapRoot(
            context,
            request: request,
            // A desktop window's root focus scope holds focus from the
            // moment the window is foreground; without it a Tab has
            // nowhere to travel FROM.
            child: FocusScope(
              autofocus: true,
              child: Builder(builder: builder),
            ),
          ),
    ),
  );
  await tester.pump();
}
