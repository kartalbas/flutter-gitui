# The settled member list

The output of the three-way census demanded by **#419**, and the thing **P1**
(#409) builds. `docs/SKIN-CONTRACT.md` states the design; this document states
**what exists**. Where the two disagree, this one wins, because the contract
derived its members from one source and this one reconciles four.

The rule the whole list obeys is the contract's spine (`SKIN-CONTRACT.md:44-46`):

> No member returns a `Color`, a `double`, an `EdgeInsets`, a `TextStyle`, a
> `ShapeBorder`, a `Duration`, a `BoxDecoration` or an `IconData`. Every member
> returns a `Widget` or a `Route`.

Two members return neither, and both were already latitudes rather than new
ones: `overlays.notify` returned `void` before this census and now returns an
opaque dismissal handle, and `SkinRootClaims` (§2.9) carries its three declared
exceptions unchanged. Nothing else moved.

Every number below was measured on this repository at `master` with
`grep -rF --include='*.dart' -o … lib | wc -l` (302 Dart files), and every claim
about a design language was read out of the resolved package source under
`C:\Users\mkadm\AppData\Local\Pub\Cache\hosted\pub.dev\` or out of
`D:\bin\scoop\apps\flutter\current\packages\flutter\lib\src\material\`
(Flutter 3.44.4, rev `ad70ec4617`). Where a census's citation did not survive
re-reading, §11 says so.

---

## 1. The delta, stated as a number

The contract claims **45 members across 7 facets** (`SKIN-CONTRACT.md:995`).
Counted against the text of §2, the members that are actually *written* are:

| Facet | Written in §2 | Where |
|---|---:|---|
| `SkinChrome` | 4 | `wrapRoot`, `shell`, `screen` (§2.7:614-620) plus `dialogSurface`, which is **called** at `:841` and never declared |
| `SkinControls` | 11 | §2.4:465-476 |
| `SkinSurfaces` | 11 | §2.5:513-542 |
| `SkinType` | 3 | §2.6:576-593 |
| `SkinLayout` | 5 | §2.3:423-453 |
| `SkinOverlays` | 4 | §2.8:815-827 |
| `SkinMotion` | **0** | declared at §2.1:308, specified nowhere |
| | **38** | |

So the honest baseline is **38 specified members**, and the stated 45 already
counts seven `SkinMotion` members that were never written. That is not a
bookkeeping quibble: it is the largest single finding of the census, because a
facet with a name and no members is the one thing P1 cannot build.

**The settled list is 55 members across 7 facets.**

| | baseline | added | removed | settled |
|---|---:|---:|---:|---:|
| `SkinChrome` | 4 | 0 | 0 | **4** |
| `SkinControls` | 11 | 5 | 1 | **15** |
| `SkinSurfaces` | 11 | 9 | 1 | **19** |
| `SkinType` | 3 | 0 | 0 | **3** |
| `SkinLayout` | 5 | 3 | 0 | **8** |
| `SkinOverlays` | 4 | 0 | 0 | **4** |
| `SkinMotion` | 0 | 2 | 0 | **2** |
| **total** | **38** | **19** | **2** | **55** |

**The delta is +17 net: nineteen new members and two deletions.** Against the
document's stated 45 the difference is +10, but that comparison is against a
number that included seven members nobody had written, so the +17 is the figure
P1 should budget.

Beside the members, the settled list adds **eight slots to existing specs**
(`ScreenSpec.primaryActions`, `ScreenSpec.selectionBar`, `ShellSpec.activity`,
`ShellSpec.blocking`, `BannerSpec.actions`, `NoticeSpec.actions`,
`ListRowSpec.title`/`subtitle`, `FieldSpec.purpose`), **removes one**
(`ShellSpec.layers`), grows the closed vocabularies from **9 enums to 15**, and
changes one return type (`notify`).

---

## 2. `SkinChrome` — the frame

```dart
abstract interface class SkinChrome {
  Widget wrapRoot     (BuildContext c, {required Widget child, required SkinRequest request});
  Widget shell        (BuildContext c, ShellSpec s);
  Widget screen       (BuildContext c, ScreenSpec s);
  Widget dialogSurface(BuildContext c, DialogSpec s);          // REPAIR: was called, never declared
}
```

| Member | Status | Demanded by |
|---|---|---|
| `wrapRoot` | existing | floor (`app_theme.dart:64`), and mandatory for macOS — `MacosWindow` throws without a `MacosTheme` (`window.dart:181`) |
| `shell` | existing | floor (`app_shell.dart:294-682`), all three canons |
| `screen` | existing | floor (18 raw `Scaffold(`, 20 `AppBar(`, 8 files using `StandardAppBar`) |
| `dialogSurface` | **repair** | floor (82 `BaseDialog(`); the `SkinChrome` interface at §2.7 never declared the member §2.8:841 calls |

No new chrome members. Four things the censuses proposed as members are
**slots** instead, and §5 says why in each case: the screen's primary action,
the selection bar, the shell's activity line and the shell's blocking progress.

### `ScreenSpec` — settled here for the first time

`ScreenSpec` is named at `SKIN-CONTRACT.md:620` and defined nowhere, which is
why the Material census could not place the speed dial. It is:

```dart
final class ScreenSpec {
  const ScreenSpec({
    required this.title,
    required this.body,
    this.toolbar        = const <ToolbarGroup>[],
    this.primaryActions = const <ToolbarActionEntry>[],
    this.selectionBar,
    this.banner,
    this.footer,
  });
  final String title;
  final ContentPort body;

  /// The screen's own toolbar. Same type as `ShellSpec.toolbar`, for the same
  /// reason: two of three languages own overflow at the bar (§4.1).
  final List<ToolbarGroup> toolbar;

  /// What this screen is FOR. The skin decides where it goes — Material's FAB,
  /// Fluent's CommandBar primary item, macOS's ToolBar action. See §5.1.
  final List<ToolbarActionEntry> primaryActions;

  /// Non-null only while items are multi-selected. See §5.2.
  final SelectionBarSpec? selectionBar;

  final BannerSpec? banner;
  final ContentPort? footer;
}
```

### `ShellSpec` — three changes

`ShellSpec` keeps every field §2.7:640-686 gives it, plus:

```dart
  /// The window's own activity strip: a thin non-blocking indicator naming the
  /// running operation. Material draws a top-edge line, Fluent a page-top
  /// ProgressBar or an InfoBar, macOS a ProgressBar in the toolbar/status area.
  final ActivitySpec? activity;

  /// Non-null while an operation blocks the whole window. Material draws a
  /// scrim plus a card in the shell, Fluent pushes a ContentDialog with a
  /// ProgressRing, macOS pushes a MacosSheet. The skin decides route vs layer.
  final BlockingProgressSpec? blocking;
```

and **loses `layers`**. `final List<ContentPort> layers` (§2.7:685) was the
contract's one uncovered hole: a `ContentPort` is the legal Widget seam, so T3
resumes its walk inside it (§3.5) and every paint decision in
`progress_overlay.dart` — the `ModalBarrier` at `:111`, the
`LinearProgressIndicator(minHeight: 3)` at `:94-95`, the two at `minHeight: 8`
at `:140` and `:159` — is attributed to the application, correctly and
permanently. Every measured user of `layers` now has a named home
(`ShellSpec.blocking`, `ShellSpec.activity`, `ScreenSpec.selectionBar`,
`ScreenSpec.primaryActions`, `surfaces.dropTarget`), so the field is deleted and
a future full-screen overlay must ask for a member rather than smuggle itself
through a port.

---

## 3. `SkinControls` — things you operate

```dart
abstract interface class SkinControls {
  Widget button       (BuildContext c, ButtonSpec s);
  Widget iconButton   (BuildContext c, IconButtonSpec s);
  Widget textField    (BuildContext c, FieldSpec s, FieldHandles h);
  Widget dateField    (BuildContext c, DateFieldSpec s, FieldHandles h);      // NEW
  Widget suggestField<T>(BuildContext c, SuggestFieldSpec<T> s, FieldHandles h); // NEW
  Widget checkbox     (BuildContext c, ToggleSpec s);
  Widget toggle       (BuildContext c, ToggleSpec s);
  Widget toggleRow    (BuildContext c, ToggleRowSpec s);                      // NEW
  Widget slider       (BuildContext c, SliderSpec s);                         // NEW
  Widget dropdown<T>  (BuildContext c, DropdownSpec<T> s);
  Widget choiceGroup<T>(BuildContext c, ChoiceGroupSpec<T> s);
  Widget filterToggle (BuildContext c, FilterToggleSpec s);
  Widget seriesPicker (BuildContext c, SeriesPickerSpec s);                   // NEW
  Widget progress     (BuildContext c, {double? fraction, required ProgressExtent extent});
  Widget describedBy  (BuildContext c, {required String message, required ContentPort child});
  // DELETED: actionBar — see §6.7
}
```

| Member | Status | Demanded by | Canon it must reach |
|---|---|---|---|
| `button` | existing | floor, all three | `FilledButton` (`filled_button.dart:79`) / `fluent.Button` (`button.dart:78`) / `PushButton` (`push_button.dart:119`) |
| `iconButton` | existing | floor, all three | `IconButton` (`icon_button.dart:186`) / `fluent.IconButton` (`icon_button.dart:77`) / `MacosIconButton` (`icon_button.dart:6`) |
| `textField` | existing | floor, all three | `TextField` (`text_field.dart:204`) / `TextBox` (`text_box.dart:140`) / `MacosTextField` (`text_field.dart:238`) |
| `dateField` | **new** | floor + all three canons | `showDatePicker` (`date_picker.dart:196`) / `DatePicker` (`date_picker.dart:85`) / `MacosDatePicker` (`date_picker.dart:40`) |
| `suggestField<T>` | **new** | floor + Fluent + macOS canon | `DropdownMenu(enableFilter:)` (`dropdown_menu.dart:176,200`) / `AutoSuggestBox<T>` (`auto_suggest_box.dart:171`) / `MacosSearchField<T>` (`search_field.dart:12`) |
| `checkbox` | existing | floor, all three | `Checkbox` / `fluent.Checkbox` (`checkbox.dart:81`) / `MacosCheckbox` (`checkbox.dart:11`) |
| `toggle` | existing | floor, all three | `Switch` / `ToggleSwitch` (`toggle_switch.dart:80`) / `MacosSwitch` |
| `toggleRow` | **new** | floor (36 sites) + Fluent canon | `CheckboxListTile` (`checkbox_list_tile.dart:158`) / `Checkbox(content:)` (`checkbox.dart:88`) / composed |
| `slider` | **new** | floor + all three canons | `Slider` (`slider.dart:150`) / `fluent.Slider` (`slider.dart:72`) / `MacosSlider` (`slider.dart:24`) |
| `dropdown<T>` | existing | floor, all three | `DropdownButton` / `ComboBox<T>` / `MacosPopupButton<T>` |
| `choiceGroup<T>` | existing | floor (6 sites, §11) | `SegmentedButton<T>` (`segmented_button.dart:119`) / `RadioButton` group / `MacosSegmentedControl` |
| `filterToggle` | existing | floor (11 sites) | `FilterChip` / `ToggleButton` / **none** |
| `seriesPicker` | **new** | floor (`project_dialog.dart:126-150`) + `Tone.series` | **none in any language** — see §7.4 |
| `progress` | existing | floor, all three | `Linear`/`CircularProgressIndicator` (`progress_indicator.dart:414,863`) / `ProgressBar`/`ProgressRing` / `ProgressBar`/`ProgressCircle` |
| `describedBy` | existing | floor (11 raw `Tooltip(`) | `Tooltip` / `fluent.Tooltip` / `MacosTooltip` |

### The new control specs

```dart
/// The 36 labelled toggle rows: 26 `CheckboxListTile(` + 10 `SwitchListTile(`,
/// e.g. behavior_section.dart:27-33 and create_stash_dialog.dart:179.
enum ToggleKind { check, switching }

final class ToggleRowSpec {
  const ToggleRowSpec({
    required this.label, required this.value, required this.onChanged,
    this.kind = ToggleKind.check, this.description, this.leading,
    this.enabled = true,
  });
  final String label;
  final String? description;
  final IconRole? leading;
  final ToggleKind kind;
  final bool? value;                    // nullable: the tristate select-all
  final ValueChanged<bool?>? onChanged;
  final bool enabled;
}

/// clone_repository_dialog.dart:132 — shallow-clone depth, min 1, max 100.
final class SliderSpec {
  const SliderSpec({
    required this.value, required this.min, required this.max,
    required this.onChanged, this.divisions, this.valueLabel, this.onChangeEnd,
  });
  final double value, min, max;
  final int? divisions;
  final String? valueLabel;
  final ValueChanged<double>? onChanged, onChangeEnd;
}

/// base_date_field.dart:154 opens `showDatePicker` today; 5 BaseDateField sites.
/// `precision` exists so a time field extends the member instead of adding one.
enum DatePrecision { date, dateTime }

final class DateFieldSpec {
  const DateFieldSpec({
    required this.value, required this.onChanged, required this.label,
    this.first, this.last, this.hint, this.precision = DatePrecision.date,
    this.enabled = true,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final String? hint;
  final DateTime? first, last;
  final DatePrecision precision;
  final bool enabled;
}

/// searchable_dropdown.dart:9 and base_dropdown.dart:164 hand-build this today
/// out of a LayerLink, an OverlayEntry and a CompositedTransformFollower.
final class SuggestItem<T> {
  const SuggestItem({required this.value, required this.label, this.icon, this.detail});
  final T value;
  final String label;
  final String? detail;
  final IconRole? icon;
}

final class SuggestFieldSpec<T> {
  const SuggestFieldSpec({
    required this.label, required this.value, required this.items,
    required this.onSelected, this.onQueryChanged, this.hint,
    this.minQueryLength = 0, this.emptyLabel, this.enabled = true,
  });
  final String label;
  final T? value;
  final List<SuggestItem<T>> items;
  final ValueChanged<T> onSelected;
  final ValueChanged<String>? onQueryChanged;
  final String? hint, emptyLabel;
  final int minQueryLength;
  final bool enabled;
}

/// Choosing a workspace / project colour once `Tone.series` owns the palette
/// AND its length (§2.2:374-379). The application indexes; it cannot enumerate.
final class SeriesPickerSpec {
  const SeriesPickerSpec({required this.selectedIndex, required this.onSelected, this.label});
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final String? label;
}
```

### `FieldSpec` and `ToggleSpec` — settled, because both were undefined

`FieldSpec` is referenced at §2.4:467 and defined nowhere, which is the danger
the Material census named precisely: written as a rename of
`InputDecoration`'s slots it would be Material's field model wearing a neutral
name. It is written as this application's questions instead.

```dart
/// What kind of field this is — and it carries ONLY the values for which a
/// language reaches for a DIFFERENT canonical widget. See §6.3.
enum FieldPurpose { text, search, password }

final class FieldSpec {
  const FieldSpec({
    required this.label,
    this.purpose = FieldPurpose.text,
    this.hint, this.helper, this.error, this.validator,
    this.leading, this.suffix,
    this.maxLines = 1, this.enabled = true, this.autofocus = false,
    this.selectable = false,
    this.onChanged, this.onSubmitted,
  });
  final String label;
  final FieldPurpose purpose;
  final String? hint, helper, error;
  final FormFieldValidator<String>? validator;   // §5.0: the API package hosts it
  final IconRole? leading;
  final FieldAffordance? suffix;                 // the in-field action (CLAUDE.md)
  final int maxLines;
  final bool enabled, autofocus, selectable;
  final ValueChanged<String>? onChanged, onSubmitted;
}

/// `value` is `bool?`, not `bool`. Measured: the tristate is live at
/// base_animated_widgets.dart:161-181 (partial folder selection); Material
/// asserts `tristate || value != null`, Fluent's `checked` is `bool?`
/// (checkbox.dart:97), and macOS's `value` is `bool?` (checkbox.dart:29) while
/// its `onChanged` is `ValueChanged<bool>?` (:32) — a loss, registered in §8.
final class ToggleSpec {
  const ToggleSpec({required this.value, required this.onChanged,
                    this.label, this.enabled = true});
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;             // accessible name only; the visible row is toggleRow
  final bool enabled;
}
```

`ChoiceGroupSpec<T>`'s option type gains the two fields Material's
`ButtonSegment` carries and the application already depends on
(`segmented_button.dart:45-46`):

```dart
final class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label,
                      this.icon, this.tooltip, this.enabled = true});
  final T value;
  final String label;
  final IconRole? icon;
  final String? tooltip;      // browse_screen.dart:320-330 labels segments 'Aa', '*', '.*'
  final bool enabled;
}
```

Without `tooltip` the search-mode switch in `browse_screen.dart` is
unreadable, and CLAUDE.md makes a tooltip on a glyph-only control
non-negotiable, so the member as previously specified could not render a live
screen correctly.

---

## 4. `SkinSurfaces` — things that hold other things

```dart
abstract interface class SkinSurfaces {
  Widget card          (BuildContext c, CardSpec s);
  Widget panel         (BuildContext c, PanelSpec s);
  Widget disclosure    (BuildContext c, DisclosureSpec s);        // NEW
  Widget listRow       (BuildContext c, ListRowSpec s);
  Widget tree          (BuildContext c, TreeSpec s);              // NEW (replaces treeRow)
  Widget tabs          (BuildContext c, TabSetSpec s);            // NEW
  Widget dataGrid      (BuildContext c, DataGridSpec s);          // NEW
  Widget pressable     (BuildContext c, PressableSpec s);         // NEW
  Widget badge         (BuildContext c, BadgeSpec s);
  Widget tag           (BuildContext c, TagSpec s);               // NEW
  Widget avatar        (BuildContext c, AvatarSpec s);            // NEW
  Widget banner        (BuildContext c, BannerSpec s);
  Widget emptyState    (BuildContext c, EmptyStateSpec s);
  Widget dropTarget    (BuildContext c, DropTargetSpec s);        // NEW
  Widget codeLine      (BuildContext c, CodeLineSpec s);
  Widget codeBlock     (BuildContext c, CodeBlockSpec s);         // NEW
  Widget commitGraphRow(BuildContext c, GraphRowSpec s);
  Widget markdown      (BuildContext c, MarkdownSpec s);
  Widget imageViewer   (BuildContext c, ImageViewerSpec s);
  // DELETED: treeRow — see §6.1
}
```

| Member | Status | Demanded by | Canon |
|---|---|---|---|
| `card` | existing | floor (16 `BaseCard`) | `Card` (`card.dart:73`) / `fluent.Card` / composed |
| `panel` | existing | floor (`base_panel.dart:119-235`) | composed in all three |
| `disclosure` | **new** | floor (3 `ExpansionTile(` + `settings_section.dart:41-47,121` + `command_log_panel.dart`) | `ExpansionTile` (`expansion_tile.dart:117`) / `Expander` (`expander.dart:96`) / **affordance only** (`disclosure_button.dart:6`) |
| `listRow` | existing | floor (40 sites) | `ListTile` (`list_tile.dart:385`) / `fluent.ListTile` / `MacosListTile` (`macos_list_tile.dart:6`) |
| `tree` | **new** | floor (3 tree surfaces) + Fluent arity | **none** / `TreeView` (`tree_view.dart:865`) / **none** |
| `tabs` | **new** | floor (2 `TabBar(` + 2 `TabBarView(`) + all three canons | `TabBar`/`TabBarView` (`tabs.dart:989,2213`) / `TabView` (`tab_view.dart:63`) / `MacosTabView` (`tab_view.dart:37`) |
| `dataGrid` | **new** | floor (`csv_viewer_dialog.dart:111`) | `DataTable` (`data_table.dart:446`) / **none** / **none** |
| `pressable` | **new** | floor (20 `InkWell(`) + CLAUDE.md state-layer rule | `InkWell` (`ink_well.dart:1509`) / `HoverButton` (`hover_button.dart:40`) / composed |
| `badge` | existing | floor | `Badge` (`badge.dart:40`) / `InfoBadge` (`info_badge.dart:23`) / **none** |
| `tag` | **new** | floor (3 removable pills, `tags_active_filters.dart`) | `Chip` (`chip.dart:687`) / **none** / **none** |
| `avatar` | **new** | floor (2 `CircleAvatar(`) | `CircleAvatar` / **none** / **none** |
| `banner` | existing | floor (3 banners) | `MaterialBanner` (`banner.dart:100`) / `InfoBar` (`info_bar.dart:209`) / **none** |
| `emptyState` | existing | floor (`empty_state.dart:80-202`) | composed in all three |
| `dropTarget` | **new** | floor (`repositories_screen.dart:368-402`) | **none in any language** |
| `codeLine` | existing | floor (`base_diff_viewer.dart:254-360`) | composed in all three |
| `codeBlock` | **new** | floor (14 `SelectableText(` in 11 files) | `SelectableText` (`selectable_text.dart:148`) / read-only `TextBox` / read-only `MacosTextField` |
| `commitGraphRow` | existing | floor (the only `extends CustomPainter`, verified: 1) | painter in all three |
| `markdown` | existing | floor (2 sites) | third-party in all three |
| `imageViewer` | existing | floor (1 site) | third-party in all three |

### The new surface specs

```dart
/// A header that reveals a body. NOT the same unit as `panel`: a settings
/// section (settings_section.dart:121), a log entry (command_log_panel.dart:255)
/// and a stash row (stash_list_tile.dart:58) all expand, and none is a panel.
final class DisclosureSpec {
  const DisclosureSpec({
    required this.header, required this.body,
    required this.expanded, required this.onExpandedChanged,
    this.leading, this.trailing, this.enabled = true,
  });
  final ContentPort header, body;
  final bool expanded, enabled;
  final ValueChanged<bool> onExpandedChanged;
  final ContentPort? trailing;
  final IconRole? leading;
}

/// The WHOLE tree. Arity N, forced by §4.3's own rule: Fluent's canonical
/// answer covers N of our rows at once (tree_view.dart:865-874, over
/// TreeViewItem :121 and TreeViewController :610). Expansion and selection are
/// carried as APPLICATION-owned data; the Fluent skin creates and drives its
/// own controller from them, exactly as the macOS gate proved for
/// MacosTabController (SKIN-CONTRACT.md:1574-1576). The roving-highlight
/// keyboard contract stays wrapped AROUND the member's return.
final class TreeNodeSpec {
  const TreeNodeSpec({
    required this.id, required this.content,
    this.children = const <TreeNodeSpec>[],
    this.leading, this.trailing, this.badgeCount,
    this.checked, this.menu = const <MenuEntry>[],
  });
  final Object id;
  final ContentPort content;
  final List<TreeNodeSpec> children;
  final IconRole? leading;
  final ContentPort? trailing;
  final int? badgeCount;
  final bool? checked;                    // the tri-state folder checkbox
  final List<MenuEntry> menu;
}

final class TreeSpec {
  const TreeSpec({
    required this.roots, required this.expanded, required this.selected,
    required this.onToggleExpanded, required this.onSelect,
    this.onActivate, this.onCheck, this.onContextMenu,
    this.containerFocused = true,
  });
  final List<TreeNodeSpec> roots;
  final Set<Object> expanded, selected;
  final ValueChanged<Object> onToggleExpanded, onSelect;
  final ValueChanged<Object>? onActivate;
  final void Function(Object id, bool? value)? onCheck;
  final void Function(Object id, Offset at)? onContextMenu;
  /// Selection and container focus are two independent facts and the PAIR
  /// decides what is drawn — base_tree_item.dart:34-40 documents the rule.
  final bool containerFocused;
}

/// The whole tab view, not the strip. Arity is forced: MacosTabView asserts
/// `controller.length == children.length && controller.length == tabs.length`
/// (tab_view.dart:47-50) and Fluent's TabView owns its bodies too. See §6.2.
final class TabEntry {
  const TabEntry({required this.label, required this.body, this.icon, this.badgeCount});
  final String label;
  final IconRole? icon;
  final int? badgeCount;
  final ContentPort Function() body;      // a BUILDER, for the same reason ShellDestination.body is
}

final class TabSetSpec {
  const TabSetSpec({required this.tabs, required this.selectedIndex, required this.onSelect});
  final List<TabEntry> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
}

/// csv_viewer_dialog.dart:111-123. No sort: the floor does not sort, and
/// members are derived from need. See §6.6.
enum GridDensity { compact, normal, roomy }

final class DataGridSpec {
  const DataGridSpec({required this.columns, required this.rows,
                      this.density = GridDensity.normal});
  final List<String> columns;
  final List<List<ContentPort>> rows;
  final GridDensity density;
}

/// An arbitrary region that is tappable AND wears the language's own hover /
/// focus / press state layer. T3's allow-list admits GestureDetector and
/// MouseRegion, which give a tap target with NO state layer at all, and
/// CLAUDE.md makes a state layer non-negotiable. The child is a ContentPort,
/// so T3 resumes inside it and this member cannot become an escape hatch.
final class PressableSpec {
  const PressableSpec({
    required this.child, this.onTap, this.onDoubleTap, this.onContextMenu,
    this.selected = false, this.enabled = true, this.tooltip, this.semanticsLabel,
  });
  final ContentPort child;
  final VoidCallback? onTap, onDoubleTap;
  final ValueChanged<Offset>? onContextMenu;
  final bool selected, enabled;
  final String? tooltip, semanticsLabel;
}

/// A labelled pill the user can remove. Split out of `badge` because Material's
/// two widgets do not overlap: `Badge` (badge.dart:40) has no delete and no
/// tap, and `Chip` (chip.dart:687) carries `onDeleted` :697, `deleteIcon` :696
/// and `deleteButtonTooltipMessage` :699 — the tooltip CLAUDE.md requires and
/// BadgeSpec has no slot for. See §6.5.
final class TagSpec {
  const TagSpec({required this.label, this.icon, this.tone = Tone.neutral,
                 this.onRemoved, this.removeTooltip, this.onTap});
  final String label;
  final IconRole? icon;
  final Tone tone;
  final VoidCallback? onRemoved, onTap;
  final String? removeTooltip;
}

/// The circular identity mark: file_blame_panel.dart:196 (author monogram) and
/// stash_list_tile.dart:61 (a glyph in a circle). See §6.8 for why "fold it
/// into the leading ContentPort" was rejected.
final class AvatarSpec {
  const AvatarSpec({this.monogram, this.glyph, this.tone = Tone.neutral,
                    this.scale = ControlScale.normal, this.semanticsLabel})
      : assert(monogram != null || glyph != null);
  final String? monogram;
  final IconRole? glyph;
  final Tone tone;
  final ControlScale scale;
  final String? semanticsLabel;
}

/// The tinted wash and callout shown while files are dragged over a screen.
/// repositories_screen.dart:368-402 decides a primary@0.1 wash, a
/// primaryContainer callout, a 2px border and a 64px glyph — five paint
/// decisions in a screen, lighting up T1, T3 and T5 at once.
final class DropTargetSpec {
  const DropTargetSpec({required this.child, required this.active,
                        required this.icon, required this.label});
  final ContentPort child;
  final bool active;
  final IconRole icon;
  final String label;
}

/// A whole block of read-only, user-selectable, monospaced output: git stdout,
/// a command-log entry, a blame line, a commit message body.
final class CodeBlockSpec {
  const CodeBlockSpec({required this.text, this.tone = Tone.neutral,
                       this.selectable = true, this.wrap = false, this.maxLines});
  final String text;
  final Tone tone;
  final bool selectable, wrap;
  final int? maxLines;
}
```

### `ListRowSpec` — two changes

```dart
final class ListRowSpec {
  const ListRowSpec({
    required this.title,            // WAS: `content`, one opaque ContentPort
    this.subtitle,                  // NEW
    this.leading, this.trailing,
    this.badgeCount,
    this.menu = const <MenuEntry>[],
    this.selection = RowSelection.none,
    this.containerFocused = true,   // NEW
    this.onTap, this.onActivate, this.onContextMenu,
  });
  final ContentPort title;
  final ContentPort? subtitle;
  /* … unchanged … */
  final bool containerFocused;
}
```

All three languages keep title and subtitle apart with separate type roles —
`ListTile.title`/`subtitle` (`list_tile.dart:385ff`), `fluent.ListTile`'s pair,
`MacosListTile.title`/`subtitle` (`macos_list_tile.dart:11-15`). With one
opaque `content` port the Material skin can only fill `title:`, so every
two-line row in the application would build its own column and choose its own
type roles — application code deciding typography, which is the exact leak the
contract exists to stop. There is no `overline`: Material's `ListTile` has no
such slot and no floor row uses one.

`containerFocused` exists because `RowSelection { none, primary, multi }`
cannot express the pair of facts a roving-highlight list has. The rule is
already written down at `base_tree_item.dart:34-40`: *while it is focused the
selected row wears a focus ring on top of its tinted background, and while
focus lives elsewhere the muted tinted background remains alone.* One enum
cannot say that; without the flag the existing keyboard behaviour becomes
invisible under every skin, which is a keyboard regression and the contract
treats keyboard behaviour as untouchable structure.

### `BannerSpec` — settled, and it must carry actions

```dart
final class NoticeAction {
  const NoticeAction({required this.label, required this.tooltip,
                      required this.onPressed, this.icon});
  final String label, tooltip;
  final IconRole? icon;
  final VoidCallback onPressed;
}

final class BannerSpec {
  const BannerSpec({required this.tone, required this.title, this.body,
                    this.icon, this.actions = const <NoticeAction>[], this.onDismiss});
  final Tone tone;                    // neutral | info | warning | danger | success
  final String title;
  final String? body;
  final IconRole? icon;
  final List<NoticeAction> actions;
  final VoidCallback? onDismiss;
}
```

`MaterialBanner` declares `required this.actions` (`banner.dart:105-108`) and
asserts the list is non-empty. A `BannerSpec` carrying only a tone and a
message therefore makes it impossible for the Material skin to call its own
canonical widget at all — hand-painting imposed by the contract, at exactly the
point the contract exists to prevent it. `Tone`'s five values map 1:1 onto
`InfoBarSeverity { info, warning, error, success }` (`info_bar.dart:106`) plus
neutral, and Fluent's `InfoBar` takes `action` and `onClose`
(`info_bar.dart:213,218`), so the same spec drives both. The
missing-settings warning at `app_shell.dart:582-659` is precisely the banner
that wants an "Open settings" action.

---

## 5. `SkinType`, `SkinLayout`, `SkinOverlays`, `SkinMotion`

### `SkinType` — three members, one addition to two of them

```dart
abstract interface class SkinType {
  Widget text(BuildContext c, String value, {
    required TextRole role, Tone tone = Tone.neutral,
    int? maxLines, TextAlign? align, bool softWrap = true,
    bool selectable = false,                              // NEW
    String? semanticsLabel,
  });
  Widget icon(BuildContext c, IconRole role, {
    Tone tone = Tone.neutral, ControlScale scale = ControlScale.normal,
    String? semanticsLabel,
  });
  Widget runs(BuildContext c, List<TextRun> runs, {
    required TextRole role, bool selectable = false,      // NEW
  });
}
```

Without `selectable`, a Git UI's hashes, paths, authors and CSV cells stop
being copyable the moment the contract lands — a functional regression, not an
appearance one, at 14 measured `SelectableText(` sites across 11 files. The
whole-block cases move to `surfaces.codeBlock`; the one-value cases stay here.
No `selectionScope` member: see §6.4.

### `SkinLayout` — five existing, three new

```dart
abstract interface class SkinLayout {
  Widget column      (BuildContext c, List<Widget> children, {…});
  Widget row         (BuildContext c, List<Widget> children, {…, bool wrap = false});
  Widget grid        (BuildContext c, GridSpec s);                 // NEW
  Widget splitPane   (BuildContext c, SplitPaneSpec s);            // NEW
  Widget propertyList(BuildContext c, PropertyListSpec s);         // NEW
  Widget inset       (BuildContext c, Widget child, {…});
  Widget separator   (BuildContext c, {Axis axis = Axis.horizontal, Inset indent = Inset.none});
  Widget gap         (BuildContext c, Proximity proximity);
}

/// repositories_screen.dart:510-517 and workspaces_screen.dart:166.
/// `onColumnsChanged` is the one place a member reports STRUCTURE back to the
/// application: the keyboard controller needs `crossAxisCount` for vertical
/// arrows to move by whole rows, and today the screen re-implements the
/// delegate's own formula to get it (repositories_screen.dart:502-508). Once
/// the skin owns the geometry the application cannot compute it, so the member
/// must report it. It carries no design value — it is a count of columns.
final class GridSpec {
  const GridSpec({required this.children, this.density = GridDensity.normal,
                  this.onColumnsChanged});
  final List<Widget> children;
  final GridDensity density;
  final ValueChanged<int>? onColumnsChanged;
}

/// browse_screen.dart:195-228 hand-builds an 8px MouseRegion strip with
/// SystemMouseCursors.resizeColumn, an inner 1px Container and a clamp between
/// _minTreeViewWidth and _maxTreeViewWidth. The stored fraction is USER STATE
/// and crosses the seam the same way ShellSpec.selectedIndex does; the handle's
/// width, hit slop, cursor, hairline and clamp are all the skin's.
enum PaneSide { leading, trailing }

final class SplitPaneSpec {
  const SplitPaneSpec({
    required this.primary, required this.secondary, required this.axis,
    required this.fraction, required this.resizableSide, this.onFractionChanged,
  });
  final ContentPort primary, secondary;
  final Axis axis;
  final double fraction;
  final PaneSide resizableSide;         // macOS ResizablePane requires it (resizable_pane.dart:44)
  final ValueChanged<double>? onFractionChanged;
}

/// Label/value pairs whose label column sizes to the longest label.
/// file_blame_panel.dart:450-478 builds a Table with IntrinsicColumnWidth +
/// FlexColumnWidth, and its own doc comment records WHY a fixed width cannot
/// work: the same labels are longer in every other locale. The alignment is a
/// property of the SET, which is why the member is at arity N.
final class PropertyRow {
  const PropertyRow({required this.label, required this.value});
  final String label;                   // WITHOUT the colon — the colon is typography
  final ContentPort value;
}

final class PropertyListSpec {
  const PropertyListSpec({required this.rows});
  final List<PropertyRow> rows;
}
```

### `SkinOverlays` — four members, one return type changed

```dart
abstract interface class SkinOverlays {
  Future<T?> presentDialog<T>(BuildContext c, DialogSpec s, SkinContentHost host);
  Future<int?> presentMenu(BuildContext c, {required Offset at,
                           required List<MenuEntry> entries, required SkinEnvelope e});
  Future<T?> presentPopover<T>(BuildContext c, PopoverSpec s, SkinContentHost host);

  /// WAS: `void notify(…)`. A void return discards the handle
  /// `ScaffoldMessengerState.showSnackBar` already gives back
  /// (scaffold.dart:314), so nothing could dismiss or replace a notice — and
  /// notification_service.dart calls `clearSnackBars()` at :20, :47, :109, :136
  /// and `hideCurrentSnackBar()` at :95 and :184 to stop a never-dismissing
  /// error notice queueing behind another. `void` was a regression against
  /// shipped behaviour, not a future need.
  NoticeHandle notify(BuildContext c, NoticeSpec s, SkinEnvelope e);
}

enum NoticeLifetime { brief, persistent }

final class NoticeSpec {
  const NoticeSpec({required this.tone, required this.title, this.body, this.icon,
                    this.actions = const <NoticeAction>[],
                    this.lifetime = NoticeLifetime.brief});
  final Tone tone;
  final String title;
  final String? body;
  final IconRole? icon;
  final List<NoticeAction> actions;
  final NoticeLifetime lifetime;
}

/// Opaque. Carries no design value; the ONLY things it can do are the two the
/// application already does today.
abstract interface class NoticeHandle {
  void dismiss();
  bool get isShowing;
}
```

`NoticeSpec.actions` and `NoticeLifetime.persistent` are not #418 speculation:
`notification_service.dart:89` sets `duration: const Duration(days: 365) //
Never auto-dismiss` and `:91` attaches a `SnackBarAction`, beside an inline
copy button and an inline open-logs button. Material supports all of it —
`action` (`snack_bar.dart:286`), `persist` (`:291`, resolved at `:303`),
`duration` (`:290`) — and so does Fluent's `InfoBar`. Without these fields the
error notice loses its actions and its lifetime at the moment the contract
lands.

`MenuEntry`'s sealed set gains two variants. `base_menu_item.dart:27-99` has
only `MenuSeparator` and `MenuAction`, while the application renders checked
entries (`MenuItemContentWithCheck`, 3 sites) and hand-styled section headers
(`quick_settings_menu.dart:31-40` builds a disabled `PopupMenuItem` holding a
`LabelSmallLabel` in `onSurfaceVariant`). Both shapes stay application-painted
unless the sealed set carries them:

```dart
final class MenuCheckable extends MenuEntry { /* label, icon, checked, onChanged, enabled */ }
final class MenuSection   extends MenuEntry { /* label */ }
```

### `SkinMotion` — two members, and the honest floor

```dart
abstract interface class SkinMotion {
  /// Something appears or disappears in place.
  Widget reveal(BuildContext c, {required ContentPort child, required bool visible,
                MotionRole role = MotionRole.feedback});

  /// One thing replaces another in the same position.
  Widget swap(BuildContext c, {required ContentPort child, required Object stateKey,
              MotionRole role = MotionRole.transition});
}
```

Two members, not the seven the stated count of 45 implied, and the reason is a
measurement rather than a preference. The whole of `lib/` contains **one**
`AnimationController(` (`settings_section.dart:41`), **one**
`AnimatedRotation(` (`base_speed_dial.dart:202`), **one** `AnimatedCrossFade(`
(`settings_section.dart:133`), **zero** `AnimatedSwitcher(`, **zero**
`AnimatedSize(`, and exactly **one** read of a motion value as a value
(`branches_screen.dart:74`, `final animDuration = context.standardAnimation`).
Every one of those sites is inside a component that becomes a member of this
list: the rotation and the cross-fade become `surfaces.disclosure`, the speed
dial's rotation becomes `chrome.screen`'s primary actions, the duration read
becomes `surfaces.tabs`. The two remaining reads of `AnimationSpeedExtension`
(`base_animated_widgets.dart:87-100`, `base_switcher.dart:39-52`) are in `Base*`
components that move bodily into the Material skin at P2.

So after this list lands, the measured application-owned motion is **zero
sites**, and the facet exists for the case that has no other legal home: the
spine rule bans a `Duration`-typed read, `SkinRequest.animationScale` is
consumed by the skin and not by the application, and there is no third option.
Two members cost the blueprint about twenty lines and close the facet; the
alternative considered and rejected was deleting `SkinMotion` from `Skin`
altogether, which loses the moment one screen wants a fade — and reopening the
contract for it is the failure #419 exists to prevent.

---

## 6. The conflicts, decided

Where two censuses proposed different answers to the same need, this is the
decision and the loser's reasoning.

### 6.1 `tree` at arity N replaces `treeRow`; `treeRow` is deleted

All four censuses agree the member must exist at the tree. They disagree about
whether `treeRow` survives beside it: the app-floor census keeps it "for the
flat single-row uses", the Material census keeps it "only if a use is proved".

**Decided: deleted.** No such use exists. `BaseTreeItem` is constructed at
exactly two sites, `file_tree_view.dart:784` and
`git_status_tree_view.dart:408`, both inside a tree. Two members for one job is
a defect by this repository's own rules, and a per-row member left standing is
the one a migrating screen will reach for.

The objection the censuses did not raise and this decision has to answer: if
the member owns the whole collection, does it also own the roving keyboard
focus and the multi-selection, which §2.8:860-864 assigns to the application?
No. `TreeSpec` carries `expanded`, `selected` and their callbacks as
application-owned data, and the Fluent skin constructs and drives its own
`TreeViewController` (`tree_view.dart:610`) from them — the same trick the
macOS gate already proved legal for `MacosTabController`
(`SKIN-CONTRACT.md:1574-1576`), and only possible because a renderer may return
a `StatefulWidget`. `BaseFocusRegion` and `KeyboardNavigableTreeView` stay in
application code and wrap **around** the member's return, exactly as they wrap
around `chrome.shell`.

### 6.2 `tabs` covers the bodies, sits on `SkinSurfaces`, and is one member

Four proposals: `SkinChrome.tabs` with bodies (app-floor), `SkinSurfaces.tabs`
with bodies (Material), `SkinControls.tabStrip` **without** bodies (Fluent),
`SkinSurfaces.tabView` with bodies (macOS).

**Decided: `SkinSurfaces.tabs(TabSetSpec)`, bodies included.**

The strip-only proposal loses on a measurement rather than on taste:
`MacosTabView` asserts
`controller.length == children.length && controller.length == tabs.length`
(`tab_view.dart:47-50`) — it *owns* its children — and Fluent's `TabView`
(`tab_view.dart:63`) owns its bodies, its close affordances and its overflow
together. A strip-only member makes the canonical widget of two of the three
languages unreachable, and §4.3's own rule ("if any language's canonical answer
covers N of our units at once, the member moves up to N") then forces the
member up.

`SkinChrome` loses because chrome is "the frame: root, shell, screens"
(§2.1:303-309) and one of the two floor sites is inside a dialog
(`select_hosted_repository_dialog.dart:158`), which is not a frame. `tabView`
loses as a name because it is macOS's class name.

### 6.3 Search: `FieldPurpose` **and** `suggestField`, but not `DropdownSpec.filterable`

Three proposals, and two of them are right about different things.

**Decided: `FieldPurpose { text, search, password }` on `FieldSpec`, plus a
separate `suggestField<T>` member. `DropdownSpec.filterable` is rejected.**

They answer different questions. `FieldPurpose.search` says *this field is a
search box*, which changes which canonical widget the skin reaches for —
`MacosSearchField` (`search_field.dart:12`), Material's `SearchBar`
(`search_anchor.dart:1404`) — while its result list stays application structure
(`inline_search_field.dart`, `command_palette.dart`: the filtering, the ranking
and the keyboard roving are behaviour). `suggestField<T>` says *this control
filters a closed list and returns one of its items*, which is one canonical
widget in two languages (`AutoSuggestBox<T>` at `auto_suggest_box.dart:171`,
`MacosSearchField<T>` with its `results`) and a third in Material
(`DropdownMenu` with `enableFilter` at `dropdown_menu.dart:200`). That is not
two affordances for one job; it is two jobs.

`DropdownSpec.filterable` loses because a filterable dropdown is a *different
canonical widget class* from a plain one in all three languages — `ComboBox`
versus `AutoSuggestBox`, `MacosPopupButton` versus `MacosSearchField`,
`DropdownButton` (`dropdown.dart:975`) versus `DropdownMenu`. A boolean that
switches which class a skin instantiates is exactly the compound the contract
split when it turned seven-value `ButtonVariant` into `Emphasis × Tone`
(§2.4:497-501).

`FieldPurpose`'s value set is also decided against both proposals. The Material
census proposed six (`text, search, password, multiline, path, number`) and the
macOS census two (`freeText, search`). **Decided: three.** A purpose value earns
its place only where a language reaches for a different canonical widget:
`search` does (three different widgets), `password` does (Fluent has a distinct
`PasswordBox`), and `text` is the default. `multiline` and `path` do not — they
are already expressed by `maxLines` and by the in-field suffix affordance — and
a purpose value that duplicates an existing parameter is a second name for the
same thing. `number` is dropped because the floor has no numeric field at all
and neither Fluent's `NumberBox` nor a macOS stepper has a counterpart in the
other two.

### 6.4 Selectable text: a flag plus `codeBlock`, not a `selectionScope` member

The app-floor census proposed `surfaces.codeBlock` plus a flag; the Material
census proposed the flag on three members plus `SkinType.selectionScope`.

**Decided: `surfaces.codeBlock` as a member, `selectable` on `type.text` and
`type.runs`, and no `selectionScope`.**

`selectionScope` loses because `SelectableRegion` is exported from
`package:flutter/widgets.dart` and selectability is *behaviour* — what the user
can do — which §2.11 and §1's Zero Test both keep in application reach. The
only design in it is the selection toolbar, and each skin already supplies that
inside its own field and text implementations via `contextMenuBuilder`. A
separate scope member would therefore be a second way to ask for the same thing
the flag already asks for. The blueprint's answer is decision D4
(`SKIN-CONTRACT.md:1907-1916`) unchanged: no selection toolbar, registered as a
blueprint-only deviation.

`codeBlock` survives as its own member because the block cases carry a fill, a
radius and a monospace family that a flag on `text` cannot express, and because
`codeLine` is per-line and a 200-line git output is not 200 members' worth of
work.

### 6.5 `badge` splits into `badge` and `tag`

The app-floor census read `BaseBadge`'s four shapes as one member's job; the
Material census proposed the split.

**Decided: split.** The argument is Material's own parameter sets, which do not
overlap: `Badge` (`badge.dart:40`) is a count or a dot with `label`,
`isLabelVisible` and a `Badge.count` constructor, and has neither a delete nor a
tap; the removable pill is `Chip` (`chip.dart:687`) with `onDeleted` (`:697`),
`deleteIcon` (`:696`) and `deleteButtonTooltipMessage` (`:699`). One member
cannot map onto both without carrying every field of each. The
tooltip is the decider: CLAUDE.md makes it non-negotiable on an icon-only
control, Material supplies it on the chip and not on the badge, and `BadgeSpec`
has no slot for it — so the three live removable pills in
`tags_active_filters.dart` would ship a close icon with no accessible name.

### 6.6 `dataGrid`, without sorting

Both censuses that raised it proposed the member; they differed on the name and
on whether the spec carries sorting.

**Decided: `surfaces.dataGrid(DataGridSpec)`, no sort.** `dataTable` loses as a
name because `DataTable` is Material's class (`data_table.dart:446`) and this
is already the census's clearest Material-only member — naming it after
Material's widget would make that worse. Sorting loses because the floor does
not sort: `csv_viewer_dialog.dart`'s `_buildColumns()` constructs `DataColumn`s
with a label and nothing else, and members are derived from need in at least one
source, not from a package's full parameter list.

### 6.7 `controls.actionBar` is deleted

**Decided: deleted.** §4.3:1464-1465 already settled that the arity of a
toolbar is the bar and that no `toolbarButton` member exists, because two of
three languages own overflow at the bar (`CommandBar.primaryItems` is
`List<CommandBarItem>` at `commandbar.dart:136`; `ToolBar.actions` is
`List<ToolbarItem>?` at `toolbar.dart:114` and grows its own
`ToolbarOverflowButton`). A bar belongs to a frame, and both frames now carry
one: `ShellSpec.toolbar` and `ScreenSpec.toolbar`, both `List<ToolbarGroup>`.
`actionBar` is a third way to ask for the same thing.

The measurement: `OverflowActionBar` has exactly **two** construction sites in
the whole application, `app_shell.dart:517` and `:548`, and both become
`ShellSpec.toolbar` at P5. The eight files using `StandardAppBar` become
`ScreenSpec.toolbar`. Nothing else in `lib/` builds a toolbar. If a
non-frame toolbar ever appears — a panel header with overflow — `PanelSpec`
grows a `toolbar` field, which is a slot on an existing member rather than a
new one.

### 6.8 `avatar` is a member, against the Material census's exclusion

The Material census excluded it: two sites, no counterpart in either package, so
both should become `type.icon` inside the row's leading `ContentPort`.

**Decided: it is a member.** The exclusion's own resolution is illegal under
§2.10, which states that the skin "POSITIONS and CONSTRAINS" a `ContentPort`
and "must never style it". If the monogram at `file_blame_panel.dart:196` goes
into a leading port, the circle, its diameter and its fill/foreground pairing
have to be drawn by the application, because the skin is forbidden from adding
them. That is the leak, not the fix. The same argument the Material census
itself accepts for `dataGrid` and the app-floor census for `dropTarget` —
absent the member, Material's answer is imposed on the other two forever, and
composing it is only *their* decision if the member exists — applies here
unchanged. Two sites is a small member, and a small member is cheaper than a
permanent deviation.

### 6.9 Four proposed members are slots instead

| Proposed as | Settled as | Why the member lost |
|---|---|---|
| `SkinControls.floatingActions` (app-floor) | `ScreenSpec.primaryActions` | Neither package ships a FAB (verified: `grep -rl FloatingActionButton` over both `lib` trees returns nothing), so a `floatingActions` member would be Material's answer under a neutral name — §10's exact failure. "What are this screen's primary actions" is a question all three answer: Fluent with a `CommandBar` primary item (`commandbar.dart:595`), macOS with a `ToolBar` item (`toolbar.dart:114`). The speed dial's drag and its expansion become Material-skin-internal; Escape-to-collapse is behaviour and stays. |
| `SkinChrome.selectionBar` (app-floor) | `ScreenSpec.selectionBar` | A member lets a screen mount the bar anywhere, which returns *placement* to the application — and placement is precisely where the three languages diverge (Material a contextual bottom bar, Fluent a `CommandBar` plus an `InfoBar`, macOS a bottom `ToolBar`). A nullable slot states the fact ("N items are selected, here are the batch actions") and lets the skin place it. |
| `SkinChrome.activityLine` (app-floor) | `ShellSpec.activity` | Same argument, one level up: the strip spans the shell and never enters the content flow, so a member would let a screen put it somewhere the language does not. |
| `SkinOverlays.presentBlockingProgress` (app-floor) | `ShellSpec.blocking` | A route forces the application to hold a handle and to have already decided that blocking progress *is* a route — which is the decision the three languages make differently (Material an in-shell scrim, Fluent a `ContentDialog` with a `ProgressRing`, macOS a `MacosSheet` at `macos_sheet.dart:102`). The application is already declarative here: the overlay is driven by a provider. A nullable slot matches what the application already knows and lets the skin choose route versus layer. |

```dart
final class ActivitySpec {
  const ActivitySpec({required this.operation, this.currentStep, this.totalSteps,
                      this.indeterminate = true, this.onShowDetail});
  final String operation;
  final int? currentStep, totalSteps;
  final bool indeterminate;
  final VoidCallback? onShowDetail;
}

final class BlockingProgressSpec {
  const BlockingProgressSpec({required this.operation, this.fraction,
                              this.currentStep, this.totalSteps, this.detail});
  final String operation;
  final double? fraction;               // null = indeterminate
  final int? currentStep, totalSteps;
  final String? detail;
}

final class SelectionBarSpec {
  const SelectionBarSpec({required this.selectedCount, required this.onClear,
                          required this.actions});
  final int selectedCount;
  final VoidCallback onClear;
  final List<ToolbarGroup> actions;
}
```

### 6.10 The persistent notification surface (#418) is spec work, not a new member

The Fluent census proposed `SkinSurfaces.notice(NoticeSurfaceSpec)`; the
Material census proposed `SkinOverlays.noticeHost(NoticeQueue)` mounted as a
shell layer.

**Decided: no new member. `BannerSpec` and `NoticeSpec` are settled with
actions, a tone and a lifetime, and `notify` returns a handle.**

`surfaces.notice` loses because `surfaces.banner` already *is* the in-page
persistent notice, and adding a second member beside it is two members for one
job. `noticeHost(NoticeQueue)` loses harder: it makes the queue an
application-visible object, but the application has never owned a queue —
`ScaffoldMessenger` owns it under Material, `displayInfoBar` under Fluent, and
under macOS there is no queue at all because the notice goes to the shell status
area (`macos_ui` ships no toast, no snackbar, no InfoBar and no banner:
verified, `grep "class .*\(Badge\|InfoBar\|Toast\|Snack\|Banner\)"` over the
whole package returns nothing). Making the queue crossable would put
presentation policy back in `lib/`. A handle is the minimum that restores what
`notification_service.dart` does today and nothing more.

### 6.11 `disclosure`, not `expander`

Both names come from a language: `Expander` is Fluent's class
(`expander.dart:96`), `ExpansionTile` is Material's (`expansion_tile.dart:117`),
`MacosDisclosureButton` is macOS's (`disclosure_button.dart:6`). **Decided:
`disclosure`**, because it is also the platform-neutral behavioural term
(HTML's `<details>`, ARIA's disclosure pattern), whereas `expander` reads as
Fluent's answer imported into the contract — the same objection C3 makes about
`IconData`.

---

## 7. The one-language members, named as such

A member only one language can delegate to is not automatically wrong. It is
wrong only if it is unjustified, and if the other skins have no stated answer.
These are all of them.

### 7.1 `surfaces.dataGrid` — Material only

Canonical in Material (`DataTable`, `data_table.dart:446`). Verified absent
from both other packages: `grep "class .*\(DataTable\|DataGrid\|Grid\)"` over
`fluent_ui-4.16.1/lib` and `macos_ui-2.2.2/lib` returns only
`_DayPickerGridDelegate`, a private date-picker helper.

*Justification:* one live surface renders a table (`csv_viewer_dialog.dart:111`)
and after P6's `no_design_language_import` it cannot name `DataTable`. Without
the member the CSV viewer either keeps a registered Material import — which
weakens the ban at the point the ban is the proof — or hand-builds a grid with
its own column widths, dividers and header treatment, which is measured layout
and belongs on the skin's side of the line.

*The other skins' answer:* both compose from their own rows and separators
(Fluent from `ListTile` plus `Divider`, macOS from `MacosListTile` plus the
theme's `dividerColor`). That composition is legal because numbers are legal
inside a skin, and it is only *their* decision because the member exists.

### 7.2 `surfaces.tree` — Fluent only, at arity N

Canonical in Fluent alone (`TreeView`, `tree_view.dart:865`). Material's
`TreeSliver` lives in `widgets/sliver_tree.dart`, i.e. on the structure side of
the line, and `macos_ui` ships no tree at all — its sidebar's
`SidebarItem.disclosureItems` is navigation, not a content tree.

*Justification:* §4.3's own rule mandates it. This is the clearest case in the
whole contract of Material's arity having been mistaken for a neutral one.

*The other skins' answer:* both compose the tree out of rows internally, which
is exactly what the application does today at `file_tree_view.dart:784` and
`git_status_tree_view.dart:408` — so the member costs them nothing they were
not already going to write, and it costs the Fluent skin the difference between
delegating and imitating.

### 7.3 `layout.splitPane` and `layout.propertyList` — macOS only

`ResizablePane` (`resizable_pane.dart:32`) is canonical in macOS and absent
from the other two (`grep "class .*Split"` over `fluent_ui` returns only
`SplitButton`, an unrelated control). It is standalone: its source reads only
`MacosTheme.of` and `MediaQuery.of`, so it does not require `MacosScaffold`,
although `MacosScaffold` asserts its children are `ContentArea` or
`ResizablePane` (`scaffold.dart:58-62`) and that is where it normally lives.

`Label` (`labels/label.dart:9`) is canonical in macOS at arity 1 — it takes
`icon`, `text` and `child`, where `child` is documented as "the widget at the
right of `text`", i.e. it *is* a label/value pair. No language has one at arity
N, and arity N is what the application needs because the alignment across rows
is a property of the set.

*The other skins' answer:* Material and Fluent implement both in-package, where
lengths are legal. For `splitPane` that is the divider's width, its hit slop and
its clamp; for `propertyList` it is the label column's intrinsic width.

### 7.4 Four members no language has canon for

`surfaces.avatar`, `surfaces.dropTarget`, `layout.grid` and
`controls.seriesPicker`. All four are verified absent everywhere: no
`class .*Avatar` in either package, no drop-target affordance in any of the
three, no canonical card grid in any of the three, and no series picker — macOS
has `MacosColorWell` (`color_well.dart:58`) and Fluent has an HSV `ColorPicker`,
but both are *free* colour pickers, which would move a `Color` across the seam
and are therefore explicitly not this member.

*Justification, and it is the same one four times:* the absence of a
counterpart is the argument **for** the member, not against it. With no member,
Material's answer — a circle at a chosen diameter, a `primary@0.1` wash with a
2px border, `maxCrossAxisExtent: 320` with `childAspectRatio: 1.2`, a swatch
grid over `WorkspaceColors.defaults` — is drawn identically under all four
skins forever, and every one of those numbers sits in a feature file where T1,
T3 and T5 all report it.

`seriesPicker` is the one of the four the application cannot even work around.
Once `Tone.series` owns the palette **and its length** (§2.2:374-379),
`WorkspaceColors.defaults` (`workspace.dart:124`) is deleted and
`project_dialog.dart:130` has nothing left to iterate. There is no legal way for
the application to know how many swatches exist.

### 7.5 Members one language cannot honour at all

Recorded here because "this skin returns nothing" is a decision the application
must survive, and in each case it does not have to, because each skin has a
stated substitute.

| Member | The language with no canon | What that skin does instead |
|---|---|---|
| `controls.filterToggle` | macOS — no chip, no multi-select toggle | `PushButton(secondary:)` per item (`push_button.dart:132`), registered deviation, not a lookalike |
| `surfaces.badge` | macOS — `grep "class .*Badge"` returns nothing | composed capsule inside the skin |
| `surfaces.banner` | macOS — no banner component | a shell-level strip; the actions in `BannerSpec` are what makes that possible |
| `overlays.notify` | macOS — no toast idiom of any kind | the shell status area (`SKIN-CONTRACT.md:823-826`), and `NoticeSpec.actions` is what lets the status area render it |
| `surfaces.tag` | Fluent and macOS — neither ships a chip | a small surface plus an icon button, composed |
| `surfaces.disclosure` | macOS ships only the **affordance** — `MacosDisclosureButton` is a chevron button with `fillColor`/`semanticLabel`/`isPressed`/`mouseCursor`/`onPressed` and no header or content slot (`disclosure_button.dart:6-16`) | composes header + chevron + body around it |
| `chrome.screen`'s `primaryActions` | Fluent and macOS — no FAB | `CommandBar` primary item / `ToolBar` action |
| `motion.reveal`, `motion.swap` | macOS — `MacosThemeData` carries no `Duration` at all (verified: no `Duration` in `macos_theme.dart`) | system-default motion, registered |

---

## 8. What every language must lose, in one place

This is each skin's deviation register **before** the skin is written. Each row
is a member, the loss, and the measurement behind it. Material's column is empty
almost everywhere by construction — the contract was derived from Material — and
that asymmetry is itself the finding.

### 8.1 Material 3

| Member | Loss | Evidence |
|---|---|---|
| `controls.button` | Five M3 button families collapse onto four `Emphasis` values; `elevated` and `filled-tonal` share `Emphasis.secondary` | `filled_button.dart:79`, `outlined_button.dart:73`, `text_button.dart:81`, `elevated_button.dart:69` against §2.2:360 |
| `controls.choiceGroup` | `SegmentedButton.multiSelectionEnabled` unreachable: multi-select routes to per-item `filterToggle` because arity is 1 in all three | `segmented_button.dart:139`, `SKIN-CONTRACT.md:1461-1463` |
| `controls.describedBy` | `Tooltip.richMessage` and `triggerMode` unreachable through a plain `String` | `tooltip.dart` |
| `surfaces.card` | Filled-versus-outlined containment is not expressible if `CardSpec` carries only `Elevation` — and that distinction is what Fluent and macOS lean on | `card.dart:73`, `Card.filled`, `Card.outlined` |
| `chrome.shell` | `NavigationRailLabelType`'s third axis is folded into the Material skin's own answer to `NavigationDensity.condensed` | `navigation_rail.dart:1082-1094` |
| `surfaces.tree` | Material has no tree component, so it composes rows — the same code it writes today | `sliver_tree.dart` is in `widgets/`, not `material/` |
| `motion.*` | The generated `Durations.short1…extralong4` and `Easing.emphasized*` ramps are collapsed onto four `MotionRole` values | `motion.dart:21-148`, `:159-232` |

### 8.2 Fluent 2 (`fluent_ui` 4.16.1)

| Member | Loss | Evidence |
|---|---|---|
| `controls.button`, `controls.iconButton` | `ControlScale`'s three steps collapse: Fluent 2 has one control height, and `IconButtonMode` is `small`/`large` only | `FINDINGS.md` §4.1 (the spike's only LOSSY button parameter), `icon_button.dart:6` |
| `controls.choiceGroup` | No segmented control exists in 4.16.1 — the group renders as `RadioButton`s | verified: `grep -rln "SegmentedControl\|SegmentedButton" fluent_ui-4.16.1/lib` → nothing |
| `controls.filterToggle` | maps to `ToggleButton`, which is a button, not a chip — no count affix | `toggle_button.dart:10` |
| `controls.textField` | `FieldSpec.helper` has no slot on `TextBox`; it must be composed. `FormRow` (`form_row.dart:14`) now offers `helper` and `error` around a child, which *upgrades* the spike's LOSSY rating to ADAPTED — see §11 | `text_box.dart:140`, `FINDINGS.md` §4.3 |
| `surfaces.tag` | No chip in the package; composed from a surface plus an icon button | verified: `grep "class .*Chip"` → nothing |
| `surfaces.avatar`, `surfaces.dataGrid` | No canon; composed | verified absent |
| `chrome.dialogSurface` | `DialogSpec.icon` has no slot on `ContentDialog`; actions are stretched to equal width whether the application wanted that or not | `content_dialog.dart:151` wraps every action in `Expanded` |
| `chrome.shell` | `ShellSpec.density` is deliberately left null: `NavigationPane` ships its own toggle, and two affordances for one job is a defect | `pane.dart:93,138`; conflict C6 |
| `layout.splitPane` | No canon; the divider is drawn in-package | verified: only `SplitButton` matches `class .*Split` |
| `overlays.presentPopover` | Flyouts do **not** capture inherited themes — the only `InheritedTheme.capture` in the whole flyouts directory is `content_dialog.dart:246` — so the skin must re-establish the theme through `SkinContentHost` on every popover | `FINDINGS.md` §1.2 |
| `motion.*` | Four theme durations plus one curve (`fasterAnimationDuration` :306, `fastAnimationDuration` :311, `mediumAnimationDuration` :316, `slowAnimationDuration` :321, `animationCurve` :326) map onto four `MotionRole` values — a near-fit, but not the same partition | `styles/theme.dart:306-326` |

### 8.3 macOS (`macos_ui` 2.2.2)

macOS loses the most, and the reason is structural rather than accidental:
`macos_ui` is a thin package over AppKit conventions and simply does not ship
several component families.

| Member | Loss | Evidence |
|---|---|---|
| `controls.checkbox` | The mixed state can be **displayed** but never **emitted**: `value` is `bool?` but `onChanged` is `ValueChanged<bool>?` | `buttons/checkbox.dart:29,32` |
| `controls.toggleRow` | `MacosCheckbox` has no label parameter at all — the whole row is composed by the skin | `buttons/checkbox.dart:15-25` |
| `controls.filterToggle` | No counterpart of any kind | `SKIN-CONTRACT.md:1577-1579` |
| `controls.slider` | No value label, and ticks are a `splits` count rather than `divisions` — `SliderSpec.valueLabel` and `divisions` are both approximations | `indicators/slider.dart:26-41` |
| `controls.progress` | `ProgressBar.value` is **required**: there is no indeterminate bar, so `ProgressExtent.block` with a null fraction falls back to the spinner | `indicators/progress_indicators.dart:155-158` |
| `controls.button` | `PushButton` has no loading state and no label slot; `ControlSize.mini` is deliberately unreachable because `ControlScale` stays three coarse values | `buttons/push_button.dart:119-132`, `enums/control_size.dart:13-25` |
| `surfaces.listRow` | `MacosListTile` has **no trailing slot**, no badge and no selection visual — `trailing`, `badgeCount` and `selection` are all composed by the skin | `layout/macos_list_tile.dart:8-17` |
| `surfaces.badge`, `surfaces.banner`, `surfaces.tag`, `surfaces.avatar`, `surfaces.dataGrid`, `surfaces.tree`, `overlays.notify` | No canon for any of them | verified: no `Badge`/`InfoBar`/`Toast`/`Snack`/`Banner`/`Avatar`/`Chip`/`DataTable`/tree class in the package |
| `surfaces.disclosure` | Only the chevron button exists; header, body and reveal are composed | `buttons/disclosure_button.dart:6-16` |
| `chrome.shell` | `NavigationDensity.condensed` is an approximation: `SidebarItem.label` is a **required** `Widget`, so there is no icon-only AppKit sidebar | `layout/sidebar/sidebar_item.dart:15` |
| `chrome.dialogSurface` | `MacosAlertDialog` takes at most two actions and is pinned to 260px, so `DialogExtent` plus action arity routes everything richer to `MacosSheet` | `dialogs/macos_alert_dialog.dart:6,40,41`; conflicts C7/C8 |
| `overlays.presentMenu` | `MenuEntry.isDestructive` has no slot — AppKit menus in `macos_ui` carry no destructive styling | `buttons/pulldown_button.dart:499-544` |
| `type.text` | `MacosTypography` has 11 Apple roles and **no monospace role**, so `TextRole.code` is styled from `SkinRequest.monoFamily` | `theme/typography.dart:152-182` |
| `type.icon` | No SF Symbols: the package renders plain `IconData` and draws its own glyphs from `CupertinoIcons`, which its own docs recommend. `IconRole` maps to `CupertinoIcons`, not to SF Symbols | `icon/macos_icon.dart`, `buttons/toolbar/toolbar_overflow_button.dart:47` |
| `motion.reveal`, `motion.swap` | No motion tokens at all: `MacosThemeData` carries no `Duration` | verified: no `Duration` in `theme/macos_theme.dart` |
| everything | Two overlay helpers read `MaterialLocalizations` unguarded, which is what makes `rootClaims.localizationsDelegates` load-bearing rather than defensive | `dialogs/macos_alert_dialog.dart:248`, `sheets/macos_sheet.dart:133` |

### 8.4 Blueprint

One loss, and it is decision D4 already taken: no text-selection toolbar,
because `AdaptiveTextSelectionToolbar` is Material/Cupertino and importing it
would weaken the compile-time proof that the contract needs no Material
(`SKIN-CONTRACT.md:1907-1916`). Everything else the blueprint renders — see §9.

---

## 9. The blueprint's obligation, parameter by parameter

The obligation from #419, restated: the blueprint **implements every member and
accepts every parameter**, and where a parameter can be rendered distinguishably
without becoming design, it is. Then a parameter the application never varies
shows up as a constant, and a parameter a skin drops shows up as a difference
from the blueprint — which turns the blueprint from a passive backdrop into a
second, independent check.

The blueprint's vocabulary is four decisions (`SKIN-CONTRACT.md:1051-1068`):
paper `#FFFFFF`, ink `#0000FF`, a 1px ink outline, everything else zero, plus
ink `DefaultTextStyle` and `IconTheme` installed at the root.

### 9.1 What the naked square renders distinguishably

| Parameter | Blueprint rendering |
|---|---|
| `Emphasis` (4) | outline weight in whole pixels: `primary` 3px, `secondary` 2px, `quiet` 1px, `link` 1px dashed |
| `ControlScale` (3) | outline box width: `compact` narrow, `normal` medium, `prominent` wide — all at zero padding, so only the box changes |
| `Elevation` (4) | nested outline count: 0, 1, 2, 3 concentric 1px rectangles |
| `Proximity` (5), `Inset` (4) | **only under `BlueprintSkin(distance: n)`**; at `distance: 0` all rungs are 0, which is precisely what T2 sweeps |
| `TextRole` (9) | a leading marker glyph per role (`#`, `##`, `>`, `·`, …) beside the text at one type size |
| `Tone` (16 + series) | a text marker **beside** the content: `Tone.danger` → `!`, `Tone.warning` → `?`, `Tone.gitAdded` → `+`, `Tone.series(n)` → `n`. Never inside, so `find.text('Delete')` still matches |
| `IconRole` (151) | the enum member's own name in brackets, e.g. `[gitBranch]` |
| `RowSelection` + `containerFocused` | selection = filled outline; container focus = a second outline. The pair is four distinguishable states, which is the point of the flag |
| `ToggleSpec.value` (`true`/`false`/`null`) | `[x]`, `[ ]`, `[-]` |
| `ProgressExtent`, `fraction` | `[####----]` at inline, `(45%)` at block; null fraction → `[????????]` |
| `GridSpec.onColumnsChanged` | reported honestly from the real measured width — a blueprint that always answers 1 would break the keyboard controller and hide a real dependency |
| `TabSetSpec.selectedIndex`, `TreeSpec.expanded/selected` | selected tab outlined twice; expanded node prefixed `v`, collapsed `>` |
| `NoticeLifetime`, `BannerSpec.actions` | `brief` auto-dismisses at `Duration.zero + 1 frame`, `persistent` does not; actions render as outlined labels |
| `MotionRole` (4) | the role name printed once in a debug overlay; every duration is `Duration.zero`, which is what makes T2 able to see a motion dependence at all |

### 9.2 The parameters a naked square cannot render distinguishably, and why

These are listed because #419 requires a written reason for every unused
parameter. "Cannot render" here always means *cannot render without becoming
design*; none of them is dropped.

| Parameter | Why not | What the blueprint does instead |
|---|---|---|
| `Proximity`, `Inset` at `distance: 0` | Rendering them would require choosing distances, which is the one thing the blueprint must not do. Rendering them at `distance: 0` collapses all rungs to 0 **by design** — that collapse is the Zero Test, executed | resolves them through `distance`, so `BlueprintSkin(distance: 64)` renders all five rungs distinctly and T2 diffs the two runs |
| `Tone`'s 16 values as colour | Two colours exist, so 16 tones cannot be 16 hues without inventing a palette | each tone renders as its own text marker (§9.1), so information survives and appearance does not |
| `IconRole`'s 151 glyphs as glyphs | Drawing 151 distinguishable marks is a glyph set, i.e. design | the role name in brackets, which is *more* distinguishable than any glyph set and makes a wrong mapping obvious |
| `MotionRole`, and every duration | Any non-zero duration is a design value, and a blueprint that animated would defeat T2, whose whole method is that `Duration.zero` under the blueprint must not change any test result | `Duration.zero` everywhere, role name in the debug overlay |
| `CardSpec` filled-versus-outlined containment | Both would be a 1px outline; the blueprint has no fill other than paper | outline count varies with `Elevation`; containment style is recorded in the debug overlay, not drawn |
| `windowChrome` | The blueprint does not draw a window frame | answers `WindowChrome.hostDefault` |
| `scrollBehavior`, `localizationsDelegates` | Behaviour objects, not appearance | `const ScrollBehavior()` and `const []`, per §2.9 |
| `FieldSpec.selectable` / `type.text(selectable:)` toolbar | D4: `AdaptiveTextSelectionToolbar` is Material/Cupertino and importing it breaks the compile-time proof | selection works (`SelectableRegion` is in `widgets.dart`); no toolbar. The one registered blueprint deviation |
| `markdown`, `imageViewer` content | Genuinely pictorial and third-party | wrapped in `BlueprintOpaque`, whose allowlist is counted and shrink-only (§3.3c) |

Everything not in this table is rendered. The rule that makes the obligation
checkable: **a blueprint member that does not read one of its spec's fields is a
build failure**, enforced by a test that reflects over each spec class and
asserts every field is referenced in the corresponding blueprint member — the
same executable-register pattern `docs/deviation_register.yaml` already uses.

---

## 10. The members that are Material's answer wearing a neutral name

Six vocabularies and four members carry Material's model under a language-
neutral label. None of them is wrong, and none is being changed here — the
point of naming them is that these are where Fluent and macOS will be forced
into adaptation, and it is cheaper to know that now than to discover it in P7.

1. **`Elevation { flush, resting, raised, overlay }`** is Material's
   elevation-plus-surface-tint ramp (`material.dart`, `elevation_overlay.dart`).
   Fluent expresses depth as acrylic layers plus a 1px stroke
   (`acrylic.dart:64`, `mica.dart:29`); macOS as flat surfaces plus hairlines.
   Both will map three or four rungs onto one or two appearances.
2. **`Tone.onAccent`** is Material's on-colour pairing model
   (`color_scheme.dart:162-163`). Neither other language has a paired
   on-colour concept; both derive foreground contrast per surface.
3. **`MotionRole.emphasis`** names Material's `Easing.emphasized*` token family
   (`motion.dart:159-232`). Fluent has four durations and one curve
   (`theme.dart:306-326`) with no emphasis tier; macOS has none at all.
4. **`Proximity`'s five rungs** are `AppTheme.paddingXS…XL` = 4/8/16/24/32
   (`app_theme.dart:601-605`), which is Material's 4dp grid counted out. Fluent
   and macOS have their own rhythms and will not land on five.
5. **`ControlScale`'s three steps** are `VisualDensity`, already measured LOSSY
   under Fluent because Fluent 2 has one control height (`FINDINGS.md` §4.1).
   macOS has four (`control_size.dart:13-25`) and loses `mini`.
6. **`FieldSpec`'s emphasis lineage.** R4 repaired `TextFieldVariant`'s *names*
   but its `emphasized` value is still `filled: true`
   (`input_decorator.dart`), and its own doc names a search bar, a command
   palette and a filter box — which are a different *widget* in all three
   languages, not a louder field. `FieldPurpose` (§6.3) is the repair.
7. **`surfaces.badge`** — Material's `Badge` (`badge.dart:40`) is the only
   canonical badge of the three; Fluent's `InfoBadge` (`info_badge.dart:23`)
   is close, macOS has none.
8. **`surfaces.dataGrid`** — Material-only canon, kept deliberately (§7.1).
9. **`ScreenSpec.primaryActions`** — the *need* is Material's FAB. The member
   was shaped as "what are this screen's primary actions" precisely so it is not
   `fab`, but its existence is owed to a Material widget neither other package
   ships.
10. **`layout.separator(indent:)`** — `indent`/`endIndent` are Material's
    parameters (`divider.dart:56ff`). Fluent's `Divider` takes a `direction`
    and a style; macOS draws hairlines with no indent concept.

One vocabulary the Material census suspected and this census clears:
**`ProgressExtent { inline, block }` is not Material's**. It maps 1:1 onto
Fluent's `ProgressBar`/`ProgressRing` and macOS's `ProgressBar`/`ProgressCircle`
(`indicators/progress_indicators.dart:16,155`) and is the one place where the
neutral name matches all three canons exactly.

---

## 11. Measurements reconciled, and citations that did not survive re-reading

Every number in the four censuses was re-run. These differ, and P1 should use
the figures here.

| Claim | Census said | Measured | Note |
|---|---|---|---|
| raw `showDialog` sites | 86 (app-floor), 75 (Material) | **75 call expressions** | `grep -o 'showDialog'` → 86 (includes comments and doc text); `grep -Eo 'showDialog(<[^>]*>)?\('` → 75; `grep -o 'showDialog('` → 32. Both censuses measured something real; 75 is the call-site count |
| raw `Tooltip(` | 11 (app-floor), 14 (Material) | **11**, in 7 files | word-boundary `grep -Eo '(^\|[^A-Za-z])Tooltip\('`. Four of the seven files are `Base*` components that move into the skin, so feature-code exposure is 3 files |
| `IntrinsicHeight(` | 2 (app-floor) | **6** | matters only for the T3 allow-list |
| `Wrap(` | 15 (app-floor), 26 (Material) | **15** | |
| `Divider(` | 47 | **47** | confirmed, including `PopupMenuDivider` and `VerticalDivider` |
| `choiceGroup` call sites | 1 (contract §4.3:1459) | **6** | 1 `BaseChoiceGroup` + 5 raw `SegmentedButton<`. The Material census's correction is right |
| `MacosCheckbox` location | `checkbox.dart:15-25` | class at **:11**, ctor **:15-25** | both usable; class line preferred |
| `MacosSlider` | "discrete tick support is first-class" | `discrete` + `splits` (`slider.dart:29-30`), **no value label** | `SliderSpec.valueLabel` is a macOS loss, now registered (§8.3) |
| Fluent `FormRow` | "Fluent has FormRow [for label/value pairs]" (app-floor census, on `propertyList`) | **wrong** | `form_row.dart:14` is `child` + `helper` + `error` — a *field* wrapper, not a label/value pair. It has no bearing on `propertyList`; it does bear on `FieldSpec.helper`, which the spike rated LOSSY under Fluent (`FINDINGS.md` §4.3) and which this widget upgrades to ADAPTED |
| macOS `Label` | "an icon-beside-text arrangement, trivial composition" (macOS census) | **understated** | `labels/label.dart:9-17` takes `icon`, `text` **and** `child`, the latter documented as "the widget at the right of `text`" — it is a label/value pair at arity 1, which is why `propertyList` is macOS-canonical at 1 and nobody's at N |
| `MacosDisclosureButton` | cited by two censuses as macOS's canonical disclosure | **affordance only** | `disclosure_button.dart:6-16`: `fillColor`, `semanticLabel`, `isPressed`, `mouseCursor`, `onPressed`. No header, no content. macOS composes the whole disclosure |
| Fluent theme durations | "three theme durations" (Fluent census) | **four** plus a curve | `theme.dart:306,311,316,321,326` |
| `SnackBar.persist` | asserted by the Material census | **confirmed** | `snack_bar.dart:291`, resolved at `:303`, field at `:469-470` |
| `MaterialBanner.actions` required | asserted | **confirmed** | `banner.dart:105-108` |

### The T3 allow-list, as a consequence rather than a member

`SKIN-CONTRACT.md:1183-1188` names a subset of the structural widgets `lib/`
actually builds. After this member list lands, `Table` (2), `TableRow` (1),
`GridView` (12) and `Wrap` (15) all disappear into `layout.propertyList`,
`layout.grid` and `layout.row(wrap: true)`. What remains and must be **added**
to the allow-list before T3's first run: `Center` (114), `Align` (8), `Spacer`
(14), `IntrinsicHeight` (6), `SafeArea` (3) and `NotificationListener` (3). None
of them needs a member — they are structure by the Zero Test — but all six
report as leaks on day one unless the list is corrected.

---

## 12. What this list does not settle

Stated so nobody mistakes an omission for an oversight.

1. **`IconRole`'s members are not enumerated here.** They are generated
   mechanically at P3a from
   `grep -rhoE 'PhosphorIcons[A-Za-z]*\.[a-zA-Z0-9_]+' lib | sed 's/.*\.//' | sort -u`,
   and the census does not change that count. The generated 151 have since
   become 156: `archive` and `bell` (drawn by the shell toolbar fixture, which
   the census did not read), `caretLineLeft` and `caretLineRight` (the
   changelog pager draws four marks and only two had a role), and
   `updateAvailable` (the shell's standing update signal was the one Fill
   usage that was not a control state, so collapsing it onto `downloadSimple`
   made it identical to the Clone action in the same toolbar row). Each
   carries its reason at the member; the conversion is not licensed to add a
   sixth without one. What the census *does* settle is
   that the enum is the only icon seam, and that macOS maps it to
   `CupertinoIcons` rather than to SF Symbols, because `macos_ui` ships no SF
   Symbols and its own internal glyphs come from `CupertinoIcons` — keeping
   Phosphor would put Phosphor glyphs beside the `ToolBar`'s own
   `CupertinoIcons.ellipsis` overflow button inside a single bar.
2. **The remaining spec classes are not all written out.** Twelve of the
   original 28 (`CardSpec`, `PanelSpec`, `EmptyStateSpec`, `CodeLineSpec`,
   `GraphRowSpec`, `MarkdownSpec`, `ImageViewerSpec`, `DropdownSpec`,
   `FilterToggleSpec`, `PopoverSpec`, `IconButtonSpec`, `AppIdentity`) are
   unchanged by the census and stay as §2 leaves them. Every spec the census
   *touched* is written out above, which is the set P1 cannot start without.
3. **`skin_arity.yaml` is not written here.** §4.3:1481-1485 requires an
   executable record of the canonical widget and its arity per member per
   language; the tables in §3, §4 and §7 are its content, but turning them into
   the checked-in YAML plus the test that fails on disagreement is P1 work.
4. **Nothing here has been compiled.** Every package claim was read from
   resolved source and every application count was re-run, but the 55 members
   have not been declared in Dart, and the blueprint has not been written
   against them. `SKIN-CONTRACT.md` §9.1 says the same thing about the contract
   and it remains true of this list.
5. **One disagreement was not settled from evidence and is recorded as a
   judgement.** `surfaces.pressable` risks becoming an escape hatch — a member
   into which any region can be wrapped and then painted inside. The mitigation
   is structural (its `child` is a `ContentPort`, so T3 resumes inside it and
   still attributes every leak by file and line), but nothing prevents the
   member from being *over-used* rather than misused, and no measurement
   distinguishes the two. It is accepted because the alternative — 20 measured
   `InkWell(` sites losing their hover, focus and press feedback, against
   CLAUDE.md's explicit requirement that every touch target keeps its state
   layer — is worse and equally unmeasurable.
