# The skin contract

The design and implementation plan for **#249** — extracting every piece of
theming and design out of the application and into replaceable skin packages,
with **Material 3**, **Fluent 2** and **macOS** as the three shipping skins and
a **blueprint** skin as the instrument that proves the extraction actually
happened.

The requirement this document is written against is the owner's, in his words:

> The design and theming must be REPLACEABLE with a simple blueprint. Not a
> single piece of theming and not a single piece of design may live in the
> code. It has to work like a plugin — only that way does our code become
> clean.

That sentence is an *assertion* until something can falsify it. This document's
central claim is that the blueprint skin, plus five checks built on top of it,
turns it into a **falsifiable** property that a CI job either passes or names a
file and a line for.

Every number below was measured on this repository at `master`, Flutter 3.44.4
(revision `ad70ec4617`) / Dart 3.12.2, on Windows 11. Every SDK and package
claim cites a file and a line in `flutter/packages/flutter/lib`,
`fluent_ui-4.16.1` or `macos_ui-2.2.2`, all three of which are resolvable from
this machine's pub cache. Where a claim comes from the completed viability
spike it cites `spike/skin_lab/FINDINGS.md`. Where a claim is *not* measured, it
says so.

---

## 0. Which design this is, and what it borrowed

Three designs were put to a review panel. The scores were 21, 20 and 19 out of
30. This document takes the highest-scoring one as its spine and grafts in the
ideas the panel named in the other two, because each of the three was strongest
in a different place: one at making leaks impossible to express, one at
measuring the real behaviour of `fluent_ui` and `macos_ui`, and one at making
the migration executable rather than merely planned.

### The spine: no contract member returns a value

The winning design's rule is one sentence:

> **No member of the skin contract returns a `Color`, a `double`, an
> `EdgeInsets`, a `TextStyle`, a `ShapeBorder`, a `Duration`, a `BoxDecoration`
> or an `IconData`. Every member returns a `Widget` or a `Route`.**

It wins for one reason, and the reason is worth stating precisely because it is
what the other two designs lost on. A token bag — `context.tokens.spacing.m`,
`SkinMetrics.space.m`, `SkinMetric.gap(Flow.related)` — moves *where the number
comes from* without moving *who decided a gap exists, where it goes, and which
rung it takes*. The panel demonstrated this concretely against the token-bag
design: its blueprint asserted that every spacing value lies on a seven-grid
`{0,7,14,21,28,35}`, and `context.space.m * 1.5` is 21 under the blueprint and
24 under Material — a hardcoded doubling of a token, i.e. layout decided in the
application, that satisfies every one of that design's four invariants. The
contract sanctioned the leak and the detector was blind to it by construction.

When there is no value to name, there is no such expression to write. Every
check in §3 draws its sharpness from that single property.

### The grafts, and where each came from

| Graft | From | Why |
|---|---|---|
| `SkinPainted` / `ContentPort` prune-and-resume element walk (**T3**) | Scene Contract | The only *automatic attribution* mechanism proposed anywhere: it names the file and line that painted a leak, needs no image capture, and therefore runs on Windows where this repo's 68 goldens are skipped entirely (`test/conformance/goldens/flutter_test_config.dart`). Repaired per the panel: the widget list is an **allow-list**, not a deny-list, and `ContentPort`'s child is **private**. |
| `no_widget_in_contract` lint | Scene Contract | Makes "every seam is data" a mechanism instead of a convention, and keeps it true as the contract grows. |
| Mandatory overlay re-theming | Scene Contract | Answers a measured, shippable, silent bug — see §4.2. Re-engineered from `@nonVirtual PageRoute` to an opaque host object, because the original would have made `showMacosAlertDialog` unusable (§0.1, conflict C2). |
| `ToolbarPickerEntry` for the four switchers | Scene Contract | Fixes the spine design's one named defect (`switchers: List<Widget>`). Verified: `MacosPulldownButton` asserts *title XOR icon* (`pulldown_button.dart:628-631`) and `CommandBarBuilderItem` can only wrap another `CommandBarItem` (`commandbar.dart:548-556`), so a pre-built Widget can never become either canonical control. |
| `NavigationDensity` instead of `railExtended: bool` | Scene Contract | A bool encodes Material's model. Merged with the spine's nullable-capability semantics — see conflict C6. |
| `docs/skin_arity.yaml` | Scene Contract | An executable record of the canonical widget and its arity per member per language, in the same both-directions style as `docs/deviation_register.yaml`. |
| Every macOS measurement | Scene Contract | The spike measured *Cupertino*; the owner has since chosen `macos_ui`. All of it re-verified against the package source in §4. |
| `token_read_is_mechanical` AST classifier | Vocabulary Substitution | The best executability idea in the set: it converts the single largest unknown in the programme (is the grind a script or a year?) into a live number. |
| The poison theme | Vocabulary Substitution | The only enforcement mechanism proposed that runs in **production** under the shipping skins, covering screens no test renders. Repaired for the `MacosAlertDialog` hole — see conflict C10. |
| `Skin.windowChrome` | Vocabulary Substitution | Window chrome is a skin decision that today lives as a one-time `window_manager` call in `main.dart`. No other design noticed. |
| The chaos pair, as **two families** (**T5**) | Vocabulary Substitution, repaired by the panel | Vary ink at frozen metrics to catch paint leaks including greys and white; vary metrics at frozen ink to catch geometry leaks. Needs no palette invariant, no grid and no widget list, and reaches inside `CustomPainter` where every lint is blind. |
| `avoid_color_expression` on the *resolved static type* | Vocabulary Substitution | Verified necessary: today's `avoid_hardcoded_colors` matches the identifier `Colors` syntactically (`avoid_hardcoded_colors.dart:21-31`) and therefore misses all 917 `colorScheme.*` reads and all 96 `withValues(alpha:)` sites. |
| `Flex.spacing` absorbing gap widgets | Vocabulary Substitution | `Flex.spacing` exists at `basic.dart:5431` in 3.44.4. 676 `SizedBox` gaps collapse into 511 existing `Column`/`Row` parents — the migration deletes more code than it adds, which is the difference between a refactor a team finishes and one it abandons. |
| The blueprint installs ink `DefaultTextStyle` / `IconTheme` | Panel | Closes a hole the winning design did not admit: with no `DefaultTextStyle` installed, a leaked raw `Text` renders in the engine's default white and satisfies a paper-and-ink pixel invariant. Installing ink defaults turns the SDK's own fallbacks into leak detectors. |
| Ink with a saturated blue channel | Panel | Makes the chromatic invariant exact rather than tolerance-based — see §3.3. |

### 0.1 Conflicts, decided, with the losing reasoning recorded

These are recorded so the questions are not reopened.

**C1 — Does the contract expose values at all?**
Decided: **no**, with exactly three declared exceptions on `SkinRootClaims`
(§2.9) that a lint confines to `lib/main.dart`. The token-bag alternative lost
because the panel showed a leak its own detector sanctions
(`context.space.m * 1.5`), and the fenced-resolver alternative lost because its
fence is `docs/design_escape_hatches.yaml` plus a shrink-only policy — process,
not proof, and its own author's risk register concedes a developer under
deadline adds a line marked "temporary" that no tool can distinguish from a
legitimate one.

**C2 — Who owns the overlay route?**
Decided: **the application owns the entry point, the API package owns the
wrapper, the skin owns the route.** The alternative — a
`@nonVirtual SkinRoute.buildPage` on an `abstract base class SkinRoute<T> extends PageRoute<T>` —
lost on a measurement: `showMacosAlertDialog` pushes
`_MacosAlertDialogRoute extends PopupRoute` (`macos_alert_dialog.dart:253`),
the class is **private**, and the helper derives its barrier from
`MacosColors.controlBackgroundColor` at 0.6 alpha (`:226-235`). A contract that
forces a `PageRoute` subclass makes `showMacosAlertDialog` unreachable and
obliges the macOS skin to re-derive the barrier by hand — route-level
hand-painting, imposed by the contract at exactly the point it is meant to
prevent it. §2.8 achieves the same guarantee with an opaque host object.

**C3 — Does `IconData` cross the line?**
Decided: **no.** `IconRole` is a 151-member enum, one per glyph the application
uses today (measured:
`grep -rhoE 'PhosphorIcons[A-Za-z]*\.[a-zA-Z0-9_]+' lib | sed 's/.*\.//' | sort -u`
→ 151 distinct names across 917 references). The design that kept `IconData`
lost because `IconData` is *type*-neutral but not *identity*-neutral: keeping it
means the Fluent skin can never use `FluentIcons` and the macOS skin can never
use SF Symbols, so every skin renders Phosphor glyphs forever. That is the
hand-painted-lookalike failure displaced from geometry onto iconography, and the
spike's own note (§6, Probe B) says exactly this: "Phosphor glyphs are neither
Fluent's `WindowsIcons` nor Apple's SF Symbols".

**C4 — Which leak detector?**
Decided: **all of T1, T2, T3, T4 and T5**, because they fail differently and
each is cheap once the harness exists. The chromatic census alone has a
white-on-white hole and an alpha hole; the element walk alone cannot see inside
a `paint()` call; the chaos pair alone cannot name a file; the lint alone is
blind inside packages; T2 alone catches only *dependence*, not presence. §3
states each one's blind spot up front and which sibling covers it.

**C5 — The shell's switchers.**
Decided: **data** (`ToolbarPickerEntry`), not `List<Widget>`. Verified above.

**C6 — Rail state: `bool?` or an enum?**
Decided: **both properties, one member.** `NavigationDensity { full, condensed, hidden }`
is the vocabulary, and it is **nullable**: a skin whose canonical navigation
owns its own display-mode control (Fluent's `NavigationPane`, macOS's
`MacosWindowScope.toggleSidebar()` at `window.dart:697`) leaves it null and
binds `onDensityChanged` to its own affordance. Two affordances for one job is
a defect by this repository's own rules (`CLAUDE.md`), so the skin decides
whether a toggle is drawn at all.

**C7 — macOS dialogs with three or more actions.**
Decided: **route by arity to `MacosSheet`.** Verified: `MacosAlertDialog` takes
`required this.primaryButton` (`macos_alert_dialog.dart:40`) and
`this.secondaryButton` (`:41`) and nothing else — two actions, maximum — and
`showMacosSheet` exists at `macos_sheet.dart:102`. The alternative, folding a
third action into the message area as an inline link, is a hand-painted
lookalike; its own author said so.

**C8 — `BaseDialog.maxWidth`.**
Decided: **deleted, and replaced by `DialogExtent`, which describes the
content, not the width.** A width bucket would still be unreachable: macOS pins
`_kDefaultDialogConstraints = BoxConstraints(minWidth: 260, maxWidth: 260)`
(`macos_alert_dialog.dart:6`) and Cupertino pins 270
(`FINDINGS.md` §4.4). `DialogExtent { alert, form, browser }` says what kind of
thing the dialog contains, which is information the skin genuinely needs — it
is what decides `MacosAlertDialog` versus `MacosSheet` — and it is the same
information 15 call sites are approximating today with a number.

**C9 — What happens to the conformance suite and the register?**
Decided: **relocated into the Material skin package, verbatim, in P0.** They
were always one skin's conformance suite: the register measures divergence from
*Material 3* and the 68 goldens render *Material's* pixels. Today they are
merely misfiled. From P0 on, `deviation_register.yaml` is per-skin.

**C10 — Does the poison theme ship?**
Decided: **yes under the blueprint and under Fluent; under macOS it poisons
only the slots application code can read.** The hole is real and measured:
`MacosAlertDialog.build` returns a Material `Dialog`
(`macos_alert_dialog.dart:135`), so a fully poisoned root `ThemeData` would
corrupt a *correctly delegating* macOS skin. But it sets its own
`backgroundColor` and `shape` (`:136-140`) and its own `DefaultTextStyle`
(`:163,168`), so poisoning `ColorScheme`, `TextTheme`, `dividerColor` and
`iconTheme` — and leaving `DialogTheme` and `visualDensity` at their defaults —
screams on every leaked `Theme.of(context).colorScheme.*` read and every
unstyled `Text` while leaving macOS's Material plumbing intact. Recorded as a
deviation with that reason.

---

## 1. Where the line runs: structure versus appearance

This is the rule someone applies to a new widget without asking anyone. It has
two halves, and a widget must pass **both** to stay in application code.

### The Zero Test — is it appearance?

> Set the thing to zero, or to nothing. If the screen still **lays out**,
> still exposes the same **semantics**, and is still **operable from the
> keyboard**, it is appearance and it belongs to the skin.

A gap at zero still lays out. A corner radius at zero still lays out. A colour
removed still lays out — the widget is in the same place, the same size, the
same reading order. An animation at `Duration.zero` still lays out. All of
these are appearance.

An `Expanded` removed does not lay out — the child collapses or overflows. A
`Stack` removed does not lay out — the children stop overlapping. A
`LayoutBuilder` removed does not lay out. Those are structure.

The Zero Test is not merely a thought experiment here. It is executed: **T2**
(§3.4) runs the entire existing test suite under `BlueprintSkin(distance: 0)`
and again under `BlueprintSkin(distance: 64)`. Any test that fails under either
was asserting design; any test whose result *differs* between the two proves the
application depends on a specific distance.

### The Substitution Test — is it *this* application's meaning?

> Could three different design languages each answer this question their own
> way and all three be right? If yes, the application may only state the
> **question**; the skin states the **answer**.

"There is a gap here" is a question three languages answer differently.
"These two things are related" is a question. "This action is destructive" is a
question. "This text names an object" is a question.

"This row is 56 pixels tall" is an answer. "This corner is 12dp" is an answer.
"This is `colorScheme.secondaryContainer`" is an answer — Material's answer, in
Material's vocabulary, chosen once for every language. So is
"`BodyMediumLabel`": `bodyMedium` is a Material type role, and a screen naming
it has picked Material's ramp for Fluent and AppKit too.

### The residue, named honestly

The two tests together leave a residue the contract cannot fully close, and it
is the same residue in every design the panel saw. `Expanded`, `Flexible`,
`Stack`, `Positioned`, `ConstrainedBox` and `LayoutBuilder` stay in application
code because flex and constraint topology is structure and the blueprint must
honour it exactly. But `Positioned(top: 12)` and
`BoxConstraints(maxWidth: 650)` are numbers that T1 cannot see (no colour), T2
cannot see (constant under both distances) and T3 does not ban.

Measured, the exposure is 26 sites: 3 `Positioned(`, 13 `ConstrainedBox(`,
10 `Stack(`. The mitigation is a hard, lint-enforced cap
(`structure_literal_budget`, §3.6) that starts at the measured count and may
only shrink, and a rule that any *measured* layout — one that does arithmetic on
a length — moves into the skin, where numbers are legal. `OverflowActionBar`
(`lib/shared/widgets/overflow_action_bar.dart:47-90`, whose
`visibleActionCount()` computes `((availableWidth - menuExtent) / (itemExtent + spacing)).floor()`
against `itemExtent = 48` and `menuExtent = 48`) is the worked example and moves
in P5.

This is a cap, not a proof. Nobody can prove the cap holds for UI that does not
exist yet.

---

## 2. The contract

Three packages define it:

```
packages/
  gitui_skin_api/        depends on: flutter (widgets only). No design library.
  gitui_skin_blueprint/  depends on: gitui_skin_api, flutter (widgets only).
  gitui_skin_material/   + flutter/material.dart, flex_color_scheme, google_fonts, phosphor_flutter
  gitui_skin_fluent/     + fluent_ui, system_theme, flutter_acrylic
  gitui_skin_macos/      + macos_ui
```

`gitui_skin_api` imports `package:flutter/widgets.dart` and nothing else from
Flutter. `gitui_skin_blueprint` does the same. **That is the standing proof
that no member of this contract secretly requires Material** — if somebody adds
a `ThemeExtension`, a `WidgetState`, an `InputBorder`, a `PopupMenuEntry` or a
`MacosThemeData` to the contract, the blueprint stops compiling, and the
analyze step that already blocks CI reddens. The blueprint's *build* is an
assertion.

That this is reachable at all was checked against the SDK rather than assumed:
`showGeneralDialog` is exported from `package:flutter/widgets.dart`
(`src/widgets/routes.dart:2759`) and `RawMenuAnchor` likewise
(`widgets.dart:112`), so the blueprint can push a real modal route and a real
menu with no Material anywhere.

The ban is enforceable exactly where it matters. `FINDINGS.md` §1.1 is right
that it cannot hold inside `gitui_skin_fluent`: `fluent_ui` re-exports 31
Material symbols including `Brightness`, `ThemeMode`, `VisualDensity`,
`ThemeExtension` and `MaterialLocalizations` (`fluent_ui.dart:1-32`, read and
confirmed). It holds in `gitui_skin_api`, in `gitui_skin_blueprint`, and in the
300 files of `lib/`.

### 2.1 The root

```dart
/// A design language, whole. Everything visible in the application is produced
/// by exactly one of these.
abstract interface class Skin {
  /// 'material' | 'fluent' | 'macos' | 'blueprint'
  String get id;

  /// Localisation key for the name shown in the settings picker.
  String get nameKey;

  /// True only for the blueprint. An instrument registers itself only under
  /// [kDebugMode], and a release-mode test asserts
  /// `SkinRegistry.all.every((s) => !s.isInstrument)`.
  bool get isInstrument;

  /// The skin's legitimate claims on the single application root. See §2.9.
  /// A lint (`root_claims_are_root_only`) confines every read of this to
  /// `lib/main.dart`.
  SkinRootClaims get rootClaims;

  SkinChrome   get chrome;     // the frame: root, shell, screens
  SkinControls get controls;   // things you operate
  SkinSurfaces get surfaces;   // things that hold other things
  SkinType     get type;       // things you read
  SkinLayout   get layout;     // how things sit next to each other
  SkinMotion   get motion;     // how things change
  SkinOverlays get overlays;   // things that appear on top
}

/// The registry that drives the settings picker. A package that registers
/// itself simply appears there.
abstract final class SkinRegistry {
  static void register(Skin skin);
  static Skin byId(String id);              // throws, listing the available ids
  static List<Skin> get all;
  static List<Skin> get selectable;         // all, minus instruments in release
}

/// The only way application code ever reaches a skin.
extension SkinContext on BuildContext {
  Skin get skin => SkinScope.of(this).skin;
}
```

Dart AOT has no dynamic code loading, so "plugin" means what it physically can
mean on Flutter desktop: adding a pubspec dependency and one `register()` line
in `main.dart`. The contract guarantees that *nothing else in the application*
changes per skin, which is the property that actually matters.

### 2.2 The vocabularies — closed types that carry no value

```dart
/// How closely two neighbours belong together. The application declares the
/// RELATIONSHIP; the skin decides the DISTANCE. There is deliberately no
/// "how many pixels" here — that is the entire point of this type.
///
/// Five rungs because `AppTheme.paddingXS/S/M/L/XL` (app_theme.dart:601-605)
/// are the five steps the application actually uses, at 1,340 reads.
enum Proximity { hairline, related, grouped, separate, sectioned }

/// How far a container's content sits from its own edge.
enum Inset { none, tight, normal, roomy }

/// What a piece of text is FOR, in this application's words. Nine roles, not
/// Material's fifteen — see decision D3 in §7.
enum TextRole {
  pageTitle,     // the name of a screen or a dialog
  sectionTitle,  // the name of a region inside a screen
  itemTitle,     // the name of one object: a repository, a branch, a tag
  body,          // ordinary prose and values
  emphasis,      // prose that must stand out from its neighbours
  detail,        // supporting detail: a path, an author, a date
  micro,         // badge counts, chip labels, status pills
  control,       // button labels, field labels, menu entries
  code,          // diffs, hashes, paths — monospaced by definition
}

enum Emphasis     { primary, secondary, quiet, link }
enum ControlScale { compact, normal, prominent }
enum Elevation    { flush, resting, raised, overlay }
enum MotionRole   { instant, feedback, transition, emphasis }
enum ProgressExtent { inline, block }

/// What a thing MEANS. Never how it looks.
///
/// A final class rather than an enum, only so that [Tone.series] can exist:
/// commit-graph lanes, branch colours and workspace colours are a generated
/// set whose PALETTE and LENGTH both belong to the skin, and the application
/// indexes into it without knowing either. This deletes the 12-colour palette
/// currently duplicated in project.dart, workspace.dart and
/// quick_settings_menu.dart (#249 §1.3).
final class Tone {
  const Tone._(this.name) : seriesIndex = null;
  const Tone.series(int index) : name = 'series', seriesIndex = index;

  final String name;
  final int? seriesIndex;

  static const Tone neutral  = Tone._('neutral');
  static const Tone muted    = Tone._('muted');
  static const Tone accent   = Tone._('accent');
  static const Tone onAccent = Tone._('onAccent');
  static const Tone danger   = Tone._('danger');
  static const Tone warning  = Tone._('warning');
  static const Tone success  = Tone._('success');
  static const Tone info     = Tone._('info');

  // Git working-tree semantics. No design language has a slot for these, so
  // each skin answers from its own palette. Replaces the fixed hex values at
  // app_theme.dart:467-478, which are identical in light and dark and fail
  // WCAG AA in light mode (#341, "the git status colours fail WCAG AA").
  static const Tone gitAdded      = Tone._('gitAdded');
  static const Tone gitModified   = Tone._('gitModified');
  static const Tone gitDeleted    = Tone._('gitDeleted');
  static const Tone gitRenamed    = Tone._('gitRenamed');
  static const Tone gitUntracked  = Tone._('gitUntracked');
  static const Tone gitConflicted = Tone._('gitConflicted');
  static const Tone gitIgnored    = Tone._('gitIgnored');
  static const Tone gitStaged     = Tone._('gitStaged');
}

/// A glyph named by MEANING. 151 members, one per glyph the application uses
/// today. `IconData` never crosses this line — see conflict C3. The GLYPH
/// WEIGHT (Phosphor Regular/Bold/Fill, SF Symbol weight) is a skin decision
/// too, which is why the role carries none and selected-state weight switching
/// moves inside the skin.
enum IconRole {
  gitBranch, gitMerge, gitPullRequest, gitCommit, gitTag, gitStash,
  add, remove, edit, delete, copy, refresh, search, settings, close,
  chevronDown, chevronRight, warning, error, info, success, overflow,
  /* … 129 more, generated from the measured census … */
}
```

### 2.3 `SkinLayout` — the facet that replaces the token bag

```dart
abstract interface class SkinLayout {
  /// Replaces `Column` + interleaved gap widgets. `Flex.spacing`
  /// (basic.dart:5431) makes this a thin resolver rather than new layout.
  Widget column(BuildContext c, List<Widget> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.stretch,
    MainAxisSize size = MainAxisSize.min,
  });

  Widget row(BuildContext c, List<Widget> children, {
    Proximity gap = Proximity.related,
    MainAxisAlignment main = MainAxisAlignment.start,
    CrossAxisAlignment cross = CrossAxisAlignment.center,
    MainAxisSize size = MainAxisSize.max,
    bool wrap = false,
  });

  /// Replaces `Padding` and `Container(padding:)`.
  Widget inset(BuildContext c, Widget child, {
    Inset all = Inset.normal, Inset? x, Inset? y,
  });

  /// Replaces `Divider` / `VerticalDivider` (47 sites).
  Widget separator(BuildContext c, {
    Axis axis = Axis.horizontal, Inset indent = Inset.none,
  });

  /// A gap between two neighbours that a single `gap:` cannot express because
  /// the run is not uniform. Reads the enclosing Flex's direction from the
  /// render tree, so one type serves both axes. The mechanical target for the
  /// 676 measured `SizedBox(width|height: AppTheme.padding*)` sites that the
  /// `column`/`row` hoist cannot absorb.
  Widget gap(BuildContext c, Proximity proximity);
}
```

`Expanded`, `Flexible`, `Stack`, `Positioned`, `ConstrainedBox` and
`LayoutBuilder` stay in application code untouched. They are structure, and the
blueprint must honour them exactly.

### 2.4 `SkinControls`

```dart
abstract interface class SkinControls {
  Widget button      (BuildContext c, ButtonSpec s);
  Widget iconButton  (BuildContext c, IconButtonSpec s);
  Widget textField   (BuildContext c, FieldSpec s, FieldHandles h);   // R8
  Widget checkbox    (BuildContext c, ToggleSpec s);
  Widget toggle      (BuildContext c, ToggleSpec s);
  Widget dropdown<T> (BuildContext c, DropdownSpec<T> s);
  Widget choiceGroup<T>(BuildContext c, ChoiceGroupSpec<T> s);        // R3
  Widget filterToggle(BuildContext c, FilterToggleSpec s);
  Widget progress    (BuildContext c, {double? fraction, required ProgressExtent extent});
  Widget describedBy (BuildContext c, {required String message, required ContentPort child});
  /// Owns its own overflow. See §4.1: two of three languages already do.
  Widget actionBar   (BuildContext c, List<ToolbarGroup> groups);
}

final class ButtonSpec {
  const ButtonSpec({
    required this.label, required this.onPressed,
    this.emphasis = Emphasis.primary, this.tone = Tone.accent,
    this.scale = ControlScale.normal,
    this.leading, this.trailing,
    this.isLoading = false, this.fillWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Emphasis emphasis;
  final Tone tone;
  final ControlScale scale;
  final IconRole? leading, trailing;
  final bool isLoading, fillWidth;
}
```

Note the split of today's seven-value `ButtonVariant` into `Emphasis × Tone`.
`dangerSecondary` was a Material compound; `Emphasis.secondary + Tone.danger` is
a meaning three languages can each answer their own way. The spike classified
`variant` as ADAPTED in both non-Material languages precisely because the
compound had to be decomposed at the skin boundary (`FINDINGS.md` §4.1).

`ControlScale` is deliberately three coarse values and not a pixel size: the
spike measured `size` as the **only LOSSY** parameter on `BaseButton` under
Fluent, because Fluent 2 has exactly one control height
(`FINDINGS.md` §4.1). `compact | normal | prominent` is the most all three
languages can honour.

### 2.5 `SkinSurfaces`

```dart
abstract interface class SkinSurfaces {
  Widget card      (BuildContext c, CardSpec s);
  Widget panel     (BuildContext c, PanelSpec s);
  Widget listRow   (BuildContext c, ListRowSpec s);
  Widget treeRow   (BuildContext c, TreeRowSpec s);
  Widget badge     (BuildContext c, BadgeSpec s);
  Widget banner    (BuildContext c, BannerSpec s);
  Widget emptyState(BuildContext c, EmptyStateSpec s);

  /// One line of a diff or of a code view, with its own fill and its
  /// intra-line runs. A member rather than a `Tone` on a generic surface,
  /// because the skin must be free to decide whether a 10,000-line diff is
  /// painted with widgets or with a painter — that is a performance decision
  /// about numbers, and numbers live on the skin's side of the line.
  Widget codeLine  (BuildContext c, CodeLineSpec s);

  /// The application's only `CustomPainter` today (measured: exactly 1
  /// `extends CustomPainter` in lib/, at
  /// lib/features/history/widgets/commit_graph_painter.dart). The spec is
  /// lanes, nodes and edges as data; each skin owns the painter, and
  /// `_laneWidth = 12`, `_dotRadius = 4`, `_strokeWidth = 2` move with it.
  Widget commitGraphRow(BuildContext c, GraphRowSpec s);

  /// Markdown. 2 call sites today (markdown_viewer_dialog.dart:91,
  /// changelog_dialog.dart:221), each hand-building a `MarkdownStyleSheet` of
  /// real `TextStyle`s. The skin owns the style sheet, so the application
  /// never constructs one — which is why this needs no escape hatch.
  Widget markdown  (BuildContext c, MarkdownSpec s);

  /// The zoomable image viewer (photo_view, 1 call site). Same reasoning.
  Widget imageViewer(BuildContext c, ImageViewerSpec s);
}

final class ListRowSpec {
  const ListRowSpec({
    required this.content,
    this.leading, this.trailing,
    this.badgeCount,
    this.menu = const <MenuEntry>[],
    this.selection = RowSelection.none,
    this.onTap, this.onActivate, this.onContextMenu,
  });
  final ContentPort content;
  final ContentPort? leading, trailing;
  final int? badgeCount;
  /// Data, not a pre-built button. The skin builds its OWN anchor, because
  /// `MacosPulldownButton` asserts title XOR icon (pulldown_button.dart:628)
  /// and a pre-built control can never become one.
  final List<MenuEntry> menu;
  final RowSelection selection;   // none | primary | multi
  final VoidCallback? onTap, onActivate;
  final ValueChanged<Offset>? onContextMenu;
}
```

`RowSelection.primary` versus `.multi` is what today's
`colorScheme.secondaryContainer` at `base_list_item.dart:204` and
`tertiaryContainer` at `:207` actually mean. Only a human knows that, which is
why P3d is the judgement-heavy phase (§5).

### 2.6 `SkinType`

```dart
abstract interface class SkinType {
  Widget text(BuildContext c, String value, {
    required TextRole role,
    Tone tone = Tone.neutral,
    int? maxLines, TextAlign? align, bool softWrap = true,
    String? semanticsLabel,
  });

  Widget icon(BuildContext c, IconRole role, {
    Tone tone = Tone.neutral,
    ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  });

  /// Rich runs — diff lines, search-hit highlighting, inline code in a label —
  /// where the application knows which SPANS mean what but not what they look
  /// like. Replaces the `RichText`/`TextSpan` construction in
  /// base_diff_viewer.dart.
  Widget runs(BuildContext c, List<TextRun> runs, {required TextRole role});
}

final class TextRun {
  const TextRun(this.text, {this.tone = Tone.neutral, this.emphasised = false});
  final String text;
  final Tone tone;
  final bool emphasised;
}
```

### 2.7 `SkinChrome` and the shell

```dart
abstract interface class SkinChrome {
  /// Installs this language's own inherited theme — `Theme` / `FluentTheme` /
  /// `MacosTheme` — plus its `IconTheme` and `DefaultTextStyle`. The single
  /// `WidgetsApp` root stays exactly where it is in `main.dart`; this wraps
  /// beneath it. The blueprint installs an INK `DefaultTextStyle` and
  /// `IconTheme` rather than returning `child` unchanged, so that an unstyled
  /// SDK default renders ILLEGALLY instead of invisibly (§3.3).
  Widget wrapRoot(BuildContext c, {required Widget child, required SkinRequest request});

  /// R5 — the one spike change still open. See §4.1.
  Widget shell(BuildContext c, ShellSpec s);

  /// Replaces `StandardAppBar` and the 18 raw `Scaffold(` sites.
  Widget screen(BuildContext c, ScreenSpec s);
}

/// Everything a skin needs to resolve a look, gathered from the user's config.
/// Carried as data so the skin — not the application — consumes it. This is
/// what deletes `AnimationSpeedExtension` and `context.quickAnimation` as
/// application-readable values.
final class SkinRequest {
  const SkinRequest({
    required this.brightness, required this.accentSeed,
    required this.textScale, required this.animationScale,
    required this.monoFamily, required this.uiFamily,
  });
  final Brightness brightness;
  final int accentSeed;
  final double textScale, animationScale;
  final String monoFamily, uiFamily;
}

final class ShellSpec {
  const ShellSpec({
    required this.identity,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.toolbar,
    required this.paneOrder,
    this.density,
    this.onDensityChanged,
    this.aside,
    this.banner,
    this.status,
    this.layers = const <ContentPort>[],
  });

  /// Name, `IconRole` and a raster app icon. Carried because macOS REQUIRES
  /// one: `MacosAlertDialog.appIcon` is a required Widget
  /// (macos_alert_dialog.dart:37).
  final AppIdentity identity;

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Structured, grouped and prioritised. THE SKIN decides what fits and what
  /// overflows — see §4.1.
  final List<ToolbarGroup> toolbar;

  /// The F6 / Shift+F6 pane cycle and the Tab order rail → toolbar → content →
  /// log. This is WHAT THE USER CAN DO, so it is structure, and the skin may
  /// not reorder it. `BaseFocusRegion(order: 1..4)` stays in application code
  /// and wraps AROUND whatever `chrome.shell` returns.
  final List<ShellPane> paneOrder;

  /// NULL means "this skin owns its own display mode". A skin whose canonical
  /// navigation ships a toggle — Fluent's `NavigationPane`, macOS's window via
  /// `MacosWindowScope.toggleSidebar()` (window.dart:697) — leaves this alone
  /// and BINDS [onDensityChanged] to its own control. The application never
  /// draws a second one.
  final NavigationDensity? density;
  final ValueChanged<NavigationDensity>? onDensityChanged;

  final ShellAside? aside;      // the command-log panel
  final BannerSpec? banner;     // the missing-settings warning
  final ShellStatus? status;
  final List<ContentPort> layers;   // the progress overlay
}

/// full → Material extended rail / `PaneDisplayMode.expanded` / sidebar shown
/// condensed → collapsed rail / `.compact` / sidebar at its `minWidth`
/// hidden → rail removed / `.minimal` / sidebar hidden
enum NavigationDensity { full, condensed, hidden }

final class ShellDestination {
  const ShellDestination({
    required this.label, required this.icon, required this.selectedIcon,
    required this.body, this.badgeCount,
  });
  final String label;
  final IconRole icon, selectedIcon;
  final int? badgeCount;
  /// The body belongs to the DESTINATION, not to the shell, and it is a
  /// BUILDER: `PaneItem.body` (pane_items.dart:89) is where Fluent wants it and
  /// `MacosScaffold` builds through `ContentArea(builder:)`. Material and macOS
  /// read `destinations[selected].body()` trivially.
  ///
  /// Honest note: Fluent does NOT force this — `NavigationView.paneBodyBuilder`
  /// exists in 4.16.1 (view.dart:121,142). It is still the right shape, because
  /// it is the only one all three drive without a wrapper.
  final ContentPort Function() body;
}

sealed class ToolbarEntry { const ToolbarEntry(); }

final class ToolbarActionEntry extends ToolbarEntry {
  const ToolbarActionEntry({
    required this.icon, required this.label, required this.tooltip,
    required this.onPressed, this.emphasis = Emphasis.secondary,
    this.badgeCount,
  });
  final IconRole icon;
  final String label, tooltip;
  final VoidCallback? onPressed;
  final Emphasis emphasis;
  final int? badgeCount;
}

/// The four switchers — workspace, repository, branch, global branch. A picker
/// NAMES the thing other controls act on; it is not an action, and every
/// language puts it somewhere different. Data rather than a Widget because
/// `MacosPulldownButton` asserts title XOR icon (pulldown_button.dart:628-631)
/// and `CommandBarBuilderItem` can only wrap another `CommandBarItem`
/// (commandbar.dart:548-556) — a pre-built control fits neither.
final class ToolbarPickerEntry extends ToolbarEntry {
  const ToolbarPickerEntry({
    required this.label, required this.value, required this.icon,
    required this.entries, this.tooltip, this.emptyLabel,
  });
  final String label, value;
  final IconRole icon;
  final List<MenuEntry> entries;
  final String? tooltip, emptyLabel;
}

final class ToolbarMenuEntry extends ToolbarEntry { /* quick settings, language */ }
final class ToolbarSeparatorEntry extends ToolbarEntry { const ToolbarSeparatorEntry(); }

final class ToolbarGroup {
  const ToolbarGroup(this.entries, {this.priority = ToolbarPriority.normal});
  final List<ToolbarEntry> entries;
  /// The ONLY overflow knowledge the application has and the skin does not:
  /// what to shed first. Everything else about overflow is the skin's.
  final ToolbarPriority priority;   // pinned | normal | sheddable
}
```

### 2.8 `SkinOverlays` — and the one seam that cannot be forgotten

The spike found that Fluent dialogs capture inherited themes but Fluent flyouts
do not (`FINDINGS.md` §1.2), and "a contract that is right only half the time is
a contract that will be got wrong". macOS is worse, and this was verified
directly in the package source rather than assumed:

- `_InheritedMacosTheme extends InheritedWidget` — **not** `InheritedTheme`
  (`macos_theme.dart:121`), so `InheritedTheme.capture` cannot carry it into a
  route the way it carries `_FluentTheme extends InheritedTheme`
  (`fluent_ui/src/styles/theme.dart:85`).
- `MacosTheme.of` returns `MacosThemeData.fallback()` rather than throwing
  (`macos_theme.dart:45-49`).

The consequence is a shippable, silent bug: a dark-mode application opens a
**light** dialog, in debug and in release, with `debugCheckHasMacosTheme`
satisfied because *a* `MacosTheme` exists. That is the spike's
"compiles-but-renders-wrong" failure in its purest form, and it must not be a
rule a skin author remembers.

The mechanism: **the application owns the entry point, the API package owns the
wrapper, the skin owns the route.**

```dart
/// Captured at the CALL SITE and carried into the route as data.
final class SkinEnvelope {
  const SkinEnvelope._(this.skin, this.request);
  final Skin skin;
  final SkinRequest request;
  static SkinEnvelope capture(BuildContext c) => SkinScope.of(c).envelope;
}

/// An opaque handle to a dialog's content. A skin CANNOT construct one and
/// CANNOT unwrap one: the only way to obtain the surface it is supposed to
/// present is to call [build], and [build] re-establishes `SkinScope` and
/// calls `chrome.wrapRoot` before it returns anything.
///
/// This is why the macOS silent-light-dialog failure becomes impossible to
/// write rather than a rule to remember: a skin that forgets the host does not
/// get a wrongly-themed dialog, it gets an EMPTY one, which is a loud failure.
final class SkinContentHost {
  SkinContentHost._(this._envelope, this._body);
  final SkinEnvelope _envelope;
  final WidgetBuilder _body;

  Widget build(BuildContext c) => SkinScope(
    envelope: _envelope,
    child: Builder(builder: (c1) => _envelope.skin.chrome.wrapRoot(
      c1, request: _envelope.request,
      child: Builder(builder: (c2) => SkinPainted(child: _body(c2))),
    )),
  );
}

abstract interface class SkinOverlays {
  /// The skin pushes ITS OWN route with ITS OWN language's helper —
  /// `showDialog`, `fluent.showDialog`, `showMacosAlertDialog`,
  /// `showMacosSheet`, `showGeneralDialog` — and MUST render `host.build` as
  /// the content. See conflict C2 for why the route is not a contract type.
  Future<T?> presentDialog<T>(BuildContext c, DialogSpec s, SkinContentHost host);

  Future<int?> presentMenu(BuildContext c, {
    required Offset at, required List<MenuEntry> entries, required SkinEnvelope e,
  });

  Future<T?> presentPopover<T>(BuildContext c, PopoverSpec s, SkinContentHost host);

  /// SnackBar / InfoBar / an inline notice. macOS has no toast idiom at all —
  /// `macos_ui` ships no snackbar, toast or InfoBar equivalent — so the macOS
  /// skin renders a transient notice in the shell's status area. Registered
  /// deviation, not a hand-painted lookalike.
  void notify(BuildContext c, NoticeSpec s, SkinEnvelope e);
}

/// The application's ONLY overlay API. It captures the envelope, builds the
/// host, and hands both to the skin. A skin never gets to define the entry
/// point, so it never gets to skip the wrapper.
abstract final class Overlays {
  static Future<T?> dialog<T>(BuildContext c, DialogSpec s) {
    final SkinEnvelope e = SkinEnvelope.capture(c);
    return e.skin.overlays.presentDialog<T>(
      c, s,
      SkinContentHost._(e, (c2) => DialogKeyboardHost(
        barrierDismissible: s.barrierDismissible,
        onSubmit: s.onSubmit,
        child: e.skin.chrome.dialogSurface(c2, s),
      )),
    );
  }

  static void notify(BuildContext c, NoticeSpec s) =>
      SkinEnvelope.capture(c).skin.overlays.notify(c, s, SkinEnvelope.capture(c));
}
```

`DialogKeyboardHost` (`lib/shared/components/base_dialog.dart:547-631`) sits
**between** the skin's route and the skin's surface, on the application's side.
Escape cancels, Enter submits, the multiline-editable exception and the
`skipTraversal` anchor are *what the user can do*. No skin may weaken them, and
the existing 57-dialog keyboard sweep therefore runs unchanged under all four
skins — it becomes a **cross-skin** sweep parameterised over
`SkinRegistry.all`, which makes the safety net stronger rather than discarding
it.

That is the boundary rule in its sharpest form: **control-internal key handling
belongs to the skin** — Material's `SegmentedButton` already implements its own
arrow keys and the application must not add a second handler —
**application-level key contracts belong to the application**: dialog
Escape/Enter, the F6 pane cycle, list roving highlight.

The theme guarantee is not only structural, it is **asserted**: a cross-skin
test opens a dialog from a `Brightness.dark` caller under every registered skin
and asserts the rendered surface resolves at `Brightness.dark`. That is the
measured macOS bug, as a test.

### 2.9 `SkinRootClaims` — the three declared exceptions

Three members do not return a `Widget` or a `Route`. Each is justified by a
Flutter plumbing requirement, each has a trivial naked answer, and a lint
(`root_claims_are_root_only`) confines every read to `lib/main.dart`, so
application code cannot reach them.

```dart
final class SkinRootClaims {
  const SkinRootClaims({
    this.localizationsDelegates = const <LocalizationsDelegate<Object?>>[],
    this.scrollBehavior,
    this.windowChrome = WindowChrome.hostDefault,
  });

  /// EXCEPTION 1 — R6. `fluent.showDialog` runs
  /// `debugCheckHasFluentLocalizations` BEFORE it pushes anything
  /// (FINDINGS §1.2), and `macos_ui` calls `MaterialLocalizations.of(context)`
  /// un-guarded in seven files (measured: popup_button.dart,
  /// pulldown_button.dart, macos_alert_dialog.dart, toolbar_popup.dart,
  /// date_picker.dart, time_picker.dart, macos_sheet.dart). The single app
  /// root installs the UNION over `SkinRegistry.all`, so a skin is not
  /// self-contained at the widget level — it has a legitimate claim on the
  /// root. Blueprint answers `const []`.
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  /// EXCEPTION 2. Scroll physics and the scrollbar are BEHAVIOUR objects, not
  /// design values, and application code never reads this — only the root
  /// installs it. Blueprint answers `const ScrollBehavior()`.
  final ScrollBehavior? scrollBehavior;

  /// EXCEPTION 3, and it is an enum rather than a value. Window chrome is a
  /// skin decision that today lives as a one-time `window_manager` call in
  /// `main.dart` — which is theming outside every skin. Fluent wants Mica and
  /// its own title bar (`NavigationView.titleBar`, view.dart:114); macOS wants
  /// traffic lights and a unified toolbar (`MacosWindow.titleBar`); Material
  /// wants the host default.
  final WindowChrome windowChrome;   // hostDefault | skinDrawn | systemAccented
}
```

Notably **absent**: there is no `ThemeData` member. The Material skin builds its
`ThemeData` inside `chrome.wrapRoot`; every other skin installs its poison
theme there. `ThemeData` therefore never crosses the contract at all.

### 2.10 `ContentPort` — the one legal Widget seam

```dart
/// The single type through which a Widget may cross into a skin. The skin
/// POSITIONS and CONSTRAINS it and must never style it — no `DefaultTextStyle`,
/// no `IconTheme`, no decoration around it beyond the surface it was asked for.
///
/// The child is PRIVATE. `mount()` is the only way to get at it, and `mount()`
/// plants the boundary that the leak detector resumes at. This is the panel's
/// repair of the original design, where `child` was public and a skin that read
/// it instead of calling `mount()` would have silently exempted that entire
/// subtree from T3 forever.
final class ContentPort {
  const ContentPort(this._child);
  final Widget _child;
  Widget mount() => ContentPortBoundary(child: _child);
}

/// Planted by `SkinScope.render` around every widget a renderer returns. T3
/// prunes its element walk here.
final class SkinPainted extends InheritedWidget {
  const SkinPainted({super.key, required super.child});
  @override bool updateShouldNotify(SkinPainted old) => false;
}

/// Planted by `ContentPort.mount`. T3 RESUMES its element walk here.
final class ContentPortBoundary extends InheritedWidget {
  const ContentPortBoundary({super.key, required super.child});
  @override bool updateShouldNotify(ContentPortBoundary old) => false;
}

abstract final class SkinScope {
  /// Plants `SkinPainted` around everything a renderer returns — in exactly
  /// ONE place, so no skin author can forget it and T3 can trust it.
  static Widget render(BuildContext c, Widget Function(Skin, BuildContext) f) =>
      SkinPainted(child: Builder(builder: (c2) => f(of(c2).skin, c2)));
}
```

The `no_widget_in_contract` lint enforces that any `Widget`-typed parameter on
any contract member is a `ContentPort`. That is what makes T3's partition
trustworthy as the contract grows, and it is why Probe A's lesson generalises:
"a `Widget`-typed parameter is exactly what lets the wrong design language
through the type system unnoticed" (`FINDINGS.md` §6).

### 2.11 What the application keeps

The 21 `Base*` components survive as the application-facing façade. Their public
signatures do not change and their `build` bodies become one line each:

```dart
class BaseButton extends StatelessWidget {
  /* … same constructor, unchanged … */
  @override
  Widget build(BuildContext context) => SkinScope.render(context, (skin, c) =>
      skin.controls.button(c, ButtonSpec(
        label: label, onPressed: onPressed,
        emphasis: _emphasisOf(variant), tone: _toneOf(variant),
        scale: _scaleOf(size),
        leading: leadingIcon, trailing: trailingIcon,
        isLoading: isLoading, fillWidth: fullWidth,
      )));
}
```

So **0 of the 73 `BaseButton`, 72 `BaseIconButton`, 46 `BaseTextField`, 40
`BaseListItem`, 11 `BaseFilterChip` and 82 `BaseDialog` construction sites
move** when the contract lands. Seven of the spike's eight required API changes
are already paid for: `DialogAction` / `DialogActionRole`
(`base_dialog.dart:37,79`), `MenuEntry` / `MenuAction`
(`base_menu_item.dart:27,66`), `BaseChoiceGroup` / `ChoiceOption`
(`base_filter_chip.dart:121,167`), semantic `TextFieldVariant`
(`base_text_field.dart:20`) and `ToolbarAction`
(`overflow_action_bar.dart:10`) all landed, and they become the contract's specs
nearly verbatim. **R5 — the shell — is the one that has not landed, and §4.1 is
its answer.**

### 2.12 Size of the contract

45 members across 7 facets, plus 28 spec classes and 9 vocabularies. The
blueprint implementation is approximately 700 lines.

---

## 3. The blueprint skin, and the five checks

### 3.1 What the blueprint is

**Naked, not inert.** It uses every primitive that carries *behaviour* —
`Focus`, `Actions`, `Shortcuts`, `Semantics`, `EditableText`, `Scrollable`,
`RawMenuAnchor`, `showGeneralDialog` — and none that carries *appearance*. Its
entire visual vocabulary is four decisions:

1. **Paper `#FFFFFF`, ink `#0000FF`.** Two colours, nothing else, ever. The
   blue channel is saturated on purpose: because paper and ink share `b = 255`,
   the set of legal pixels is closed under alpha compositing over paper **and**
   under any per-channel-uniform coverage blend, which is what greyscale,
   gamma-corrected text antialiasing produces. The census in §3.3 is therefore
   **exact arithmetic, not a tolerance**.
2. **A 1px ink outline** on every control and every surface. That is the naked
   square.
3. **Zero.** Every `Proximity` is 0, every `Inset` is 0, every corner is 0,
   every `Elevation` is flat, every `Duration` is `Duration.zero`, all type is
   the system default at one size.
4. **Ink defaults installed.** `chrome.wrapRoot` installs a `DefaultTextStyle`
   and an `IconTheme` in ink. This is the panel's correction and it matters: if
   the blueprint installed nothing, a leaked raw `Text` would render in the
   engine's default **white** and pass a paper-and-ink invariant invisibly.
   Installing ink defaults turns the SDK's own fallbacks into leak detectors.

Meaning that a colour would have carried renders as a **text marker beside** the
content, never inside it — `Tone.danger` becomes a small `!` marker adjacent to
the label, so `find.text('Delete')` still matches. The rule:

> **The blueprint never destroys information, only appearance.**

The blueprint is also parameterised — `BlueprintSkin(distance: n)` — which is
what T2 uses, and it is the template a fourth skin starts from: copy blueprint,
replace the bodies.

### 3.2 The five checks, and what each is blind to

| | Check | Catches | Blind to | Runs on |
|---|---|---|---|---|
| **T1** | Chromatic census | any colour the application painted | alpha blends along the legal line; geometry | Linux CI |
| **T2** | Zero-and-extremes sweep | any *dependence* on a distance | presence of a value nothing depends on | everywhere |
| **T3** | Attribution walk | any paint widget the application built, **by file and line** | anything inside a `paint()` call | **everywhere, incl. Windows** |
| **T4** | Lint countdown | any design *syntax* in `lib/` | anything inside a package; runtime-computed values | everywhere |
| **T5** | Chaos pair | paint leaks incl. greys and white; geometry leaks; leaks inside `CustomPainter` | a leak that happens to match what the skin would have chosen | Linux CI |

No single one is sufficient and the document says so rather than claiming
coverage. A leak has to be invisible to **all five** to survive: achromatic,
distance-independent, structurally inside a `SkinPainted` subtree it did not
create, syntactically legal, and identical across two independently varied
families.

### 3.3 T1 — the chromatic census

Render every scene under the blueprint at 1280×800 with `devicePixelRatio: 1.0`,
capture the frame via `layer.toImage(renderObject.paintBounds)` — the mechanism
`flutter_test`'s own `_matchers_io.dart:34` uses; note that
`tester.binding.takeScreenshot()` does **not** exist in `flutter_test`, it is an
`integration_test` API — and assert one line of arithmetic per pixel:

```dart
// Every legal pixel is an alpha blend of paper (255,255,255) and ink (0,0,255):
//     lerp(t) = (255·(1−t), 255·(1−t), 255)
// so the invariant is exact, and antialiasing satisfies it by construction.
bool isBlueprintPixel(int r, int g, int b) => r == g && b == 0xFF;
```

Any third hue is a colour the **application** painted. A hardcoded `Colors.red`
fails (`b = 0`). A grey `withValues(alpha: 0.3)` divider over paper fails
(`b = 76`). A leftover `colorScheme.secondaryContainer` fails. A stray
`Colors.black` fails. A leaked raw `Text` fails because the blueprint installed
ink defaults (§3.1).

The failure **names the widget**: take the first violating offset, call
`tester.hitTestOnBinding(offset)` (`flutter_test/src/controller.dart:1903`),
walk the `HitTestResult` to the deepest `RenderBox`, and read its
`debugCreator` (`rendering/object.dart:2222`, populated from
`DebugCreator`, `widgets/framework.dart:7374`) — the same mechanism Flutter uses
to print *"The relevant error-causing widget was: …"*, available under
`flutter test` because `--track-widget-creation` is on in debug.

**Blind spots, stated up front.**
(a) A hit test only reaches hit-testable render objects, so a decorative
`DecoratedBox` under an `IgnorePointer` gets a pixel report without an
attribution; T3 attributes it instead.
(b) An `Opacity` or alpha leak blends *along* the legal line and passes; T3 and
T5 cover it.
(c) Genuinely pictorial raster content — `country_flag.dart`, the application
icon — is wrapped in a `BlueprintOpaque` marker whose rects the census skips.
The marker list is a checked-in allowlist with a hard count cap that may only
shrink. **The census is only as strong as the shortness of that list**, and a
leak wrapped in `BlueprintOpaque` is invisible to T1. That is process, not
proof.

### 3.4 T2 — the zero-and-extremes sweep

This is the Zero Test, executed. Run the **entire existing non-conformance
suite** — 850 test declarations across 113 test files, including the 57-dialog
keyboard contract sweep
(`test/shared/dialogs/dialog_keyboard_contract_sweep_test.dart` over
`dialog_population.dart`), the dialog flex sweep, the a11y semantics matrix
(`test/conformance/a11y/component_matrix_a11y_test.dart`) and every feature and
widget test — under `BlueprintSkin(distance: 0)` and again under
`BlueprintSkin(distance: 64)`:

```bash
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=0
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=64
```

- **Any test that fails under either setting was asserting design.**
- **Any test whose result *differs* between 0 and 64 proves the application
  depends on a specific distance.**

That is the only check in any of the three designs that falsifies *dependence on
a value* rather than the presence of one, and it is exactly the criterion this
programme is judged against, run as CI.

**It is not free, and the cost is named.** 49 of 123 files under `test/` pump
their own `MaterialApp` (measured), so under `--dart-define=SKIN=blueprint` they
would silently keep measuring Material and pass vacuously. A false-confidence
risk in the instrument itself is worse than no instrument, so P1 includes
re-rooting those 49 files onto a shared `pumpUnderSkin(tester, …)` helper, and a
grep-based gate fails CI if a new `MaterialApp(` appears under `test/` outside
`packages/gitui_skin_material/test/`.

### 3.5 T3 — the attribution walk

Grafted from the Scene Contract, with the panel's two repairs applied.

`SkinPainted` is planted in exactly one place — `SkinScope.render`
(§2.10) — so no skin author can forget it. `ContentPortBoundary` is planted in
exactly one place, `ContentPort.mount()`, whose child is private so it cannot be
bypassed. Then:

> Walk the element tree from the root. **Prune at every `SkinPainted`. Resume at
> every `ContentPortBoundary`.** Everything reachable in the un-pruned region
> was built by application code.

Assert that the un-pruned region contains **only** widgets on an **allow-list**
of structural and behavioural types: `Column`, `Row`, `Flex`, `Expanded`,
`Flexible`, `Stack`, `Positioned`, `ConstrainedBox`, `LayoutBuilder`,
`SingleChildScrollView`, `ListView`, `CustomScrollView`, `Focus`, `Actions`,
`Shortcuts`, `Semantics`, `GestureDetector`, `MouseRegion`, `Builder`,
`Consumer`, the `Base*` façades, and the framework internals those construct.

**An allow-list, not a deny-list**, because a deny-list is only as good as its
enumeration, and the panel demonstrated the failure concretely on this
repository: the original deny-list named `DecoratedBox` and
`Container(decoration:)` but not `ColoredBox` — and `lib/` contains **0**
`DecoratedBox(`, **0** `ColoredBox(` and **168** `Container(` (measured), so
`Container(color: grey)` builds the one node the deny-list omitted and paints
the one colour an achromatic invariant permits. It would have passed every
check. An allow-list has no such hole and costs the same to write.

Every hit is reported through `element.debugCreator`, which carries the creating
file and line.

**T3 is the check that runs on Windows**, where this repository's owner
develops and where the entire golden suite is skipped by
`skip: !Platform.isLinux` (`test/conformance/goldens/flutter_test_config.dart`).
It needs no screenshot, no hit test and no image comparator, which makes it
usable *during* a codemod rather than only in CI afterwards.

**Blind spot:** T3 cannot see inside a `paint()` call. `lib/` contains exactly
one `extends CustomPainter`, and it becomes `surfaces.commitGraphRow` in P3d, so
after that phase the count is zero and the blind spot is closed by construction
rather than by allowlist. T5 covers it in the meantime.

### 3.6 T4 — the lint countdown

`custom_lint` already runs 25 rules
(`lint_rules/flutter_gitui_lint/lib/src/lints/`) and is already blocking in CI
(#343). Four of them change meaning and seven are new.

The two existing rules are weaker than they look, which was verified by reading
them:

- `avoid_hardcoded_spacing` only flags the whole numbers `{4, 8, 16, 24, 32}`
  (`avoid_hardcoded_spacing.dart:20`), so `SizedBox(height: 12)` and
  `EdgeInsets.all(6)` are legal in this repository today.
- `avoid_hardcoded_colors` matches the *identifier* `Colors` syntactically
  (`avoid_hardcoded_colors.dart:21-31`), so it misses all 917 `colorScheme.*`
  reads, all 789 `Theme.of(` calls and all 96 `withValues(alpha:)` sites.

The replacements are stronger by construction:

| Rule | How it fires | Blast radius today |
|---|---|---:|
| `no_bare_gap` | bans the **widget** — `SizedBox` with a constant, `Padding`, any `EdgeInsets` construction — outside skin packages, so it closes the `const _gap = 12.0` hole every literal-matching rule has | 730 `SizedBox(`, 91 `Padding(`, 292 `EdgeInsets` |
| `avoid_color_expression` | any expression whose **resolved static type** is `Color`, outside skin packages | 917 `colorScheme.`, 96 `withValues(alpha:`, 95 `Colors.` |
| `avoid_text_style_expression` | same, on `TextStyle` | 125 `textTheme.` |
| `no_theme_access` | `Theme.of`, `Theme.maybeOf`, `IconTheme.of`, `DefaultTextStyle.of` | 789 `Theme.of(` in 127 files |
| `no_paint_widgets` | `BoxDecoration`, `DecoratedBox`, `ColoredBox`, `Opacity`, `Border`, `ClipRRect`, `Container` with `color:`/`decoration:` | 152 `BoxDecoration(`, 45 `Border.all`, 149 `BorderRadius`, 3 `ClipRRect(` |
| `no_icon_data` | any `IconData`-typed expression outside skin packages | 917 Phosphor references, 151 distinct glyphs |
| `no_design_language_import` | `flutter/material.dart`, `flutter/cupertino.dart`, `fluent_ui`, `macos_ui`. Applies to `lib/**`, `gitui_skin_api`, `gitui_skin_blueprint`. **Deliberately NOT inside `gitui_skin_fluent`** — the spike proved it unenforceable there | 178 of 300 `lib/` files import material |
| `no_widget_in_contract` | any `Widget`-typed parameter on a contract member that is not a `ContentPort` | 0 (a standing guarantee, not a countdown) |
| `root_claims_are_root_only` | any read of `SkinRootClaims` outside `lib/main.dart` | 0 |
| `structure_literal_budget` | numeric literals in `Positioned`/`ConstrainedBox`/`BoxConstraints`, capped at the measured count, shrink-only | 26 |
| `token_read_is_mechanical` | **migration-only**, deleted at P6. See §5.2 | 1,340 → 0 |

Because `no_design_language_import` makes `Chip`, `Card`, `ElevatedButton`,
`ListTile`, `AlertDialog` and friends *unnameable* in `lib/`, the 14 existing
`avoid_<material widget>` rules become superseded at P6 rather than deleted
earlier — they remain the working ratchet until then. `avoid_print`,
`avoid_raw_shortcuts` and `require_confirm_destructive` are not design rules and
survive unchanged.

**The count is the programme's progress bar, and it is a number that goes to
zero.** Measured today in `lib/` (300 files):

| Leak class | Sites |
|---|---:|
| `AppTheme.*` reads | 1,340 |
| `colorScheme.*` + `textTheme.*` reads | 1,042 |
| `Theme.of(` calls | 789 |
| `SizedBox` / `Padding` / `EdgeInsets` | 1,113 |
| `IconData` glyph references (151 distinct) | 917 |
| Material-named typography widgets (`BodyMediumLabel` …) | 635 |
| raw `Text(` | 170 |
| `BoxDecoration` / `Border.all` / `BorderRadius` | 346 |
| `Container(` | 168 |
| `SnackBar(` / `ScaffoldMessenger` | 180 |

De-duplicated — 825 of the layout widgets are also `AppTheme` reads, and most
`BoxDecoration`s also read `colorScheme` — this is **approximately 4,400 places
a human or a codemod must edit**. When the count is 0, no *syntax* of design
exists in `lib/`. T1 and T5 then prove no *pixel* escaped anyway, T3 proves
nothing was structurally built by the application, and T2 proves nothing the
application *does* depends on a value.

### 3.7 T5 — the chaos pair, as two families

The original proposal ran two seeds of one chaotic skin and diffed for
*invariant* pixels. The panel showed it vacuous: varying the metrics displaces
a leak's pixels between seeds, so nothing is invariant, the zero threshold is
met, and the check goes green on a clean application and a maximally leaky one
alike. A green test measuring nothing is the worst failure a test instrument can
have.

The repair is one decision, and it makes the idea the strongest paint check
available: **two families, each freezing what the other varies.**

- **`BlueprintSkin.chromaChaos(seed: 1|2)` — vary ink, freeze metrics.**
  Positions correspond exactly between the two renders, so any pixel that is
  *identical* across the pair is a pixel the skin did not choose — that is, a
  pixel the **application** chose. This catches greys, whites, alpha blends and
  runtime-computed colours, all of which T1 permits, and it reaches inside
  `CustomPainter` and third-party widgets where every lint is blind.
- **`BlueprintSkin.metricChaos(seed: 1|2)` — vary metrics, freeze ink.**
  Any region that fails to move between the two renders is geometry the
  application decided. This catches the hardcoded `padding: 24` that T1 (wrong
  colour only) and T2 (constant under both) both miss.

The failure artifact is the mask PNG: a black picture with the leak lit up in
its exact screen position. No human eye, no per-widget assertion.

**Honest floor:** text antialiasing and coincidental glyph overlap produce a
handful of invariant pixels in the chroma family. The runner carries a per-scene
tolerance in a checked-in file that CI allows only to shrink — the same ratchet
the deviation register uses.

### 3.8 A worked example of a leak being caught

`lib/features/repositories/widgets/repository_list_item.dart` today draws a
status chip with a hardcoded amber `Container`. Run the blueprint over the
repositories screen before the P3d surface migration, and three orthogonal
detectors agree on one line of source:

```
DESIGN LEAK — 3 findings under skin 'blueprint', scene 'screen/repositories'

  [T3] Container(decoration: BoxDecoration(borderRadius, color))
       built by APPLICATION code, outside any SkinPainted region
       (allow-list contains no painting widget)
         at lib/features/repositories/widgets/repository_list_item.dart:431:12
       → replace with context.skin.surfaces.badge(context, BadgeSpec(...))

  [T1] Blueprint leak: 1,284 of 1,024,000 pixels are not on the paper→ink line.
       first at (412, 189) = #FFC107   (r=255 g=193 → r != g; b=7 != 0xFF)
       painted by: Container ← _StatusChip ← RepositoryListItem
         at lib/features/repositories/widgets/repository_list_item.dart:431:12

  [T5] chroma-family invariance: 1,284 pixels identical across seeds 1 and 2
       → this region's colour was not chosen by the skin
       mask written to build/blueprint/repositories.chroma.mask.png
```

That is what a golden cannot do. A golden says *"something changed"*; this says
*which file drew a colour, and which line*. And the three reports are
independent: T3 found it without rendering an image at all, which is why it runs
on the owner's Windows machine while the goldens do not.

The same run under `--dart-define=DISTANCE=64` would additionally report, for a
hardcoded gap:

```
  [T2] test/features/repositories/repositories_screen_test.dart
       'shows three cards in view' PASSES at DISTANCE=0, FAILS at DISTANCE=64
       → this test asserts a layout that depends on a specific distance
```

---

## 4. The three skins, and the hard cases

### 4.1 The app shell — R5, the one spike change still open

`lib/core/navigation/app_shell.dart` is **1,418 lines** and takes no parameters
(`const AppShell({super.key})`), so its composition cannot be skinned at all
today — the question is not even askable of it (`FINDINGS.md` F5). It splits in
two:

- **`AppShellController` (≈1,150 lines, zero design)** — the 14 provider reads,
  the auto-fetch `Timer`, the 21 `Ctrl`/`Meta` shortcut bindings,
  `_performFetch` / `_performPull` / `_performPush` / `_performCreateBranch` /
  `_performCreatePR` / `_performMergeBranches`, the What's-New and update flows.
  None of this is design and none of it moves.
- **`ShellSpec` construction (≈170 lines)** — destinations, `selectedIndex`,
  `onSelect`, the toolbar groups, the pickers, the banner, the aside, and
  `paneOrder`.

Everything from `app_shell.dart:294` (`Scaffold`) to `:682` — the `Row`, the
`NavigationRail`, the `VerticalDivider`, the toolbar `Container` with its
`BoxDecoration`, the two nested `LayoutBuilder`s and the `ConstrainedBox`
arithmetic at `:474-497` — is **deleted from `lib/` and reappears inside
`gitui_skin_material`**.

| | resolution |
|---|---|
| **Material** | Today's code, verbatim: `Scaffold(body: Stack([Row([NavigationRail(extended: density == full, destinations: …), VerticalDivider, Expanded(Column([actionBar, banner, destinations[selected].body().mount()])), aside]), …layers]))`. Byte-identical goldens are the proof of a behaviour-preserving move. |
| **Fluent** | `NavigationView(titleBar: …, pane: NavigationPane(selected:, onChanged:, displayMode:, items: [for (d in destinations) PaneItem(icon:, title:, infoBadge:, body: d.body().mount())]))`, with the toolbar as a `CommandBar(primaryItems: [...], overflowBehavior: …)` **inside** the page. Verified: the parameter is `titleBar`, not `appBar` (`view.dart:114`); `NavigationAppBar` **does not exist** in 4.16.1; `NavigationView` asserts `(pane != null && content == null) \|\| (pane == null && content != null)` (`view.dart:123-126`); `PaneDisplayMode` is `{top, expanded, compact, minimal, auto}` (`pane.dart:26-61`) — `expanded`, not `open`. |
| **macOS** | `MacosWindow(titleBar: TitleBar(…), sidebar: Sidebar(minWidth:, top: identity, bottom: status, builder: (c, sc) => SidebarItems(currentIndex:, onChanged:, items: [SidebarItem(leading:, label:, trailing:)])), endSidebar: aside, child: MacosScaffold(toolBar: ToolBar(title:, actions: [ToolBarIconButton…, ToolBarPullDownButton…]), children: [ContentArea(builder: (c, sc) => destinations[selected].body().mount())]))`. |
| **Blueprint** | `Column([Row(destinations as outlined squares), Expanded(body)])`, 1px outlines, zero gaps. About 40 lines. |

Three sub-problems the spec resolves explicitly:

**Toolbar overflow belongs to the skin, and two of three languages already say
so.** `ToolBar.actions` is `List<ToolbarItem>?` (`macos_ui/…/toolbar.dart:114`)
where `ToolbarItem` is an abstract `Diagnosticable` with
`build(context, displayMode)` (`:341`), and the bar grows its own
`ToolbarOverflowButton` through an `OverflowHandler` (`:286-300`).
`CommandBar.primaryItems` is `List<CommandBarItem>`
(`fluent_ui/…/commandbar.dart:136`) with a `CommandBarOverflowBehavior`
(`:153`). **Both refuse Widgets and both own their overflow.** Material is the
outlier. That is the same decision the application already made with
`ToolbarAction` (`overflow_action_bar.dart:10`), independently confirmed by two
design languages. So `ShellSpec.toolbar` is `List<ToolbarGroup>` and
`OverflowActionBar` — with `visibleActionCount()`, `itemExtent = 48`,
`menuExtent = 48`, `spacing` and its existing unit tests — migrates into
`gitui_skin_material`. The measurement problem does not get an escape hatch; it
gets moved to the side of the line that owns numbers.

**Navigation density is a capability, not a command.** `app_shell.dart:353`
currently draws a caret `BaseIconButton`. Fluent's `NavigationPane` ships its own
toggle; macOS's window owns it (`MacosWindowScope.toggleSidebar()`,
`window.dart:697`, and `isSidebarShown`, `:688`). Two affordances for one job is
a defect by this repository's own rules, so the *skin* decides whether a toggle
is drawn, and the caret button is deleted from `lib/`. Honest note:
`NavigationDensity.condensed` is an approximation on macOS, because
`SidebarItem.label` is a required `Widget` (`sidebar_item.dart:15,35`) and there
is no icon-only AppKit sidebar — registered deviation.

**`paneOrder` is structure and the skin may not touch it.** The F6 / Shift+F6
pane cycle and the Tab order rail → toolbar → content → log are *what the user
can do*. `BaseFocusRegion(order: 1..4)` stays in application code and wraps
**around** whatever `chrome.shell` returns.

### 4.2 Dialogs and overlays

The route/surface split (`FINDINGS.md` F1, R7) is a hard requirement, and the
keyboard contract is why it must be **three** layers: the skin's route, the
application's `DialogKeyboardHost`, the skin's surface (§2.8). Because
`BaseDialog.show(context:)` already carries the skin through its existing
`context` parameter (`FINDINGS.md` F7), **none of the 14 `.show` sites and none
of the 82 `BaseDialog(` constructions change a character.**

| | dialog surface | route |
|---|---|---|
| **Material** | `Dialog(shape: RoundedRectangleBorder(12dp — deviation DLG-001))`, today's body verbatim | `showDialog` |
| **Fluent** | `ContentDialog(title:, content:, actions:)` with actions reordered **affirmative-first** and stretched to equal width, `DialogActionRole.destructive` on Fluent's critical style, `dismissWithEsc`. Reachable only because `DialogAction.role` landed (`base_dialog.dart:37`) | `fluent.showDialog`; needs `FluentLocalizations` from `rootClaims` (R6). Menus go through `presentMenu`, so the flyout theme re-wrap the spike found necessary (§1.2) lives inside the skin where it belongs |
| **macOS** | **Routed by arity and extent.** `DialogExtent.alert` with ≤ 2 actions → `MacosAlertDialog(appIcon:, title:, message:, primaryButton:, secondaryButton:)`; everything else → `MacosSheet`. Verified: `required this.appIcon` (`macos_alert_dialog.dart:37`), `required this.primaryButton` (`:40`), optional `this.secondaryButton` (`:41`), `assert(primaryButton.controlSize == ControlSize.large)` (`:118`), `_kDefaultDialogConstraints = BoxConstraints(minWidth: 260, maxWidth: 260)` (`:6`), and `showMacosSheet` at `macos_sheet.dart:102` | `showMacosAlertDialog` / `showMacosSheet`, each pushing its own `PopupRoute` — which is exactly why the contract does not own the route class (conflict C2) |
| **Blueprint** | `Align(child: outlined Column([title, content, Row(actions)]))`, about 25 lines | `showGeneralDialog(barrierColor: Colors.transparent, transitionDuration: Duration.zero)` — reachable from `flutter/widgets.dart` (`routes.dart:2759`) |

**The arity population, counted.** The application has 82 `BaseDialog(`
constructions across 55 files, and the dialog sweep population
(`test/shared/dialogs/dialog_population.dart:434`) enumerates **57 dialog
cases**. Of the dialogs that declare three or more actions —
`update_available_dialog.dart` (4), `reset_mode_dialog.dart` (4),
`advanced_search_dialog.dart` (3), `settings_screen.dart` (×2, 3),
`file_tree_view.dart` (3) — every one routes to `MacosSheet`, which is what
macOS itself does for anything richer than an alert. That routing is a skin
decision, invisible to all 82 call sites.

`AppIdentity.icon` exists on `ShellSpec` solely because macOS requires it.

### 4.3 The chip / segmented-control pattern

The unit is decided by a rule, not case by case:

> **A contract member exists at level L if and only if every target language
> has a canonical widget whose *arity* is L. If any language's canonical answer
> covers N of our units at once, the member moves up to N.**

Applied, with every claim checked against the package source:

- **Single choice** — Material `SegmentedButton<T>` (group, EXACT); macOS
  `MacosSegmentedControl` (group, **ADAPTED, not EXACT**: it requires
  `List<MacosTab> tabs` **and** a `MacosTabController`
  (`macos_ui/src/buttons/segmented_control.dart:22-33`), so it is the tab bar
  `MacosTabView` is built on, not a value selector — the skin creates and syncs
  the controller internally, which is only possible because a renderer may
  return a `StatefulWidget`); Fluent `RadioButton` in a group, **ADAPTED**
  because `fluent_ui` 4.16.1 ships no segmented control (verified by grepping
  the whole package). Arity mismatch at 1, match at N → the member is
  **`choiceGroup`**. This is R3, already landed, at **1 call site**
  (`create_branch_dialog.dart:226`).
- **Multi-select filter chips** — all three have a per-item toggle
  (`FilterChip`, `ToggleButton`, `PushButton(secondary:)`), arity 1 → the member
  stays **`filterToggle`**, per chip. 11 sites, unchanged.
- **Toolbar buttons** — two of three languages own overflow at the bar → arity
  is the bar → **no `toolbarButton` member exists at all**.
- **Dialog actions** — languages reorder and restretch the *set* → arity is the
  set → `DialogSpec.actions`.
- **List row plus its menu** — all three have a row and an anchored menu
  independently, arity 1 each, but the *anchor* is the skin's, so
  `ListRowSpec.menu` is data and `base_list_item.dart:175` stops building a
  `BasePopupMenuButton` itself.
- **Field plus trailing action** — this repository's non-negotiable
  in-field-action rule (`CLAUDE.md`) is *better* served by macOS than by
  Cupertino: `MacosTextField` has `prefix`, `suffix` **and** `clearButtonMode`,
  so the five parameters the spike scored BLOCKED under Cupertino
  (`suffixIcon`, `onSuffixTap`, `suffixTooltip`, `showClearButton`,
  `showPasswordToggle`, `FINDINGS.md` §4.3) become ADAPTED. `FormField`
  registration is composed inside the skin — no change to any of the 46
  `BaseTextField` sites.

The rule is enforced, not merely stated. `docs/skin_arity.yaml` records the
canonical widget and its arity per member per language, and a test fails when a
member's declared arity disagrees with any language's recorded answer — the same
executable-register pattern `docs/deviation_register.yaml` already uses in both
directions.

---

## 5. The migration

Nine phases. Every one ships on `master`, keeps CI green, and looks identical
under the Material skin until P7. Counts are `grep` over `lib/` at `master`
(300 Dart files, 178 of which import `package:flutter/material.dart`).

**Total: approximately 22 weeks to enforcement, 28 including the two
non-Material skins.** That exceeds #341's 14–18 week estimate, and the reason is
stated rather than hidden: #249's Phase 0 planned to re-plumb spacing and radii
only, and this programme additionally moves 789 `Theme.of` reads, 917
`colorScheme` reads, 635 Material-named labels and 917 icon references, which is
where the other half of the design actually lives.

### 5.0 A gate that runs before P0

**A one-week `macos_ui` probe**, mirroring `spike/skin_lab`. The spike's 195
classifications were against *Cupertino* and none of that evidence transfers.
Much of the probe is already done — every macOS claim in this document was read
out of `macos_ui-2.2.2` source and is cited — but three questions remain
unmeasured and each could change a contract member:

1. Does `MacosWindow` + `Sidebar` + `MacosScaffold` + `ToolBar` render under a
   non-`MacosApp` root, on Windows, in a widget test? (The Fluent equivalent was
   the spike's day-one answer and it decided the architecture.)
2. Does `MacosTextField` compose with `FormField` registration cleanly enough to
   keep `formKey.currentState!.validate()` working at all 46 sites?
3. Do `macos_ui`, `fluent_ui` and the app's existing pins co-resolve in one pub
   workspace? (`fluent_ui` provably does — `FINDINGS.md` §1.1 shows a purely
   additive lockfile diff. `macos_ui` is unverified against this workspace.)

If (1) fails, `chrome.shell` and `chrome.wrapRoot` are where the change lands
and the cost of the programme grows. That is why this runs first.

#### The gate has run. Two answers passed, one did not.

Measured in `spike/skin_lab/test/macos_gate_test.dart` (19 tests) against
`macos_ui 2.2.2`. Every claim below is executed, not read.

**(3) Co-resolution — passed, purely additively.** Four new transitive packages
and **no removed lines at all** in `pubspec.lock`; no existing application
dependency moved version. A pub workspace shares one version solve, so a
constraint fight would have moved the app's own pins silently. `macos_ui` is as
well-behaved here as `fluent_ui` was.

**(1) The shell under a foreign root — passed.** `MacosWindow` + `Sidebar` +
`MacosScaffold` + `ToolBar` mount and paint under a plain `MaterialApp`, with a
recorder installed on all four macOS-only channels asserting it stays empty.
`showMacosAlertDialog` and `showMacosSheet` push onto a Material `Navigator`.
`MacosTheme` is *mandatory* rather than optional — `MacosWindow` without one
throws at `window.dart:181` — so `chrome.wrapRoot` must install it.

§2.8's account of the failure mode is **wrong in the direction that makes its
own remedy more necessary**. A `MacosTheme` genuinely does not survive into a
route (`_InheritedMacosTheme extends InheritedWidget`, `macos_theme.dart:121`,
not `InheritedTheme`). But `debugCheckHasMacosTheme` asserts on
`MacosTheme.maybeOf(context) == null` (`utils.dart:21-37`), so in the
architecture §2.7 specifies — the theme installed by `wrapRoot`, below the
navigator — a skin that forgets `SkinContentHost` gets a **hard debug throw**
before anything renders, not the silently light dialog the prose describes. The
silent case appears only when a *different* `MacosTheme` sits above the
navigator, which satisfies the assert with the wrong theme. Both arrangements
are pinned as tests. §2.9 Exception 1 is also confirmed load-bearing: both macOS
overlay helpers read `MaterialLocalizations` unguarded
(`macos_alert_dialog.dart:248`, `macos_sheet.dart:133`).

**(2) Form registration — failed, and the contract changes.** `MacosTextField`
does not register with a `Form`: `grep -rn 'FormField' macos_ui/lib` returns
zero hits, and a measured `validate()` over an empty required field returns
**`true`**. That is precisely the defect this repository already shipped once —
`base_text_field.dart` carries the comment describing how a `TextField` never
runs a validator, so `formKey.currentState!.validate()` found no fields and
waved invalid input through. The fix there was `TextFormField`, a Material
widget the macOS skin cannot use.

So `SkinControls.textField` (§2.4) **must not leave form registration to the
skin**. `FieldSpec` carries the validator, and the API package wraps every
skin's returned field in a single `FormField<String>` host that feeds
`field.didChange` from `onChanged` — the same "impossible to forget" shape as
`SkinContentHost`. `FormField` is exported from `package:flutter/widgets.dart`
(`widgets.dart:63`), not from material, so the blueprint keeps compiling and the
compile-time proof survives. Without this, the 46 `BaseTextField(` sites and 12
`currentState!.validate()` sites stop guarding the moment a non-Material skin is
selected — silently, which is the failure mode this whole design exists to
prevent.

**Also settled, ahead of P8.** `MacosSegmentedControl` requires both a
`List<MacosTab>` and a `MacosTabController` and carries no value type
(`segmented_control.dart:22-33`): it is a tab bar. `choiceGroup<T>` adapts onto
it for single-select with string labels; `filterToggle` — multi-select — has no
macOS counterpart at all, and that belongs in the register before the skin is
written rather than during it.

### 5.1 P0 — move the ruler, change nothing (1 week)

Relocate `test/conformance/` (15 component suites, the a11y matrix, the theme
suite, all 68 golden PNGs) and all 65 entries of `docs/deviation_register.yaml`
into `packages/gitui_skin_material/test/`, **verbatim**.

Nothing is discarded, and the relocation is a correction rather than a
concession: the register measures divergence from *Material 3* and the goldens
render *Material's* pixels. They were always one skin's conformance suite; today
they are only misfiled. From P0 on, `deviation_register.yaml` is per-skin, and
Fluent and macOS each get their own — which is how "delegate, never hand-paint"
stays checkable.

**Breaks:** import paths in about 30 test files.
**Blast radius: 0 files in `lib/`.**
**Independently valuable if P1 is delayed:** the register is correctly filed and
the goldens are attributed to the skin they actually measure.

### 5.2 P1 — the API package, the blueprint, and the classifier (3 weeks)

Create `packages/gitui_skin_api` (45 members, 28 specs, `flutter/widgets.dart`
only) and `packages/gitui_skin_blueprint` (≈700 lines). Add `SkinScope`,
`SkinRegistry` and `context.skin`. Build the screen-scene harness that T1, T4
and T5 need — today `test/conformance/goldens/screen_scenes.dart` contains
**3 fragments** (`screen_shell_toolbar`, `screen_changes_file_rows`,
`screen_tags_filter_band`), and the comparable population file for dialogs is
1,302 lines of Riverpod overrides, so this is real work and it is budgeted here
rather than assumed. Re-root the 49 test files that pump their own `MaterialApp`
onto `pumpUnderSkin` (§3.4).

**One pubspec consequence that must not be discovered later.**
`analysis_options.yaml:47` escalates `depend_on_referenced_packages` to
**error**, pinned by `test/conformance/dependency_isolation_gate_test.dart`
(#383). So `lib/` cannot import a workspace member that is not a declared
dependency. `gitui_skin_api` and each skin package therefore enter
`dependencies:` with a `path:` reference — one pubspec edit, and the gate test
stays green because the dependency edge genuinely exists. Extend the same gate
with a test that `gitui_skin_api` does not resolve
`package:flutter/material.dart`.

Ship **`token_read_is_mechanical`** here, as a migration-only lint that is
deleted at P6. It is the answer to the question that decides whether the grind
is a script or a year, and it was measured rather than estimated:

> **A bare `AppTheme.*` token as a named argument in a closed set of positions
> (`SizedBox` `width:`/`height:`, an `EdgeInsets` argument, `Radius`/
> `BorderRadius`, `size:`, `spacing:`, `runSpacing:`, `iconSize:`) is
> MECHANICAL. A token inside a binary expression is DESIGN-BEARING.**

Measured across the 1,340 `AppTheme.*` reads: **approximately 32 occurrences in
16 files** appear inside an arithmetic expression, and 6 of those 16 files are
already inside `lib/shared/components/` or `lib/shared/widgets/`
(`base_badge.dart`, `base_diff_viewer.dart`, `base_dropdown.dart`,
`base_speed_dial.dart`, `base_tree_item.dart`, `command_log_panel.dart`), where
they belong. The partition is therefore roughly **1,308 mechanical : 32
design-bearing**, and because the classifier ships as a lint it is
*continuously re-measured* rather than asserted once. It doubles as P3c's
progress bar.

**Breaks:** nothing — `lib/` does not call either package yet.
**Blast radius: 0 `lib/` files, 2 new packages, 1 pubspec edit, 49 test files
re-rooted.**
**Independently valuable if P2 is delayed:** the blueprint compiling against
`flutter/widgets.dart` alone is already the proof that the contract is
design-language-free, obtained before a single application file moves. The
classifier's number is already actionable.

*Caveat recorded here rather than discovered later:* `fluent_ui` re-exports 31
Material symbols, so `no_design_language_import` is enforceable on
`gitui_skin_api`, on `gitui_skin_blueprint` and on `lib/` — never inside
`gitui_skin_fluent`. That package runs on review and discipline forever, and no
amount of design changes it.

### 5.3 P2 — Material by extraction (3 weeks)

Implement every contract member by **moving today's bodies in**.
`base_button.dart`'s `_variantStyle` and per-size metrics become the Material
skin's `controls.button`; `base_dialog.dart:357-503` becomes
`chrome.dialogSurface`; `base_list_item.dart`'s `Ink`/`InkWell` tile becomes
`surfaces.listRow`; `app_theme.dart`'s `FlexThemeData` factory becomes
`chrome.wrapRoot`. The 21 `Base*` widgets stay, each reduced to a one-line
delegation.

Delete `main.dart`'s `ValueKey('$fontSize-$fontFamily-…')` rebuild hack (#249
§1.5) — it nukes navigation and scroll state on every settings change, and once
the skin owns its own theme installation it is unnecessary.

**Breaks:** nothing user-visible — **the 68 goldens must be byte-identical**,
and any diff is a defect, not an expected change. That is what makes a
three-week rewrite of the highest-traffic components safe.
**Blast radius: 21 component files + `app_theme.dart` + `main.dart`; 0 call
sites; `app_shell.dart` untouched.**
**Independently valuable if P3 is delayed:** the theme factory is behind a
contract, the settings picker can list one skin, and the state-destroying
rebuild hack is gone.

### 5.4 P3 — detokenise (10 weeks) — the grind, and the honest cost

Four sub-steps, each ending by flipping one lint rule to `error` when its count
hits zero. Sequenced so that the mechanical steps land first and build
confidence in the codemod before the judgement-heavy one starts.

| Step | What | Sites | Nature | Weeks |
|---|---|---:|---|---:|
| **P3a** | 151-member `IconRole`; `PhosphorIcons*.x` → `IconRole.x` | 917 refs, 145 files | fully mechanical | 1 |
| **P3b** | `BodyMediumLabel` … → `context.skin.type.text(role:)` on 9 application roles; 170 raw `Text(` folded in | 805 | 15→9 mapping decisions, then mechanical | 2 |
| **P3c** | 676 `SizedBox(…: AppTheme.padding*)` → `layout.column/row(gap:)` or `layout.gap`; 153 `EdgeInsets` → `layout.inset`; the residue of `SizedBox`/`Padding` | 1,113 | the classifier says ≈98% is a 1:1 token→enum substitution | 2 |
| **P3d** | 917 `colorScheme.*` + 125 `textTheme.*` + 789 `Theme.of(` reads; 152 `BoxDecoration` + 45 `Border.all` + 168 `Container` → `Tone` + `surfaces.*` | ≈2,100 | **the judgement-heavy step** | 5 |

P3c is where the migration **deletes** code: 676 gap `SizedBox`es are absorbed
into 511 existing `Column`/`Row` constructions (239 + 272, measured) that gain
one `gap:` argument, using `Flex.spacing` (`basic.dart:5431`) underneath. A
refactor that removes more code than it adds is one a team finishes.

The one place the codemod can fail is the `gap:` hoist when a single `Column`
mixes proximities; the codemod refuses those and emits explicit
`layout.gap(...)` calls instead. **The refusal rate is the checkpoint that says
whether P3c is 2 weeks or 4**, and it is visible on day two.

P3d is not codemoddable and pretending otherwise is where this programme would
fail. `colorScheme.secondaryContainer` at `base_list_item.dart:204` means
"primary selection" and `tertiaryContainer` at `:207` means "multi-selection";
only a human knows that. It ships as **one pull request per feature directory**,
with `avoid_color_expression` flipping from `info` to `error` **per directory**
as each lands, so the ratchet tightens continuously and a regression in a
finished directory is a build failure the same day. **The checkpoint: if
directory three is still adding `Tone` members, the vocabulary is wrong** and
the abstraction must be revisited before directory four.

`AppTheme`'s token constants (`app_theme.dart:601-640`) are then deleted as a
*consequence*, not as their own step; the class keeps only `availableFonts`
(`:567`).

Two named structural consequences that are *not* mechanical:

- The four `_rowExtent = 56|72|80|104` constants exist because
  `KeyboardNavigableListView` uses `itemExtent` to scroll the roving highlight
  into view. Row height becomes skin-owned, so those lists switch to
  `Scrollable.ensureVisible` on the row's own context — a better implementation
  regardless, since a fixed extent already breaks when content wraps.
- `commit_graph_painter.dart` becomes `surfaces.commitGraphRow` with a
  lanes/nodes/edges spec; `_laneWidth = 12`, `_dotRadius = 4`,
  `_strokeWidth = 2` move into the Material skin. After this, `lib/` contains
  **zero** `CustomPainter`, which closes T3's only blind spot by construction.

**What breaks at each step:** in principle nothing — the Material skin returns
the same numbers, so **the entire detokenisation is golden-neutral and any
golden diff is a bug**. The one exception is P3b, where collapsing 15 Material
type roles into 9 application roles changes rendered text sizes at some of 805
call sites; see decision **D3** in §7.

**Blast radius: ≈4,400 edit sites across ≈240 files.**
**Independently valuable if the next step is delayed:** each sub-step ends with
one lint rule at `error`, which is a permanent, enforced property. P3a alone
makes `FluentIcons` and SF Symbols reachable. P3c alone deletes 676 widgets.

### 5.5 P4 — overlays (2 weeks)

`BaseDialog.show` (14 sites) and the 86 raw `showDialog` sites route through
`Overlays.dialog`. `NotificationService` becomes `Overlays.notify`, and the
**121 raw `SnackBar(` constructions and 59 `ScaffoldMessenger` references
outside the service** are folded in. `avoid_dialog`'s whitelist and new
`no_scaffold_messenger` / `no_raw_route` rules flip to `error`.

**Breaks:** any dialog that relied on Material route metrics. The two dialog
sweeps in `test/shared/dialogs/` must keep passing unchanged — they derive their
population from source, so they will catch a dialog that silently left the
funnel.
**Blast radius: 280 call sites across ~70 files.**
**Independently valuable if P5 is delayed:** every overlay in the application
goes through one funnel, which is a correctness win on its own (#341 already
lists 51 rogue `ScaffoldMessenger` sites as a defect).

### 5.6 P5 — the shell (2 weeks)

R5. `app_shell.dart` 1,418 → `AppShellController` (≈1,150) + `ShellSpec` (≈170);
`:294-682` moves into the Material skin. `OverflowActionBar` and
`visibleActionCount()` move with it. The caret toggle at `:353` is deleted in
favour of `onDensityChanged`. The four switchers become `ToolbarPickerEntry`.

**Breaks:** the riskiest single file in the programme — the F6 pane cycle, 21
shortcut bindings, the auto-fetch timer and 14 provider reads all live here.
Mitigated by doing it **after** P3, so the file being split no longer contains
any design.
**Blast radius: 1 file, 1,418 lines.**
**Independently valuable if P6 is delayed:** the shell is testable in isolation
for the first time, and `AppShellController` becomes unit-testable without
pumping a widget tree.

### 5.7 P6 — the ban (1 week)

All eleven lint rules to `error`. `AppTheme` deleted.
`avoid_hardcoded_spacing` / `avoid_hardcoded_colors` / `avoid_hardcoded_radius`
and the 14 `avoid_<material widget>` rules retired as superseded by
`no_design_language_import`. `token_read_is_mechanical` deleted. The blueprint
CI jobs (T1, T2, T3, T5) flip from advisory to **blocking**.

**This is the milestone at which the owner's sentence becomes true and
enforced** — approximately 22 weeks in, with no other skin shipped yet. From
here a regression is a build failure, not a review miss.

### 5.8 P7 — Fluent (3 weeks), P8 — macOS (3 weeks)

Independent workspace packages, shippable one at a time behind the settings
picker. Each starts as a copy of `BlueprintSkin` with the bodies replaced, and
each ships its own `deviation_register.yaml` and its own golden set.

**Breaks:** nothing in `lib/`. **If either skin requires an `lib/` change, the
contract was wrong**, and that is the signal to stop and fix the contract rather
than to patch the application.

### 5.9 The gate that makes each phase honest

CI runs, from P1 onward:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run custom_lint --fatal-infos --fatal-warnings   # the countdown
flutter test                                          # Material; goldens byte-identical
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=0
flutter test --dart-define=SKIN=blueprint --dart-define=DISTANCE=64
flutter test --tags blueprint-pixels                  # T1 + T5, Linux only
```

The blueprint jobs are **advisory until P3d completes and blocking
thereafter** — because before then they are *expected* to fail, and the number
of failures is the same progress bar as the lint count. T3 is blocking from P2
onward, because it needs no rendering and its allow-list only has to hold for
the components already migrated.

---

## 6. What is preserved

Every existing asset is a safety net a 4,400-site refactor needs, not an
obstacle. Nothing is discarded.

**`docs/deviation_register.yaml` — 65 entries, executable in both directions.**
Relocated verbatim to `packages/gitui_skin_material/test/` in P0 and gains a
`skin:` key; all 65 entries become `skin: material`. The both-directions
assertion (an unregistered mismatch fails a test, and a registered entry that
now conforms fails as *stale*, so it cannot rot) is preserved unchanged. Fluent
and macOS each ship their own register from P7/P8, which is how "delegate, never
hand-paint" stays checkable for languages we have not yet written. New entries
this programme adds are already known: the macOS three-action → sheet routing,
`NavigationDensity.condensed` on macOS, macOS having no toast idiom, Fluent
having no segmented control, and the poison-theme scope (conflict C10).

**The 68 goldens.** Relocated in P0, byte-identical through P2 and all of P3
except P3b. They are the acceptance test for every behaviour-preserving move,
and they are precisely what makes a rewrite of the highest-traffic components
survivable. Their one structural limitation is recorded rather than papered
over: they are **Linux-only** (`skip: !Platform.isLinux`) with a 0.5%-tolerant
comparator (`test/conformance/goldens/flutter_test_config.dart`), which is why
T3 exists as the check that runs on the owner's Windows machine.

**The two dialog sweeps.** `dialog_keyboard_contract_sweep_test.dart` and
`base_dialog_flex_sweep_test.dart` run over `dialog_population.dart`'s 57
`DialogCase`s, whose population is derived from source so a dialog cannot leave
the funnel silently. They are not merely preserved — they are **strengthened**:
from P4 they are parameterised over `SkinRegistry.all` and become a **cross-skin
sweep**, which means Escape-cancels and Enter-submits are asserted under Fluent
and macOS too. `DialogKeyboardHost` stays in application code (§2.8) precisely so
that no skin can weaken them.

**The 25 lint rules.** 3 are not design rules and survive untouched
(`avoid_print`, `avoid_raw_shortcuts`, `require_confirm_destructive`). 4 are
replaced by strictly stronger versions in P1 (`avoid_hardcoded_colors` →
`avoid_color_expression`, `avoid_hardcoded_spacing` → `no_bare_gap`,
`avoid_hardcoded_radius` → `no_paint_widgets`, `avoid_text_with_style` →
`avoid_text_style_expression`). 14 ban a specific Material widget and remain the
working ratchet until P6, then retire as superseded by
`no_design_language_import`, which makes those widgets *unnameable* rather than
merely discouraged. `avoid_null_color_in_copy_with` becomes moot when no
application expression has type `Color`. 11 new rules are added.

**The a11y matrix** (`test/conformance/a11y/component_matrix_a11y_test.dart`)
runs unchanged under every skin as part of T2, which is how "the blueprint never
destroys information, only appearance" is verified rather than asserted.

**The workspace-isolation gate** (#383,
`test/conformance/dependency_isolation_gate_test.dart`) stays at `error` and is
extended in P1 with a test that `gitui_skin_api` cannot resolve
`package:flutter/material.dart`.

---

## 7. Decisions the owner must make before implementation starts

These are stated as decisions, not as uncertainty. Each has a default, and each
has a consequence if the default is rejected.

> **D1 — Fund P3 to zero, or do not start.**
> The programme is ≈22 weeks to enforcement against #341's 14–18 week estimate,
> and 10 of those weeks are P3, a mechanical and judgement grind with no
> user-visible value. If it is cut short mid-P3, the application carries **two
> vocabularies for the same thing** (`AppTheme.paddingM` beside
> `layout.gap(Proximity.grouped)`), which is worse than either endpoint. The
> lint countdown makes that state visible; it does not make it safe.
> *Default: fund it. If the answer is no, this design should not be started and
> a token-bag design should be chosen instead, with its blind spots accepted
> knowingly.*

> **D2 — 151-member `IconRole` now, or Phosphor glyphs in every skin.**
> `IconRole` costs 917 mechanical edits and imposes a permanent tax: every new
> feature that wants a glyph must add an enum member and implement it in four
> skins. Cutting it means Fluent renders Phosphor instead of `FluentIcons` and
> macOS renders Phosphor instead of SF Symbols — a visible spec violation that
> belongs in the register.
> *Default: take it, at P3a. It is the cheapest phase and it is fully
> mechanical.*

> **D3 — Accept a one-time visible typography change, or freeze Material's
> ramp.**
> Collapsing 15 Material type roles into 9 application roles changes rendered
> text sizes at some of 805 call sites, so the 68 goldens must be regenerated
> once and the owner will see the application change. The alternative is a
> 15-member `TextRole` that is Material's ramp under new names, which satisfies
> the letter of "no design in the code" while shipping Material's typography
> decisions to Fluent and macOS.
> *Default: accept the change, ship it as one release with a documented type
> scale note. Note that #341 already found the current ramp broken — the type
> scale collapses from 15 sizes to 5 at runtime, and `labelLarge` renders at
> 11px instead of 14px — so "preserve today's sizes" preserves a defect.*

> **D4 — The blueprint's text field: no selection toolbar, or one Material
> import.**
> `EditableText` is available from `flutter/widgets.dart`, but the selection
> toolbar is `AdaptiveTextSelectionToolbar`, which is Material/Cupertino. Either
> the blueprint imports material for that one widget — weakening the claim that
> the blueprint proves the contract needs no Material — or it ships a text field
> with no selection toolbar, weakening the blueprint as a usable development
> instrument.
> *Default: no toolbar, registered as a blueprint-only deviation. The compile-
> time proof is the more valuable of the two.*

> **D5 — Poison-theme scope under macOS.**
> `MacosAlertDialog.build` returns a Material `Dialog`
> (`macos_alert_dialog.dart:135`), so a fully poisoned root `ThemeData` would
> corrupt a correctly delegating macOS skin. The proposed resolution poisons
> `ColorScheme`, `TextTheme`, `dividerColor` and `iconTheme` and leaves
> `DialogTheme` and `visualDensity` at their defaults, which is safe because the
> dialog sets its own `backgroundColor`, `shape` and `DefaultTextStyle`.
> *Default: take the narrow poison under all non-Material skins. The alternative
> is opt-in via `--dart-define`, which loses the property that made the idea
> worth grafting — that it runs in production, on screens no test renders.*

> **D6 — Is a macOS skin developed and tested on Windows and Linux
> acceptable?**
> `macos_ui` is a macOS-only plugin, but its two platform-channel users
> (`AccentColorListener`, `WindowMainStateListener`) both begin
> `if (!Platform.isMacOS) return;`, so it renders on Windows and Linux. That is
> what makes a macOS skin developable on this repository's own machines — and it
> also means the skin will be shipped having never been seen on the platform it
> imitates.
> *Default: yes, with a registered deviation stating that macOS conformance is
> asserted against `macos_ui`'s rendering and not against AppKit itself.*

> **D7 — Add a Windows golden lane, or accept that T1 and T5 are CI-only?**
> The 68 goldens and therefore T1 and T5 are Linux-only. T3 and T2 run
> everywhere. Adding a Windows baseline set doubles the golden maintenance
> burden; not adding it means the owner cannot run the pixel-level leak checks
> locally.
> *Default: no Windows lane. T3 is specifically designed to be the local check,
> and it is the one that names the file.*

> **D8 — Where does `window_manager` configuration move?**
> `Skin.rootClaims.windowChrome` says the title bar is a skin decision. Today it
> is a one-time call in `main.dart`. Moving it means a skin change may need a
> window reconfiguration, and `flutter_acrylic` (for Fluent's Mica) is a new
> dependency.
> *Default: `main.dart` reads `windowChrome` and configures the window; a skin
> switch reconfigures it. Mica ships behind an experimental toggle defaulting
> off, because a transparent swapchain causes resize flicker (#249 §3.3).*

> **D9 — Does a skin switch need to preserve navigation state?**
> The root is `home: const AppShell()` (`main.dart:283`), not a router, and
> navigation lives in `navigationDestinationProvider`, so a skin change loses
> scroll offsets and uncommitted text and nothing else. But `go_router` is
> already a dependency, and if it is ever adopted the router instance must be
> hoisted into a provider **before** the skin picker ships, or a skin swap will
> reset the navigation stack.
> *Default: accept the ephemeral-state loss and document it; add a note to the
> go_router adoption issue so the ordering constraint is not discovered late.*

> **D10 — One issue, or a tracked epic?**
> `CLAUDE.md` requires one issue per commit and every commit wired to its issue.
> A 28-week, 4,400-site programme cannot be one issue.
> *Default: #249 becomes a tracking epic with one sub-issue per phase (P0–P8)
> and one per P3 sub-step, all on the board's three columns, with only the
> phase in flight in `In Progress`.*

---

## 8. Appendix — how to re-verify every number in this document

All counts are `grep -rF --include='*.dart' -o … lib | wc -l` at `master`
unless noted.

| Claim | Command |
|---|---|
| 300 Dart files in `lib/` | `find lib -name '*.dart' \| wc -l` |
| 178 import material | `grep -rl "package:flutter/material.dart" --include='*.dart' lib \| wc -l` |
| 1,340 `AppTheme.*` reads in 137 files | `grep -rhoE 'AppTheme\.[a-zA-Z0-9_]+' --include='*.dart' lib \| wc -l` |
| ≈32 arithmetic token reads in 16 files | `grep -rnoE '(AppTheme\.[a-zA-Z0-9_]+\s*[*+/-]\s*[0-9A-Za-z_.]+\|[0-9A-Za-z_.]+\s*[*+/-]\s*AppTheme\.[a-zA-Z0-9_]+)' --include='*.dart' lib` |
| 676 gap `SizedBox`es | `grep -rE "SizedBox\((width\|height): AppTheme\." --include='*.dart' lib \| wc -l` |
| 511 flex parents (239 `Column(` + 272 `Row(`) | two `grep -rF -o` counts |
| 917 Phosphor refs, 151 distinct glyphs | `grep -rhoE 'PhosphorIcons[A-Za-z]*\.[a-zA-Z0-9_]+' --include='*.dart' lib \| sed 's/.*\.//' \| sort -u \| wc -l` |
| 635 Material-named label constructions | `grep -rhoE '\b(Display\|Headline\|Title\|Body\|Label)(Large\|Medium\|Small)Label\(' --include='*.dart' lib \| wc -l` |
| 168 `Container(`, **0** `DecoratedBox(`, **0** `ColoredBox(` | three `grep -rF -o` counts — the measurement behind the allow-list decision |
| 26 structure-literal sites (3 `Positioned(` + 13 `ConstrainedBox(` + 10 `Stack(`) | three `grep -rF -o` counts |
| exactly 1 `extends CustomPainter` | `grep -rF -o 'extends CustomPainter' lib \| wc -l` |
| 65 register entries | `grep -c '^  - id:' docs/deviation_register.yaml` |
| 68 golden PNGs | `find test/conformance/goldens -name '*.png' \| wc -l` |
| 57 dialog cases | `grep -c 'DialogCase(' test/shared/dialogs/dialog_population.dart` |
| 850 test declarations in 113 files | `grep -rho "testWidgets(\\\|test(" --include='*_test.dart' test \| wc -l` |
| 49 of 123 test files pump their own `MaterialApp` | `grep -rl "MaterialApp(" --include='*.dart' test \| wc -l` |
| 25 lint rules | `ls lint_rules/flutter_gitui_lint/lib/src/lints/*.dart \| wc -l` |
| 3 screen scenes | `grep -oE "'screen_[a-z_]+'" test/conformance/goldens/screen_scenes.dart \| sort -u` |

SDK and package citations, all read directly from
`$FLUTTER/packages/flutter/lib` and `$PUB_CACHE/hosted/pub.dev`:

| Claim | Location |
|---|---|
| `Flex.spacing` exists | `src/widgets/basic.dart:5431` |
| `showGeneralDialog` in `widgets` | `src/widgets/routes.dart:2759` |
| `RawMenuAnchor` exported from `widgets.dart` | `widgets.dart:112` |
| `debugCreator` on `RenderObject` | `src/rendering/object.dart:2222` |
| `DebugCreator` | `src/widgets/framework.dart:7374` |
| `hitTestOnBinding` | `flutter_test/src/controller.dart:1903` |
| layer `toImage` capture | `flutter_test/src/_matchers_io.dart:34` |
| `takeScreenshot` is **not** in `flutter_test` | `grep -rn takeScreenshot flutter_test/lib` → no results |
| `_FluentTheme extends InheritedTheme` | `fluent_ui-4.16.1/lib/src/styles/theme.dart:85` |
| 31 Material re-exports | `fluent_ui-4.16.1/lib/fluent_ui.dart:1-32` |
| `NavigationView.titleBar`; `pane` XOR `content`; `paneBodyBuilder` | `…/navigation_view/view.dart:114, 123-126, 121` |
| `NavigationAppBar` does not exist | `grep -rn "class NavigationAppBar" fluent_ui-4.16.1` → no results |
| `PaneDisplayMode {top, expanded, compact, minimal, auto}` | `…/navigation_view/pane.dart:13,26,36,42,48,61` |
| `PaneItem.body` | `…/navigation_view/pane_items.dart:89` |
| `CommandBar.primaryItems` is `List<CommandBarItem>`; `CommandBarBuilderItem` wraps a `CommandBarItem` | `…/surfaces/commandbar.dart:136, 153, 522, 548-556` |
| no segmented control in `fluent_ui` | `grep -rln "SegmentedControl\|SegmentedButton" fluent_ui-4.16.1/lib` → no results |
| `_InheritedMacosTheme extends InheritedWidget` | `macos_ui-2.2.2/lib/src/theme/macos_theme.dart:121` |
| `MacosTheme.of` returns `MacosThemeData.fallback()` | `…/macos_theme.dart:45-49` |
| `MacosAlertDialog`: required `appIcon`, required `primaryButton`, optional `secondaryButton`, 260px pinned, returns Material `Dialog` | `…/dialogs/macos_alert_dialog.dart:37, 40, 41, 6, 135` |
| `showMacosAlertDialog` pushes a **private** `PopupRoute` with a `controlBackgroundColor`@0.6 barrier | `…/macos_alert_dialog.dart:253, 226-235` |
| `showMacosSheet` | `…/sheets/macos_sheet.dart:102` |
| `MaterialLocalizations.of` in 7 `macos_ui` files | `grep -rln "MaterialLocalizations.of" macos_ui-2.2.2/lib` |
| `MacosPulldownButton` asserts title XOR icon | `…/buttons/pulldown_button.dart:628-631` |
| `ToolBar.actions` is `List<ToolbarItem>?`; `ToolbarItem` is abstract; overflow is automatic | `…/layout/toolbar/toolbar.dart:114, 341, 286-300` |
| `SidebarItem.label` is a required `Widget` | `…/layout/sidebar/sidebar_item.dart:15, 35` |
| `MacosSegmentedControl` requires `List<MacosTab>` + `MacosTabController` | `…/buttons/segmented_control.dart:22-33` |
| `MacosWindowScope.toggleSidebar()` / `isSidebarShown` | `…/layout/window.dart:697, 688` |

---

## 9. What this document does not know

Stated so nobody mistakes an omission for an oversight.

1. **Nothing here has been compiled against the real application.** The package
   measurements are real and re-verified line by line, but they were taken by
   reading `fluent_ui-4.16.1` and `macos_ui-2.2.2` source, not by running the
   three chromes inside this application. The `macos_ui` probe (§5.0) is the
   gate that closes this before P0.
2. **`macos_ui` and `fluent_ui` co-resolution in this workspace is unverified.**
   `fluent_ui` provably resolves additively (`FINDINGS.md` §1.1); `macos_ui`
   does not yet have that evidence against these pins.
3. **Package churn is a standing tax that cannot be priced.** `fluent_ui`
   renamed `NavigationView.appBar` → `titleBar` and `PaneDisplayMode.open` →
   `expanded` between minor versions — that rename is exactly what invalidated
   one of the three submitted designs' shell mapping. `macos_ui` is community
   code tracking a moving Apple target, and `_InheritedMacosTheme` being a plain
   `InheritedWidget` is arguably a bug a future version fixes, in which case
   §2.8's guarantee becomes belt-and-braces rather than load-bearing. That is
   fine; a guarantee that stops being needed is not a cost.
4. **`Tone`, `TextRole`, `Proximity` and `IconRole` are hypotheses until
   ≈4,400 call sites vote on them.** They were derived from what the code does
   today — five spacing steps, the colour-scheme slots read ten or more times,
   sixteen label classes, 151 glyphs — but the mapping is not injective.
   `colorScheme.primary` means "emphasis", "the selection" and "the brand mark"
   in different places, and only a human can split those. The early warning
   signal is P3d's per-directory pull requests (§5.4).
5. **The `BlueprintOpaque` allowlist and the `structure_literal_budget` cap are
   process, not proof.** A leak wrapped in `BlueprintOpaque` is invisible to
   every check in this document, and no mechanism distinguishes a legitimate
   entry from a shortcut. Both are counted and shrink-only, and both need a
   review on a schedule.
