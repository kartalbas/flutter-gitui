# Component Quick Reference

Fast lookup guide for all Base* components, import paths, and common usage patterns.

---

## 📦 Import Paths

```dart
// Buttons
import 'package:flutter_gitui/shared/components/base_button.dart';

// Dialogs
import 'package:flutter_gitui/shared/components/base_dialog.dart';

// Lists
import 'package:flutter_gitui/shared/components/base_list_item.dart';

// Typography (Labels)
import 'package:flutter_gitui/shared/components/base_label.dart';

// Forms
import 'package:flutter_gitui/shared/components/base_text_field.dart';
import 'package:flutter_gitui/shared/components/base_date_field.dart';

// Layout
import 'package:flutter_gitui/shared/components/base_card.dart';
import 'package:flutter_gitui/shared/components/base_panel.dart';

// UI Elements
import 'package:flutter_gitui/shared/components/base_badge.dart';
import 'package:flutter_gitui/shared/components/base_filter_chip.dart';
import 'package:flutter_gitui/shared/components/base_menu_item.dart';
import 'package:flutter_gitui/shared/components/base_switcher.dart';

// Code/Diff
import 'package:flutter_gitui/shared/components/base_diff_viewer.dart';

// Utilities
import 'package:flutter_gitui/shared/components/copyable_text.dart';
import 'package:flutter_gitui/shared/components/base_select_all_button.dart';
import 'package:flutter_gitui/shared/components/base_animated_widgets.dart';

// Theme
import 'package:flutter_gitui/shared/theme/app_theme.dart';

// Icons
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

---

## 🎨 BaseButton - Button Variants

| Variant | Use Case | Visual | Example |
|---------|----------|--------|---------|
| **primary** | Main action | Filled, primary color | Save, Commit, Create |
| **secondary** | Alternative action | Outlined, primary color | Export, View Details |
| **tertiary** | Cancel, dismiss | Text only | Cancel, Close, Dismiss |
| **danger** | Destructive action | Filled, red | Delete, Discard, Remove |
| **dangerSecondary** | Secondary destructive | Outlined, red | Remove (alternative) |
| **ghost** | Subtle action | Transparent | Collapse, Minimize |
| **success** | Positive confirmation | Filled, green | Mark as Good (bisect) |

### Button Sizes

Measured, not estimated: these are the values
`packages/gitui_skin_material/test/conformance/components/base_button_conformance_test.dart` asserts. The
earlier "14 / 16 / 18px" icon column here was wrong in two of three rows.

| Size | Container height | Label role | Icon size | M3 | Use Case |
|------|---|---|---|---|----------|
| **small** | 32px (`BTN-002`) | `labelMedium` (`BTN-003`) | **16px** (`BTN-004`) | 40 / `labelLarge` / 18 | Tight spaces, inline actions |
| **medium** | 40px (conforms) | `labelLarge` (conforms) | **18px** (conforms) | 40 / `labelLarge` / 18 | Standard (default) |
| **large** | 48px (`BTN-005`) | `labelLarge` (conforms) | **18px** (conforms) | 40 / `labelLarge` / 18 | Primary prominent actions |

M3 reference values: `_FilledButtonDefaultsM3` — `minimumSize` `Size(64, 40)`
(Flutter 3.44.4 `filled_button.dart:611`), `textStyle` `labelLarge` (`:544`),
`iconSize` `18.0` (`:617`). The `BTN-*` ids are the registered deviations in
`packages/gitui_skin_material/docs/deviation_register.yaml`.

`BaseIconButton` sizes differ — container 32 / 40 / 48 and glyph **16 / 20 /
24** (`ICO-002`..`ICO-005`; M3 is a 40 dp container with a 24 dp glyph,
`icon_button.dart:1128` and `:1138`).

At every size, the *hit area* of both components is ≥ 48×48 even where the
painted container is smaller — asserted with
`meetsGuideline(androidTapTargetGuideline)`.

### Examples

```dart
// Primary action
BaseButton(
  label: 'Commit',
  variant: ButtonVariant.primary,
  leadingIcon: PhosphorIconsRegular.gitCommit,
  onPressed: () => commitChanges(),
)

// Cancel action
BaseButton(
  label: 'Cancel',
  variant: ButtonVariant.tertiary,
  onPressed: () => Navigator.pop(context),
)

// Destructive action
BaseButton(
  label: 'Delete Branch',
  variant: ButtonVariant.danger,
  leadingIcon: PhosphorIconsRegular.trash,
  onPressed: () => deleteBranch(),
)

// Loading state
BaseButton(
  label: isLoading ? 'Saving...' : 'Save',
  variant: ButtonVariant.primary,
  isLoading: isLoading,
  onPressed: isLoading ? null : () => save(),
)

// Icon-only button
BaseButton(
  label: '',
  variant: ButtonVariant.ghost,
  leadingIcon: PhosphorIconsRegular.x,
  onPressed: () => close(),
)

// Full-width button (the parameter is `fullWidth`, base_button.dart:128 —
// `isFullWidth` does not exist)
BaseButton(
  label: 'Continue',
  variant: ButtonVariant.primary,
  fullWidth: true,
  onPressed: () => proceed(),
)
```

---

## 💬 BaseDialog - Dialog Variants

| Variant | Use Case | Icon Color | Example |
|---------|----------|------------|---------|
| **normal** | Info, input | Primary | Settings, Info, Forms |
| **confirmation** | Confirm action | Primary | "Are you sure?" |
| **destructive** | Delete, remove | Error (red) | Delete confirmation |

### Examples

```dart
// Information dialog
await showDialog(
  context: context,
  builder: (context) => BaseDialog(
    title: 'About',
    variant: DialogVariant.normal,
    icon: PhosphorIconsRegular.info,
    content: BodyMediumLabel('Flutter GitUI v1.0.0'),
    actions: [
      BaseButton(
        label: 'Close',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  ),
);

// Confirmation dialog
await showConfirmationDialog(
  context: context,
  title: 'Push Changes',
  icon: PhosphorIconsRegular.arrowUp,
  message: 'Push 3 commits to origin/master?',
  confirmLabel: 'Push',
  onConfirm: () => push(),
);

// Destructive dialog
await showDestructiveDialog(
  context: context,
  title: 'Delete Branch',
  icon: PhosphorIconsRegular.trash,
  message: 'This will permanently delete the branch "feature/new-ui".',
  confirmLabel: 'Delete',
  onConfirm: () => deleteBranch(),
);
```

---

## 📝 BaseListItem - List Component

### Selection States

| State | Visual | Use Case |
|-------|--------|----------|
| **Normal** | Default | Standard list item |
| **Hover** | Subtle background | Mouse over |
| **Selected** | Primary border (2px) | Single selection |
| **Multi-selected** | Border (3px) + checkbox | Batch operations |

### Examples

```dart
// Basic list item
BaseListItem(
  leading: Icon(PhosphorIconsRegular.folder, size: AppTheme.iconM),
  content: BodyMediumLabel('Repository Name'),
  trailing: Icon(PhosphorIconsRegular.caretRight),
  onTap: () => openRepository(),
)

// With title and subtitle
BaseListItem(
  leading: Icon(PhosphorIconsRegular.gitBranch, size: AppTheme.iconM),
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BodyMediumLabel('main', isBold: true),
      const SizedBox(height: AppTheme.paddingXS),
      BodySmallLabel(
        'Last commit 2 hours ago',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  ),
  trailing: BaseBadge(
    label: 'local',
    variant: BadgeVariant.success,
  ),
  isSelected: isSelected,
  onTap: () => selectBranch(),
)

// Multi-selection with checkbox
BaseListItem(
  leading: Icon(PhosphorIconsRegular.file, size: AppTheme.iconM),
  content: BodyMediumLabel('README.md'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BaseBadge(label: 'Modified', variant: BadgeVariant.warning),
    ],
  ),
  isMultiSelected: selectedFiles.contains(file),
  onMultiSelectToggle: () => toggleSelection(file),
)

// With context menu
BaseListItem(
  leading: CircleAvatar(child: Text('JD')),
  content: BodyMediumLabel('John Doe'),
  trailing: Icon(PhosphorIconsRegular.dotsThree),
  onTap: () => selectUser(),
  onSecondaryTap: (details) {
    showContextMenu(
      context: context,
      position: details.globalPosition,
      items: [
        BaseMenuItem(
          label: 'View Profile',
          icon: PhosphorIconsRegular.user,
          onTap: () => viewProfile(),
        ),
        BaseMenuItem(
          label: 'Send Message',
          icon: PhosphorIconsRegular.chatCircle,
          onTap: () => sendMessage(),
        ),
      ],
    );
  },
)
```

---

## 📰 BaseLabel - Typography

Sizes are at `AppFontSize.medium` and are what the theme really renders — the
column this table used to carry was the *Material 3* scale, which differs on
nine of fifteen roles. Both columns are asserted role by role by
`packages/gitui_skin_material/test/conformance/theme/text_theme_conformance_test.dart`; the `TYPE-*` ids
are the entries in `packages/gitui_skin_material/docs/deviation_register.yaml`.

| Component | Size | M3 | Weight | Use Case |
|-----------|------|----|--------|----------|
| **DisplayLargeLabel** | **45px** (`TYPE-001`) | 57 | Regular | Splash screens (rarely used) |
| **DisplayMediumLabel** | **36px** (`TYPE-002`) | 45 | Regular | Hero sections (rarely used) |
| **DisplaySmallLabel** | **32px** (`TYPE-003`) | 36 | Regular | Large headings (rarely used) |
| **HeadlineLargeLabel** | **28px** (`TYPE-004`) | 32 | Regular | Major sections |
| **HeadlineMediumLabel** | **24px** (`TYPE-005`) | 28 | Regular | Section dividers |
| **HeadlineSmallLabel** | **22px** (`TYPE-006`) | 24 | Regular | Sub-sections |
| **TitleLargeLabel** | **20px** (`TYPE-007`) | 22 | Medium | Dialog titles, main headings |
| **TitleMediumLabel** | 16px | 16 | Medium | Card headers, section titles |
| **TitleSmallLabel** | 14px | 14 | Medium | Panel headers |
| **BodyLargeLabel** | **15px** (`TYPE-008`) | 16 | Regular | Prominent body text |
| **BodyMediumLabel** | **13px** (`TYPE-009`) | 14 | Regular | List titles, body text (MOST COMMON) |
| **BodySmallLabel** | 12px | 12 | Regular | Subtitles, descriptions |
| **LabelLargeLabel** | 14px | 14 | Medium | Large labels (M3 button-label role) |
| **LabelMediumLabel** | 12px | 12 | Medium | Standard labels |
| **LabelSmallLabel** | 11px | 11 | Medium | Captions, timestamps |

The `tiny` / `small` / `large` user settings derive from this column by a
single multiplier (×0.85 / ×0.92 / ×1.10, rounded), `app_theme.dart:231-236`.

### Special Typography Components

```dart
// Menu item label (used in context menus)
MenuItemLabel('Open Repository')

// Monospace label (for code, commit hashes)
MonoLabel('a3f4b2c', fontSize: 12)
```

### Examples

```dart
// Dialog title
TitleLargeLabel('Create New Branch')

// Section header
TitleMediumLabel('Recent Commits')

// List item title
BodyMediumLabel('feature/new-ui', isBold: true)

// List item subtitle
BodySmallLabel(
  'Created 2 days ago',
  color: Theme.of(context).colorScheme.onSurfaceVariant,
)

// Timestamp/caption
LabelSmallLabel('Last updated: 10:30 AM')

// Error message
BodyMediumLabel(
  'Invalid repository path',
  color: Theme.of(context).colorScheme.error,
)

// Custom styling
BodyMediumLabel(
  'Important Note',
  isBold: true,
  color: Theme.of(context).colorScheme.primary,
  textAlign: TextAlign.center,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

---

## 📋 BaseTextField - Form Input

### Variants

| Variant | Visual | Use Case |
|---------|--------|----------|
| **outlined** | Border | Standard forms (most common) |
| **filled** | Filled background | Dense forms |
| **underlined** | Bottom border only | Minimal forms |

### Examples

```dart
// Basic text field
BaseTextField(
  label: 'Repository Name',
  variant: TextFieldVariant.bordered,
  hintText: 'Enter repository name',
  controller: nameController,
)

// With validation
BaseTextField(
  label: 'Email',
  variant: TextFieldVariant.bordered,
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@')) {
      return 'Invalid email format';
    }
    return null;
  },
)

// Password field
BaseTextField(
  label: 'Password',
  variant: TextFieldVariant.bordered,
  obscureText: true,
  suffixIcon: Icon(PhosphorIconsRegular.eye),
)

// Multi-line text field
BaseTextField(
  label: 'Commit Message',
  variant: TextFieldVariant.bordered,
  maxLines: 5,
  hintText: 'Describe your changes...',
)

// With prefix icon
BaseTextField(
  label: 'Search',
  variant: TextFieldVariant.emphasized,
  prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
  hintText: 'Search repositories...',
)

// Read-only field
BaseTextField(
  label: 'Commit Hash',
  variant: TextFieldVariant.bordered,
  initialValue: 'a3f4b2c7d8e9f0a1',
  readOnly: true,
)

// With focus node (for programmatic focus)
final focusNode = FocusNode();

BaseTextField(
  label: 'Username',
  variant: TextFieldVariant.bordered,
  focusNode: focusNode,
)

// Programmatically focus
focusNode.requestFocus();
```

---

## 🏷️ BaseBadge - Status Indicators

| Variant | Color | Use Case |
|---------|-------|----------|
| **primary** | Primary | General status |
| **secondary** | Secondary | Alternative status |
| **success** | Green | Added, success |
| **warning** | Orange | Modified, warning |
| **error** | Red | Deleted, error |
| **info** | Blue | Information |

### Examples

```dart
// Git status badges
BaseBadge(label: 'Added', variant: BadgeVariant.success)
BaseBadge(label: 'Modified', variant: BadgeVariant.warning)
BaseBadge(label: 'Deleted', variant: BadgeVariant.error)

// Branch type badges
BaseBadge(label: 'local', variant: BadgeVariant.success)
BaseBadge(label: 'remote', variant: BadgeVariant.info)
BaseBadge(label: 'tag', variant: BadgeVariant.warning)

// Status indicators
BaseBadge(label: '3 conflicts', variant: BadgeVariant.error)
BaseBadge(label: 'Up to date', variant: BadgeVariant.success)
```

---

## 🎛️ BaseFilterChip - Filters

### Examples

```dart
// Filter chip
BaseFilterChip(
  label: 'Modified Files',
  icon: PhosphorIconsRegular.pencilSimple,
  isSelected: showModified,
  onTap: () => setState(() => showModified = !showModified),
)

// Multiple filters
Wrap(
  spacing: AppTheme.paddingS,
  children: [
    BaseFilterChip(
      label: 'Added',
      isSelected: filters.contains('added'),
      onTap: () => toggleFilter('added'),
    ),
    BaseFilterChip(
      label: 'Modified',
      isSelected: filters.contains('modified'),
      onTap: () => toggleFilter('modified'),
    ),
    BaseFilterChip(
      label: 'Deleted',
      isSelected: filters.contains('deleted'),
      onTap: () => toggleFilter('deleted'),
    ),
  ],
)
```

---

## 🔧 AppTheme Constants

### Spacing

| Constant | Value | Use Case |
|----------|-------|----------|
| `paddingXS` | 4px | Same logical group (icon + text) |
| `paddingS` | 8px | Related elements, between buttons |
| `paddingM` | 16px | Standard spacing (DEFAULT) |
| `paddingL` | 24px | Section spacing, generous spacing |
| `paddingXL` | 32px | Major section breaks, dialog padding |

### Border Radius

| Constant | Value | Use Case |
|----------|-------|----------|
| `radiusS` | 4px | Text fields, chips |
| `radiusM` | 8px | **Buttons and icon buttons** (`BTN-001`, `ICO-001`) |
| `radiusL` | 12px | **Cards** (`base_card.dart:156`), panels, dialogs, modals |
| `radiusXL` | 16px | Large panels, screens |

Corrected: buttons use `radiusM` (8), not `radiusS`; cards use `radiusL` (12),
not `radiusM`; and `BaseListItem` carries **no** radius at all — it paints
square, matching M3's `ListTile`. The M3 button and icon-button shape is a
`StadiumBorder` (20 dp at the 40 dp container, `filled_button.dart:645` and
`icon_button.dart:1146`), so the 8 dp corner is a registered deviation, not a
conformance.

### Icon Sizes

| Constant | Value | Use Case |
|----------|-------|----------|
| `iconXS` | 12px | Inline indicators, tiny icons |
| `iconS` | 16px | Small buttons, tab icons |
| `iconM` | 20px | Standard icons in lists; the default `BaseIconButton` glyph (`ICO-004`) |
| `iconL` | 24px | Bare `Icon` default; the `BaseIconButton.large` glyph (M3-conforming) |
| `iconXL` | 32px | Headers, emphasis |

Do **not** pass a size to a `BaseButton`/`BaseIconButton` icon — the component
sets it from its `ButtonStyle` (18 dp inside `BaseButton`, 16/20/24 dp inside
`BaseIconButton`). These constants are for icons you place yourself.

Sizes above 32px are expressed as multiples of the scale, e.g.
`AppTheme.iconXL * 2` (64px) for empty-state artwork and drag overlays.

### Git Semantic Colors

Brightness-aware: each role resolves to a light or dark value matching the
active theme (see `GitSemanticColors` in `lib/shared/theme/git_semantic_colors.dart`).

```dart
context.gitColors.added      // Green (added files)
context.gitColors.modified   // Orange (modified files)
context.gitColors.deleted    // Red (deleted files)
context.gitColors.renamed    // Blue (renamed files)
context.gitColors.untracked  // Grey (untracked files)
context.gitColors.conflict   // Pink (merge conflicts)

// Branch colors
context.gitColors.branchLocal   // Green (local branches)
context.gitColors.branchRemote  // Blue (remote branches)
context.gitColors.branchTag     // Orange (tags)
context.gitColors.branchStash   // Purple (stashes)
```

### Examples

```dart
// Spacing
SizedBox(height: AppTheme.paddingM)
Padding(padding: EdgeInsets.all(AppTheme.paddingL))
EdgeInsets.symmetric(horizontal: AppTheme.paddingS, vertical: AppTheme.paddingXS)

// Border radius
BorderRadius.circular(AppTheme.radiusL)
decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.radiusM))

// Icons
Icon(PhosphorIconsRegular.folder, size: AppTheme.iconM)
Icon(PhosphorIconsRegular.gitBranch)  // No size: falls back to IconTheme (24px)

// Colors
color: context.gitColors.modified
backgroundColor: context.gitColors.added
```

---

## 🎯 Decision Trees

### Which Button Variant?

```
Primary action? (Save, Create, Commit)
  → ButtonVariant.primary

Destructive? (Delete, Discard, Remove)
  → ButtonVariant.danger

Cancel/Dismiss?
  → ButtonVariant.tertiary

Alternative action? (Export, View)
  → ButtonVariant.secondary

Subtle action? (Collapse, Minimize)
  → ButtonVariant.ghost

Positive confirmation? (Mark as Good)
  → ButtonVariant.success
```

### Which Dialog Variant?

```
Informational or input? (90% of dialogs)
  → DialogVariant.normal

Requires explicit confirmation?
  → DialogVariant.confirmation

Destructive action? (Delete, Remove)
  → DialogVariant.destructive
```

### Which Typography?

```
Dialog title or main heading?
  → TitleLargeLabel (20px)

Section header?
  → TitleMediumLabel (16px)

List item title or body text?
  → BodyMediumLabel (13px)

List item subtitle?
  → BodySmallLabel (12px)

Timestamp or caption?
  → LabelSmallLabel (11px)
```

### Which Spacing?

```
Icon next to text in same group?
  → AppTheme.paddingXS (4px)

Between related elements? (form fields, buttons)
  → AppTheme.paddingS (8px)

Standard spacing? (default)
  → AppTheme.paddingM (16px)

Between sections?
  → AppTheme.paddingL (24px)

Major breaks? (dialog padding, screen padding)
  → AppTheme.paddingXL (32px)
```

---

## ⚡ Quick Copy-Paste Examples

### Standard Form

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    BaseTextField(
      label: 'Field 1',
      variant: TextFieldVariant.bordered,
    ),
    const SizedBox(height: AppTheme.paddingM),
    BaseTextField(
      label: 'Field 2',
      variant: TextFieldVariant.bordered,
    ),
    const SizedBox(height: AppTheme.paddingL),
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        BaseButton(
          label: 'Cancel',
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: AppTheme.paddingS),
        BaseButton(
          label: 'Submit',
          variant: ButtonVariant.primary,
          onPressed: () => submit(),
        ),
      ],
    ),
  ],
)
```

### Dialog Action Row

```dart
actions: [
  BaseButton(
    label: 'Cancel',
    variant: ButtonVariant.tertiary,
    onPressed: () => Navigator.pop(context),
  ),
  BaseButton(
    label: 'Confirm',
    variant: ButtonVariant.primary,
    onPressed: () {
      performAction();
      Navigator.pop(context);
    },
  ),
]
```

### List Item with Title/Subtitle

```dart
BaseListItem(
  leading: Icon(icon, size: AppTheme.iconM),
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BodyMediumLabel(title, isBold: true),
      const SizedBox(height: AppTheme.paddingXS),
      BodySmallLabel(
        subtitle,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ],
  ),
  trailing: Icon(PhosphorIconsRegular.caretRight),
  onTap: () => action(),
)
```

### Empty State

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: AppTheme.iconXL * 2),
      const SizedBox(height: AppTheme.paddingL),
      TitleLargeLabel(title),
      const SizedBox(height: AppTheme.paddingS),
      BodyMediumLabel(description),
      const SizedBox(height: AppTheme.paddingXL),
      BaseButton(
        label: actionLabel,
        variant: ButtonVariant.primary,
        leadingIcon: actionIcon,
        onPressed: () => action(),
      ),
    ],
  ),
)
```

### Card with Header

```dart
BaseCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: AppTheme.iconM),
          const SizedBox(width: AppTheme.paddingS),
          TitleMediumLabel(title),
        ],
      ),
      const SizedBox(height: AppTheme.paddingM),
      BodyMediumLabel(content),
    ],
  ),
)
```

---

## 📚 See Also

- **UI-CONCEPT.md** - Complete design system documentation (usage)
- **packages/gitui_skin_material/docs/deviation_register.yaml** - Registered
  departures from Material 3.
  Normative and executable; where it and any prose document disagree, the
  register wins. Asserted by `packages/gitui_skin_material/test/conformance/`.
- **ACCESSIBILITY.md** - Accessibility standards, marked Asserted vs Aspirational
- **NAVIGATION-PATTERNS.md** - Screen structure and navigation
- **ERROR-HANDLING-PATTERNS.md** - Error state patterns
- **DESIGN-RATIONALE.md** - Why these decisions were made
- **CONTRIBUTING.md** - Development guidelines

---

**Need a component that's not here?** Check UI-CONCEPT.md or open an issue to extend the design system.
