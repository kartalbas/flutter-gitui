# `gitui_skin_blueprint` — the instrument

The blueprint is a whole design language that draws nothing but outlines. A
button is a square, a field is a box, a chip is a rectangle. It is
**development-only**: render the application under it and anything that still
looks styled is design that leaked out of a skin and into application code.

It is not a fallback and not a theme. It is the falsifier the contract in
`packages/gitui_skin_api` is judged against, and it is the template a fourth
skin starts from — copy this package, replace the bodies.

The design is `docs/SKIN-CONTRACT.md` §3; the obligation this package answers,
parameter by parameter, is `docs/SKIN-CONTRACT-MEMBERS.md` §9.

## The whole visual vocabulary

Four decisions, and everything in `lib/src/blueprint_ink.dart` implements one
of them.

1. **Paper `#FFFFFF`, ink `#0000FF`.** Two colours, and at rest always these
   two - the T5 chaos families below are the one exception, and they are a
   measurement rather than a look. The blue channel is
   saturated on purpose: paper and ink share `b = 255`, so the set of legal
   pixels is closed under alpha compositing over paper and under any
   per-channel-uniform coverage blend — which is what greyscale, gamma-corrected
   text antialiasing produces. The chromatic census is therefore exact
   arithmetic, `r == g && b == 0xFF`, and not a tolerance.
2. **A 1px ink outline** on every control and every surface. That is the naked
   square.
3. **Zero.** Every corner square, every elevation flat, every duration
   `Duration.zero`, and — at the default distance — every gap and every inset
   nothing at all.
4. **Ink defaults installed at the root**, so a leaked raw `Text` renders in the
   engine's white and fails the census instead of passing it invisibly.

And one rule the whole package obeys:

> **The blueprint never destroys information, only appearance.**

A meaning a colour would have carried renders as a text **marker beside** the
content and never inside it, so `find.text('Delete')` still matches a screen
that asked for a destructive button. That rule is what lets the entire existing
test suite run under this skin at all.

## Naked, not inert

It uses every primitive that carries **behaviour** — `Focus`, `Actions`,
`Shortcuts`, `Semantics`, `EditableText`, `Scrollable`, `showGeneralDialog` —
and none that carries **appearance**. A blueprint that could not be operated
would measure nothing, because half of what this application promises its user
is what the keyboard does.

## The marks

Every mark is declared once, in `BlueprintMarks`, so two members cannot invent
two ways of saying the same thing. `docs/SKIN-CONTRACT-MEMBERS.md` §9.1 fixes
some of them by name; everything else follows the bracketed-name convention
that section sets for `IconRole`.

| Vocabulary | Rendering |
|---|---|
| `IconRole` (151) | the role's own name in brackets — `[gitBranch]` |
| `Tone` (16 + series) | `!` danger, `?` warning, `+` gitAdded, `n` for `Tone.series(n)`, nothing for neutral, `[name]` for the rest |
| `TextRole` (9) | a leading marker — `#`, `##`, `###`, `**`, `-`, `.`, `>`, `` ` `` — at one type size |
| `Emphasis` (4) | outline weight in whole pixels: 3 / 2 / 1 / 1 dashed for the link |
| `ControlScale` (3) | the smallest box the control may be drawn in: 16 / 32 / 64 |
| `Elevation` (4) | concentric outlines: 0, 1, 2, 3 |
| toggle `value` | `[x]` `[ ]` `[-]` for a checkbox, `(x)` `( )` `(-)` for a switch |
| selection | `[*]` / `[ ]`, plus an ink wash and a second outline |
| `ProgressExtent` + fraction | `[####----]` inline, `(45%)` block, `[????????]` / `(??%)` when the end is unknowable |
| `MotionRole` (4) | the role's name, printed — every duration is `Duration.zero` |
| `Proximity` (5), `Inset` (4) | resolved through `BlueprintDistance`, which answers 0 for every rung unless the instrument was built with a distance |

## The one registered deviation

**No text-selection toolbar** (`docs/SKIN-CONTRACT.md` decision D4,
`docs/SKIN-CONTRACT-MEMBERS.md` §8.4). `AdaptiveTextSelectionToolbar` is
Material/Cupertino, and importing it would break the compile-time proof that
neither this package nor the contract needs Material. Selection itself still
works — `SelectableRegion` and `EditableText` are both in
`package:flutter/widgets.dart` — so nothing the user can *do* is lost; only the
toolbar they would have done it from. Every text control here therefore passes
`contextMenuBuilder: null`.

## Parameterised: the zero-and-extremes sweep

`BlueprintSkin(distance: n)` is the only parameter, and it defaults to
`--dart-define=DISTANCE`, so the sweep needs no harness of its own:

```bash
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=0
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=64
```

Any test that fails under either setting was asserting design. Any test whose
result *differs* between the two proves the application depends on a specific
distance. That is the only check in this programme that falsifies *dependence
on a value* rather than the presence of one.

The skin is installed by `test/skin/pump_under_skin.dart`, beneath the single
`WidgetsApp` root that stays where `main.dart` has it (`SKIN-CONTRACT.md`
§2.7). So a blueprint run today renders every migrated widget through this
package and leaves the rest as Material — which is the measurement the
programme wants, because at P1 the rest is all of it, and the ink defaults are
what make the remainder visible.

## The chaos pair: `chromaChaos` and `metricChaos`

T5 (`SKIN-CONTRACT.md` §3.7) is two families, and the split is what makes it a
measurement rather than a picture. Each freezes exactly what the other varies:

```dart
BlueprintSkin.chromaChaos(seed: 1)   // two colours from the seed, metrics frozen
BlueprintSkin.metricChaos(seed: 1)   // strokes, extents and distance from the
                                     // seed, both colours frozen
```

- **Chroma.** Positions correspond exactly between two seeds, so any pixel that
  is *identical* across the pair is a pixel this skin did not choose — a colour
  the application chose. It catches greys, whites, alpha blends and
  runtime-computed colours, all of which the chromatic census permits, and it
  reaches inside a `CustomPainter` where every lint is blind.
- **Metric.** Any region that fails to *move* between two seeds is geometry the
  application decided. It is the only check that sees a hardcoded
  `SizedBox(height: 13)`: the census cannot (no colour) and the sweep cannot
  (the same 13 under both distances).

Ring counts and the link dash vary under neither, because they carry
`Elevation` and `Emphasis` — the two seeds of a family must look different and
*say* the same thing.

The pixel comparison itself is the Linux-only runner behind
`--tags blueprint-pixels`; what this package owes and ships is the instrument,
and `test/chaos_families_test.dart` pins that each family varies what it claims
and freezes what it claims.

## Layout

```
lib/gitui_skin_blueprint.dart      the barrel
lib/src/blueprint_ink.dart         the vocabulary, the marks, the naked square,
                                   the pressable region — SHARED by every facet
lib/src/blueprint_skin.dart        the Skin implementation and its registration
lib/src/facets/blueprint_*.dart    one file per facet, seven of them
```

**One file per facet, and the shared primitives in one place.** A facet that
needs a mark, a box or a stroke takes it from `blueprint_ink.dart` rather than
spelling one out at the call site: the blueprint's whole value is that two
members which render the same way do so *on purpose* and two members which
render differently differ *for a stated reason*, and a private helper in one
facet file destroys that property quietly.

All fifty-five members are implemented. A facet member that still threw
`UnimplementedError` would be one nobody had written, and the error would say
so - deliberately loud, because a placeholder that rendered something could be
mistaken for an implementation and §9's obligation is that every member is
implemented and every parameter accepted.

## Two lints are off here, each with its own reason

`analysis_options.yaml` switches off `avoid_text_with_style`. The rule tells
the code it finds to use a `BaseLabel` subclass, which binds a Material 3
text-theme role — and a skin package can neither import that layer (it lives in
the application, and the workspace-isolation gate makes reaching for it a hard
error) nor obey it in spirit, because a skin **is** the layer that decides what
text looks like.

It also switches off `avoid_hardcoded_spacing`, one step further along the same
argument: that rule points at `AppTheme.paddingXS…XL`, constants the isolation
gate makes unreachable from here, and its spirit is that application code must
not decide a length. A skin is the layer that decides lengths — that is the
whole of the line this programme draws, and `docs/SKIN-CONTRACT.md` §3.6 scopes
that family of rules to `lib/**` for exactly this reason. What keeps the
discipline here is the vocabulary rather than the analyser: every length the
facets resolve comes from `BlueprintDistance`, `BlueprintGeometry` or
`BlueprintVocabulary`.

Everything else the application is analysed under still applies, including
`depend_on_referenced_packages` at error severity.

The discipline the rule stood in for is kept by the package instead:
`BlueprintText` is the one place a `Text` is given a style, and every mark and
every piece of application content goes through it.

Two things about that are worth knowing before P2 writes the Material skin:

- A package only reads its own `analysis_options.yaml` under `custom_lint` if
  it depends on the plugin, which is why `custom_lint` and `flutter_gitui_lint`
  are dev dependencies here.
- `custom_lint` 0.8.1 **silently discards a package's whole `custom_lint:`
  section when the same file carries a relative `include:`**. The section only
  takes effect with a `package:` include, which is why this file restates the
  root's analyzer settings instead of including it. That cost one debugging
  round here; it will cost the same anywhere else it is met.

## Registration

```dart
BlueprintSkin.register();          // debug builds only, in lib/main.dart, at P2
```

`SkinRegistry.selectable` hides it in a release build, because `isInstrument`
is true — a user who picked it would find the application drawn in outlines.
That is what "plugin" reduces to on a desktop AOT build with no dynamic code
loading: one pubspec dependency and one call, and nothing else in the
application learns this package's name.

## Tests

```bash
cd packages/gitui_skin_blueprint && flutter test
```

`test/spec_field_coverage_test.dart` is §9's obligation made executable: it
reads the contract's own source, extracts every field of **every** spec class,
and fails if the facets recorded as rendering that spec never read one.
`dart:mirrors` does not exist on this platform, so the reflection is over
source rather than over types — which is stronger in the way that matters,
because a field appears in the source the moment it is written.

Two properties of it are load-bearing, and both were learned the hard way:

- It is **complete**. A spec class in the contract and in neither table fails
  the run, and a name in a table that has left the contract fails it too. While
  the test covered one facet of seven, `AppIdentity.appIcon` was accepted by
  `chrome.shell` and silently dropped, and nothing reddened.
- It reads **code, not prose**. Comments and the literal text of strings are
  stripped before anything is matched. `appIcon` appeared exactly once in this
  package, inside a doc comment explaining why it was not drawn; and once it
  was drawn, its own allowlist string `'chrome.shell/appIcon'` re-satisfied the
  matcher on its own until string text was stripped too.

A field a facet legitimately never reads is listed with its reason: today
`FieldSpec.validator`, which `SkinFormFieldHost` consumes before any skin is
called, and `DialogSpec.onSubmit`, which the application's own
`DialogKeyboardHost` owns.

`test/marks_are_distinguishable_test.dart` holds the other half of §9, which no
source scan can see: that two values of one vocabulary never render the *same*.
`test/no_overflow_on_application_words_test.dart` holds a property the
instrument needs before it can be trusted at all — that it does not overflow on
the application's own words, in any of six languages, because an overflow
paints stripes the chromatic census would report against the application.
