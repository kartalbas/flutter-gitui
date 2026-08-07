/// The blueprint's entire visual vocabulary, and the primitives every facet
/// draws with.
///
/// **This library is shared by all seven facets.** A facet that needs a mark,
/// a box or a stroke takes it from here rather than spelling one out at the
/// call site, because the blueprint's whole value is that two members which
/// render the same way are indistinguishable *on purpose* and two members
/// which render differently differ *for a stated reason*. A private helper in
/// one facet file destroys that property quietly.
///
/// The vocabulary is four decisions and nothing else
/// (`docs/SKIN-CONTRACT.md` §3.1):
///
///  1. **Paper `#FFFFFF`, ink `#0000FF`.** Two colours, and at rest always
///     these two - the T5 chaos families in [BlueprintVocabulary] are the one
///     exception, and they are a measurement rather than a look. The blue
///     channel
///     is saturated on purpose: paper and ink share `b = 255`, so the set of
///     legal pixels is closed under alpha compositing over paper and under any
///     per-channel-uniform coverage blend - which is what greyscale,
///     gamma-corrected text antialiasing produces. The chromatic census is
///     therefore exact arithmetic (`r == g && b == 0xFF`) rather than a
///     tolerance, and every wash offered here stays on that line by
///     construction.
///  2. **A 1px ink outline** on every control and every surface. That is the
///     naked square.
///  3. **Zero.** Every corner is square, every duration is `Duration.zero`,
///     every rung of [Proximity] and [Inset] resolves through
///     [BlueprintDistance], which answers 0 for all of them unless the
///     instrument was built with a distance.
///  4. **Ink defaults installed** at the root, so a leaked raw `Text` renders
///     in the engine's white and fails the census instead of passing it
///     invisibly.
///
/// And one rule the whole package obeys:
///
/// > **The blueprint never destroys information, only appearance.**
///
/// Meaning that a colour would have carried renders as a text **marker beside**
/// the content and never inside it, so `find.text('Delete')` still matches an
/// application that asks for a destructive button.
library;

import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

/// The instrument's four decisions, as they stand in THIS build.
///
/// Ordinarily this is [standard] - white paper, blue ink, a 1px outline - and
/// nothing else. It is a value rather than a constant because of **T5, the
/// chaos pair** (`docs/SKIN-CONTRACT.md` §3.7), which is the only check in the
/// programme that catches a leak with no colour of its own and no dependence
/// on a distance:
///
///  * **`BlueprintSkin.chromaChaos(seed:)` varies the two colours and freezes
///    every metric.** Positions correspond exactly between two seeds, so any
///    pixel that is IDENTICAL across the pair is a pixel this skin did not
///    choose - which is to say a pixel the application chose. That catches
///    greys, whites, alpha blends and runtime-computed colours, all of which
///    the chromatic census permits, and it reaches inside a `CustomPainter`
///    and a third-party widget where every lint is blind.
///  * **`BlueprintSkin.metricChaos(seed:)` varies the metrics and freezes the
///    two colours.** Any region that fails to MOVE between two seeds is
///    geometry the application decided - the hardcoded `SizedBox(height: 13)`
///    that the census cannot see (it has no colour) and the zero-and-extremes
///    sweep cannot see either (it is the same 13 under both distances).
///
/// Both families freeze exactly what the other varies, which is what makes the
/// pair a measurement rather than a picture: the original single-family
/// proposal displaced a leak's pixels between seeds, so nothing was invariant,
/// the threshold was met, and the check went green on a clean application and
/// a maximally leaky one alike.
///
/// Two things deliberately do NOT vary under either family. [BlueprintGeometry]
/// ring counts and the link dash carry `Elevation` and `Emphasis` - they are
/// information, not appearance - and a family that varied them would make the
/// two seeds say different things rather than look different, which is the one
/// thing this skin may never do.
@immutable
final class BlueprintVocabulary {
  /// Declares one resolved vocabulary.
  const BlueprintVocabulary({
    this.paper = BlueprintInk.standardPaper,
    this.ink = BlueprintInk.standardInk,
    this.strokeScale = 1,
    this.extentScale = 1,
  });

  /// Paper, ink and a 1px outline: the instrument at rest, and what every
  /// check other than T5 runs against.
  static const BlueprintVocabulary standard = BlueprintVocabulary();

  /// Two colours derived from [seed], with every metric frozen.
  ///
  /// The derivation is a multiply-and-mask of the seed by two different odd
  /// constants, so it is deterministic, cheap, constant-foldable and produces
  /// a different pair for every seed. It deliberately does NOT stay on the
  /// paper-to-ink line: the chroma family is the one place the census
  /// invariant is not in force, because the whole method is to compare two
  /// renders with each other rather than each against a fixed palette.
  factory BlueprintVocabulary.chromaChaos(int seed) => BlueprintVocabulary(
    paper: _hue(seed, 0x9E3779B1),
    ink: _hue(seed, 0x85EBCA77),
  );

  /// Metrics derived from [seed], with the two colours frozen.
  ///
  /// The scales are small whole steps rather than arbitrary reals, so a
  /// difference between two seeds is a difference a human can read off a mask
  /// PNG, and so no seed produces a hairline thinner than a physical pixel.
  factory BlueprintVocabulary.metricChaos(int seed) => BlueprintVocabulary(
    strokeScale: 1 + (seed % 4),
    extentScale: 1 + (seed % 3),
  );

  /// One colour from a seed and a salt.
  ///
  /// `seed + 1` so that seed 0 is a colour rather than black, the xor-shift so
  /// that neighbouring seeds are far apart rather than adjacent, and two
  /// different salts so that paper and ink of one seed never collide. It is
  /// deterministic, which is what lets a failing T5 mask be reproduced from
  /// the seed alone.
  static Color _hue(int seed, int salt) {
    final int mixed = (seed + 1) * salt;
    return Color(0xFF000000 | ((mixed ^ (mixed >> 13)) & 0x00FFFFFF));
  }

  /// The background of everything.
  final Color paper;

  /// The foreground of everything: every outline, every glyph, every mark.
  final Color ink;

  /// What every stroke width is multiplied by.
  final double strokeScale;

  /// What every minimum control extent is multiplied by.
  final double extentScale;

  /// The width of the naked outline, in logical pixels.
  double get hairline => strokeScale;

  /// Ink over paper at [alpha]. The blueprint's only fill.
  Color wash(double alpha) => ink.withValues(alpha: alpha);

  /// How loud a control is, as whole pixels of outline.
  double stroke(Emphasis emphasis) =>
      strokeScale *
      switch (emphasis) {
        Emphasis.primary => 3,
        Emphasis.secondary => 2,
        Emphasis.quiet => 1,
        Emphasis.link => 1,
      };

  /// The smallest box a control of this scale may be drawn in.
  double extent(ControlScale scale) =>
      extentScale *
      switch (scale) {
        ControlScale.compact => 16,
        ControlScale.normal => 32,
        ControlScale.prominent => 64,
      };

  /// The vocabulary in force at [context].
  ///
  /// Falls back to [standard] when no root treatment has been installed, which
  /// is what lets a test call one member directly without pumping a whole
  /// application. That is a fallback about the INSTRUMENT's own configuration
  /// and not about the application's design language, which is why it is
  /// allowed to be silent where `SkinScope.of` is not: the worst it can do is
  /// render the resting instrument instead of a chaotic one, and a T5 run
  /// establishes the root by construction.
  static BlueprintVocabulary of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_BlueprintVocabularyScope>()
          ?.vocabulary ??
      standard;

  /// Installs [vocabulary] over [child]. Called by `chrome.wrapRoot`, which is
  /// the one place a skin's root treatment is installed.
  static Widget install({
    required BlueprintVocabulary vocabulary,
    required Widget child,
  }) => _BlueprintVocabularyScope(vocabulary: vocabulary, child: child);

  @override
  bool operator ==(Object other) =>
      other is BlueprintVocabulary &&
      other.paper == paper &&
      other.ink == ink &&
      other.strokeScale == strokeScale &&
      other.extentScale == extentScale;

  @override
  int get hashCode => Object.hash(paper, ink, strokeScale, extentScale);

  @override
  String toString() =>
      'BlueprintVocabulary(paper: $paper, ink: $ink, '
      'stroke: x$strokeScale, extent: x$extentScale)';
}

/// A region whose pixels the chromatic census skips.
///
/// The census asserts one line of arithmetic per pixel - every legal pixel is
/// an alpha blend of paper and ink, so `r == g && b == 0xFF` - and genuinely
/// pictorial content cannot satisfy it, because the application did not choose
/// the colours in a PNG either. `docs/SKIN-CONTRACT.md` §3.3(c) accepts that
/// and names the cost precisely: **the census is only as strong as the
/// shortness of this list**, and a leak wrapped in one of these is invisible to
/// it. That is process rather than proof, so the process is made as hard to
/// slip as a process can be: every region names the member that opened it, the
/// [sites] allowlist is checked in, the constructor asserts membership, and
/// [cap] is a count a test holds shrink-only.
///
/// It lives in the shared library rather than in one facet because two members
/// need it and a third would otherwise grow a private copy - which is exactly
/// how an allowlist stops being one.
final class BlueprintOpaque extends InheritedWidget {
  /// Fences [child] as content the census does not read, on behalf of [site].
  BlueprintOpaque({super.key, required this.site, required super.child})
    : assert(
        sites.contains(site),
        'A region the chromatic census skips has to be on the allowlist in '
        'BlueprintOpaque.sites, because the census is only as strong as the '
        'shortness of that list. Add "$site" there with its reason, and lower '
        'BlueprintOpaque.cap in the same commit if it can be lowered.',
      );

  /// The member that needed it, for the failure message and for the audit.
  final String site;

  /// Every member allowed to open one, and why it has to.
  ///
  ///  * `surfaces.imageViewer` - the application's own image viewer, whose
  ///    content is a photograph.
  ///  * `chrome.shell/appIcon` - `AppIdentity.appIcon` is a raster the
  ///    application supplies, carried on the spec because macOS's own alert
  ///    requires one. Rendering it is not optional: it is not in the
  ///    §9.2 exemption table, whose rule is that everything absent from it is
  ///    rendered, and a skin that dropped it would be indistinguishable from
  ///    one that drew it if the blueprint dropped it too.
  ///
  /// `surfaces.markdown` is deliberately NOT here: Markdown source is text,
  /// rendering it verbatim destroys no information, and fencing it would hide
  /// a skin that lost it.
  static const List<String> sites = <String>[
    'surfaces.imageViewer',
    'chrome.shell/appIcon',
  ];

  /// The hard cap §3.3(c) requires. It may only ever shrink; a test pins it.
  static const int cap = 2;

  @override
  bool updateShouldNotify(covariant BlueprintOpaque oldWidget) => false;
}

/// Carries the resolved vocabulary down the tree from `chrome.wrapRoot`.
class _BlueprintVocabularyScope extends InheritedWidget {
  const _BlueprintVocabularyScope({
    required this.vocabulary,
    required super.child,
  });

  final BlueprintVocabulary vocabulary;

  @override
  bool updateShouldNotify(_BlueprintVocabularyScope oldWidget) =>
      oldWidget.vocabulary != vocabulary;
}

/// The two colours, and the one stroke.
///
/// Every member here reads the vocabulary in force at the given context rather
/// than a constant, so that the T5 chaos families reach every mark, every
/// outline and every glyph without a single facet knowing they exist.
abstract final class BlueprintInk {
  /// The background of everything, at rest.
  static const Color standardPaper = Color(0xFFFFFFFF);

  /// The foreground of everything, at rest: every outline, every glyph, every
  /// mark.
  ///
  /// The blue channel is saturated on purpose - paper and ink share `b = 255`,
  /// so the census invariant `r == g && b == 0xFF` is exact arithmetic rather
  /// than a tolerance.
  static const Color standardInk = Color(0xFF0000FF);

  /// The background of everything.
  static Color paper(BuildContext context) =>
      BlueprintVocabulary.of(context).paper;

  /// The foreground of everything.
  static Color ink(BuildContext context) => BlueprintVocabulary.of(context).ink;

  /// The width of the naked outline, in logical pixels.
  static double hairline(BuildContext context) =>
      BlueprintVocabulary.of(context).hairline;

  /// How many members `Tone.series` has under this skin.
  ///
  /// The contract gives the palette AND its length to the skin, which is why
  /// `controls.seriesPicker` exists at all: once the length is the skin's, the
  /// application has no legal way to enumerate the swatches. The blueprint has
  /// no palette, so this is simply the length it declares - twelve, the number
  /// of distinct lanes the commit graph and the workspace colours ask for -
  /// and every member of the series renders as its own index rather than as a
  /// hue.
  static const int seriesLength = 12;

  /// Ink over paper at [alpha].
  ///
  /// At rest every value it can return satisfies the census invariant, because
  /// `lerp(paper, ink, t) = (255(1-t), 255(1-t), 255)`. It is the only fill
  /// the blueprint has, and it is used for exactly one meaning: a selected
  /// thing (`docs/SKIN-CONTRACT-MEMBERS.md` §9.1, "selection = filled
  /// outline").
  static Color wash(BuildContext context, double alpha) =>
      BlueprintVocabulary.of(context).wash(alpha);

  /// How much ink a selected surface is washed with.
  static const double selectedWash = 0.18;

  /// The one type style: whatever the root installed, forced to ink.
  ///
  /// Forced rather than trusted, because a control that painted in the
  /// engine's default colour would be a chromatic-census failure attributed to
  /// the skin - and the census exists to attribute failures to the
  /// application. The blueprint never sets a size, a weight or a family: the
  /// root installed one style and everything is drawn in it.
  static TextStyle textStyle(BuildContext context) {
    final TextStyle inherited = DefaultTextStyle.of(context).style;
    return inherited.color == null
        ? inherited.copyWith(color: ink(context))
        : inherited;
  }
}

/// Every closed vocabulary of the contract, rendered as a text marker.
///
/// This is the mechanism behind "never destroys information, only appearance".
/// A meaning that a design language would have carried in a colour, a weight
/// or a glyph is carried here as a short string placed BESIDE the content, so
/// that the fact survives, the appearance does not, and a widget test that
/// looks for the content still finds it.
///
/// The convention is two-tiered, and the tiers are deliberate:
///
///  * `docs/SKIN-CONTRACT-MEMBERS.md` §9.1 fixes a handful of marks by name -
///    `!` for danger, `?` for warning, `+` for a git addition, the series
///    index for `Tone.series(n)`, `[x]`/`[ ]`/`[-]` for the three toggle
///    states, `[####----]` and `(45%)` for progress. Those are honoured
///    literally.
///  * Everything else follows the bracketed-name convention §9.1 sets for
///    [IconRole] (`[gitBranch]`): the enum member's own name in brackets. It is
///    more distinguishable than any invented glyph set and it makes a wrong
///    mapping obvious on sight, which is the whole job.
abstract final class BlueprintMarks {
  /// Nothing at all. Returned where a parameter is at its default and the
  /// blueprint deliberately shows no mark, so the marks that ARE shown mean
  /// something.
  static const String none = '';

  /// The name of an [IconRole], which is the only honest way to draw 151
  /// distinguishable glyphs without inventing a glyph set.
  static String icon(IconRole role) => '[${role.name}]';

  /// What a [Tone] means.
  ///
  /// [Tone.neutral] renders nothing: it is the default, and a mark on the
  /// default would make every label in the application carry one.
  static String tone(Tone tone) {
    if (tone.seriesIndex != null) return '${tone.seriesIndex}';
    return switch (tone.name) {
      'neutral' => none,
      'danger' => '!',
      'warning' => '?',
      'gitAdded' => '+',
      final String name => '[$name]',
    };
  }

  /// What a piece of text is FOR.
  ///
  /// A leading marker per role at one type size, because the blueprint has one
  /// type size and a ramp would be typography.
  static String textRole(TextRole role) => switch (role) {
    TextRole.pageTitle => '#',
    TextRole.sectionTitle => '##',
    TextRole.itemTitle => '###',
    TextRole.body => none,
    TextRole.emphasis => '**',
    TextRole.detail => '-',
    TextRole.micro => '.',
    TextRole.control => '>',
    TextRole.code => '`',
  };

  /// What a change of state means in time.
  ///
  /// Printed once beside whatever moved, because every duration under this
  /// skin is `Duration.zero` - which is precisely what lets the
  /// zero-and-extremes sweep see a motion dependence at all.
  static String motion(MotionRole role) => '[${role.name}]';

  /// The three states of a checkbox: set, clear, and mixed.
  static String check(bool? value) => switch (value) {
    true => '[x]',
    false => '[ ]',
    null => '[-]',
  };

  /// The three states of a switch.
  ///
  /// Parentheses rather than brackets, so that a `toggle` and a `checkbox`
  /// cannot be confused for one another on screen. Two members that render
  /// identically would hide a mis-wired call site, which is the opposite of
  /// what this skin is for.
  static String switching(bool? value) => switch (value) {
    true => '(x)',
    false => '( )',
    null => '(-)',
  };

  /// Whether a thing is currently chosen.
  static String selected(bool value) => value ? '[*]' : '[ ]';

  /// A thing that exists but cannot be used right now.
  static const String disabled = '[disabled]';

  /// A thing that is running.
  static const String busy = '[busy]';

  /// A count riding on something else.
  static String count(int value) => '($value)';

  /// How far along something is, and how much room saying so may take.
  ///
  /// `[####----]` inline and `(45%)` as a block, exactly as §9.1 fixes them; a
  /// null fraction is unknowable and renders as `?` in whichever of the two
  /// shapes the extent asked for, so that the extent stays visible even when
  /// the fraction is not.
  static String progress(double? fraction, ProgressExtent extent) {
    const int cells = 8;
    switch (extent) {
      case ProgressExtent.inline:
        if (fraction == null) return '[${'?' * cells}]';
        final int filled = (fraction.clamp(0, 1) * cells).round();
        return '[${'#' * filled}${'-' * (cells - filled)}]';
      case ProgressExtent.block:
        if (fraction == null) return '(??%)';
        return '(${(fraction.clamp(0, 1) * 100).round()}%)';
    }
  }
}

/// The geometry the naked square varies, and nothing else.
///
/// Every one of these is a parameter §9.1 requires to be *distinguishable*:
/// render it and a parameter the application never varies shows up as a
/// constant, while a parameter a skin drops shows up as a difference from the
/// blueprint. None of them is a design decision being smuggled back in -
/// numbers are legal inside a skin, and these four are the smallest set that
/// keeps four vocabularies visible without inventing a look.
abstract final class BlueprintGeometry {
  /// How loud a control is, as whole pixels of outline.
  static double stroke(BuildContext context, Emphasis emphasis) =>
      BlueprintVocabulary.of(context).stroke(emphasis);

  /// Whether the outline is broken.
  ///
  /// Only [Emphasis.link] is, which is what keeps it apart from
  /// [Emphasis.quiet] - the two share a stroke width, and two values of one
  /// vocabulary that render identically would be a vocabulary the blueprint
  /// cannot falsify.
  static bool dashed(Emphasis emphasis) => emphasis == Emphasis.link;

  /// How much room a control is entitled to, as the smallest box it may be
  /// drawn in.
  ///
  /// The scale changes the BOX and never the padding: the blueprint has no
  /// padding, so a wider square is the only way three coarse steps can be told
  /// apart at zero inset.
  static double extent(BuildContext context, ControlScale scale) =>
      BlueprintVocabulary.of(context).extent(scale);

  /// How far a surface stands off the one behind it, as concentric outlines.
  ///
  /// Zero extra rings at [Elevation.flush] and three at [Elevation.overlay].
  /// A shadow would be a design decision; a count of rectangles is a fact
  /// anybody can read off the screen - which is also why no chaos family
  /// varies it: a count carries information, and the two seeds of a family
  /// must differ in appearance and agree in what they say.
  static int rings(Elevation elevation) => switch (elevation) {
    Elevation.flush => 0,
    Elevation.resting => 1,
    Elevation.raised => 2,
    Elevation.overlay => 3,
  };
}

/// How the two distance vocabularies resolve.
///
/// The blueprint is parameterised - `BlueprintSkin(distance: n)` - and this is
/// the only thing the parameter touches. At `distance: 0` every rung of
/// [Proximity] and [Inset] collapses to zero, which is the Zero Test executed
/// rather than described; at `distance: 64` the five rungs and the four insets
/// are distinct, and the zero-and-extremes sweep diffs the two runs. A test
/// whose result differs between them proves the application depends on a
/// specific distance.
///
/// The rungs are evenly spaced fractions of [pixels] rather than a ramp of the
/// blueprint's own choosing, so that the largest inset a run can produce is
/// exactly the number the run was named after and nothing overflows by
/// surprise.
@immutable
final class BlueprintDistance {
  /// Resolves every rung against [pixels].
  const BlueprintDistance(this.pixels);

  /// Every rung is zero. The blueprint's default, and the left-hand run of the
  /// sweep.
  static const BlueprintDistance zero = BlueprintDistance(0);

  /// The largest distance any rung can resolve to, in logical pixels.
  final double pixels;

  /// How far apart two neighbours sit.
  double gap(Proximity proximity) => switch (proximity) {
    Proximity.hairline => 0,
    Proximity.related => pixels * 0.25,
    Proximity.grouped => pixels * 0.5,
    Proximity.separate => pixels * 0.75,
    Proximity.sectioned => pixels,
  };

  /// How far a container's content sits from its own edge.
  double inset(Inset inset) => switch (inset) {
    Inset.none => 0,
    Inset.tight => pixels / 3,
    Inset.normal => pixels * 2 / 3,
    Inset.roomy => pixels,
  };

  @override
  bool operator ==(Object other) =>
      other is BlueprintDistance && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;

  @override
  String toString() => 'BlueprintDistance($pixels)';
}

/// The one place in this package a `Text` is given a style.
///
/// Every string this skin draws - the application's own words and the skin's
/// own marks alike - goes through here, so that "everything is drawn in the
/// one style the root installed" is a fact about a single line of code rather
/// than a habit forty call sites have to keep.
///
/// The `avoid_text_with_style` rule cannot apply to a skin package: it points
/// application code at the `BaseLabel` layer, which binds a Material
/// text-theme role, and a skin can neither import it - it lives in the
/// application, and the isolation gate makes reaching for it a hard error -
/// nor obey it in spirit, because THIS is the layer that decides what text
/// looks like. The rule is right about `lib/`, so it stays on everywhere else
/// and is switched off for this package alone, with the reasoning in
/// `analysis_options.yaml`. What that rule was standing in for is kept here
/// instead, and kept better: one class, one style, one place.
class BlueprintText extends StatelessWidget {
  /// Draws [value] in ink, at the one type size.
  const BlueprintText(
    this.value, {
    super.key,
    this.maxLines,
    this.align,
    this.softWrap = true,
    this.semanticsLabel,
  });

  /// The string, whether it came from the application or from the skin.
  final String value;

  /// How many lines it may take, or null for as many as it needs. Carried
  /// because `type.text` accepts it: line limits are structure the caller
  /// states, not appearance the skin invents.
  final int? maxLines;

  /// How its lines are aligned, where the caller stated an alignment.
  final TextAlign? align;

  /// Whether it may break across lines.
  final bool softWrap;

  /// What a screen reader hears instead of [value], where the caller stated
  /// one.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: BlueprintInk.textStyle(context),
      maxLines: maxLines,
      textAlign: align,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// One mark, drawn in ink at the one type size.
///
/// Its own type rather than a bare [BlueprintText] so that every mark in the
/// package is one searchable widget - a test can count the marks on a control
/// without matching the content beside them - and so that a mark can never
/// accidentally be given a style of its own.
class BlueprintMark extends StatelessWidget {
  /// Draws [text] as a mark.
  const BlueprintMark(this.text, {super.key});

  /// The mark, from [BlueprintMarks].
  final String text;

  @override
  Widget build(BuildContext context) => BlueprintText(text);
}

/// The naked square: a 1px ink outline around whatever it is given.
///
/// Everything the contract's geometry vocabularies say is expressed here and
/// nowhere else - the stroke width from [Emphasis], the ring count from
/// [Elevation], the dash from [Emphasis.link], the minimum extent from
/// [ControlScale] and the wash from a selection. The outline is painted BEHIND
/// the child and adds no padding of its own, because the blueprint has no
/// padding: the content sits against the edge, which is what "zero" looks like
/// when it is drawn honestly.
class BlueprintBox extends StatelessWidget {
  /// Draws the naked square around [child].
  const BlueprintBox({
    super.key,
    required this.child,
    this.stroke,
    this.rings = 1,
    this.dashed = false,
    this.filled = false,
    this.minExtent = 0,
    this.fillWidth = false,
  });

  /// What is inside the square.
  final Widget child;

  /// How wide the outline is, or null for the hairline in force.
  ///
  /// Nullable rather than defaulted to a constant, because the hairline is a
  /// metric and a metric is what the T5 metric family varies; a constant
  /// default would have pinned every unstyled box at 1px through both seeds
  /// and made the box itself the one thing that never moves.
  final double? stroke;

  /// How many concentric outlines are drawn. Zero draws none at all, which is
  /// what a flush surface asks for.
  final int rings;

  /// Whether the outline is broken.
  final bool dashed;

  /// Whether the square is washed, which is how a selected thing is drawn.
  final bool filled;

  /// The smallest square this may be drawn in.
  final double minExtent;

  /// Whether it takes the whole width it is offered.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final BlueprintVocabulary vocabulary = BlueprintVocabulary.of(context);
    return CustomPaint(
      painter: _NakedOutline(
        stroke: stroke ?? vocabulary.strokeScale,
        rings: rings,
        dashed: dashed,
        filled: filled,
        ink: vocabulary.ink,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minExtent, minHeight: minExtent),
        child: fillWidth
            ? Row(children: <Widget>[Expanded(child: child)])
            : child,
      ),
    );
  }
}

/// Draws the concentric ink rectangles and the selection wash.
class _NakedOutline extends CustomPainter {
  const _NakedOutline({
    required this.stroke,
    required this.rings,
    required this.dashed,
    required this.filled,
    required this.ink,
  });

  final double stroke;
  final int rings;
  final bool dashed;
  final bool filled;

  /// The ink in force, passed in rather than read from a constant so that a
  /// chaos family reaches the one place this skin actually paints.
  final Color ink;

  /// The length of a dash and of the gap after it, in logical pixels.
  static const double _dash = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (filled) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = ink.withValues(alpha: BlueprintInk.selectedWash),
      );
    }
    final Paint pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ink;
    for (int ring = 0; ring < rings; ring++) {
      final double inset = stroke / 2 + ring * stroke * 2;
      final Rect rect = Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      );
      if (rect.width <= 0 || rect.height <= 0) return;
      if (dashed) {
        _paintDashed(canvas, rect, pen);
      } else {
        canvas.drawRect(rect, pen);
      }
    }
  }

  /// Walks each edge in [_dash]-long steps, drawing every other one.
  void _paintDashed(Canvas canvas, Rect rect, Paint pen) {
    void edge(Offset from, Offset to) {
      final double length = (to - from).distance;
      if (length <= 0) return;
      final Offset step = (to - from) / length * _dash;
      for (double at = 0; at < length; at += _dash * 2) {
        final Offset start = from + step * (at / _dash);
        final double remaining = (length - at).clamp(0, _dash);
        canvas.drawLine(start, start + step * (remaining / _dash), pen);
      }
    }

    edge(rect.topLeft, rect.topRight);
    edge(rect.topRight, rect.bottomRight);
    edge(rect.bottomRight, rect.bottomLeft);
    edge(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_NakedOutline old) =>
      old.stroke != stroke ||
      old.rings != rings ||
      old.dashed != dashed ||
      old.filled != filled ||
      old.ink != ink;
}

/// A region the user can operate, with everything that carries BEHAVIOUR and
/// nothing that carries appearance.
///
/// Focus, keyboard activation, hover reporting, tap, secondary tap and
/// semantics - `docs/SKIN-CONTRACT.md` §3.1's "naked, not inert". Both
/// activation intents are bound because the platform default maps Enter and
/// Space to [ActivateIntent] on desktop and to [ButtonActivateIntent] on the
/// web, and a control that answered only one of them would be operable by
/// keyboard on some hosts and not others.
class BlueprintPressable extends StatelessWidget {
  /// Makes [child] operable.
  const BlueprintPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onDoubleTap,
    this.onContextMenu,
    this.onHover,
    this.focusNode,
    this.autofocus = false,
    this.semanticsLabel,
    this.tooltip,
    this.isButton = true,
    this.selected,
    this.checked,
  });

  /// What is inside.
  final Widget child;

  /// What operating it does. Null means it cannot be operated, which also
  /// takes it out of the focus order.
  final VoidCallback? onPressed;

  /// What operating it twice does, where that means something else.
  final VoidCallback? onDoubleTap;

  /// What asking it for a menu does, and where the user asked.
  final ValueChanged<Offset>? onContextMenu;

  /// How to tell the caller the pointer entered or left.
  final ValueChanged<bool>? onHover;

  /// The caller's own handle on this region's focus.
  final FocusNode? focusNode;

  /// Whether it takes the keyboard when it appears.
  final bool autofocus;

  /// What it is, for a screen reader, where the visible content does not say.
  final String? semanticsLabel;

  /// The longer explanation, carried into the semantics tree.
  ///
  /// There is no hovering tooltip: `Tooltip` is a Material widget, and drawing
  /// one would be both a design decision and an import this package may not
  /// make. The message is not lost - it is announced - and `controls.
  /// describedBy` renders the same way for the same reason.
  final String? tooltip;

  /// Whether a screen reader should call it a button.
  final bool isButton;

  /// Whether it is currently chosen, or null when choosing is not what it
  /// does.
  final bool? selected;

  /// Whether the fact it stands for holds, or null when it is not a toggle.
  final bool? checked;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    // Merged rather than excluded: the visible marks and the label inside are
    // the control's accessible name in every case where the caller did not
    // pass one, so throwing the subtree's semantics away would destroy
    // information - which is the one thing this skin may never do.
    return MergeSemantics(
      child: Semantics(
        button: isButton,
        enabled: enabled,
        label: semanticsLabel,
        tooltip: tooltip,
        selected: selected,
        checked: checked,
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: focusNode,
          autofocus: autofocus,
          onShowHoverHighlight: onHover,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent _) {
                onPressed?.call();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent _) {
                onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            onDoubleTap: onDoubleTap,
            onSecondaryTapUp: onContextMenu == null
                ? null
                : (TapUpDetails details) =>
                      onContextMenu!.call(details.globalPosition),
            child: child,
          ),
        ),
      ),
    );
  }
}
