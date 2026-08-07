# UI Concept & Design System
# Flutter GitUI

**Version:** 2.0
**Date:** 2025-11-17
**Status:** Current Standards & Best Practices Guide

---

## ⚠️ CRITICAL: WHICH DOCUMENT DECIDES WHAT

This document is the **prose** standard for UI *usage*: which component to
reach for, which constant to spend, which pattern to follow. It is not, and
cannot be, the authority on whether those components match Material 3 — prose
is not executed.

**Precedence, highest first:**

1. **`packages/gitui_skin_material/docs/deviation_register.yaml` — the normative machine-readable appendix
   to this document.** Where this document and the register disagree, **the
   register wins**, without exception and without discussion. The register is
   executed by `packages/gitui_skin_material/test/conformance/`: an unregistered mismatch fails a test, and
   a registered entry that has come back into line fails as stale
   (`packages/gitui_skin_material/test/conformance/support/expect_conformant.dart`). This document is
   executed by nobody. A number here can rot silently; a number there cannot.
2. **The Flutter SDK sources** for every Material 3 spec value. The ruler is
   `packages/flutter/lib/src/material/`, specifically the
   `// BEGIN GENERATED TOKEN PROPERTIES` blocks, which are generated from the
   Material token database. Never this document, and never memory.
3. **This document** for everything the two above do not cover.

**Sibling documents that are also current** — the earlier "read nothing but
this file" rule was never true and is withdrawn:

| Document | Scope |
|---|---|
| `packages/gitui_skin_material/docs/deviation_register.yaml` | Registered departures from M3 (normative, executable) |
| `docs/ACCESSIBILITY.md` | Accessibility standards, and what is actually asserted |
| `docs/COMPONENT-QUICK-REFERENCE.md` | Per-component API lookup |
| `docs/DESIGN-RATIONALE.md` | Why the system is shaped the way it is |
| `docs/ANIMATION-GUIDELINES.md` | Motion, durations, reduced motion |
| `docs/NAVIGATION-PATTERNS.md` | Screen and panel navigation |

The previous version of this section also told readers never to open
`STATUS.md`, `ARCHITECTURE.md`, `REQUIREMENTS.md` and `DIALOG-PATTERNS.md`.
**None of those four files exists**, and `git log` shows none of them ever did.
They have been removed from the list rather than left as a rule that cannot be
followed.

---

## ✅ COMPONENT MIGRATION COMPLETE (November 16, 2025) — USAGE ONLY

**Every call site uses the Base\* components. That is a *usage* result, not a
Material 3 *conformance* result, and the two must not be conflated.**

What the migration established is that the codebase routes through the Base\*
layer instead of raw Material widgets. Whether that layer matches Material 3
is a separate question, answered by `packages/gitui_skin_material/test/conformance/` and recorded in
`packages/gitui_skin_material/docs/deviation_register.yaml` — not by this list.

**Current state (usage):**
- ✅ All dialogs use BaseDialog (0 violations)
- ✅ All buttons use BaseButton (17/17 migrated)
- ✅ All list items use BaseListItem (17/17 migrated)
- ✅ All text fields use BaseTextField (with documented exceptions)
- ✅ All spacing uses AppTheme constants (36 files, ~200+ values migrated)
- ✅ All semantic colors use theme ColorScheme (8 replacements)
- ✅ 64 files migrated across 15 commits

**Current state (conformance):** every `Base*` component is now measured
against its Material 3 oracle by a suite under `packages/gitui_skin_material/test/conformance/components/`
— the buttons, the container components (`BaseCard`, `BaseListItem`,
`BasePanel`), the input components (`BaseTextField`, `BaseDropdown`,
`BaseDateField`), the chips, the two dialogs, the menu family and the badge
family — and the app's `TextTheme` by
`packages/gitui_skin_material/test/conformance/theme/text_theme_conformance_test.dart`. Every deliberate
departure those suites find is registered in `packages/gitui_skin_material/docs/deviation_register.yaml`,
and the register is executable in both directions: an unregistered mismatch
fails, and a registered entry that has come back into line fails as stale.

---

## Table of Contents

1. [Purpose & Overview](#1-purpose--overview)
2. [Base Component System](#2-base-component-system)
3. [Unified UI Standards](#3-unified-ui-standards)
4. [Component Decision Trees](#4-component-decision-trees)
5. [Design-System Usage Checklist (§5.1) and Material 3 Conformance (§5.2)](#5-design-system-usage-checklist-51-and-material-3-conformance-52)
6. [Code Review Guidelines](#6-code-review-guidelines)
7. [Appendix: Quick Reference](#appendix-quick-reference)

---

## 1. Purpose & Overview

### 1.1 Purpose of This Document

This document serves as:
1. **Standard** - Defines the "correct" way for every UI pattern
2. **Reference** - Single source of truth for code reviews and new development
3. **Training** - Onboarding guide for new developers
4. **Quality Control** - Ensures UI consistency across the entire application

### 1.2 Design Philosophy

Flutter GitUI follows Material Design 3 principles with:
- **Component-based architecture** - Reusable Base* components
- **Design tokens** - Centralized theme constants (AppTheme)
- **Semantic colors** - Theme-aware color system
- **Consistent spacing** - 4px base unit (4, 8, 16, 24, 32)
- **Unified typography** - BaseLabel component family

### 1.3 Base Component System Overview

Flutter GitUI has 7 comprehensive base components:

| Component | File | Purpose | Status |
|-----------|------|---------|--------|
| **BaseDialog** | `lib/shared/components/base_dialog.dart` | All dialogs | ✅ Complete |
| **BaseButton** | `lib/shared/components/base_button.dart` | All buttons | ✅ Complete |
| **BaseListItem** | `lib/shared/components/base_list_item.dart` | List items | ✅ Complete |
| **BaseCard** | `lib/shared/components/base_card.dart` | Cards | ✅ Complete |
| **BaseTextField** | `lib/shared/components/base_text_field.dart` | Text inputs | ✅ Complete |
| **BaseBadge** | `lib/shared/components/base_badge.dart` | Badges/chips | ✅ Complete |
| **BaseLabel** | `lib/shared/components/base_label.dart` | Typography | ✅ Complete |
| **BasePanel** | `lib/shared/components/base_panel.dart` | Layout regions | ✅ Complete |

"Complete" above means *implemented and used everywhere* — see the note on
usage versus conformance at the top of this document. Each of these components
additionally has a Material 3 conformance suite under
`packages/gitui_skin_material/test/conformance/components/`, which is a separate claim: that the component
matches the specification, not merely that call sites use it.

---

## 2. Base Component System

### 2.1 BaseDialog

**Features:**
- 3 semantic variants (normal, confirmation, destructive)
- Material 3's own dialog insets: `AppTheme.paddingL` (24px) around the
  dialog, 16px between title and content, 24px between content and the action
  row, and 8px between the actions — `base_dialog.dart:399`
- Border radius: `AppTheme.radiusL` (12px) — `base_dialog.dart:382`
- Keyboard support (ESC to close, Enter to submit)
- Helper functions for common dialogs

> **Conformance: measured.**
> `packages/gitui_skin_material/test/conformance/components/base_dialog_conformance_test.dart` asserts
> nineteen tokens against a real `AlertDialog` pushed through the same harness
> and read with the same probes. Padding, action spacing, action alignment,
> elevation, surface role, surface tint, barrier colour, title role, content
> role and icon size all measure the Material 3 value — the padding used to be
> a uniform 32px and now spends M3's asymmetric 24/16/24. Four departures are
> approved and recorded in `packages/gitui_skin_material/docs/deviation_register.yaml`: the 12px corner
> against M3's 28 (DLG-001, Flutter 3.44.4
> `packages/flutter/lib/src/material/dialog.dart:1967`), the `primary` variant
> icon against `secondary` (DLG-002), and the fixed 650px column against M3's
> shrink-to-content between 280px and the viewport (DLG-003, DLG-004).

**Variants:**
```dart
enum DialogVariant {
  normal,       // Info, input, general dialogs
  confirmation, // Confirm actions
  destructive,  // Delete, irreversible operations (red icon)
}
```

**Example:**
```dart
await showDialog(
  context: context,
  builder: (context) => BaseDialog(
    title: 'Delete Branch',
    icon: PhosphorIconsRegular.warning,
    variant: DialogVariant.destructive,
    content: BodyMediumLabel(
      'Are you sure you want to delete branch "feature/xyz"?',
    ),
    actions: [
      BaseButton(
        label: 'Cancel',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.pop(context),
      ),
      BaseButton(
        label: 'Delete',
        variant: ButtonVariant.danger,
        onPressed: () => deleteBranch(),
      ),
    ],
  ),
);
```

---

### 2.2 BaseButton

**Features:**
- 7 semantic variants
- 3 size options (small, medium, large)
- Loading states
- Leading/trailing icons
- Full-width option (the parameter is `fullWidth`, `base_button.dart:128`)
- Border radius: `AppTheme.radiusM` (**8px**, `base_button.dart:323`) — the
  earlier "`AppTheme.radiusS` (4px)" in this section was wrong

> **Conformance: measured.** `BaseButton` maps its variants onto
> `FilledButton` / `OutlinedButton` / `TextButton` and is measured against
> those classes' `defaultStyleOf` by
> `packages/gitui_skin_material/test/conformance/components/base_button_conformance_test.dart`. The M3
> corner is a `StadiumBorder` — 20.0 dp at the 40 dp container
> (`_FilledButtonDefaultsM3.shape`, Flutter 3.44.4 `filled_button.dart:645`) —
> so the 8 dp corner is a **registered** deviation, `BTN-001` in
> `packages/gitui_skin_material/docs/deviation_register.yaml`. Icon sizes are **16 / 18 / 18** dp for
> small / medium / large (M3 is 18 for all three,
> `_FilledButtonDefaultsM3.iconSize`, `filled_button.dart:617`; the small step
> is registered as `BTN-004`). Container heights are **32 / 40 / 48**
> (`BTN-002`, conforming, `BTN-005`), and the small label drops to
> `labelMedium` (`BTN-003`); medium and large carry the M3 `labelLarge`.

**Variants:**
```dart
enum ButtonVariant {
  primary,          // Filled, primary color (main actions)
  secondary,        // Outlined, secondary color
  tertiary,         // Text only (cancel, dismiss)
  danger,           // Red filled (delete, destructive)
  dangerSecondary,  // Red outlined
  ghost,            // Transparent background
  success,          // Green filled (confirm, save)
}
```

**Example:**
```dart
// Primary action
BaseButton(
  label: 'Commit Changes',
  variant: ButtonVariant.primary,
  leadingIcon: PhosphorIconsRegular.checkCircle,
  onPressed: () => commitChanges(),
)

// Destructive action
BaseButton(
  label: 'Delete',
  variant: ButtonVariant.danger,
  size: ButtonSize.small,
  onPressed: () => deleteItem(),
)

// Icon button
BaseIconButton(
  icon: PhosphorIconsRegular.trash,
  tooltip: 'Delete',
  variant: ButtonVariant.danger,
  onPressed: () => deleteItem(),
)
```

---

### 2.3 BaseListItem

**Features:**
- 4 selection states (normal, hover, selected, multi-selected)
- Consistent padding: `EdgeInsetsDirectional.only(start: AppTheme.paddingM,
  end: AppTheme.paddingL, top: AppTheme.paddingM, bottom: AppTheme.paddingM)`
  — start 16 / end 24 / vertical 16, `base_list_item.dart:76-81`. The earlier
  `symmetric(horizontal: paddingL)` in this section was wrong: the row is
  **not** symmetric, and its 16 dp start inset is exactly the M3 value.
- **No border radius** — the row paints square, like M3's `ListTile`. The
  earlier "`AppTheme.radiusS` (4px)" was wrong.
- Context menu support
- Material Design 3 surface tones

> **Conformance: measured** against `ListTile` by
> `packages/gitui_skin_material/test/conformance/components/base_list_item_conformance_test.dart`. Start
> inset (16), end inset (24), shape (0), leading gap (16), min tile height
> (56) and the `bodyLarge` title role all conform
> (`_LisTileDefaultsM3`, Flutter 3.44.4 `list_tile.dart:1818-1860`). Two
> departures are registered: the 16 dp vertical padding (`LIST-001`, against
> M3's 8 dp `minVerticalPadding`, `list_tile.dart:1831`) and the absent
> per-row focus layer (`LIST-002`), because the collection owns the Tab stop
> and the arrow keys move the highlight inside it.

**Example:**
```dart
BaseListItem(
  leading: Icon(
    PhosphorIconsRegular.gitBranch,
    size: AppTheme.iconM,
  ),
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BodyMediumLabel(branch.name, isBold: true),
      const SizedBox(height: AppTheme.paddingXS),
      BodySmallLabel(
        'Last commit: ${branch.lastCommit}',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  ),
  trailing: BaseIconButton(
    icon: PhosphorIconsRegular.trash,
    tooltip: 'Delete branch',
    variant: ButtonVariant.danger,
    onPressed: () => deleteBranch(),
  ),
  isSelected: branch.isCurrent,
  onTap: () => selectBranch(branch),
)
```

---

### 2.4 BaseCard

**Features:**
- Header/content/footer sections
- Elevation-based states
- Border radius: `AppTheme.radiusL` (**12px**, `base_card.dart:156`) — the
  earlier "`AppTheme.radiusM` (8px)" in this section was wrong
- Selection support

> **Conformance: measured** against `Card.outlined` by
> `packages/gitui_skin_material/test/conformance/components/base_card_conformance_test.dart`. The 12 dp
> corner, the 0 elevation, the `outlineVariant` 1 dp border and the
> `bodyMedium` content role all conform to `_OutlinedCardDefaultsM3`
> (Flutter 3.44.4 `card.dart:363-399`). Three departures are registered:
> container colour `surfaceContainerHigh` instead of `surface` (`CARD-001`),
> zero margin instead of M3's 4 dp (`CARD-002`, `card.dart:376`), and no
> per-card focus layer (`CARD-003`), for the same collection-owns-the-Tab-stop
> reason as `LIST-002`.

**Example:**
```dart
BaseCard(
  header: Row(
    children: [
      Icon(PhosphorIconsRegular.folderOpen),
      const SizedBox(width: AppTheme.paddingS),
      TitleMediumLabel(repository.name),
    ],
  ),
  content: BodyMediumLabel(repository.path),
  footer: BaseButton(
    label: 'Open',
    variant: ButtonVariant.secondary,
    size: ButtonSize.small,
    onPressed: () => openRepository(),
  ),
  isSelected: selectedRepo == repository,
  onTap: () => selectRepository(repository),
)
```

---

### 2.5 BaseTextField

**Features:**
- 3 visual variants (standard, outlined, filled)
- Prefix/suffix icons
- Clear button
- Password toggle
- Validation support
- Border radius: `AppTheme.radiusS` (4px, `base_text_field.dart:336`)

> **Conformance: measured.**
> `packages/gitui_skin_material/test/conformance/components/base_text_field_conformance_test.dart` asserts
> nineteen tokens against a real `TextField` pumped through the same harness,
> reading the container, its outline and its corners out of the paint stream
> because `InputDecorator` resolves them privately. The 4 dp corner is
> Flutter's `OutlineInputBorder` default and is now asserted as one; three
> departures are registered as FIELD-001 to FIELD-003 in
> `packages/gitui_skin_material/docs/deviation_register.yaml`.

**Example:**
```dart
BaseTextField(
  label: 'Commit Message',
  hintText: 'Enter a descriptive commit message',
  variant: TextFieldVariant.bordered,
  maxLines: 3,
  prefixIcon: PhosphorIconsRegular.chatText,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Commit message is required';
    }
    return null;
  },
  onChanged: (value) => updateCommitMessage(value),
)
```

---

### 2.6 Theme Constants (AppTheme)

**File:** `lib/shared/theme/app_theme.dart`

**Spacing:**
```dart
static const double paddingXS = 4.0;
static const double paddingS = 8.0;
static const double paddingM = 16.0;
static const double paddingL = 24.0;
static const double paddingXL = 32.0;
```

**Border Radius:**
```dart
static const double radiusS = 4.0;   // Buttons, text fields, list items
static const double radiusM = 8.0;   // Cards, containers
static const double radiusL = 12.0;  // Dialogs, modals
static const double radiusXL = 16.0; // Large panels, screens
```

**Icon Sizes:**
```dart
static const double iconXS = 12.0;
static const double iconS = 16.0;
static const double iconM = 20.0;
static const double iconL = 24.0;
static const double iconXL = 32.0;
```

**Git-Specific Colors:**

The `AppTheme.gitAdded`/`gitModified`/… constants this section used to list
**no longer exist** — `grep -r gitAdded lib/` returns nothing. One fixed hex
per role cannot hold 4.5:1 on both a near-white and a near-black surface, so
the palette became a brightness-aware `ThemeExtension`:

**File:** `lib/shared/theme/git_semantic_colors.dart`

```dart
// Read it from the BuildContext extension; never hardcode a git colour.
Icon(PhosphorIconsRegular.plus, color: context.gitColors.added)
```

| Role | Light | Dark |
|---|---|---|
| `added` | `#006318` | `#59BC5B` |
| `modified` | `#7D4800` | `#FF9800` |
| `deleted` | `#A70007` | `#FF8272` |
| `renamed` | `#005794` | `#58ACFF` |
| `untracked` | `#555656` | `#A8A8A8` |
| `conflict` | `#A40040` | `#FF7E98` |
| `branchLocal` | `#006318` | `#59BC5B` |
| `branchRemote` | `#005794` | `#58ACFF` |
| `branchTag` | `#7D4800` | `#FF9800` |
| `branchStash` | `#8C10A1` | `#ED76FD` |

Values are `git_semantic_colors.dart:65-110`. The contrast these hold is
asserted by `packages/gitui_skin_material/test/conformance/a11y/git_colors_contrast_test.dart`; see
`docs/ACCESSIBILITY.md` for exactly what that test checks.

---

## 3. Unified UI Standards

### ⚠️ REMINDER: THIS SECTION IS THE *USAGE* STANDARD

When implementing any UI component:
- ✅ Follow the patterns in this section for which component and which
  constant to reach for
- ✅ Check `packages/gitui_skin_material/docs/deviation_register.yaml` before changing any value a `Base*`
  component renders — the register outranks this section
- ❌ Do not treat a number in this section as a Material 3 spec value unless
  it carries an SDK `file:line`

---

### 3.1 Dialog Standard

**Rule:** ALWAYS use `BaseDialog` for all dialogs.

**Never use:**
- ❌ `SimpleDialog`
- ❌ `AlertDialog`
- ❌ Raw `showDialog` without BaseDialog

**Pattern:**
```dart
// Standard dialog
await showDialog(
  context: context,
  builder: (context) => BaseDialog(
    title: 'Dialog Title',
    variant: DialogVariant.normal,
    content: BodyMediumLabel('Dialog content goes here'),
    actions: [
      BaseButton(
        label: 'Cancel',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.pop(context),
      ),
      BaseButton(
        label: 'Confirm',
        variant: ButtonVariant.primary,
        onPressed: () => performAction(),
      ),
    ],
  ),
);

// Helper functions
await showConfirmationDialog(
  context: context,
  title: 'Confirm Action',
  content: 'Are you sure?',
  confirmLabel: 'Yes, Continue',
  onConfirm: () => performAction(),
);

await showDestructiveDialog(
  context: context,
  title: 'Delete Item',
  content: 'This action cannot be undone.',
  confirmLabel: 'Delete',
  onConfirm: () => deleteItem(),
);
```

---

### 3.2 Button Standard

**Rule:** ALWAYS use `BaseButton` or `BaseIconButton` for all buttons.

**Never use:**
- ❌ `FilledButton`
- ❌ `ElevatedButton`
- ❌ `TextButton`
- ❌ `OutlinedButton`
- ❌ Raw `IconButton`

**Pattern:**
```dart
// Primary action
BaseButton(
  label: 'Save Changes',
  variant: ButtonVariant.primary,
  leadingIcon: PhosphorIconsRegular.floppyDisk,
  onPressed: () => saveChanges(),
)

// Destructive action
BaseButton(
  label: 'Delete',
  variant: ButtonVariant.danger,
  onPressed: () => deleteItem(),
)

// Cancel/tertiary
BaseButton(
  label: 'Cancel',
  variant: ButtonVariant.tertiary,
  onPressed: () => Navigator.pop(context),
)

// Icon button
BaseIconButton(
  icon: PhosphorIconsRegular.trash,
  tooltip: 'Delete',
  variant: ButtonVariant.danger,
  onPressed: () => deleteItem(),
)

// Loading state
BaseButton(
  label: 'Saving...',
  variant: ButtonVariant.primary,
  isLoading: true,
  onPressed: () {},
)
```

---

### 3.3 List Item Standard

**Rule:** ALWAYS use `BaseListItem` for list items.

**Never use:**
- ❌ `ListTile`
- ❌ Raw `Container` with manual layout

**Pattern:**
```dart
BaseListItem(
  leading: Icon(
    PhosphorIconsRegular.file,
    size: AppTheme.iconM,
  ),
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BodyMediumLabel(item.title, isBold: true),
      const SizedBox(height: AppTheme.paddingXS),
      BodySmallLabel(
        item.subtitle,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  ),
  trailing: BaseIconButton(
    icon: PhosphorIconsRegular.dotsThreeVertical,
    tooltip: 'More options',
    onPressed: () => showContextMenu(),
  ),
  isSelected: selectedItem == item,
  onTap: () => selectItem(item),
)
```

---

### 3.4 Spacing Standard

**Rule:** ALWAYS use `AppTheme.padding*` constants for spacing.

**Never use:**
- ❌ Hardcoded numbers in `SizedBox`
- ❌ Hardcoded numbers in `EdgeInsets`
- ❌ Non-standard values (2, 3, 6, 10, 12, 14, 20)

**Pattern:**
```dart
// Vertical spacing
const SizedBox(height: AppTheme.paddingXS),  // 4px  - Minimal
const SizedBox(height: AppTheme.paddingS),   // 8px  - Compact
const SizedBox(height: AppTheme.paddingM),   // 16px - Standard
const SizedBox(height: AppTheme.paddingL),   // 24px - Generous
const SizedBox(height: AppTheme.paddingXL),  // 32px - Section breaks

// Padding
padding: const EdgeInsets.all(AppTheme.paddingM),
padding: const EdgeInsets.symmetric(
  horizontal: AppTheme.paddingL,
  vertical: AppTheme.paddingM,
),
```

---

### 3.5 Color Standard

**Rule:** ALWAYS use `Theme.of(context).colorScheme.*` for colors.

**Never use:**
- ❌ `Colors.white`
- ❌ `Colors.blue`
- ❌ `Colors.grey`
- ❌ Any `Colors.*` except for git-specific semantic colors

**Pattern:**
```dart
// Background colors
color: Theme.of(context).colorScheme.surface,
color: Theme.of(context).colorScheme.surfaceContainerLow,  // Slightly elevated
color: Theme.of(context).colorScheme.surfaceContainerHigh, // More elevated

// Text colors
color: Theme.of(context).colorScheme.onSurface,         // Primary text
color: Theme.of(context).colorScheme.onSurfaceVariant,  // Secondary text

// Primary/accent colors
color: Theme.of(context).colorScheme.primary,
color: Theme.of(context).colorScheme.onPrimary,  // Text on primary

// Error/destructive colors
color: Theme.of(context).colorScheme.error,
color: Theme.of(context).colorScheme.onError,

// Git-specific colors (OK to use)
color: context.gitColors.added,     // Green - for added files
color: context.gitColors.modified,  // Orange - for modified files
color: context.gitColors.deleted,   // Red - for deleted files
```

#### Material 3 state-layer opacities

The table this section used to carry — hover `0.08`, pressed `0.12`, selected
`0.16`, disabled `0.38` — was **wrong on two of its four rows**, and the
wrong rows are the ones a reviewer would actually check. The real values,
read out of the generated token blocks in the Flutter SDK the app builds
against (3.44.4, `packages/flutter/lib/src/material/`):

| State | Alpha | SDK source (Flutter 3.44.4) |
|---|---|---|
| Hover | **0.08** | `filled_button.dart:571` (`onPrimary.withOpacity(0.08)`); `icon_button.dart:1103`; `FilledButton.styleFrom` at `filled_button.dart:280` |
| Focus | **0.10** — *not 0.16* | `filled_button.dart:574`; `icon_button.dart:1106`; `filled_button.dart:281` |
| Pressed | **0.10** — *not 0.12* | `filled_button.dart:568`; `icon_button.dart:1100`; `filled_button.dart:279` |
| Disabled container | **0.12** on `onSurface` | `filled_button.dart:550` |
| Disabled content | **0.38** on `onSurface` | `filled_button.dart:559` |

Two further corrections that matter more than the digits:

- **There is no "selected" state-layer opacity in Material 3, and `0.16` is
  not an M3 value at all.** Selection is expressed by *changing a colour
  role*, not by laying a tint over the old one: the navigation components
  switch their indicator to `secondaryContainer`
  (`navigation_bar.dart:1463`, `navigation_rail.dart:1272`,
  `navigation_drawer.dart:749`), and a selected `IconButton` switches its
  foreground to `primary` (`icon_button.dart:1080`). Where a *selected*
  control does paint a state layer, it uses the same 8/10/10 opacities on the
  selected foreground role (`icon_button.dart:1088-1098`). The only `0.16`
  values left in the framework are in Material-2 code paths that M3 does not
  use — `button_theme.dart:583` and `toggle_buttons.dart:961,971`.
- **A bare `InkWell` does not get these numbers.** With no `ButtonStyle`
  supplying an `overlayColor`, `InkWell` falls back to `ThemeData` —
  `focusColor` = 12% black/white, `hoverColor` = 4% black/white
  (`theme_data.dart:467-468`), and `highlightColor`/`splashColor` = opaque-ish
  greys (`0x66BCBCBC`/`0x66C8C8C8` in light, `0x40CCCCCC` in dark,
  `theme_data.dart:501-502`). Those are **not** M3 state layers.
  Hand-painting a component out of `Material` + `InkWell` therefore opts it
  out of the M3 state-layer system silently. This is why the Base\*
  components delegate to the `ButtonStyleButton` family rather than
  reimplementing it.

```dart
// State layers are supplied by the component's ButtonStyle, not written
// by hand at the call site. If you are typing an alpha for a hover,
// focus or pressed tint, you are almost certainly in the wrong layer.
```

---

### 3.6 Border Radius Standard

**Rule:** ALWAYS use `AppTheme.radius*` constants for border radius.

**Never use:**
- ❌ `BorderRadius.circular(8)` - hardcoded value
- ❌ Non-standard values (6, 10)

**Pattern:**
```dart
// Small radius (text fields, chips)
borderRadius: BorderRadius.circular(AppTheme.radiusS),  // 4px

// Medium radius (buttons and icon buttons)
borderRadius: BorderRadius.circular(AppTheme.radiusM),  // 8px

// Large radius (cards, panels, dialogs, modals)
borderRadius: BorderRadius.circular(AppTheme.radiusL),  // 12px

// Extra large radius (large panels, bottom sheets)
borderRadius: BorderRadius.circular(AppTheme.radiusXL), // 16px
```

The earlier version of this list put buttons and list items on `radiusS` and
cards on `radiusM`. Neither matched the code: `BaseButton` uses `radiusM`
(`base_button.dart:323`), `BaseCard` uses `radiusL` (`base_card.dart:156`),
and `BaseListItem` has no radius at all — it paints square, as M3's `ListTile`
does.

---

### 3.7 Icon Size Standard

**Rule:** ALWAYS use `AppTheme.icon*` constants for icon sizes.

**Pattern:**
```dart
Icon(PhosphorIconsRegular.icon, size: AppTheme.iconXS),  // 12px - Very small
Icon(PhosphorIconsRegular.icon, size: AppTheme.iconS),   // 16px - Small
Icon(PhosphorIconsRegular.icon, size: AppTheme.iconM),   // 20px - Medium (default)
Icon(PhosphorIconsRegular.icon, size: AppTheme.iconL),   // 24px - Large
Icon(PhosphorIconsRegular.icon, size: AppTheme.iconXL),  // 32px - Extra large
```

---

### 3.8 Typography Standard

**Rule:** ALWAYS use `BaseLabel` components for text.

**Never use:**
- ❌ Raw `Text` widget with manual styling
- ❌ Manual `TextStyle` definition

**Pattern:**
```dart
// Display text (largest)
DisplayLargeLabel('Large Display Text')
DisplayMediumLabel('Medium Display Text')

// Headline text
HeadlineLargeLabel('Large Headline')
HeadlineMediumLabel('Medium Headline')

// Title text
TitleLargeLabel('Large Title')
TitleMediumLabel('Medium Title', isBold: true)

// Body text (most common)
BodyLargeLabel('Large body text')
BodyMediumLabel('Standard body text')
BodySmallLabel('Small body text')

// Label text (buttons, chips)
LabelLargeLabel('Large Label')
LabelMediumLabel('Medium Label')
```

---

## 4. Component Decision Trees

### 4.1 Which Button Variant to Use?

```
Is this the PRIMARY action in the current context?
├─ YES → ButtonVariant.primary (filled, prominent)
└─ NO
   ├─ Is this a DESTRUCTIVE action (delete, remove, discard)?
   │  ├─ YES → Is it the primary destructive action?
   │  │  ├─ YES → ButtonVariant.danger (filled red)
   │  │  └─ NO → ButtonVariant.dangerSecondary (outlined red)
   │  └─ NO
   │     ├─ Is this a SUCCESS/CONFIRMATION action (save, confirm, apply)?
   │     │  └─ YES → ButtonVariant.success (filled green)
   │     ├─ Is this a CANCEL/DISMISS action?
   │     │  └─ YES → ButtonVariant.tertiary (text only)
   │     ├─ Is this a SECONDARY action?
   │     │  └─ YES → ButtonVariant.secondary (outlined)
   │     └─ Is this a subtle action that shouldn't stand out?
   │        └─ YES → ButtonVariant.ghost (transparent)
```

**Examples:**
- Save button in form → `ButtonVariant.primary`
- Delete button in dialog → `ButtonVariant.danger`
- Cancel button → `ButtonVariant.tertiary`
- Alternative action → `ButtonVariant.secondary`

---

### 4.2 Which Dialog Variant to Use?

```
What type of action does this dialog perform?
├─ DESTRUCTIVE (delete, remove, irreversible)
│  └─ DialogVariant.destructive (red warning icon)
├─ CONFIRMATION (needs user approval)
│  └─ DialogVariant.confirmation (info icon)
└─ INFORMATIONAL or INPUT (show info, collect input)
   └─ DialogVariant.normal (standard dialog)
```

---

### 4.3 Which Spacing to Use?

```
What is the relationship between elements?
├─ Same logical group (icon + text)
│  └─ AppTheme.paddingXS (4px)
├─ Related elements (form fields in a section)
│  └─ AppTheme.paddingS (8px)
├─ Standard spacing (list items, card content)
│  └─ AppTheme.paddingM (16px)
├─ Generous spacing (sections within a screen)
│  └─ AppTheme.paddingL (24px)
└─ Major section breaks (screen sections)
   └─ AppTheme.paddingXL (32px)
```

---

### 4.4 Which Border Radius to Use?

```
What type of component?
├─ Text fields, chips
│  └─ AppTheme.radiusS (4px)
├─ Buttons, icon buttons
│  └─ AppTheme.radiusM (8px)   [registered deviation BTN-001 / ICO-001]
├─ Cards, panels, dialogs, modals, popovers
│  └─ AppTheme.radiusL (12px)
├─ Extra large containers (bottom sheets, side panels)
│  └─ AppTheme.radiusXL (16px)
└─ List rows
   └─ no radius — square, as M3's ListTile
```

---

### 4.5 Which Color to Use?

```
What element needs color?
├─ BACKGROUND
│  ├─ Main screen/view background → colorScheme.surface
│  ├─ Slightly elevated (cards at level 1) → colorScheme.surfaceContainerLow
│  ├─ Moderately elevated (floating elements) → colorScheme.surfaceContainer
│  └─ Highly elevated (dialogs, modals) → colorScheme.surfaceContainerHigh
├─ TEXT
│  ├─ Primary text (headings, important content) → colorScheme.onSurface
│  ├─ Secondary text (descriptions, timestamps) → colorScheme.onSurfaceVariant
│  └─ Text on colored backgrounds
│     ├─ On primary → colorScheme.onPrimary
│     └─ On error → colorScheme.onError
├─ ACCENT/INTERACTIVE
│  ├─ Primary actions, links, highlights → colorScheme.primary
│  ├─ Secondary actions → colorScheme.secondary
│  └─ Errors, warnings → colorScheme.error
└─ GIT-SPECIFIC (semantic colors)
   ├─ Added files → context.gitColors.added
   ├─ Modified files → context.gitColors.modified
   ├─ Deleted files → context.gitColors.deleted
   ├─ Renamed files → context.gitColors.renamed
   └─ Conflicts → context.gitColors.conflict
```

---

## 5. Design-System Usage Checklist (§5.1) and Material 3 Conformance (§5.2)

**Two different questions are being asked here, and this section used to ask
only one of them under the other's name.**

- **"Did the call site use the design system?"** — a *usage* question. It is
  answered by reading the diff: `BaseButton` instead of `FilledButton`,
  `AppTheme.paddingM` instead of `16`. That is §5.1 below, and it is the only
  thing the old "Material Design 3 Compliance Checklist" ever checked.
- **"Does the design system match Material 3?"** — a *conformance* question.
  A reviewer cannot answer it by reading a diff, because the number to compare
  against lives in the Flutter SDK's generated token tables, not in the diff
  and not in this document. Checking that `BaseButton` was used tells you
  nothing about whether `BaseButton`'s corner, label role, icon size or state
  layers match `FilledButton`'s. **This is exactly the gap that let the app
  ship a 4 dp corner, an 11 px button label and six failing colour contrasts
  while every checklist item above was ticked.** That is §5.2, and it is not
  a checklist — it is a test run.

### 5.1 Usage checklist (read the diff)

Use this for code reviews and new feature development:

#### 5.1.1 Dialogs
- [ ] Uses `BaseDialog` (not SimpleDialog, AlertDialog)
- [ ] Uses appropriate `DialogVariant` (normal, confirmation, destructive)
- [ ] Actions use `BaseButton` with correct variants
- [ ] Content uses `BaseLabel` components for text
- [ ] No hardcoded padding or spacing

#### 5.1.2 Buttons
- [ ] Uses `BaseButton` or `BaseIconButton` (not FilledButton, ElevatedButton, TextButton, IconButton)
- [ ] Uses appropriate `ButtonVariant`
- [ ] Uses appropriate `ButtonSize` if not default
- [ ] No manual style definition
- [ ] Tooltip provided for icon buttons

#### 5.1.3 List Items
- [ ] Uses `BaseListItem` (not ListTile)
- [ ] Selection states properly handled (isSelected, isMultiSelected)
- [ ] Leading/trailing icons use `AppTheme.icon*` sizes
- [ ] No hardcoded padding

#### 5.1.4 Colors
- [ ] Uses `Theme.of(context).colorScheme.*` for all colors
- [ ] No `Colors.white`, `Colors.blue`, or other `Colors.*`
- [ ] Git-specific colors (`context.gitColors.*`) only for semantic use
- [ ] **No hand-written state-layer alpha at the call site at all.** Hover,
      focus and pressed tints come from the component's `ButtonStyle`. If a
      literal alpha is unavoidable, it must be one of the M3 values in §3.5
      (hover 0.08, focus 0.10, pressed 0.10, disabled container 0.12,
      disabled content 0.38) — and note that the old "0.08 / 0.12 / 0.16 /
      0.38" line that stood here named two values M3 does not use.

#### 5.1.5 Spacing
- [ ] Uses `AppTheme.padding*` for all spacing
- [ ] No hardcoded numbers in SizedBox
- [ ] No hardcoded numbers in EdgeInsets
- [ ] No non-standard values (2, 3, 6, 10, 12, 14, 20)

#### 5.1.6 Border Radius
- [ ] Uses `AppTheme.radius*` for all border radius
- [ ] No hardcoded `BorderRadius.circular(X)`
- [ ] No non-standard values (6, 10)

#### 5.1.7 Typography
- [ ] Uses `BaseLabel` components (not raw Text)
- [ ] No manual `TextStyle` definition
- [ ] Appropriate label type for context (BodyMedium, TitleLarge, etc.)

#### 5.1.8 Icons
- [ ] Icon sizes use `AppTheme.icon*` constants
- [ ] No hardcoded icon sizes
- [ ] Phosphor icons used consistently

#### 5.1.9 Text Fields
- [ ] Uses `BaseTextField` (not TextField)
- [ ] Appropriate variant selected
- [ ] Validation handled via validator parameter

#### 5.1.10 Cards
- [ ] Uses `BaseCard` (not Container with manual decoration)
- [ ] No hardcoded padding or border radius inside card

---

### 5.2 Material 3 conformance (run the suite)

Conformance is not reviewed, it is **executed**. Nothing in §5.1 can detect a
`Base*` component whose geometry, typography role, state-layer opacity, focus
indication or minimum tap target differs from Material 3 — that requires
measuring the rendered widget against the SDK's own generated defaults.

**How to answer the conformance question:**

```bash
cd packages/gitui_skin_material && flutter test
```

**What that runs, and what each part proves:**

| Path | What it measures | Oracle |
|---|---|---|
| `packages/gitui_skin_material/test/conformance/theme/text_theme_conformance_test.dart` | all 15 M3 text roles of the app's `TextTheme` | `Typography.englishLike2021`, `typography.dart:2096-2112` |
| `packages/gitui_skin_material/test/conformance/components/base_button_conformance_test.dart` | geometry, label role, icon size, colour roles, state layers, focus, Enter/Space, tap target | `FilledButton`/`OutlinedButton`/`TextButton` `defaultStyleOf` |
| `packages/gitui_skin_material/test/conformance/components/base_icon_button_conformance_test.dart` | same, plus the tooltip-labelled tap target | `_IconButtonDefaultsM3`, pinned with citations |
| `packages/gitui_skin_material/test/conformance/components/base_card_conformance_test.dart` | shape, elevation, container/border colour, margin, state layers | `Card.outlined` |
| `packages/gitui_skin_material/test/conformance/components/base_list_item_conformance_test.dart` | insets, min height, shape, title role, state layers | `ListTile` |
| `packages/gitui_skin_material/test/conformance/components/base_panel_conformance_test.dart` | container and header, measured against two oracles | `Card` + `ExpansionTile` header |
| `packages/gitui_skin_material/test/conformance/a11y/git_colors_contrast_test.dart` | WCAG contrast of the git palette on every scheme, surface and brightness | WCAG 2.1 SC 1.4.3 / 1.4.11 |
| `packages/gitui_skin_material/test/conformance/deviation_register_test.dart` | that every register entry is well-formed and reachable | — |

**How a mismatch is resolved.** `expectConformant`
(`packages/gitui_skin_material/test/conformance/support/expect_conformant.dart`) fails in *both*
directions:

- a mismatch with **no** register entry fails as `M3 CONFORMANCE FAILURE`;
- a register entry whose value has come back into line fails as
  `STALE DEVIATION`;
- a register entry whose documented `spec_value` no longer matches the SDK
  fails as `REGISTER SPEC MISMATCH` (the SDK default moved);
- a register entry whose measured value drifted to a third value fails as
  `DEVIATION DRIFT`.

So there are exactly two acceptable outcomes for a difference from Material 3:
**make the component conform**, or **register the deviation** in
`packages/gitui_skin_material/docs/deviation_register.yaml` with `id`, `component`, `property`,
`spec_value`, `app_value`, `spec_source` (an SDK `file:line`), `rationale` and
`registered` date. An unregistered difference is a defect, not a decision.

**Adding a measurement** additionally requires listing the token in
`packages/gitui_skin_material/test/conformance/support/token_manifest.dart`; `expectConformant` refuses to
assert on a token that is not in the manifest, so the set of things being
measured stays reviewable in a diff.

**Do not read silence as conformance.** Every `Base*` component now has a
conformance suite, but a suite only measures the tokens listed in
`packages/gitui_skin_material/test/conformance/support/token_manifest.dart`. Where this document gives a
number that no token covers, it is a description of the current code, not a
conformance claim.

---

## 6. Code Review Guidelines

### ⚠️ REMINDER: WHAT A REVIEW CAN AND CANNOT SETTLE

During code reviews:
- ✅ Cite this document for **usage** questions (which component, which constant)
- ✅ Cite `packages/gitui_skin_material/docs/deviation_register.yaml` for **conformance** questions — and if
  it disagrees with this document, the register is right
- ✅ Cite an SDK `file:line` under
  `packages/flutter/lib/src/material/` for any Material 3 spec value
- ❌ Never settle a conformance argument by quoting prose, this document
  included; run `cd packages/gitui_skin_material && flutter test` instead

---

### 6.1 Review Process

**For ALL pull requests, reviewers must check:**

1. **Component Usage**
   - ✅ Approve: Uses Base* components
   - ❌ Reject: Uses raw Material widgets

2. **Spacing & Layout**
   - ✅ Approve: Uses AppTheme.padding* constants
   - ❌ Reject: Hardcoded spacing values

3. **Colors**
   - ✅ Approve: Uses colorScheme.*
   - ❌ Reject: Uses Colors.* (except semantic git colors)

4. **Border Radius**
   - ✅ Approve: Uses AppTheme.radius*
   - ❌ Reject: Hardcoded BorderRadius.circular()

5. **Typography**
   - ✅ Approve: Uses BaseLabel components
   - ❌ Reject: Raw Text with manual styling

6. **Conformance (only if the PR touches a `Base*` component or the theme)**
   - ✅ Approve: `cd packages/gitui_skin_material && flutter test` is green,
     and any new difference from Material 3 carries a
     `packages/gitui_skin_material/docs/deviation_register.yaml` entry with
     an SDK `spec_source` and a reason
   - ❌ Reject: a `Base*` geometry, typography role, state layer or tap target
     changed with no conformance run and no register entry

---

### 6.2 Auto-Rejection Rules

**Reject PR immediately if:**
- Uses `SimpleDialog` or `AlertDialog`
- Uses `FilledButton`, `ElevatedButton`, `TextButton`, `OutlinedButton`
- Uses `ListTile` for new code
- Uses `Colors.white`, `Colors.blue`, or hardcoded color values
- Hardcoded spacing: `SizedBox(height: 16)` instead of `SizedBox(height: AppTheme.paddingM)`
- Hardcoded border radius: `BorderRadius.circular(8)` instead of `AppTheme.radiusM`
- Non-standard spacing values: 6, 10, 12, 14, 20
- Raw `Text` widget with manual `TextStyle`

---

### 6.3 Comment Templates

**For inconsistent spacing:**
```
Please use AppTheme spacing constants:
- Replace `const SizedBox(height: 16)` with `const SizedBox(height: AppTheme.paddingM)`
- Replace `EdgeInsets.all(8)` with `EdgeInsets.all(AppTheme.paddingS)`
```

**For wrong button:**
```
Please use BaseButton instead of [Material button]:
- Replace `FilledButton(...)` with `BaseButton(variant: ButtonVariant.primary, ...)`
- Replace `TextButton(...)` with `BaseButton(variant: ButtonVariant.tertiary, ...)`
```

**For hardcoded colors:**
```
Please use theme colors instead of hardcoded values:
- Replace `Colors.white` with `Theme.of(context).colorScheme.onPrimary`
- Replace `Colors.blue` with `Theme.of(context).colorScheme.primary`
```

---

### 6.4 Approval Criteria

**Only approve PR if:**
- ✅ All Base* components used correctly
- ✅ All spacing uses AppTheme constants
- ✅ All colors from colorScheme
- ✅ All border radius uses AppTheme constants
- ✅ All MD3 compliance checklist items passed
- ✅ No technical debt introduced

---

## Appendix: Quick Reference

### A.1 When to Use Each Base Component

| Need | Component | Example |
|------|-----------|---------|
| Dialog | `BaseDialog` | Confirmation, input, info |
| Button | `BaseButton` | Save, Cancel, Delete |
| Icon button | `BaseIconButton` | Toolbar icons, actions |
| List item | `BaseListItem` | File list, branch list |
| Card | `BaseCard` | Repository card, info panel |
| Text input | `BaseTextField` | Forms, search |
| Text label | `BaseLabel` (BodyMedium, TitleLarge, etc.) | All text |
| Badge/chip | `BaseBadge` | Status, count, label |

---

### A.2 Spacing Quick Reference

| Size | Constant | Value | Use Case |
|------|----------|-------|----------|
| XS | `AppTheme.paddingXS` | 4px | Icon+text, minimal gaps |
| S | `AppTheme.paddingS` | 8px | Related elements |
| M | `AppTheme.paddingM` | 16px | Standard spacing |
| L | `AppTheme.paddingL` | 24px | Section spacing |
| XL | `AppTheme.paddingXL` | 32px | Major breaks |

---

### A.3 Border Radius Quick Reference

| Size | Constant | Value | Use Case |
|------|----------|-------|----------|
| S | `AppTheme.radiusS` | 4px | Text fields, chips |
| M | `AppTheme.radiusM` | 8px | Buttons, icon buttons (`BTN-001`/`ICO-001`) |
| L | `AppTheme.radiusL` | 12px | Cards, panels, dialogs, modals |
| XL | `AppTheme.radiusXL` | 16px | Large panels, sheets |
| — | *(none)* | 0 | List rows — square, as M3's `ListTile` |

---

### A.4 Button Variant Quick Reference

| Variant | Use Case | Example |
|---------|----------|---------|
| `primary` | Main action | Save, Submit, Create |
| `secondary` | Alternative action | Edit, View Details |
| `tertiary` | Cancel/dismiss | Cancel, Close, Back |
| `danger` | Destructive | Delete, Remove, Discard |
| `dangerSecondary` | Secondary destructive | Delete (not primary) |
| `success` | Positive confirmation | Confirm, Apply, Save |
| `ghost` | Subtle action | Toolbar buttons |

---

### A.5 Material Design 3 State-Layer Opacities

Corrected against the Flutter 3.44.4 generated token blocks; see §3.5 for the
full explanation and for why "Selected 0.16" is not a Material 3 concept.

| State | Alpha | SDK source (`packages/flutter/lib/src/material/`) |
|-------|-------|---|
| Hover | 0.08 | `filled_button.dart:571`, `icon_button.dart:1103` |
| Focus | 0.10 | `filled_button.dart:574`, `icon_button.dart:1106` |
| Pressed | 0.10 | `filled_button.dart:568`, `icon_button.dart:1100` |
| Disabled container | 0.12 on `onSurface` | `filled_button.dart:550` |
| Disabled content | 0.38 on `onSurface` | `filled_button.dart:559` |
| Selected | *(no opacity — change the colour role)* | `navigation_bar.dart:1463` (`secondaryContainer`), `icon_button.dart:1080` (`primary`) |

---

### A.6 Icon Size Quick Reference

| Size | Constant | Value | Use Case |
|------|----------|-------|----------|
| XS | `AppTheme.iconXS` | 12px | Very small indicators |
| S | `AppTheme.iconS` | 16px | Compact UI, badges |
| M | `AppTheme.iconM` | 20px | Standard UI (default) |
| L | `AppTheme.iconL` | 24px | Prominent actions |
| XL | `AppTheme.iconXL` | 32px | Large features |

---

## Document Usage Rules

### ⚠️ CRITICAL: Precedence, not exclusivity

This section used to say "use ONLY UI-CONCEPT.md" and to forbid opening
`STATUS.md`, `ARCHITECTURE.md`, `REQUIREMENTS.md` and `DIALOG-PATTERNS.md` —
**four files that do not exist and never have**. Worse, the rule guaranteed
the failure it was meant to prevent: a document that forbids consulting the
executable ruler is a document that can be wrong for months without anybody
noticing, which is precisely what happened to §3.5's opacity table and to
`docs/ACCESSIBILITY.md`'s contrast claim.

The rule is replaced by a precedence order.

**ALWAYS:**
- ✅ Use this document for UI **usage** decisions
- ✅ Defer to `packages/gitui_skin_material/docs/deviation_register.yaml` on any **conformance** question —
  it is this document's normative machine-readable appendix, it is executed by
  `packages/gitui_skin_material/test/conformance/`, and where the two disagree, **the register wins**
- ✅ Take Material 3 spec values from the Flutter SDK
  (`packages/flutter/lib/src/material/`, the
  `// BEGIN GENERATED TOKEN PROPERTIES` blocks), citing `file:line`
- ✅ Update this document when a pattern changes — and update the register
  and the conformance suite when a *value* changes

**NEVER:**
- ❌ Quote this document as evidence that something conforms to Material 3
- ❌ Write an M3 number here without an SDK `file:line` beside it
- ❌ Leave a difference from Material 3 unregistered

### For contributors and tooling

**When asked to work on UI:**
1. Read this document for the pattern
2. Read `packages/gitui_skin_material/docs/deviation_register.yaml` before changing any `Base*` value
3. Read the relevant `packages/gitui_skin_material/test/conformance/` suite to see what is already asserted
4. Consult `docs/ACCESSIBILITY.md` for accessibility requirements
5. If a number here is not backed by an SDK citation or a test, treat it as
   unverified and go measure it

---

**Document Version:** 2.1
**Last Updated:** 2026-08-07
**Maintained By:** Flutter GitUI Team

---

## ⚠️ FINAL REMINDER

**Prose does not prove conformance.**

- Usage question → this document
- Conformance question → `cd packages/gitui_skin_material && flutter test`,
  and `packages/gitui_skin_material/docs/deviation_register.yaml` for anything
  deliberately different
- Material 3 spec value → the Flutter SDK, with a `file:line`

---

**END OF DOCUMENT**
