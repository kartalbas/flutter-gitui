import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'blueprint_ink.dart';
import 'facets/blueprint_chrome.dart';
import 'facets/blueprint_controls.dart';
import 'facets/blueprint_layout.dart';
import 'facets/blueprint_motion.dart';
import 'facets/blueprint_overlays.dart';
import 'facets/blueprint_surfaces.dart';
import 'facets/blueprint_type.dart';

/// The instrument: a whole design language that renders nothing but outlines.
///
/// It is not a look and it is not a fallback. It is the falsifier the contract
/// is judged against: render the application under it and anything that still
/// looks styled is design that leaked out of a skin and into application code.
/// Everything it knows how to draw is four decisions and one rule, and both
/// live in `BlueprintInk`.
///
/// **Its obligation is stronger than "renders nothing"**
/// (`docs/SKIN-CONTRACT-MEMBERS.md` §9): it implements every member and accepts
/// every parameter, and wherever a parameter can be rendered distinguishably
/// without becoming design - a wider box for a larger scale, a heavier outline
/// for a louder emphasis, a broken outline for a link - it is. A blueprint
/// that silently ignored a parameter would teach the next skin author to
/// ignore it, because the blueprint is the template they copy: copy this
/// package, replace the bodies. With the parameters rendered, a parameter the
/// application never varies shows up as a constant and a parameter a skin
/// drops shows up as a difference from the blueprint - which turns the
/// instrument from a passive backdrop into a second, independent check.
///
/// **It is parameterised**, and [distance] is the only parameter. At the
/// default of zero every rung of `Proximity` and `Inset` collapses to nothing,
/// which is the Zero Test executed rather than described. The
/// zero-and-extremes sweep runs the whole suite twice:
///
/// ```bash
/// flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=0
/// flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=64
/// ```
///
/// so [distance] defaults to `--dart-define=DISTANCE` and needs no harness of
/// its own. Any test that fails under either setting was asserting design; any
/// test whose result differs between the two proves the application depends on
/// a specific distance.
final class BlueprintSkin implements Skin {
  /// Builds the instrument at [distance].
  const BlueprintSkin({this.distance = _environmentDistance})
    : chaos = BlueprintChaos.none,
      seed = 0;

  /// Builds the instrument with its two colours derived from [seed] and every
  /// metric frozen - the paint half of T5 (`docs/SKIN-CONTRACT.md` §3.7).
  ///
  /// Render a scene under seed 1 and again under seed 2 and compare: because
  /// the metrics are frozen, positions correspond exactly, so **any pixel that
  /// is identical across the pair is a pixel this skin did not choose.** That
  /// is a colour the application chose - including the greys, the whites, the
  /// alpha blends and the runtime-computed colours that the chromatic census
  /// permits, and including the ones inside a `CustomPainter` where every lint
  /// is blind.
  const BlueprintSkin.chromaChaos({
    required this.seed,
    this.distance = _environmentDistance,
  }) : chaos = BlueprintChaos.chroma;

  /// Builds the instrument with its metrics derived from [seed] and its two
  /// colours frozen - the geometry half of T5.
  ///
  /// **Any region that fails to move between two seeds is geometry the
  /// application decided.** This is the only check in the programme that sees
  /// a hardcoded `SizedBox(height: 13)`: the census cannot (it has no colour),
  /// and the zero-and-extremes sweep cannot either (it is the same 13 under
  /// `DISTANCE=0` and `DISTANCE=64`, so no result differs).
  ///
  /// It varies three things, and between them they move everything this skin
  /// draws: the distance every rung resolves against, the width of every
  /// stroke, and the minimum extent of every control.
  const BlueprintSkin.metricChaos({
    required this.seed,
    this.distance = _environmentDistance,
  }) : chaos = BlueprintChaos.metric;

  /// What `--dart-define=DISTANCE` said, or zero when it said nothing.
  static const int _environmentDistance = int.fromEnvironment('DISTANCE');

  /// The largest distance any rung resolves to, in logical pixels.
  ///
  /// Zero is the instrument's resting state and the left-hand run of the
  /// sweep: every gap, every inset and every indent is nothing at all, so a
  /// layout that still holds together is a layout that never depended on a
  /// number.
  final int distance;

  /// Which of T5's two families this instrument belongs to, if either.
  final BlueprintChaos chaos;

  /// What that family derives its variation from. Ignored at
  /// [BlueprintChaos.none].
  final int seed;

  /// The two colours and the two metric scales this build draws with.
  ///
  /// Installed once by `chrome.wrapRoot` and read from the tree by every
  /// primitive, so a facet never learns that the chaos families exist.
  BlueprintVocabulary get vocabulary => switch (chaos) {
    BlueprintChaos.none => BlueprintVocabulary.standard,
    BlueprintChaos.chroma => BlueprintVocabulary.chromaChaos(seed),
    BlueprintChaos.metric => BlueprintVocabulary.metricChaos(seed),
  };

  /// How this skin is named in configuration and in a test parameterisation.
  @override
  String get id => 'blueprint';

  /// The key for the name a user would see, if a user could pick it.
  ///
  /// A key rather than a string, because the application owns its
  /// translations and a skin package must not ship its own.
  @override
  String get nameKey => 'skinBlueprint';

  /// True, and it is the only skin for which it is true.
  ///
  /// An instrument is not something to ship: `SkinRegistry.selectable` hides
  /// it in a release build, so a user cannot end up looking at an application
  /// drawn in outlines. It stays reachable in debug precisely because that is
  /// when it is being used as an instrument.
  @override
  bool get isInstrument => true;

  /// Nothing at all, which is the point.
  ///
  /// The three declared exceptions exist because Flutter plumbing requires
  /// them of SOME skin - `fluent.showDialog` checks its own localisations
  /// before it pushes, `macos_ui` reads `MaterialLocalizations` un-guarded,
  /// and window chrome is a one-time `window_manager` call today. The
  /// blueprint needs none of it, and answering with the empty values is what
  /// demonstrates that the claims are a latitude for particular design
  /// languages rather than a hole in the contract.
  @override
  SkinRootClaims get rootClaims => const SkinRootClaims(
    localizationsDelegates: <LocalizationsDelegate<Object?>>[],
    scrollBehavior: ScrollBehavior(),
    windowChrome: WindowChrome.hostDefault,
  );

  @override
  SkinChrome get chrome => BlueprintChrome(_distance, vocabulary: vocabulary);

  @override
  SkinControls get controls => BlueprintControls(_distance);

  @override
  SkinSurfaces get surfaces => BlueprintSurfaces(_distance);

  @override
  SkinType get type => BlueprintType(_distance);

  @override
  SkinLayout get layout => BlueprintLayout(_distance);

  @override
  SkinMotion get motion => BlueprintMotion(_distance);

  @override
  SkinOverlays get overlays => BlueprintOverlays(_distance);

  /// The resolved distance, handed to every facet.
  ///
  /// The facets are getters rather than fields, and each is a value object
  /// with no state of its own. That keeps this class `const`-constructible -
  /// which matters, because the instrument is configured from a compile-time
  /// define - at the cost of one small allocation per access, and it means a
  /// facet can be rewritten without touching this file. Three people work in
  /// this package at once; a facet that had to be wired in here would make
  /// this file the contended one.
  ///
  /// Under [BlueprintChaos.metric] the distance comes from the seed rather
  /// than from [distance], because a family that varied strokes and extents
  /// while leaving every gap at the same number would leave most of the screen
  /// exactly where it was - and "did not move" is the metric family's word for
  /// "the application decided this".
  BlueprintDistance get _distance => switch (chaos) {
    BlueprintChaos.metric => BlueprintDistance(8 + (seed % 7) * 8),
    _ => BlueprintDistance(distance.toDouble()),
  };

  /// Adds the instrument to this build's list of design languages.
  ///
  /// The whole of what "plugin" can mean on a desktop AOT build with no
  /// dynamic code loading: one pubspec dependency and one call. Nothing else
  /// in the application learns this package's name.
  static void register({int distance = _environmentDistance}) =>
      SkinRegistry.register(BlueprintSkin(distance: distance));
}

/// Which of T5's two families an instrument belongs to.
///
/// Two families rather than two seeds of one, and the repair matters: varying
/// ink AND metrics together displaces a leak's pixels between seeds, so
/// nothing is invariant, the zero threshold is met, and the check goes green
/// on a clean application and a maximally leaky one alike. Each family freezes
/// exactly what the other varies.
enum BlueprintChaos {
  /// The instrument at rest: paper, ink, and whatever distance was asked for.
  none,

  /// Colours from the seed, metrics frozen. Identical pixels are the
  /// application's colours.
  chroma,

  /// Metrics from the seed, colours frozen. Unmoved regions are the
  /// application's geometry.
  metric,
}
