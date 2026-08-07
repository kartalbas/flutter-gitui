// Renders every screen of the application, once, through the one skin funnel
// (#249, P1).
//
// ## What this sweep is for
//
// It is the harness the blueprint's leak checks are built on, run today under
// the only skin that exists. Its job right now is narrow and load-bearing:
// prove that every screen in `screenPopulation()` really renders, really
// carries its data, and really terminates - because the moment
// `packages/gitui_skin_blueprint` lands, the same population is pumped through
// the same funnel and the frames are handed to T1 (the chromatic census), T3
// (the attribution walk) and T5 (the chaos pair) instead of being thrown away.
// A scene that only renders under Material is worth nothing to them, and a
// scene that hangs or throws is worth less than nothing: it removes a screen
// from the instrument's field of view without anybody noticing.
//
// That is why the sweep asserts three separate things per scene rather than
// just "it did not throw":
//
//   * **It rendered without an exception.** A layout overflow is an exception
//     in debug, so this is also the assertion that a screen fits the window it
//     was given - the same failure mode the Material screen goldens exist to
//     catch, here at whole-screen scale.
//   * **It carries its fixture's data.** A screen that renders its "no
//     repository" empty state passes any smoke test and is useless as a leak
//     surface, because an empty state contains almost nothing that could have
//     leaked. The expected texts are what tell the two apart.
//   * **It is still there after the schedule.** A screen that threw its
//     content away mid-settle would satisfy the first two on an early frame.
//
// ## Why every scene is pumped at one brightness and one width
//
// Two renders per scene would double a sweep that is already the heaviest in
// this suite, and would buy something this file is not the right owner of: the
// light/dark axis belongs to the Material conformance goldens
// (packages/gitui_skin_material/test/conformance/goldens/), which capture both
// brightnesses of everything they cover, and the leak checks that will consume
// this population render under the blueprint's single paper-and-ink palette
// where brightness does not exist. A scene that needs an unusual window
// declares it as its own `surface`.
//
// ## The census
//
// The list at the bottom is what makes this a sweep rather than a long test:
// it enumerates every screen file in lib/ and fails when one is neither
// covered by a scene nor carried by a documented exclusion, and it fails just
// as loudly on an exclusion that has gone stale. A screen therefore cannot be
// added to the application without the leak checks noticing that they cannot
// see it.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// flutter_riverpod does not re-export the Override type an override list is
// typed with.
import 'package:riverpod/misc.dart' show Override;

import 'pump_under_skin.dart';
import 'screen_population.dart';

void main() {
  setUpAll(prepareScreenFixtures);
  tearDownAll(disposeScreenFixtures);

  for (final ScreenScene scene in screenPopulation()) {
    testWidgets('${scene.name} renders under skin $kSkinUnderTest', (
      WidgetTester tester,
    ) async {
      silenceDesktopDrop(tester.binding.defaultBinaryMessenger);

      // One list, pumped twice: Riverpod forbids changing the number of
      // overrides on a live scope, and reusing the instances is also what
      // keeps the take-down below running against the container the screen
      // was built against.
      final List<Override> overrides = scene.overrides();

      await pumpUnderSkin(
        tester,
        home: scene.build(),
        overrides: overrides,
        surface: scene.surface,
      );

      final Object? exception = await _settle(tester, scene);
      expect(
        exception,
        isNull,
        reason:
            'The ${scene.name} scene (${scene.source}) threw while rendering '
            'at ${scene.surface.width.toStringAsFixed(0)}x'
            '${scene.surface.height.toStringAsFixed(0)}. Until it renders, '
            'every #249 leak check is blind to that screen.',
      );

      for (final String expected in scene.expectedTexts) {
        expect(
          find.textContaining(expected),
          findsAtLeast(1),
          reason:
              'The ${scene.name} scene rendered without "$expected" on '
              'screen, so it is not showing the data its overrides gave it - '
              'most likely it fell back to an empty or an error state. Such a '
              'scene passes a smoke test and hides a leak, because a screen '
              'with nothing on it has nothing that could have leaked.',
        );
      }

      // Take the screen down the way the application takes one down: the
      // screen is replaced while the ProviderScope goes on living, because
      // main.dart's scope outlives every screen and a screen that saves state
      // in `dispose` is writing into a container that is still there.
      //
      // Doing this explicitly is not politeness towards the harness. Without
      // it, the tree is disposed by flutter_test's own end-of-test `runApp`,
      // which tears the scope down in the same frame - an ordering the
      // application never produces - so a screen's `dispose` would fail
      // against a disposed container and report a defect that is not one.
      // Asserting on it afterwards means the reverse also holds: a screen
      // that really does throw on the way out fails here, by name.
      await tester.pumpWidget(
        skinRoot(home: const SizedBox.shrink(), overrides: overrides),
      );
      expect(
        await settleUnderSkin(tester),
        isNull,
        reason:
            'The ${scene.name} scene (${scene.source}) threw while being '
            'taken down, with its providers still alive.',
      );
    });
  }

  test(
    'every screen in lib/ is covered by a scene or a named exclusion',
    () {
      final Set<String> discovered = _screenSourcesInLib();
      final Set<String> covered = <String>{
        for (final ScreenScene scene in screenPopulation()) scene.source,
      };
      final Set<String> excluded = kScreensNoSceneCovers.keys.toSet();

      expect(
        discovered.difference(covered).difference(excluded),
        isEmpty,
        reason:
            'These screens exist in lib/ and no scene renders them, so every '
            '#249 leak check is blind to them. Add a scene to '
            'screen_population.dart, or add an entry to kScreensNoSceneCovers '
            'saying why the programme accepts not looking at this screen.',
      );

      // The register is honest in both directions: a scene or an exclusion
      // naming a file that no longer exists is a claim about nothing.
      expect(
        covered.difference(discovered),
        isEmpty,
        reason:
            'These scenes name a lib/ file that does not exist. A scene whose '
            'source has been renamed stops being counted by the census while '
            'still looking like coverage.',
      );
      expect(
        excluded.difference(discovered),
        isEmpty,
        reason:
            'These exclusions name a lib/ file that does not exist and are '
            'therefore excusing nothing.',
      );
      expect(
        excluded.intersection(covered),
        isEmpty,
        reason:
            'These screens are both excluded and covered. The exclusion is '
            'stale and reads as a decision not to look at a screen this sweep '
            'is in fact looking at.',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

/// Gets [scene] onto the screen, by whichever of the two routes it declared,
/// and reports the first framework exception seen on the way.
///
/// The real-work route waits for the scene's own promised content rather than
/// for a fixed number of milliseconds, which is what keeps a slow machine from
/// turning a correct screen into a flaky failure - and keeps a screen that
/// never loads from being waited on for longer than the bound.
Future<Object?> _settle(WidgetTester tester, ScreenScene scene) async {
  final Object? exception = await settleUnderSkin(tester);
  if (exception != null || scene.settle == SceneSettle.onScheduledFrames) {
    return exception;
  }
  return settleRealWorkUnderSkin(
    tester,
    ready: () => scene.expectedTexts.every(
      (String text) => find.textContaining(text).evaluate().isNotEmpty,
    ),
  );
}

/// Every screen file in lib/, slash-separated and relative to the package
/// root.
///
/// "A screen" is a file whose name ends in `_screen.dart` - the convention
/// this application has followed without exception - plus the shell, which is
/// the frame every one of them is rendered inside and is named for what it is
/// rather than for the convention.
Set<String> _screenSourcesInLib() {
  final Directory lib = Directory(_resolveFromPackageRoot('lib'));
  final int rootLength = _resolveFromPackageRoot('').length;
  return <String>{
    'lib/core/navigation/app_shell.dart',
    for (final FileSystemEntity entity in lib.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('_screen.dart'))
        entity.path.substring(rootLength).replaceAll(r'\', '/'),
  };
}

/// Resolves [relativePath] against the package root, walking up from the
/// current directory to the first pubspec.yaml (tests may run from a
/// subdirectory).
String _resolveFromPackageRoot(String relativePath) {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return '${dir.path}/$relativePath';
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) return relativePath;
    dir = parent;
  }
}
