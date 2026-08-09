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
// That is why the sweep asserts four separate things per scene rather than
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
//   * **The skin draws as much of it as the register says.** The first three
//     are satisfied identically by a screen that renders through the contract
//     and by one that draws Material by hand, so on their own they made a
//     blueprint run green while it was still measuring Material. See
//     [kContractRenderedPerScene].
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
import 'package:gitui_skin_api/gitui_skin_api.dart';
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

      // How much of this screen the skin actually draws; see
      // [kContractRenderedPerScene] for why an exact number and not a floor,
      // and [kContractRenderedUnderBlueprint] for the one scene whose count
      // the SKIN changes and why that is a measurement rather than a licence.
      expect(
        contractRenderedComponents(),
        _measuringAtDistance
            ? (kContractRenderedUnderBlueprint[scene.name] ??
                  kContractRenderedPerScene[scene.name])
            : kContractRenderedPerScene[scene.name],
        reason:
            'The ${scene.name} scene renders a different number of components '
            'through the contract than kContractRenderedPerScene records. If '
            'it went UP, a migration landed and the register is what makes '
            'that visible - update the number in the same commit. If it went '
            'DOWN, a component stopped reaching its skin and this screen went '
            'back to drawing Material by hand.',
      );

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

/// How many components each scene renders through a contract member.
///
/// ## What this register is for, and why every number is zero today
///
/// The sweep's own claim - "the number of screens that survive the sweep is the
/// progress bar" - was not true of the thing #249 is actually judged on. A
/// screen survives the sweep identically whether it renders through the
/// contract or draws Material by hand, so the whole population went green under
/// `--dart-define=SKIN=blueprint` while producing a widget tree indistinguishable
/// from the Material one: a design language that draws in blue outlines on white
/// paper changed nothing, because nothing on any screen asked it anything. A P3
/// that migrated nothing therefore looked exactly like a P3 that migrated
/// everything, which is the one comparison the instrument exists to make.
///
/// This is that comparison, written down. Every entry is the number of
/// application widgets in that scene that reach their skin - one per
/// `SkinScope.render`, which is the single fence every migrated `Base*`
/// component plants.
///
/// **They were all zero when P2 ended, and P3a's icon conversion is what moved
/// them.** The vocabulary conversion is what unblocked the façade: while
/// `BaseButton.leadingIcon` was an `IconData` and `ButtonSpec.leading` an
/// `IconRole`, no button could be wired through `controls.button` without a
/// reverse glyph table in `lib/` - conflict C3 exactly. With the parameters
/// speaking the contract's vocabulary, `BaseButton`, `BaseIconButton` and
/// `BaseIcon` became façades over their members, and every screen that draws a
/// button or a mark now reaches its skin. The shell and the settings screen
/// dominate because they are almost entirely toolbar actions and rows of
/// buttons.
///
/// **P3b roughly trebled every one of them, and that is the typography
/// collapse.** The thirteen `Base*Label` classes named after Material's type
/// scale became one `BaseLabel` asking for a [TextRole], so text - the thing a
/// screen does far more of than anything else - now reaches the skin too.
/// Screens that were almost all prose moved most: `history` from 3 to 24,
/// `merge_conflicts` from 1 to 17, `browse` from 1 to 11. These are the numbers
/// that make "how much of this screen does the skin actually draw" a fact
/// rather than an impression, and the rise is exactly what the register exists
/// to force somebody to write down.
///
/// **P3c raised every one of them again, and that is the spacing collapse.**
/// The gaps between things and the breathing room inside them were the last
/// large population still written as Material's own numbers - 1,046
/// `AppTheme.padding*` reads and 695 childless `SizedBox`es - and they became
/// [BaseGap] and [BaseInset] asking for a [Proximity] and an [Inset]. Distance
/// is the thing a screen states most often of all, so the rise is the largest
/// so far and it is spread evenly: `repositories` from 21 to 53, `tags` from
/// 13 to 29, `history` from 24 to 63. Nothing about the rendered pixels
/// changed under Material - the five [Proximity] rungs resolve to the five
/// steps the application already used - which is exactly the point: the
/// numbers left application code without the screens moving.
///
/// Asserted as an exact number rather than a floor, in both directions. A drop
/// is a regression - a component stopped reaching its skin. A rise is a
/// migration, and it has to fail here so that the number is updated in the
/// commit that earned it; a floor of zero would let the register go stale and
/// silently stop measuring, which is how the sweep got here in the first place.
const Map<String, int> kContractRenderedPerScene = <String, int>{
  // The nine navigation-rail destination labels are still bare `Text`s,
  // deliberately. The rail owns that slot's typography - it lerps each label
  // between its unselected and selected styles - so those labels are part of
  // a larger member and convert with the shell chrome, the same carve-out
  // BaseLabel documents for a button's words. See the comment at the call
  // site (app_shell.dart) for the paint-path assert that made the
  // misplacement visible.
  //
  // P3d raised most of these once more, and the rise is three things at
  // once: the last wave of the spacing and icon conversion landing on the
  // shell, the changes tree, the history panels, the stash, tag and branch
  // lists and the settings form; `BaseSeparator` finally being adopted for
  // every plain `Divider()` outside the component layer (the settings
  // sections alone account for most of that screen's rise); and the review
  // pass taking a handful BACK - the status tree's bold staging marks, the
  // ref/hash/stats badges' between-the-rungs insets and the empty states'
  // hero marks returned to literals rather than staying rounded onto rungs
  // that moved their pixels, which is why some numbers rose by less than the
  // conversion first measured.
  // The tone conversion's review pass moved exactly two numbers, both by one,
  // and both are the same change: an empty state that used to hand-roll its
  // column adopted `EmptyStateWidget` (#430), whose `BaseInset.roomy` is one
  // more fence than the column planted. The shell's is the command-log
  // panel's "no commands yet" state; browse's is its "no file selected"
  // state. Every other scene measured unchanged - the same run that took the
  // four repository-card metadata marks and the project-section mark back to
  // literals confirmed neither direction moved a count.
  // P5's member wirings raised seven scenes by +50 in total: the badges and
  // tags, the list rows, the command log's disclosure, the repositories grid,
  // the colour picker, the data grid, the commit-graph rows and the suggest
  // fields now reach the skin instead of being hand-painted copies of it.
  // Changes, browse, stashes and tags measured unchanged. Every number below
  // is the sweep's own measurement at closing time, not a sum of the slices'
  // claims.
  // The #438 closing wave raised four scenes by +8: the changes diff panel
  // (its frame, header actions and code lines are the skin's now, +3), the
  // history screen (the commit-graph gutter reservation and the details
  // file tree, +2), the browse screen (its options menu opens through the
  // contract's anchored menu, +1) and the tags screen (its sort and group
  // anchors, +2). Measured at closing under BOTH skins - Material and the
  // blueprint agree on every resting count, so the register stays
  // skin-independent and kContractRenderedUnderBlueprint stays shell-only.
  // The P6 mechanical token sweep raised four scenes by +1 each: converting a
  // hand-stated gap or inset row into the contract's `layout.row` plants one
  // more `SkinScope.render` fence, and one landed on the shell, one on the
  // repositories widgets, one on the history screen and one on the settings
  // screen's config-and-logs section. Measured at closing under BOTH skins -
  // Material and the blueprint report the same four rises - so the register
  // stays skin-independent.
  // The surfaces wave (BaseCard becoming a facade over `surfaces.card`, and
  // the settings sections adopting `surfaces.disclosure`) moved four scenes,
  // in both directions, and every number below is the closing agent's own
  // measurement under BOTH skins - Material and the blueprint agree on each.
  // The falls are consolidation into members, not components leaving their
  // skin, and the attribution walk proves it fence by fence: a BaseCard now
  // plants its OWN card fence while its old internal `BaseInset(all: inset)`
  // fence left with the hand-painting (per card the two cancel), and each
  // settings section's hand-built header - its BaseInset, its BaseIcon mark,
  // its BaseGap and its caret's BaseIcon, four fences - became ONE disclosure
  // fence, -3 per section. Settings fell 18 that way, and the shell fell the
  // same 18 because its scene parks the shell on the settings destination
  // while the chrome measures byte-identical. Changes rose 8 and history 3:
  // the diff viewer's card plants the member's fence now, and the panel
  // headers' insets and action gaps are `BaseInset`/`BaseGap` fences since
  // base_panel.dart's conversion. The shell's skin-independence was RESTORED
  // at closing rather than absorbed into a per-skin entry: the switcher
  // conversion had handed `OverflowActionBar` a skin-dependent width - three
  // extra actions under the blueprint's collapsed insets - and was taken
  // back to literals (see base_switcher.dart for the finding it reports).
  // The banner/badge/avatar wave moved three scenes, in both directions, and
  // every number below is the closing agent's own measurement under BOTH
  // skins - Material and the blueprint agree on each. The shell fell 1: the
  // command log's hand-painted count pill was two fences (its BaseInset and
  // the BaseLabel inside it) and is one `surfaces.badge` fence now.
  // Repositories rose 1: the screen's hand-rolled drag overlay became
  // `surfaces.dropTarget`, whose fence wraps the whole screen; the overlay's
  // own internals render only mid-drag, which no scene performs, and the
  // status pills' conversions to `surfaces.badge`/`surfaces.pressable` land
  // on states this scene's fixture does not reach, so the count moves by the
  // drop target alone. Merge_conflicts fell 5, and the fall is consolidation,
  // not a component leaving its skin: the manual-resolution callout was six
  // fences (a BaseInset, a BaseIcon, two BaseLabels and their two BaseGaps)
  // and is one `surfaces.banner` fence now; the error callout converted the
  // same way (-3) in a branch the scene never renders.
  'shell': 173,
  'workspaces': 34,
  'repositories': 61,
  'changes': 50,
  'history': 90,
  'browse': 26,
  'branches': 19,
  // #249 P4's overlay migration raised exactly two scenes, both for the same
  // reason: their row overflow menus now open through the contract's anchored
  // menu (`Overlays.anchor`). Stashes +2 is its fixture's two stash rows'
  // anchors; tags +3 is its fixture's three tag rows' - each row's trigger is
  // the skin's control now, named 'More actions' where Material's default
  // said 'Show menu'. Measured at closing under BOTH skins - Material and
  // the blueprint land on the same two numbers - so the rise is the
  // application reaching the contract, not a skin drawing more of itself.
  'stashes': 19,
  'tags': 39,
  'settings': 139,
  'merge_conflicts': 31,
};

/// The scenes whose count the SKIN changes, and by how much.
///
/// The register above claims the number is skin-independent: application code
/// plants the fences, so Material and the blueprint should agree, and a
/// disagreement "would itself be a defect". The shell disagreed - 94 under
/// Material, 93 under the blueprint, when this map was first written - and
/// the claim is right: the disagreement IS the defect, and it is one this
/// programme already knows about by name.
///
/// Both numbers grew by 55 when the typography conversion turned every
/// `Base*Label` into a `BaseLabel` reaching `type.text` (64 label sites landed
/// and the nine rail destination labels deliberately went back out - see the
/// register comment above), and the DIFFERENCE stayed at exactly one. That is
/// the useful part: the gap is still the single toolbar action the arithmetic
/// below sheds, and not a second leak hiding inside a bigger number.
///
/// `OverflowActionBar.visibleActionCount()`
/// (lib/shared/widgets/overflow_action_bar.dart:49-69) decides how many
/// toolbar actions to draw by dividing the width it was given by
/// `itemExtent = 48` - a number the application knows only because Material's
/// mark-only control happens to lay out at 48 dp. Under a design language
/// whose controls are wider, the neighbours in the same toolbar take more
/// room, the bar is handed less width, and it draws one action fewer. That is
/// application code deciding a layout from a design language's measurement,
/// which is exactly the residue `docs/SKIN-CONTRACT.md` §1 names, with this
/// very file as its worked example and P5 as its home.
///
/// It is recorded here rather than hidden behind a floor for the same reason
/// every other number is exact: when P5 moves the arithmetic into the skin
/// this map becomes empty, and the day it does is visible. A NEW entry
/// appearing here is a new leak of the same kind and has to be argued for.
///
/// **After P3c the disagreement became distance-conditional, and the entry
/// records the stretched half of the T2 sweep.** Nothing about
/// `visibleActionCount()` changed - it still divides the width it is handed
/// by `itemExtent = 48`. What changed is on the other side of the division:
/// the spacing around the bar's neighbours is now the skin's answer rather
/// than the application's. At the resting distance the blueprint collapses
/// every gap and inset to zero, the bar is handed at least the width every
/// action needs at this window size - exactly as under Material - and both
/// skins land on 137, which is why the map is consulted only on the
/// stretched run (see [_measuringAtDistance]). At `DISTANCE=64` the same
/// neighbours take 64-pixel gaps, the bar is handed less width, and it sheds
/// one action: 136. A count that depends on the distance is precisely the
/// design-dependence T2 exists to surface, and it is the already-named §1
/// residue with P5 as its home - so the sweep asserts the measured number of
/// each half instead of averaging the dependence away or deleting the entry
/// that names it. When P5 moves the arithmetic into the skin, both halves
/// agree, this map becomes empty, and the day it does is visible.
const Map<String, int> kContractRenderedUnderBlueprint = <String, int>{
  // Exactly one less than the register's shell entry, and it must stay
  // exactly one less: the difference IS the single toolbar action
  // `visibleActionCount()` sheds at the stretched distance, so this number
  // moves in lockstep whenever the shell's own count moves. Re-measured at
  // DISTANCE=64 at the surfaces wave's closing: the stretched run lands on
  // 173 against the resting 174, and the gap is still exactly the one shed
  // action. The lockstep had in fact been missed once already - P6 raised
  // the shell to 192 and left this entry at 190, so the stretched half was
  // failing at 191-measured before this wave touched anything - which is
  // worth recording precisely because nothing in the resting gates can see
  // this number go stale.
  'shell': 173,
};

/// Whether this run is the blueprint stretched to a non-zero distance - the
/// right-hand half of the T2 sweep.
///
/// Only that run consults [kContractRenderedUnderBlueprint]: at the resting
/// distance the blueprint currently lands on the skin-independent counts, so
/// the left-hand run keeps asserting [kContractRenderedPerScene] and a
/// resting-state disagreement would fail by name instead of being absorbed
/// by an entry measured under stretch.
bool get _measuringAtDistance =>
    kSkinUnderTest == kBlueprintSkinId &&
    (int.tryParse(kSkinDistance) ?? 0) != 0;

/// How many application widgets currently on screen render through a contract
/// member.
///
/// It counts `SkinPainted` fences BELOW the application's own content boundary,
/// which is exactly the population in question: `SkinScope.install` plants one
/// fence above the boundary for the root treatment, and every `SkinScope.render`
/// - the one door application code has - plants one below it. Counting widgets
/// rather than reading a list is what makes the measurement independent of which
/// skin the run was parameterised with: the fences are planted by application
/// code, so Material and the blueprint produce the same number and a difference
/// between the two runs would itself be a defect.
int contractRenderedComponents() => find
    .descendant(
      of: find.byType(ContentPortBoundary),
      matching: find.byType(SkinPainted),
    )
    .evaluate()
    .length;

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
