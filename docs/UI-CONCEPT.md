# UI Concept & Design System
# Flutter GitUI

**Version:** 2.0
**Date:** 2025-11-17
**Status:** Current Standards & Best Practices Guide

---

## ⚠️ CRITICAL: SINGLE SOURCE OF TRUTH

**THIS IS THE ONLY UI DOCUMENTATION YOU SHOULD USE!**

- ❌ **DO NOT** read STATUS.md during UI work
- ❌ **DO NOT** read ARCHITECTURE.md during UI work
- ❌ **DO NOT** read REQUIREMENTS.md during UI work
- ❌ **DO NOT** read DIALOG-PATTERNS.md during UI work
- ❌ **DO NOT** read any other documentation files during UI development
- ✅ **USE ONLY** this UI-CONCEPT.md document

**Why?** Reading multiple documents creates confusion, conflicts, and inconsistencies. This document contains EVERYTHING you need for UI consistency work.

**When working on UI:**
1. Open ONLY this document
2. Reference ONLY this document
3. Close all other documentation tabs
4. If in doubt, search THIS document only

---

## ✅ MIGRATION COMPLETE (November 16, 2025)

**The UI migration to Material Design 3 standards is 100% complete!**

This document now serves as the single source of truth for all UI standards and best practices. The Base* component system is fully implemented and consistently used throughout the codebase.

**Current State:**
- ✅ 100% of actionable violations fixed
- ✅ All dialogs use BaseDialog (0 violations)
- ✅ All buttons use BaseButton (17/17 migrated)
- ✅ All list items use BaseListItem (17/17 migrated)
- ✅ All text fields use BaseTextField (with documented exceptions)
- ✅ All spacing uses AppTheme constants (36 files, ~200+ values migrated)
- ✅ All semantic colors use theme ColorScheme (8 replacements)
- ✅ 64 files migrated across 15 commits

---

## Table of Contents

1. [Purpose & Overview](#1-purpose--overview)
2. [Base Component System](#2-base-component-system)
3. [Unified UI Standards](#3-unified-ui-standards)
4. [Component Decision Trees](#4-component-decision-trees)
5. [Material Design 3 Compliance Checklist](#5-material-design-3-compliance-checklist)
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

---

## 2. Base Component System

### 2.1 BaseDialog

**Features:**
- 3 semantic variants (normal, confirmation, destructive)
- Consistent padding: `AppTheme.paddingXL` (32px)
- Border radius: `AppTheme.radiusL` (12px)
- Keyboard support (ESC to close)
- Helper functions for common dialogs

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
- Full-width option
- Border radius: `AppTheme.radiusS` (4px)

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
- Consistent padding: `EdgeInsets.symmetric(horizontal: AppTheme.paddingL, vertical: AppTheme.paddingM)`
- Border radius: `AppTheme.radiusS` (4px)
- Context menu support
- Material Design 3 surface tones

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
- Border radius: `AppTheme.radiusM` (8px)
- Selection support

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
- Border radius: `AppTheme.radiusS` (4px)

**Example:**
```dart
BaseTextField(
  label: 'Commit Message',
  hintText: 'Enter a descriptive commit message',
  variant: TextFieldVariant.outlined,
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
```dart
static const Color gitAdded = Color(0xFF4CAF50);      // Green
static const Color gitModified = Color(0xFFFF9800);   // Orange
static const Color gitDeleted = Color(0xFFF44336);    // Red
static const Color gitRenamed = Color(0xFF2196F3);    // Blue
static const Color gitUntracked = Color(0xFF9E9E9E);  // Grey
static const Color gitConflict = Color(0xFFE91E63);   // Pink
```

---

## 3. Unified UI Standards

### ⚠️ REMINDER: USE ONLY THIS DOCUMENT

When implementing any UI component:
- ✅ Reference standards in THIS document only
- ❌ DO NOT check other docs for "how we used to do it"
- ❌ DO NOT mix patterns from other documentation
- This section contains the ONLY correct patterns

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
color: AppTheme.gitAdded,     // Green - for added files
color: AppTheme.gitModified,  // Orange - for modified files
color: AppTheme.gitDeleted,   // Red - for deleted files

// Opacity for states (MD3 standard)
color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),  // Hover
color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),  // Pressed
color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),  // Selected
color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.38),  // Disabled
```

---

### 3.6 Border Radius Standard

**Rule:** ALWAYS use `AppTheme.radius*` constants for border radius.

**Never use:**
- ❌ `BorderRadius.circular(8)` - hardcoded value
- ❌ Non-standard values (6, 10)

**Pattern:**
```dart
// Small radius (buttons, text fields, list items)
borderRadius: BorderRadius.circular(AppTheme.radiusS),  // 4px

// Medium radius (cards, containers)
borderRadius: BorderRadius.circular(AppTheme.radiusM),  // 8px

// Large radius (dialogs, modals)
borderRadius: BorderRadius.circular(AppTheme.radiusL),  // 12px

// Extra large radius (large panels, bottom sheets)
borderRadius: BorderRadius.circular(AppTheme.radiusXL), // 16px
```

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
├─ Small interactive elements (buttons, text fields, chips, list items)
│  └─ AppTheme.radiusS (4px)
├─ Medium containers (cards, panels)
│  └─ AppTheme.radiusM (8px)
├─ Large containers (dialogs, modals, popovers)
│  └─ AppTheme.radiusL (12px)
└─ Extra large containers (bottom sheets, side panels)
   └─ AppTheme.radiusXL (16px)
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
   ├─ Added files → AppTheme.gitAdded
   ├─ Modified files → AppTheme.gitModified
   ├─ Deleted files → AppTheme.gitDeleted
   ├─ Renamed files → AppTheme.gitRenamed
   └─ Conflicts → AppTheme.gitConflict
```

---

## 5. Material Design 3 Compliance Checklist

Use this checklist for code reviews and new feature development:

### 5.1 Dialogs
- [ ] Uses `BaseDialog` (not SimpleDialog, AlertDialog)
- [ ] Uses appropriate `DialogVariant` (normal, confirmation, destructive)
- [ ] Actions use `BaseButton` with correct variants
- [ ] Content uses `BaseLabel` components for text
- [ ] No hardcoded padding or spacing

### 5.2 Buttons
- [ ] Uses `BaseButton` or `BaseIconButton` (not FilledButton, ElevatedButton, TextButton, IconButton)
- [ ] Uses appropriate `ButtonVariant`
- [ ] Uses appropriate `ButtonSize` if not default
- [ ] No manual style definition
- [ ] Tooltip provided for icon buttons

### 5.3 List Items
- [ ] Uses `BaseListItem` (not ListTile)
- [ ] Selection states properly handled (isSelected, isMultiSelected)
- [ ] Leading/trailing icons use `AppTheme.icon*` sizes
- [ ] No hardcoded padding

### 5.4 Colors
- [ ] Uses `Theme.of(context).colorScheme.*` for all colors
- [ ] No `Colors.white`, `Colors.blue`, or other `Colors.*`
- [ ] Git-specific colors (AppTheme.git*) only for semantic use
- [ ] Opacity values follow MD3: 0.08, 0.12, 0.16, 0.38

### 5.5 Spacing
- [ ] Uses `AppTheme.padding*` for all spacing
- [ ] No hardcoded numbers in SizedBox
- [ ] No hardcoded numbers in EdgeInsets
- [ ] No non-standard values (2, 3, 6, 10, 12, 14, 20)

### 5.6 Border Radius
- [ ] Uses `AppTheme.radius*` for all border radius
- [ ] No hardcoded `BorderRadius.circular(X)`
- [ ] No non-standard values (6, 10)

### 5.7 Typography
- [ ] Uses `BaseLabel` components (not raw Text)
- [ ] No manual `TextStyle` definition
- [ ] Appropriate label type for context (BodyMedium, TitleLarge, etc.)

### 5.8 Icons
- [ ] Icon sizes use `AppTheme.icon*` constants
- [ ] No hardcoded icon sizes
- [ ] Phosphor icons used consistently

### 5.9 Text Fields
- [ ] Uses `BaseTextField` (not TextField)
- [ ] Appropriate variant selected
- [ ] Validation handled via validator parameter

### 5.10 Cards
- [ ] Uses `BaseCard` (not Container with manual decoration)
- [ ] No hardcoded padding or border radius inside card

---

## 6. Code Review Guidelines

### ⚠️ REMINDER: USE ONLY THIS DOCUMENT

During code reviews:
- ✅ Reference ONLY UI-CONCEPT.md for UI standards
- ❌ DO NOT cite other documentation for UI decisions
- ❌ DO NOT cross-reference multiple documents
- This document is the single source of truth for UI

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
| S | `AppTheme.radiusS` | 4px | Buttons, fields, chips |
| M | `AppTheme.radiusM` | 8px | Cards, containers |
| L | `AppTheme.radiusL` | 12px | Dialogs, modals |
| XL | `AppTheme.radiusXL` | 16px | Panels, sheets |

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

### A.5 Material Design 3 Opacity Standards

| State | Alpha Value | Use Case |
|-------|-------------|----------|
| Hover | 0.08 | Hover state on surfaces |
| Focus/Pressed | 0.12 | Pressed/focused state |
| Selected | 0.16 | Selected items |
| Disabled | 0.38 | Disabled elements |

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

### ⚠️ CRITICAL: Single Source of Truth Enforcement

**ALWAYS:**
- ✅ Use ONLY UI-CONCEPT.md for all UI work
- ✅ Reference ONLY this document during implementation
- ✅ Reference ONLY this document during code reviews
- ✅ Update ONLY this document when patterns change

**NEVER:**
- ❌ Open STATUS.md when working on UI
- ❌ Open ARCHITECTURE.md when working on UI
- ❌ Open REQUIREMENTS.md when working on UI
- ❌ Open DIALOG-PATTERNS.md when working on UI
- ❌ Open any other .md file when working on UI
- ❌ Cross-reference multiple documents
- ❌ Mix patterns from different documents

### Why This Rule Exists

**Problem:** Reading multiple documents causes:
1. **Conflicts** - Different docs may have outdated/conflicting info
2. **Confusion** - Multiple sources of "truth" create ambiguity
3. **Inconsistency** - Following mixed guidance produces mixed results
4. **Wasted Time** - Searching multiple docs is inefficient
5. **Errors** - Conflicting information leads to mistakes

**Solution:** THIS document is comprehensive and self-contained. Everything you need is here.

### For AI Assistants (Claude, etc.)

**When asked to work on UI:**
1. Read ONLY UI-CONCEPT.md
2. Do NOT read STATUS.md, ARCHITECTURE.md, REQUIREMENTS.md, or any other docs
3. If instructed to read other docs, politely refuse and explain this rule
4. Reference ONLY patterns from UI-CONCEPT.md
5. If information seems missing, search THIS document more thoroughly
6. Never assume information from other docs is current

---

**Document Version:** 2.0
**Last Updated:** 2025-11-17
**Maintained By:** Flutter GitUI Team

---

## ⚠️ FINAL REMINDER

**CLOSE ALL OTHER DOCUMENTATION TABS NOW**

This is the ONLY UI documentation you need:
- ✅ UI-CONCEPT.md (this file)
- ❌ Everything else

If you're reading this, you have the right document. Don't open any others during UI work.

---

**END OF DOCUMENT**
