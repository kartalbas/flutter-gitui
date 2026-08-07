// The one place a test in this package builds an application root (#249, P1).
//
// ## Why a funnel, and why now
//
// The #249 programme is judged by a check it calls T2 (docs/SKIN-CONTRACT.md
// §3.4): run the entire test suite twice under the blueprint skin, once at
// `DISTANCE=0` and once at `DISTANCE=64`. A test that fails under either was
// asserting design; a test whose result differs between the two proves the
// application depends on a specific distance. That check is worth nothing
// unless the suite actually renders under the skin it was told to render
// under - and today 46 test files build a `MaterialApp` themselves, so a
// blueprint run would silently keep measuring Material and pass vacuously.
// "A false-confidence risk in the instrument itself is worse than no
// instrument" is the design's own phrasing, and it is the reason this file
// exists before the blueprint does.
//
// So every test that needs an application root gets it from here. When P2
// lands `SkinRegistry` and the Material skin, exactly one function below
// changes - [_root] - and the whole suite moves with it. Nothing at a call
// site changes, which is the property that makes a 46-file migration
// finishable.
//
// ## What it deliberately refuses to do
//
// It refuses to pump under a skin that does not exist. `--dart-define=SKIN`
// and `--dart-define=DISTANCE` are read here and validated here, and anything
// other than a skin this file can genuinely build throws by name. Running the
// T2 sweep against a skin that is not in the tree therefore fails loudly
// instead of producing a green run that measured Material twice.
//
// ## What "under the blueprint" means at P1, exactly
//
// `SKIN=blueprint` installs the real `BlueprintSkin`: the skin-painted fence,
// the `SkinScope`, the application's own `DialogKeyboardHost`, and
// `chrome.wrapRoot` with its ink `DefaultTextStyle` and `IconTheme`. It does
// NOT remove the `MaterialApp`, and that is not a compromise but the
// architecture: SKIN-CONTRACT.md §2.7 says the single `WidgetsApp` root stays
// exactly where `main.dart` has it and the skin wraps BENEATH it.
//
// So the honest description of a blueprint run today is: every widget that has
// been migrated onto the contract renders through the blueprint, and every
// widget that has not still renders Material - which is precisely the
// measurement the programme wants, because at P1 that is all of them. The ink
// defaults are what make the un-migrated remainder visible: a leaked raw
// `Text` renders in ink rather than in the engine's white, and the chromatic
// census can then tell the two apart. The number of screens that survive the
// sweep is the progress bar, exactly as §5.9 says the blueprint jobs are
// advisory until P3d and blocking after it.
//
// ## What it deliberately does not decide
//
// It pumps exactly one frame and returns. Settling is the caller's, because
// there is no single right answer: a screen carrying an indefinite progress
// indicator never settles, so `pumpAndSettle` would hang rather than fail on
// it, while a screen driven by an overridden `FutureProvider` needs a couple
// of scheduled frames before its data branch is on screen. `settleUnderSkin`
// below is the terminating schedule the scene sweep uses; a test that knows
// its screen settles keeps calling `pumpAndSettle` itself.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';
import 'package:gitui_skin_blueprint/gitui_skin_blueprint.dart';
import 'package:gitui_skin_material/gitui_skin_material.dart';
import 'package:google_fonts/google_fonts.dart';
// flutter_riverpod does not re-export the Override type an override list is
// typed with.
import 'package:riverpod/misc.dart' show Override;

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_dialog.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

/// The skin the run was asked to render under, from
/// `--dart-define=SKIN=<id>`. Defaults to the skin the application ships.
const String kSkinUnderTest = String.fromEnvironment(
  'SKIN',
  defaultValue: kMaterialSkinId,
);

/// The blueprint's spacing distance, from `--dart-define=DISTANCE=<n>`.
///
/// A String rather than an int, so "not passed" and "passed as 0" stay
/// distinguishable: T2 runs the suite at 0 and at 64 and compares, and a
/// harness that cannot tell an unset define from a zero one cannot notice
/// that it is being asked to do something it cannot yet do.
const String kSkinDistance = String.fromEnvironment('DISTANCE');

/// The id of the skin the application ships.
const String kMaterialSkinId = 'material';

/// The id of the instrument.
const String kBlueprintSkinId = 'blueprint';

/// Every skin id [pumpUnderSkin] can render, with the phase that adds it.
///
/// The map is the honest statement of how far the harness has got, and a T2
/// run naming an id that is not in the tree is told which phase it is waiting
/// for rather than being handed a Material tree with another skin's label on
/// it.
const Map<String, String> kSkinRoadmap = <String, String>{
  kMaterialSkinId: 'available: the application root as main.dart builds it',
  kBlueprintSkinId:
      'available: the application root with BlueprintSkin installed beneath '
      'it, which is where SKIN-CONTRACT.md §2.7 puts a skin - the single '
      'WidgetsApp root stays where main.dart has it',
  'fluent': 'not yet in the tree - P7',
  'macos': 'not yet in the tree - P8',
};

/// The skin ids this file can genuinely build a root for.
const Set<String> kBuildableSkins = <String>{kMaterialSkinId, kBlueprintSkinId};

/// A desktop surface, because this is a desktop application.
///
/// The test binding defaults to 800x600, which no window of this application
/// is ever laid out at: every screen here is a multi-column layout that
/// overflows below roughly 1200 logical pixels, and an overflow is an
/// exception, so a scene pumped at the default would fail on the harness's
/// window size rather than on anything the application did. 1600x1000 is the
/// size the screen-level keyboard tests already settled on for the same
/// reason.
const Size kDesktopSurface = Size(1600, 1000);

/// Builds the application root for the selected skin, without pumping it.
///
/// Returned as a widget rather than pumped so a caller that has to hold the
/// tree (a population file handing the same root to two sweeps, a test that
/// pumps it twice) uses the same one place. [pumpUnderSkin] is this plus one
/// frame.
Widget skinRoot({
  required Widget home,
  List<Override> overrides = const <Override>[],
  Brightness brightness = Brightness.light,
  TransitionBuilder? appBuilder,
  Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  _refuseASkinThatDoesNotExist();
  return ProviderScope(
    overrides: overrides,
    child: _root(
      home: home,
      brightness: brightness,
      appBuilder: appBuilder,
      routes: routes,
      navigatorKey: navigatorKey,
    ),
  );
}

/// Pumps [home] under the selected skin and returns after one frame.
///
/// [surface] sizes the test window and is reset on tear-down. Null leaves the
/// binding's own surface alone, which is what a test that already sizes the
/// view itself wants.
Future<void> pumpUnderSkin(
  WidgetTester tester, {
  required Widget home,
  List<Override> overrides = const <Override>[],
  Brightness brightness = Brightness.light,
  Size? surface = kDesktopSurface,
  TransitionBuilder? appBuilder,
  Map<String, WidgetBuilder> routes = const <String, WidgetBuilder>{},
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    skinRoot(
      home: home,
      overrides: overrides,
      brightness: brightness,
      appBuilder: appBuilder,
      routes: routes,
      navigatorKey: navigatorKey,
    ),
  );
}

/// Advances the pumped tree by a fixed, terminating schedule.
///
/// Deliberately not `pumpAndSettle`: several screens of this application run
/// an indicator that never stops (a repository whose status is still being
/// probed, a diff that stays loading), and settling on those hangs the run
/// instead of failing it. The schedule below covers a route transition plus
/// the two frames an overridden `FutureProvider` needs to deliver its value
/// and rebuild into its data branch - the same reasoning, and very nearly the
/// same numbers, as `openDialogOfCase` in test/shared/dialogs/.
///
/// Returns the first exception the framework caught while advancing, or null.
/// A layout overflow and a build-time throw both arrive this way, so a caller
/// gets one answer to "did this render cleanly" rather than having to
/// remember to call `takeException` after every pump.
Future<Object?> settleUnderSkin(WidgetTester tester) async {
  for (final Duration step in const <Duration>[
    Duration.zero,
    Duration(milliseconds: 400),
    Duration.zero,
    Duration(milliseconds: 400),
    Duration.zero,
  ]) {
    await tester.pump(step);
    final Object? exception = tester.takeException();
    if (exception != null) return exception;
  }
  return null;
}

/// Advances the pumped tree in *real* elapsed time until [ready] reports the
/// content arrived, or the bound is reached.
///
/// [settleUnderSkin] is enough for everything a widget test controls, because
/// an overridden provider completes inside the test's fake-async zone. It is
/// not enough for work that genuinely leaves the isolate: the browse screen
/// scans a directory off disk, and `dart:io` does not complete inside fake
/// async at all, so no number of `pump`s will ever produce its rows. Only
/// `runAsync` lets that work happen.
///
/// Bounded rather than open-ended, and it returns the first framework
/// exception it saw. When the bound is reached without [ready] ever becoming
/// true it returns normally, leaving the caller's own assertion to report what
/// never appeared - which is a better failure than this function inventing one,
/// and it is still a failure rather than a hang.
Future<Object?> settleRealWorkUnderSkin(
  WidgetTester tester, {
  required bool Function() ready,
  int attempts = 100,
  Duration step = const Duration(milliseconds: 10),
}) async {
  for (int attempt = 0; attempt < attempts; attempt++) {
    if (ready()) return null;
    await tester.runAsync(() => Future<void>.delayed(step));
    final Object? exception = await settleUnderSkin(tester);
    if (exception != null) return exception;
  }
  return null;
}

/// The application root, as `main.dart` builds it, with the selected skin
/// installed beneath it.
///
/// **This is the whole seam**, and there is exactly one of it. At P2, when the
/// Material skin exists as a package, the `theme:`/`darkTheme:` arguments below
/// move inside that skin's own `chrome.wrapRoot` and this function loses two
/// lines; nothing at a call site changes, which is the entire reason the 46
/// roots were collapsed into it.
///
/// It mirrors lib/main.dart rather than inventing a smaller root, because a
/// test rendering under a theme the application never installs measures
/// something the user never sees: `AppTheme` is where every corner radius,
/// every component sub-theme and the whole type ramp come from, and a bare
/// `MaterialApp` with no arguments has none of them.
Widget _root({
  required Widget home,
  required Brightness brightness,
  required TransitionBuilder? appBuilder,
  required Map<String, WidgetBuilder> routes,
  required GlobalKey<NavigatorState>? navigatorKey,
}) {
  // No test may reach the network for a font: the app bundles every family it
  // uses under assets/google_fonts/ and `flutter test` serves those assets, so
  // google_fonts resolves them locally and deterministically.
  GoogleFonts.config.allowRuntimeFetching = false;

  return MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme(),
    darkTheme: AppTheme.darkTheme(),
    themeMode: brightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark,
    // The skin is installed beneath the app root and above the navigator, which
    // is where §2.7 puts it. The caller's own builder runs first, so a test
    // that wraps the app in a MediaQuery override still gets what it asked for
    // and gets it OUTSIDE the skin, where the application's own root would put
    // it.
    builder: (BuildContext context, Widget? child) {
      final Widget app = appBuilder == null
          ? (child ?? const SizedBox.shrink())
          : appBuilder(context, child);
      return installSkinUnderTest(app, brightness: brightness);
    },
    routes: routes,
    home: home,
  );
}

/// Installs the selected skin over the application.
///
/// Both skins are the real thing from P2 on - the fence, the scope, the
/// application's own dialog keyboard host, and `chrome.wrapRoot`. Under
/// Material that root treatment installs the theme `AppTheme` used to build,
/// extracted; under the blueprint it installs the ink `DefaultTextStyle` and
/// `IconTheme` that turn the SDK's own fallbacks into leak detectors.
///
/// The Material branch is no longer a no-op, and that is what P2 changed: a
/// `Base*` component that renders through a contract member reaches its skin
/// through this scope, so a harness without one would fail every test that
/// pumps a migrated component rather than measuring it.
/// Public because a handful of suites build their own application root for a
/// reason this file cannot serve - the two dialog sweeps derive their host from
/// a population and insert a key listener at a measured depth, the shell tests
/// pump a bare `MaterialApp` on purpose. They still have to install the skin,
/// or every migrated `Base*` component they render fails on a missing scope
/// rather than being measured, so the composition lives here in one place and
/// they call it instead of writing a second one.
Widget installSkinUnderTest(
  Widget app, {
  Brightness brightness = Brightness.light,
}) {
  _refuseASkinThatDoesNotExist();
  return SkinScope.install(
    skin: kSkinUnderTest == kBlueprintSkinId
        ? BlueprintSkin(distance: _distance)
        : const MaterialSkin(),
    request: SkinRequest(
      brightness: brightness,
      // The accent seed, the two families and the two scales come from the
      // user's configuration in a running application. A sweep pins them, so
      // that a difference between two runs is the skin's doing and not the
      // machine's - and under Material they are pinned at exactly the values
      // `AppTheme.lightTheme()` / `darkTheme()` default to, so the extracted
      // theme resolves to the one the un-migrated half of the tree is still
      // measured against.
      accentSeed: 0,
      textScale: 1,
      animationScale: 1,
      monoFamily: kSkinUnderTest == kBlueprintSkinId
          ? 'monospace'
          : 'JetBrains Mono',
      uiFamily: kSkinUnderTest == kBlueprintSkinId ? 'sans-serif' : 'Inter',
    ),
    // The application's own keyboard contract, wired in here rather than
    // stubbed: Escape cancels and Enter submits are what the user can do, and
    // a harness that dropped them would let a skin weaken them unnoticed -
    // which is the one thing the three-layer split exists to prevent.
    dialogKeyboardHost:
        (BuildContext context, DialogSpec spec, Widget surface) =>
            DialogKeyboardHost(
              barrierDismissible: spec.barrierDismissible,
              onSubmit: spec.onSubmit,
              child: surface,
            ),
    app: ContentPort(app),
  );
}

/// What `--dart-define=DISTANCE` said, as a number.
///
/// An unset define is zero, which is the instrument's resting state and the
/// left-hand run of the sweep.
int get _distance => kSkinDistance.isEmpty ? 0 : int.parse(kSkinDistance);

/// Fails the run when it was told to render under a skin this harness cannot
/// build, and when it was handed a blueprint parameter with no blueprint to
/// hand it to.
///
/// Both are the same failure in two costumes: a run that believes it measured
/// something it did not. Silence here would make the T2 sweep green on the day
/// it is most important that it is red.
void _refuseASkinThatDoesNotExist() {
  if (!kBuildableSkins.contains(kSkinUnderTest)) {
    throw UnsupportedError(
      'This suite was asked to render under skin "$kSkinUnderTest" '
      '(--dart-define=SKIN=$kSkinUnderTest), and pumpUnderSkin cannot build '
      'that root yet: ${kSkinRoadmap[kSkinUnderTest] ?? 'no such skin id; '
              'known ids are ${kSkinRoadmap.keys.join(', ')}'}. '
      'Failing rather than falling back to Material, because a fallback '
      'would report a green sweep that never rendered the skin it named.',
    );
  }
  if (kSkinDistance.isNotEmpty && kSkinUnderTest != kBlueprintSkinId) {
    throw UnsupportedError(
      'This suite was handed --dart-define=DISTANCE=$kSkinDistance, which '
      'only the blueprint skin reads, while rendering under "$kSkinUnderTest". '
      'The T2 sweep compares a DISTANCE=0 run against a DISTANCE=64 one; '
      'under Material both runs are identical, so a pass here would mean '
      'nothing at all.',
    );
  }
  if (kSkinDistance.isNotEmpty && int.tryParse(kSkinDistance) == null) {
    throw UnsupportedError(
      'This suite was handed --dart-define=DISTANCE=$kSkinDistance, which is '
      'not a number. The distance is the one parameter of the instrument and '
      'a run that silently fell back to zero would report the left-hand half '
      'of the sweep twice.',
    );
  }
}
