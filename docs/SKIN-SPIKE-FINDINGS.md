# Skin viability spike — findings

Throwaway measurement for **#249** (pluggable Material 3 / iOS Cupertino /
Fluent 2 skins), run as **Track C of #341**. It answers exactly one question
with running code:

> Can the `Base*` public signatures, **as they are written today**, drive the
> canonical widgets of all three design languages?

**Verdict: YELLOW.** Viable after a listed set of API changes. The list is in
§8, each change classified mechanical vs semantic, each blast radius counted by
an actual grep.

Environment: Flutter 3.44.4 (stable, rev ad70ec4617) / Dart 3.12.2, Windows 11.
`fluent_ui` 4.16.1. Every number below was produced by the code in this
directory against `master` @ `570a404`; nothing here is estimated.

---

## 1. The two day-one answers

Both were front-loaded before any component work, because either one changes
the architecture and the cost of the whole programme.

### 1.1 Does `fluent_ui` resolve at all, in this workspace, against this Flutter and Dart version? — **YES, cleanly.**

`fluent_ui 4.16.1` resolves as a member of the app's pub workspace
(`spike/skin_lab` added to the root `workspace:` list). The full lockfile diff
is **purely additive**:

```
+ fluent_ui        4.16.1
+ math_expressions 3.2.0     (transitive)
+ recase           4.1.0     (transitive)
+ scroll_pos       0.5.0     (transitive)
```

**No existing app dependency changed version.** That is the load-bearing part:
a workspace shares one version solve, so a `fluent_ui` constraint that fought
`intl`, `collection` or `material_color_utilities` would have downgraded the
app. It does not.

`test/day_one_risk_test.dart` asserts the package is not merely resolvable but
*linkable*: `FluentThemeData`, `FilledButton`, `ContentDialog`,
`NavigationView` and `TextBox` all compile and instantiate.

Three packaging notes for #249:

- **`fluent_ui` re-exports 31 symbols from `package:flutter/material.dart`**
  (`fluent_ui.dart:1-32`), among them `Brightness`, `ThemeMode`,
  `VisualDensity` and `ThemeExtension`. The `no_material_import` rule proposed
  in #249 §4 therefore cannot be enforced by import path alone inside the
  Fluent skin package — importing `fluent_ui` *is* importing part of Material.
- `fluent_ui` declares `uses-material-design: true`; a consumer that does not
  prints a warning on every run.
- The app cannot reach the spike: `analysis_options.yaml` keeps
  `depend_on_referenced_packages` at **error** (the #383 gate), so an import of
  `package:skin_lab` from `lib/` fails the blocking analyze step. Verified to
  still hold with a second workspace member present.

### 1.2 Do Fluent overlays work under a non-`FluentApp` root? — **YES, with one rule that belongs in the contract.**

This is the answer that decides the architecture. Had Fluent overlays required
a `FluentApp` root, the app root itself would have had to be swapped per skin
and the cost would have grown. They do not. Six measurements, all passing in
`test/day_one_risk_test.dart`:

| Probe | Result |
|---|---|
| A Fluent control under a `MaterialApp` root | Renders. |
| `fluent.showDialog` on a Material `Navigator` | Opens a real `ContentDialog`. |
| An ancestor `FluentTheme` reaching the route | **Survives.** `fluent.showDialog` calls `InheritedTheme.capture(from: callerContext, to: navigatorContext)` (`content_dialog.dart:241-244`) and `_FluentTheme extends InheritedTheme` (`styles/theme.dart:85`), so the caller's theme — including its brightness — arrives inside the route with no re-wrap. |
| No `FluentTheme` anywhere | Hard `FlutterError`: *"A FluentTheme widget is necessary to draw this layout."* There is no default fallback. |
| `FlyoutController.showFlyout` | **Does NOT capture.** Flyout content is hosted in the root `Overlay` without the capture, so the flyout builder must re-establish the theme itself. Asymmetric with dialogs. |
| `FluentLocalizations` | **Required.** `fluent.showDialog` runs `debugCheckHasFluentLocalizations` *before* it pushes anything. |

**What this changes for #249, concretely:**

1. `SkinOverlays` must re-establish the skin's theme inside **every** overlay
   builder unconditionally, rather than relying on `InheritedTheme.capture` —
   because dialogs capture and flyouts do not, and a contract that is right
   only half the time is a contract that will be got wrong.
2. `SkinChrome` needs a **`localizationsDelegates`** member, and the single app
   root must install the **union of every registered skin's** delegates. A skin
   is therefore *not* self-contained at the widget level; it has a legitimate
   claim on the app root. #249 §2.2 does not currently list this member.
3. Nothing else. One `MaterialApp` root, one `Navigator`, three skins — proven
   in `test/skin_coexistence_test.dart`.

---

## 2. What was built, and the rules it was built under

```
spike/skin_lab/
  lib/app_stubs.dart      stand-ins for app symbols (token VALUES copied verbatim)
  lib/skin.dart           the Skin contract — the measurement instrument
  lib/frozen/             the five components under test, frozen, each with its source SHA
  lib/skins/              material_skin.dart, cupertino_skin.dart, fluent_skin.dart
  lib/lab_app.dart        ONE MaterialApp, three SkinScopes side by side
  test/day_one_risk_test.dart       the two answers above
  test/skin_coexistence_test.dart   the RED criteria + the pinned findings
  probe/probe_a_context_menu.dart.txt   Probe A, with the real compiler output
```

Frozen sources. Each SHA was still the newest commit for that file at
`master` @ `570a404` when the spike finished, so no frozen copy is stale:

| Frozen copy | Source | SHA |
|---|---|---|
| `frozen_base_button.dart` | `lib/shared/components/base_button.dart` | `f9ca5b2820ca01f18bbb7734be88bb31a51bfdce` |
| `frozen_base_text_field.dart` | `lib/shared/components/base_text_field.dart` | `a078563e220d2fa458f7d6bfdce536e18e4c4080` |
| `frozen_base_dialog.dart` | `lib/shared/components/base_dialog.dart` | `09949eaf5942a045a59d20f5a4f23de6c4899f5c` |
| `frozen_base_filter_chip.dart` | `lib/shared/components/base_filter_chip.dart` | `19b162315ff8f75b93824b69ce712f15d90104ad` |
| `frozen_app_shell.dart` | `lib/core/navigation/app_shell.dart` | `7b7aca82efed558523b02e2a6b4bf3b9be8b0865` |

Rules held throughout:

- **Every skin delegates to that language's canonical widgets.** Nothing is
  hand-painted. Where delegation was impossible the spike stopped and recorded
  it rather than drawing a lookalike — see §5.
- The permitted edit to a frozen copy is a **one-line dispatch** to the skin,
  marked `// SKIN DISPATCH` and fenced with `// dart format off` so it stays
  one line. Everything else a skin forced is in §3.
- `lib/` was not touched. `pubspec.yaml`'s `workspace:` list and
  `analysis_options.yaml`'s `exclude:` list were, both as permitted.

---

## 3. Forced edits — the recorded, not-silently-made list

Every deviation from "one dispatch line and nothing else":

| # | Where | What was forced | Why it is a finding |
|---|---|---|---|
| F1 | `frozen_base_dialog.dart` | **TWO** dispatch lines, not one: `build()` for the surface *and* `static show()` for the route. | The dialog is the only component whose per-language behaviour is unreachable from the widget. Route type, barrier, transition, dismissal and the Cupertino/Fluent metrics are properties of the **route**. `SkinWidgets` cannot cover dialogs; `SkinOverlays` must own `show`. |
| F2 | `frozen_base_text_field.dart` | The dispatch carries a `TextFieldSlot` holding the State's private `_controller`, `_obscureText`, `_hasText`, `_clearText`, `_togglePasswordVisibility`. | `showClearButton`, `showPasswordToggle` and `initialValue` are *behaviours* whose realisation lives in private State. A skin either receives that state or re-implements it. The public signature alone is insufficient. |
| F3 | `frozen_base_button.dart` | `_MaterialBase` / `_baseOf` unprivated to `MaterialBase` / `baseOf`. | Only the Material skin reads it. Harmless, but it shows the variant-to-family mapping is a private implementation detail a skin package would need re-declared. |
| F4 | `frozen_base_filter_chip.dart` | `FrozenBaseChoiceChip.build` has **no dispatch line at all**; a new `FrozenChoiceChipGroup` was added instead. | A skin has *nothing to return* for one choice chip. See 4.6 — this is the pattern-vs-widget result. |
| F5 | `frozen_app_shell.dart` | Not a verbatim copy: a declared **structural reduction**. | `AppShell` takes **no parameters at all** (`const AppShell({super.key})`, `app_shell.dart:88-89`) and its 1418 lines read 14 Riverpod providers. The shell's composition is not a signature today, so the question is not even *askable* of it until one is extracted. The Material rendering reproduces `app_shell.dart:294-412` exactly. |
| F6 | `cupertino_skin.dart` | The `railExtended: false` state is **ignored**; the sidebar renders at a fixed 220 px. | `CupertinoListTile` hard-overflows below about 110 px ("A RenderFlex overflowed by 22 pixels on the right", reproduced at 88 px). A collapsed icon-only rail has no iOS counterpart; honouring the parameter would have meant hand-painting. |
| F7 | `lab_app.dart` | The dialog opener needs a `Builder` so its context sits below the `SkinScope`. | **Good news, recorded as such:** the skin resolves through the `context` that `BaseDialog.show(context:)` already takes. The route seam needs **no new argument** at any of the 14 `BaseDialog.show` call sites. |

---

## 4. Per-parameter classification

**EXACT** — the canonical widget takes it under the same meaning.
**ADAPTED** — expressible, through a different mechanism (composition, a style
override, a different constructor).
**LOSSY** — accepted, but part of its meaning is discarded.
**BLOCKED** — the canonical widget has nowhere to put it.

### 4.1 `BaseButton` — 9 parameters

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| `onPressed` | EXACT — `FilledButton.onPressed` | EXACT — `CupertinoButton.onPressed` | EXACT — `fluent.BaseButton.onPressed` |
| `label` | EXACT — the child `Text` | EXACT — the child `Text` | EXACT — the child `Text` |
| `variant` (7) | EXACT — 3 M3 families plus a colour each | ADAPTED — `.filled`/`.tinted`/plain; HIG has no `dangerSecondary` emphasis and `ghost` collapses onto `tertiary` | ADAPTED — `FilledButton`/`Button`/`HyperlinkButton`; `danger`/`success` are colour overrides, not named Fluent styles |
| `size` (3) | ADAPTED — M3 defines one size; `minimumSize` + `textStyle` + `iconSize` overrides | ADAPTED — `CupertinoButtonSize` exists but is 28/32/50, not our 32/40/48 | **LOSSY** — Fluent 2 has one control height (32 px) and no size scale; all three collapse |
| `leadingIcon` | EXACT | EXACT | EXACT |
| `trailingIcon` | ADAPTED — M3's `.icon` constructor is leading-only; a `Row` in the child | EXACT | EXACT |
| `isLoading` | ADAPTED — no M3 loading state; spinner in the child | ADAPTED — `CupertinoActivityIndicator`; HIG replaces the label, which the signature cannot say | ADAPTED — `fluent.ProgressRing` |
| `isDisabled` | EXACT | EXACT | EXACT |
| `fullWidth` | EXACT | EXACT | EXACT |

**Best case confirmed.** The recently rebuilt button is the strongest of the
five: **0 BLOCKED** across all three languages, 1 LOSSY. Its API is already
semantic — `variant` / `size` / `label` / `onPressed`, no colours, no paddings —
and that is exactly why it ports. Its 232 call sites need no change at all.

### 4.2 `BaseIconButton` — 7 parameters

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| `onPressed` | EXACT | EXACT | EXACT |
| `icon` | EXACT | EXACT | EXACT |
| `tooltip` | EXACT — `IconButton.tooltip` | **BLOCKED** — iOS has no tooltip and Flutter's cupertino library ships none. The string survives as `Semantics(label:)`; the hover-name behaviour does not exist | EXACT — `fluent.Tooltip` |
| `variant` | EXACT — standard / `.filled` / `.outlined` | ADAPTED | ADAPTED — Fluent has no outlined icon button |
| `size` | ADAPTED | ADAPTED | **LOSSY** — `IconButtonMode.small/large` only (24/32), no three-step scale |
| `isDisabled` | EXACT | EXACT | EXACT |
| `isSelected` | EXACT — native toggle plus semantics | **LOSSY** — no selected state on `CupertinoButton`; only the glyph can be recoloured, the toggle *semantics* are lost | ADAPTED — `fluent.ToggleButton`, a **different widget class**, switched on a nullable bool |

The same `tooltip` parameter scores EXACT in two languages and BLOCKED in one.
That is not a signature defect — it is an accepted per-language loss that
belongs in `docs/deviation_register.yaml`, not in an API change.

### 4.3 `BaseTextField` — 22 parameters

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| `controller` | EXACT | EXACT | EXACT |
| `initialValue` | EXACT | EXACT | EXACT |
| `focusNode` | EXACT | EXACT | EXACT |
| `label` | EXACT — `labelText` | **LOSSY** — a floating label has no Cupertino meaning; the HIG idiom is an inline leading label, i.e. the `prefix` slot | ADAPTED — `fluent.InfoLabel` header **above** the box; Fluent labels never float |
| `hintText` | EXACT | EXACT — `placeholder` | EXACT — `placeholder` |
| `helperText` | EXACT | **BLOCKED** — `CupertinoTextFormFieldRow` has no helper slot; `CupertinoFormRow` does but is not exposed, and dropping to it loses Form registration (`validator`) | **LOSSY** — no slot on `TextFormBox`; only stackable *around* the widget, i.e. composition rather than delegation |
| `errorText` | EXACT | ADAPTED — folded into the validator | ADAPTED — folded into the validator |
| `prefixIcon` | EXACT | **LOSSY** — shares the single `prefix` slot with `label`; a field with both cannot be expressed | EXACT — `prefix` |
| `suffixIcon` | EXACT | **BLOCKED** | EXACT — `suffix` |
| `onSuffixTap` | EXACT | **BLOCKED** | EXACT |
| `suffixTooltip` | EXACT | **BLOCKED** | EXACT |
| `variant` (3) | EXACT — the enum literally names `UnderlineInputBorder` / `OutlineInputBorder` | **LOSSY** — Cupertino has one field appearance; all three values collapse | **LOSSY** — Fluent has one TextBox appearance; all three collapse |
| `obscureText` | EXACT | EXACT | EXACT |
| `showClearButton` | EXACT | **BLOCKED** | EXACT |
| `showPasswordToggle` | EXACT | **BLOCKED** | EXACT |
| `maxLines` | EXACT | EXACT | EXACT |
| `onChanged` | EXACT | EXACT | EXACT |
| `onSubmitted` | EXACT | EXACT | EXACT |
| `validator` | EXACT | EXACT | EXACT |
| `autofocus` | EXACT | EXACT | EXACT |
| `enabled` | EXACT | EXACT | EXACT |
| `escapeClears` | EXACT | EXACT | EXACT |

**The Cupertino suffix cluster is the sharpest single result of this table.**
`CupertinoTextFormFieldRow` has `prefix` and **no `suffix` at all**
(`cupertino/text_form_field_row.dart:104-166`). Five public parameters —
`suffixIcon`, `onSuffixTap`, `suffixTooltip`, `showClearButton`,
`showPasswordToggle` — all target one missing slot. `CupertinoTextField` *does*
have `suffix`, but it is not a `FormField`, so choosing it trades away
`validator` and every dialog's `formKey.currentState!.validate()` contract.
Pinned by `test/skin_coexistence_test.dart` ("FINDING textField: Cupertino has
no suffix slot on the form row").

**The nuance that keeps this out of the RED tally:** the cluster is BLOCKED *by
the canonical widget*, not *by our signature*. The fix is Cupertino-skin
implementation work (compose `CupertinoFormRow` + `CupertinoTextField` with its
own FormField registration) plus a registered deviation — **no call-site
change**. Only `variant` needs an API change, and that one is mechanical.

### 4.4 `BaseDialog` — 8 parameters

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| `title` | EXACT | EXACT | EXACT |
| `content` | EXACT | EXACT | EXACT |
| `actions` | EXACT — `AlertDialog.actions` is `List<Widget>` too | **BLOCKED** | **BLOCKED** |
| `variant` (3) | ADAPTED — icon plus colour | **LOSSY** — HIG puts "destructive" on the **action** (`CupertinoDialogAction.isDestructiveAction`), unreachable through opaque actions | **LOSSY** — Fluent styles the affirmative **button**, likewise unreachable |
| `icon` | EXACT — M3 has an icon slot | **BLOCKED** — HIG alerts have no icon; no slot | **BLOCKED** — `ContentDialog` has no icon slot |
| `maxWidth` | ADAPTED — a `ConstrainedBox` | **BLOCKED** — `CupertinoAlertDialog` is hard-pinned to `_kCupertinoDialogWidth = 270` (`cupertino/dialog.dart:92,458-463`). Not a parameter, cannot be widened | EXACT — `ContentDialog.constraints` |
| `barrierDismissible` | EXACT | EXACT (Cupertino's own default is `false`, ours `true`) | EXACT (Fluent's own default is `false`) |
| `onSubmit` | ADAPTED — our own keyboard host | ADAPTED | ADAPTED (Fluent has `dismissWithEsc`) |

**`actions: List<Widget>` is the headline result of the whole spike.** Fluent 2
places the affirmative action on the **left** and the dismissive on the right,
both stretched to equal width. The skin sees only "two widgets" and cannot tell
which is affirmative, so:

- Blind reversal is wrong the moment a dialog has three actions — the update
  dialog does.
- Equal-width stretching would require re-styling a widget the skin cannot
  re-style.
- Cupertino needs `CupertinoDialogAction` children to get the alert's dividers,
  full-width stacking and default/destructive treatment; a `List<Widget>` of
  `BaseButton`s renders as foreign controls inside the alert.

Pinned by `test/skin_coexistence_test.dart` ("FINDING dialog.actions"), which
asserts the Fluent skin renders `[Cancel, Delete]` — Material's order, not
Fluent's — and fails if that ever silently changes. `maxWidth` is pinned by
"FINDING dialog.maxWidth": 270 px measured against a passed 650.

### 4.5 App shell — 9 composition parameters

The shell has **no signature at all** today; this table is against the
extracted composition (F5).

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| `destinations` | EXACT — `NavigationRailDestination` | ADAPTED — `CupertinoListSection.insetGrouped` plus `CupertinoListTile` | EXACT — `fluent.PaneItem(icon:, title:)` |
| `badgeCount` | EXACT — `Badge` | ADAPTED — `CupertinoListTile.additionalInfo` | EXACT — `PaneItem.infoBadge`, first-class |
| `selectedIndex` | EXACT | ADAPTED — no selection model beyond a background colour | EXACT — `NavigationPane.selected` |
| `onDestinationSelected` | EXACT | ADAPTED — per-tile `onTap` | EXACT — `NavigationPane.onChanged` |
| `railExtended` | EXACT | **BLOCKED** — iOS sidebars do not collapse to a rail, and the canonical row overflows at rail width (F6) | EXACT — `PaneDisplayMode.expanded` / `.compact` |
| `onToggleRailExtended` | ADAPTED — a trailing button | **BLOCKED** — no HIG affordance to bind to | **LOSSY** — `NavigationPane` owns its own `toggleButton`; binding ours would be two affordances for one job |
| `toolbar` (`Widget`) | EXACT | ADAPTED — `CupertinoNavigationBar` wants leading/middle/trailing, not one opaque Widget | **BLOCKED** — `NavigationView` dissolves the AppBar: chrome lives in the window `titleBar` and in a `CommandBar` *inside* the page, and `CommandBar` needs `List<CommandBarItem>`, which the signature does not carry |
| `body` | EXACT | EXACT | EXACT — `PaneItem.body` |
| `statusBar` | EXACT | ADAPTED — stacked | ADAPTED — stacked |

**The structural finding:** Flutter's cupertino library ships **no sidebar
widget**. The destination *list* delegates cleanly to `CupertinoListSection` /
`CupertinoListTile`; the sidebar *container* — the fixed-width, always-visible
column beside the content — has no counterpart. In `cupertino_skin.dart` it is
a raw `SizedBox` + `ColoredBox`, left visibly plain and labelled
`// NOT A CANONICAL WIDGET`. It is the one place in this spike where delegation
was impossible.

Fluent's `NavigationView` is the opposite problem: it is *more* capable than our
shell (built-in toggle, built-in badges, built-in display modes), and the
friction is that our shell hands it opaque `Widget`s where it wants structured
items.

### 4.6 `BaseFilterChip` (6) and `BaseChoiceChip` (4)

| Parameter | Material 3 | iOS Cupertino | Fluent 2 |
|---|---|---|---|
| **FilterChip** `label` | EXACT | EXACT | EXACT |
| `selected` | EXACT | ADAPTED — a tinted/plain `CupertinoButton` toggle | ADAPTED — `fluent.ToggleButton` |
| `onSelected` | EXACT | ADAPTED | ADAPTED |
| `icon` | EXACT | EXACT | EXACT |
| `count` | EXACT | EXACT | EXACT |
| `showCount` | EXACT | EXACT | EXACT |
| **ChoiceChip** `label` | EXACT | **BLOCKED** | **BLOCKED** |
| `selected` | EXACT | **BLOCKED** | **BLOCKED** |
| `onSelected` | EXACT | **BLOCKED** | **BLOCKED** |
| `icon` | EXACT | **BLOCKED** | **BLOCKED** |

**This is the component that answers "is the skinning unit the widget or the
pattern?", and for single choice the answer is: the pattern.**

A *single* choice chip has no counterpart in either language, so a per-widget
skin has literally nothing to return — `FrozenBaseChoiceChip` carries no
dispatch line at all, and that absence is the measurement (F4). Regrouped as a
**group**, the same information maps cleanly:

| | canonical widget |
|---|---|
| Material 3 | `SegmentedButton<T>` — EXACT |
| iOS Cupertino | `CupertinoSlidingSegmentedControl<T>` — **EXACT, 1:1** |
| Fluent 2 | `RadioGroup` + `fluent.RadioButton` — ADAPTED (fluent_ui 4.16.1 ships no segmented control) |

Multi-select filter chips do **not** need regrouping: a per-chip toggle maps to
a canonical toggle in every language. Only single choice does.

### 4.7 Totals

65 public parameters across the five components, times 3 languages = 195
classifications.

| Language | EXACT | ADAPTED | LOSSY | BLOCKED | LOSSY+BLOCKED |
|---|---:|---:|---:|---:|---:|
| Material 3 | 57 | 8 | 0 | 0 | **0 %** |
| iOS Cupertino | 26 | 18 | 5 | 16 | **32 %** |
| Fluent 2 | 45 | 13 | 6 | 7 | **20 %** |
| **All three** | **128** | **39** | **11** | **23** | **17 %** |

---

## 5. Where delegation was refused rather than faked

Recorded so nobody mistakes an omission for an oversight:

1. **The Cupertino sidebar container** (4.5). Rendered as a plain
   `SizedBox` + `ColoredBox` and labelled as not canonical.
2. **The Cupertino text-field suffix, helper line and variant borders** (4.3).
   No hand-built suffix row, no hand-drawn helper line, no hand-painted
   borders — each would have hidden a BLOCKED finding behind a lookalike.
3. **The Fluent action order** (4.4). The Fluent skin does **not**
   blind-reverse `actions`; it renders the wrong-for-Fluent order so the
   breakage is visible in the lab and pinned by a test.
4. **The Fluent button size scale** (4.1). Rendered at Fluent's single control
   height rather than forced to 32/40/48.

---

## 6. The three cheap probes

### Probe A — `List<PopupMenuEntry<dynamic>>` against the other two languages

Full transcript in `probe/probe_a_context_menu.dart.txt`. Subject:
`BaseListItem.contextMenuItems` (`base_list_item.dart:105`).

**Fluent — hard compile error, run for real:**

```
error - The argument type 'List<PopupMenuEntry<dynamic>>' can't be assigned to
        the parameter type 'List<MenuFlyoutItemBase>'.
        - argument_type_not_assignable
```

`MenuFlyoutItemBase` is not even a `Widget`, so no cast, adapter or covariance
gets from one to the other. Asserted at runtime in
`test/skin_coexistence_test.dart`.

**Cupertino — no compile error, which is worse:**

```
No issues found! (ran in 1.7s)
```

`CupertinoContextMenu.actions` is typed `List<Widget>` and `PopupMenuEntry`
**is** a Widget, so it compiles cleanly and then renders Material
`PopupMenuItem`s inside an iOS context menu: Material ink, Material typography,
Material 48 dp rows, none of the `CupertinoContextMenuAction`
divider/destructive/dismissal behaviour.

**The lesson generalises past this one parameter:** a `Widget`-typed parameter
is exactly what lets the wrong design language through the type system
unnoticed. A compile error is a bug you cannot ship; a Material widget silently
rendering inside a Cupertino menu is a spec violation that ships and looks
almost right. The replacement must therefore be a **data** type (label, icon,
callback, destructive flag, enabled flag, separator), never a Widget type. The
same reasoning applies to `BaseDialog.actions` and to the shell's `toolbar`.

### Probe B — raw `Color` / `EdgeInsets` / length parameters across the Base layer

**58 of 353 public fields (16 %)** in `lib/shared/components/` are raw visual
parameters — a `Color`, an `EdgeInsets`, a bare length, a `TextStyle` or a
`FontWeight`. Each one is a hole through which a call site can pin a value the
skin must then honour or ignore.

| Kind | Count | Concentration |
|---|---:|---|
| `Color?` | 31 | `base_label.dart` (16, one per typography role), `base_menu_item.dart` (7), `base_animated_widgets.dart` (6), `base_viewer_dialog.dart` (3), `base_card.dart` (2) |
| bare `double` length | 15 | `base_menu_item.dart` `iconSize`/`spacing` (6), `base_viewer_dialog.dart` `widthFactor`/`heightFactor`, `base_dialog.dart` `maxWidth`, `base_panel.dart` `elevation`, `base_shrinking_row.dart` (2), `base_badge.dart`, `base_animated_widgets.dart` (2), `country_flag.dart` (2) |
| `EdgeInsets(Geometry)` | 4 | `base_card.dart`, `base_list_item.dart`, `base_panel.dart` |
| `TextStyle?` / `FontWeight?` | 3 | `base_label.dart`, `base_menu_item.dart`, `copyable_text.dart` |

Two observations that matter more than the count:

- **The concentration is benign.** 16 of the 31 `Color?` fields are
  `base_label.dart`'s per-role override and 7 more are `base_menu_item.dart`'s;
  neither component is among the five under test and both are thin typography
  wrappers. The high-traffic components — `BaseButton` (232 sites),
  `BaseIconButton` (72), `BaseFilterChip` (11) — expose **zero** raw visual
  parameters. That is precisely why the button ported so well, and it is
  evidence that the Base layer is not uniformly Material-shaped.
- **`base_dialog.dart:111 maxWidth` is the one raw length that actually hurt**,
  because it is BLOCKED under Cupertino (4.4) and 15 call sites pass a value. A
  raw length is harmless right up until a language refuses it.

Also in the public API, though neither a colour nor a length: `IconData` on 13
public fields. `IconData` is language-neutral in Flutter (all three libraries
take it), so it is not a portability problem — but Phosphor glyphs are neither
Fluent's `WindowsIcons` nor Apple's SF Symbols, so icon *identity* is a
per-skin mapping question rather than a signature question.

### Probe C — `AppTheme.*` reads, shared layer vs features

| Location | `AppTheme.*` reads |
|---|---:|
| `lib/shared/components/` | **167** |
| `lib/features/` | **703** |
| `lib/` total | **1351** |

The ratio is **1 : 4.2** — for every token read inside the component layer there
are more than four outside it. That is the number #249 Phase 0 has to plan
against: making tokens per-skin is not a component-layer job, it is an app-wide
codemod, and the Base layer cannot shield the 703 reads in feature code.

The distribution is mercifully uniform: 88 % of all reads are `padding*` or
`radius*`, and there are only 15 distinct symbols in the component layer. A
mechanical `AppTheme.paddingS` to `context.tokens.spacing.s` codemod covers the
overwhelming majority.

---

## 7. Verdict: **YELLOW**

Viable after the API changes in section 8. Checked explicitly against each RED
trigger:

| RED trigger | Measured | Fires? |
|---|---|---|
| The skins cannot coexist in one running app | `test/skin_coexistence_test.dart` pumps ONE `MaterialApp` with three `SkinScope`s: `FilledButton` + `CupertinoButton` + `fluent.Button`, `SegmentedButton` + `CupertinoSlidingSegmentedControl` + `fluent.RadioButton`, `NavigationRail` + `CupertinoListSection` + `fluent.NavigationView` — all alive simultaneously. Each skin then opens **its own** canonical dialog (`AlertDialog`, `CupertinoAlertDialog`, `fluent.ContentDialog`) through the **single shared Navigator**. | **No** |
| Three or more of the five need pattern-level regrouping | Exactly **one**: single-choice chips (4.6). The dialog needs a parameter *type* change, not a regrouping. The shell needs a signature *extracted*, not its unit changed. The text field and both buttons are parameter-level throughout. | **No** |
| More than about a quarter of public parameters are BLOCKED/LOSSY **with fixes requiring semantic call-site migration** | 17 % of all classifications are BLOCKED/LOSSY (32 % in the worst language). But most BLOCKED entries need **no API change at all** — they are per-language losses to register as deviations (Cupertino tooltip, Cupertino dialog icon, Cupertino `maxWidth`, Fluent dialog icon) or skin-internal implementation work (the Cupertino suffix cluster). Parameters whose fix genuinely requires **semantic call-site migration**: `actions`, `contextMenuItems`, the choice-chip trio and the shell composition — **15 of 65 = 23 %**, and 82 % of that blast radius is one parameter. | **No** |

**What YELLOW rests on.** The `Base*` layer is *not* a Material transcript. The
components that were designed semantically — `BaseButton` (232 call sites,
0 BLOCKED in any language), `BaseIconButton`, `BaseFilterChip` — port to all
three languages with only accepted per-language losses. The friction is
concentrated in three identifiable decisions, each fixable before Track D
rebuilds anything:

1. **`Widget`-typed parameters where data was meant** — `actions`,
   `contextMenuItems`, the shell's `toolbar`. This single pattern is behind
   almost every BLOCKED cell that needs an API change.
2. **One enum that names Material implementation classes** —
   `TextFieldVariant`.
3. **One component whose unit is wrong** — single-choice chips.

**The counter-evidence that stops this being GREEN** is `BaseDialog.actions`:
82 `BaseDialog(` constructions across 55 files pass a `List<Widget>` that no
skin can reorder, restyle or classify, and Fluent's left-affirmative convention
makes that a spec violation rather than a cosmetic difference. That change alone
justifies running this spike before the dialog is rebuilt.

---

## 8. Required API changes, with blast radii

All counts are `grep -rF --include='*.dart'` over `lib/` at `master` @
`570a404`, re-verified in a clean worktree.

### R1 — `BaseDialog.actions`: `List<Widget>` to `List<DialogAction>` — **SEMANTIC**

*Blast radius: **82 constructions in 55 files** (`BaseDialog(`), plus 14
`BaseDialog.show` sites and 5 `showConfirmationDialog` / `showDestructiveDialog`
sites that build actions internally.*

```dart
class DialogAction {
  const DialogAction({
    required this.label,
    required this.onPressed,
    this.emphasis = ActionEmphasis.normal,  // affirmative | normal | dismissive
    this.isDestructive = false,
    this.enabled = true,
  });
}
```

Why semantic and not mechanical: every call site today writes
`BaseButton(label: ..., variant: ButtonVariant.tertiary, onPressed: () =>
Navigator.pop(context, false))` and must become `DialogAction(label: ...,
emphasis: ActionEmphasis.dismissive, onPressed: ...)`. The shape is regular
enough to codemod, but *which action is affirmative* is a judgement the codemod
cannot make — a human has to decide it in each of the 82 dialogs. That judgement
is exactly the information Fluent needs and today's API throws away.

One change unblocks: Fluent left-affirmative ordering, Fluent equal-width action
stretching, Cupertino `CupertinoDialogAction` conversion with its dividers and
full-width stacking, and the `DialogVariant.destructive` to
`isDestructiveAction` mapping that both non-Material languages express on the
action rather than on the dialog.

### R2 — `BaseListItem.contextMenuItems`: `List<PopupMenuEntry<dynamic>>` to `List<MenuAction>` — **SEMANTIC**

*Blast radius: **1 real call site** (`branch_list_tile.dart:125`) plus the
component. `BasePopupMenuButton.itemBuilder` shares the type and has about 3
further sites.*

Data, not widgets: `label`, `icon`, `onPressed`, `isDestructive`, `enabled`,
plus a `MenuSeparator` variant. Probe A is the argument: Fluent rejects the
current type at compile time and Cupertino accepts it and renders Material.

Trivial blast radius, high value — land it early, it is nearly free.

### R3 — `BaseChoiceChip` to `BaseChoiceGroup` — **SEMANTIC (pattern-level)**

*Blast radius: **1 call site** (`create_branch_dialog.dart:226`).*

```dart
BaseChoiceGroup<T>({
  required List<ChoiceOption<T>> options,
  required T selected,
  required ValueChanged<T> onSelected,
})
```

The only pattern-level regrouping the spike found. `BaseFilterChip` (11 sites)
stays exactly as it is — multi-select genuinely is per-chip.

### R4 — `TextFieldVariant` to semantic names — **MECHANICAL**

*Blast radius: **8 sites in 4 files**.*

`standard` / `outlined` / `filled` name `UnderlineInputBorder` /
`OutlineInputBorder`. Rename to intent — for example `minimal` / `bordered` /
`emphasized` — so a skin maps a meaning rather than a Material class. Pure
rename: no behaviour change, no judgement, codemoddable in full.

### R5 — Extract the app-shell composition into a signature — **SEMANTIC, single site**

*Blast radius: **1 site** (`AppShell` itself), but it is 1418 lines.*

`AppShell` takes no parameters, so its composition cannot be skinned at all
today (F5). Extract `destinations` / `selectedIndex` / `onDestinationSelected` /
`railExtended` / `onToggleRailExtended` / `toolbar` / `body` / `statusBar`, and
make `toolbar` **structured** (`List<ToolbarAction>` plus overflow) rather than
an opaque `Widget`, or Fluent's `CommandBar` stays permanently unreachable
(4.5).

### R6 — `SkinChrome.localizationsDelegates` — **NEW CONTRACT MEMBER, no call sites**

Required by the day-one probe (1.2): `fluent.showDialog` asserts
`FluentLocalizations` before it pushes. The single app root installs the union
of every registered skin's delegates.

### R7 — Split the dialog seam: `SkinWidgets.dialog` **and** `SkinOverlays.showDialog` — **NEW CONTRACT SHAPE, no call sites**

F1. Route, barrier, transition, dismissal and the per-language metrics are
properties of the route, not of the widget. `BaseDialog.show(context:)` already
carries the skin through its existing `context` parameter (F7), so **no call
site changes**.

### R8 — Give `BaseTextField`'s skin seam access to its own State — **MECHANICAL, no call sites**

F2. `showClearButton` / `showPasswordToggle` / `initialValue` are behaviours
realised in private State. Either hand the skin a small slot object (as the
spike does) or move the clear/reveal behaviour into the contract. Entirely
internal to the Base layer.

### Not API changes — register these as deviations instead

BLOCKED, but no signature change would help. They belong in
`docs/deviation_register.yaml` as accepted per-language losses:

| Item | Language | Note |
|---|---|---|
| `BaseIconButton.tooltip` | Cupertino | No tooltip in iOS or in Flutter's cupertino library. Keep the string as the accessible name. |
| `BaseDialog.icon` | Cupertino, Fluent | Neither language's alert has an icon slot. |
| `BaseDialog.maxWidth` | Cupertino | Hard-pinned at 270 pt in the SDK. |
| `BaseButton.size`, `BaseIconButton.size` | Fluent | Fluent 2 has one control height. |
| `railExtended` collapsed state | Cupertino | No collapsed-rail idiom, and the canonical row overflows at rail width. |
| Text-field suffix cluster | Cupertino | Skin-internal work (`CupertinoFormRow` + `CupertinoTextField` + FormField registration), not an API change. |

### Sequencing recommendation for #341

R2, R3 and R4 are cheap — about 10 call sites combined — so land them before
Track D starts. R1 is the expensive one (82 sites) and is exactly the change
that must happen **before** `BaseDialog` is rebuilt, or the highest-traffic
dialog component gets rewritten twice, which is the failure mode this spike
exists to prevent. R5 belongs with the Track E app-level keyboard work, since
both touch `app_shell.dart`. R6, R7 and R8 cost no call sites and can land with
the contract itself.

---

## 9. How to re-run this

```bash
cd spike/skin_lab
flutter analyze          # No issues found!
flutter test             # 15 tests, all passing
flutter run -d windows -t lib/lab_app.dart   # the three skins side by side
```

The app's own gates stay green. `spike/**` is excluded from the root
`analysis_options.yaml` (with the reason recorded there), because the spike
deliberately imports the raw Material, Cupertino and Fluent widget classes that
the design-system lint bans app-wide — delegating to those canonical widgets is
the experiment, so the bans would measure the wrong thing. Verified in an
isolated worktree at `570a404` with only this spike applied:

```
dart format --output=none --set-exit-if-changed .   Formatted 439 files (0 changed)
flutter analyze                                     No issues found!
dart run custom_lint --fatal-infos --fatal-warnings No issues found!
flutter test                                        +913: All tests passed!
```

Deleting `spike/`, the one `workspace:` entry in `pubspec.yaml` and the one
`exclude:` entry in `analysis_options.yaml` removes every trace of this spike,
including `fluent_ui` from the lockfile.
