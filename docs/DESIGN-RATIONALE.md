# Design Rationale

This document explains the "why" behind Flutter GitUI's design system, component architecture, and UI patterns.

---

## Why Base* Components Exist

### The Problem

In typical Flutter applications, you encounter these issues:

1. **Inconsistent styling** - Buttons look different across screens
2. **Repeated code** - Same dialog structure copy-pasted everywhere
3. **No single source of truth** - Padding values hardcoded throughout
4. **Difficult updates** - Changing button styles requires updating hundreds of files
5. **Poor accessibility** - Missing tooltips, labels, keyboard support

### The Solution: Base Components

Flutter GitUI uses a component system inspired by design systems like Material-UI and Chakra UI:

```
Base Components (lib/shared/components/)
├── base_button.dart          # All button variants
├── base_dialog.dart          # All dialog variants
├── base_label.dart           # Typography system
├── base_list_item.dart       # List item patterns
├── base_panel.dart           # Container patterns
└── base_card.dart            # Card patterns
```

### Benefits

**1. Single Source of Truth**
```dart
// ❌ Before: Inconsistent buttons
ElevatedButton(
  onPressed: () => save(),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: Text('Save'),
)

// ✅ After: Consistent buttons
BaseButton(
  label: 'Save',
  variant: ButtonVariant.primary,
  onPressed: () => save(),
)
```

**2. Enforced Patterns**
```dart
// Base components enforce accessibility and best practices
BaseButton(
  label: 'Delete',                        // Required label
  variant: ButtonVariant.danger,          // Semantic variant
  leadingIcon: PhosphorIconsRegular.trash, // Consistent icons
  isLoading: isDeleting,                  // Built-in loading state
  onPressed: isDeleting ? null : () => delete(), // Auto-disabled when loading
)
```

**3. Easy Updates**
```dart
// Update all buttons in one place by changing BaseButton implementation
// No need to hunt through hundreds of files
```

### The Philosophy: "Extend, Don't Bypass"

Base components are designed to be **extended**, not bypassed:

```dart
// ✅ Good: Extend base components
class DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DeleteButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BaseButton(
      label: 'Delete',
      variant: ButtonVariant.danger,
      leadingIcon: PhosphorIconsRegular.trash,
      onPressed: onPressed,
    );
  }
}

// ❌ Bad: Bypass base components
ElevatedButton(
  onPressed: onPressed,
  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  child: Row(
    children: [
      Icon(Icons.delete),
      SizedBox(width: 8),
      Text('Delete'),
    ],
  ),
)
```

**When to Extend vs. Use Directly:**

| Scenario | Approach | Example |
|----------|----------|---------|
| One-off button | Use `BaseButton` directly | Submit button in form |
| Repeated pattern | Extend to create specialized component | `DeleteButton`, `SaveButton` |
| Feature-specific | Create in feature's widgets/ | `CreateBranchButton` in branches/ |
| App-wide pattern | Add to shared/components/ | `BaseButton`, `BaseDialog` |

### Examples from Codebase

**BaseButton** - 7 variants covering all use cases:
```dart
enum ButtonVariant {
  primary,          // Filled primary - main actions
  secondary,        // Outlined - secondary actions
  tertiary,         // Text only - subtle actions
  danger,           // Red filled - destructive actions
  dangerSecondary,  // Red outlined - destructive secondary
  ghost,            // Transparent - toolbar buttons
  success,          // Green - positive confirmations
}
```

**BaseDialog** - 3 variants covering all cases:
```dart
enum DialogVariant {
  normal,       // Standard informational dialog
  confirmation, // Yes/No with question icon
  destructive,  // Warning with red accent
}
```

**BaseListItem** - Unified list item with selection states:
```dart
BaseListItem(
  content: /* any widget */,
  leading: /* optional icon/avatar */,
  trailing: /* optional actions */,
  isSelected: true,        // Primary selection (current item)
  isMultiSelected: true,   // Secondary selection (batch ops)
  contextMenuItems: [/* popup menu */],
  onTap: () => /* action */,
)
```

---

## Why This Spacing Scale

Flutter GitUI uses Material Design 3's **4dp base unit** spacing scale:

```dart
static const double paddingXS = 4.0;   // Tight spacing (chips, badges)
static const double paddingS  = 8.0;   // Small gaps (icon-text, list items)
static const double paddingM  = 16.0;  // Standard spacing (default)
static const double paddingL  = 24.0;  // Section spacing (cards, panels)
static const double paddingXL = 32.0;  // Page margins (dialog padding)
```

### Why These Specific Values?

**1. Material Design 3 Compliance**

Material Design 3 specifies 4dp as the base unit for all measurements. This creates a consistent rhythm:
- 4dp = 1 unit
- 8dp = 2 units
- 16dp = 4 units
- 24dp = 6 units
- 32dp = 8 units

**2. Visual Hierarchy**

The scale creates clear visual separation:

```dart
// ❌ Random spacing - no hierarchy
Padding(padding: EdgeInsets.all(7))    // Why 7?
Padding(padding: EdgeInsets.all(13))   // Why 13?
Padding(padding: EdgeInsets.all(19))   // Why 19?

// ✅ Systematic spacing - clear hierarchy
Padding(padding: EdgeInsets.all(AppTheme.paddingS))   // Small gap
Padding(padding: EdgeInsets.all(AppTheme.paddingM))   // Standard gap
Padding(padding: EdgeInsets.all(AppTheme.paddingL))   // Section gap
```

**3. Mathematical Consistency**

Each step is 2x or 1.5x the previous:
- XS → S: 2x (4 → 8)
- S → M: 2x (8 → 16)
- M → L: 1.5x (16 → 24)
- L → XL: 1.33x (24 → 32)

This creates noticeable but not jarring differences.

**4. Accessibility**

Material Design's 4dp grid ensures touch targets meet minimum size requirements:
- Minimum **hit area**: 48x48dp (12 units) — `kMinInteractiveDimension = 48.0`,
  Flutter 3.44.4 `packages/flutter/lib/src/material/constants.dart:27`.
  Asserted for `BaseButton` and `BaseIconButton` at every size by
  `meetsGuideline(androidTapTargetGuideline)` in
  `test/conformance/components/base_button_conformance_test.dart` and
  `..._icon_button_conformance_test.dart`.
- Icon buttons, **painted container**: 32 / 40 / 48 dp for small / medium /
  large. The M3 container is a single 40 dp
  (`_IconButtonDefaultsM3.minimumSize`, `icon_button.dart:1128`), so the 32
  and the 48 are registered deviations `ICO-002` and `ICO-005`. The container
  is smaller than the hit area on purpose — Material's padded tap target
  inflates the layout box while the paint stays compact.
- Icon buttons, **glyph**: **16 / 20 / 24** px for small / medium / large, not
  a flat 24. M3 specifies 24 for all sizes
  (`_IconButtonDefaultsM3.iconSize`, `icon_button.dart:1138`); the 16 and the
  20 are registered as `ICO-003` and `ICO-004`. Only `ButtonSize.large`
  carries the conforming 24 (`AppTheme.iconL`). The earlier line here —
  "Icon buttons: 40x40dp with a 24px icon" — described neither the default
  size nor the default glyph correctly.

### Usage Guidelines

```dart
// Component internal spacing (tight)
SizedBox(width: AppTheme.paddingXS)  // Between icon and text
SizedBox(height: AppTheme.paddingS)  // Between form fields

// Standard spacing (most common)
SizedBox(height: AppTheme.paddingM)  // Between sections
EdgeInsets.all(AppTheme.paddingM)    // Default padding

// Section spacing (separation)
SizedBox(height: AppTheme.paddingL)  // Between major sections
EdgeInsets.all(AppTheme.paddingL)    // Screen padding

// Page-level spacing (emphasis)
SizedBox(height: AppTheme.paddingXL) // Dialog/modal spacing
EdgeInsets.all(AppTheme.paddingXL)   // Large container padding
```

---

## Why These Dialog Variants

Flutter GitUI has exactly **3 dialog variants** - no more, no less:

```dart
enum DialogVariant {
  normal,        // Standard informational
  confirmation,  // Yes/No decision
  destructive,   // Dangerous action
}
```

### Why Only 3?

**1. Cognitive Load**

Research shows humans can easily distinguish between 3-5 visual variants. More than that causes decision fatigue.

**2. Coverage Analysis**

We analyzed all dialog use cases and found they fall into 3 categories:

| Variant | Purpose | Color | Icon | Example |
|---------|---------|-------|------|---------|
| **normal** | Information | Primary | Custom or none | "About", "Help" |
| **confirmation** | Get decision | Primary | Question | "Create branch?", "Save changes?" |
| **destructive** | Warn about consequences | Error | Warning | "Delete branch?", "Discard all?" |

**3. Automatic Styling**

Each variant has automatic defaults:

```dart
// Confirmation dialog
BaseDialog(
  title: 'Create Branch?',
  variant: DialogVariant.confirmation,
  // Automatically gets:
  // - Question icon
  // - Primary color
  // - OK/Cancel buttons (if you add them)
)

// Destructive dialog
BaseDialog(
  title: 'Delete All?',
  variant: DialogVariant.destructive,
  // Automatically gets:
  // - Warning icon
  // - Error color (red)
  // - Delete/Cancel buttons (if you add them)
)
```

### Why Not More Variants?

**Rejected Variants:**

| Variant | Why Rejected | Use Instead |
|---------|--------------|-------------|
| `info` | Same as `normal` | Use `normal` with info icon |
| `warning` | Same as `destructive` | Use `destructive` |
| `success` | Dialogs aren't for success | Use SnackBar notification |
| `error` | Dialogs aren't for errors | Use error state component |

**Design Principle:** Dialogs interrupt the user's flow. They should only be used for:
1. Getting input/confirmation (confirmation variant)
2. Warning about consequences (destructive variant)
3. Showing information that requires acknowledgment (normal variant)

For transient feedback (success, errors), use SnackBars instead.

### Real Examples

```dart
// ✅ Good: Confirmation variant
final confirmed = await BaseDialog.show<bool>(
  context: context,
  dialog: BaseDialog(
    title: 'Stage All Changes?',
    variant: DialogVariant.confirmation,
    content: Text('Stage all 15 unstaged files?'),
    actions: [
      BaseButton(label: 'Cancel', variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context, false)),
      BaseButton(label: 'Stage All', variant: ButtonVariant.primary,
                onPressed: () => Navigator.pop(context, true)),
    ],
  ),
);

// ✅ Good: Destructive variant
final confirmed = await BaseDialog.show<bool>(
  context: context,
  dialog: BaseDialog(
    title: 'Discard All Changes?',
    variant: DialogVariant.destructive,
    content: Text('This action cannot be undone.'),
    actions: [
      BaseButton(label: 'Cancel', variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context, false)),
      BaseButton(label: 'Discard', variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true)),
    ],
  ),
);

// ✅ Good: Normal variant
await BaseDialog.show(
  context: context,
  dialog: BaseDialog(
    title: 'About Flutter GitUI',
    variant: DialogVariant.normal,
    icon: PhosphorIconsRegular.info,
    content: Column(children: [/* about info */]),
    actions: [
      BaseButton(label: 'Close', variant: ButtonVariant.primary,
                onPressed: () => Navigator.pop(context)),
    ],
  ),
);
```

---

## Why Opacity Standards

Flutter GitUI uses **Material Design 3 opacity standards** for interaction states:

```dart
// Hover on a container (a tonal step, NOT an opacity — see below)
backgroundColor: colorScheme.surfaceContainerHighest

// Disabled content (M3: onSurface at 38%, filled_button.dart:559)
foregroundColor: colorScheme.onSurface.withValues(alpha: 0.38)

// Selection: change the colour role, do not tint
backgroundColor: colorScheme.secondaryContainer

// Subtle hints (this app's convention, not an M3 token)
hintColor: colorScheme.onSurface.withValues(alpha: 0.6)
```

### Why These Specific Values?

**1. Material Design 3 Specification**

**The table that stood here was wrong**, and it was wrong in the two rows a
reviewer is most likely to check: it gave focus as 16 % and pressed/selection
as 12 %. Material 3 uses neither. These are the values as generated into the
Flutter SDK the app builds against (3.44.4,
`packages/flutter/lib/src/material/`):

| State | Opacity | SDK source |
|-------|---------|---|
| Hover | **0.08** | `filled_button.dart:571`, `icon_button.dart:1103` |
| Focus | **0.10** | `filled_button.dart:574`, `icon_button.dart:1106` |
| Pressed | **0.10** | `filled_button.dart:568`, `icon_button.dart:1100` |
| Disabled container | **0.12** on `onSurface` | `filled_button.dart:550` |
| Disabled content | **0.38** on `onSurface` | `filled_button.dart:559` |
| Selected | *no opacity at all* | selection changes the **colour role** — `secondaryContainer` for a navigation indicator (`navigation_bar.dart:1463`), `primary` for a selected `IconButton` foreground (`icon_button.dart:1080`) |

`0.16` is not a Material 3 value. It survives in the framework only in
Material-2 code paths that M3 does not use (`button_theme.dart:583`,
`toggle_buttons.dart:961,971`).

The 60 % and 70 % rows were never state-layer values either; they are this
app's own hint- and helper-text conventions, not M3 tokens, and nothing
measures them.

**2. Accessibility**

The two WCAG claims that stood here — "38% disabled = 4.5:1" and "60% hints =
4.5:1+" — were **asserted without ever being measured, and are not true as
stated**. Nothing in `test/` measures either one.

What is actually the case:

- **Disabled content at 38 % does not reach 4.5:1** against a light surface,
  and is not required to. WCAG 2.1 SC 1.4.3 exempts "text or images of text
  that are part of an **inactive** user interface component", and SC 1.4.11
  carries the same exemption for inactive components. The 38 % is Material 3's
  disabled treatment (`filled_button.dart:559`), and this app conforms to it —
  that conformance is asserted by
  `test/conformance/components/base_button_conformance_test.dart`
  (`BaseButton.disabled.foregroundColor`). It is a *conformance* result, not a
  contrast result.
- **Hint text at 60 % is not exempt** — placeholder text is live text and must
  clear 4.5:1. **This is unverified**: no test measures it, and it is close
  enough to the threshold that it must be measured rather than assumed.
- **Selection contrast is unverified.** Selection is a container-role change,
  so the relevant check is the `on*` pairing of that container, which nothing
  in `test/` measures.

The only contrast this repository actually asserts is the git semantic
palette; see `docs/ACCESSIBILITY.md`.

**3. Visual Feedback**

The progression creates noticeable but not jarring feedback:

```dart
// ❌ Bad: Random opacities
.withValues(alpha: 0.45)  // Why 45%?
.withValues(alpha: 0.23)  // Why 23%?

// ✅ Good: Standard opacities
.withValues(alpha: 0.38)  // Disabled (MD3 standard)
.withValues(alpha: 0.60)  // Hint (MD3 standard)
```

### Usage in Components

**BaseListItem** - Multiple selection states:
```dart
Color? backgroundColor;
if (widget.isSelected) {
  // Selected: use secondaryContainer (colored background)
  backgroundColor = colorScheme.secondaryContainer;
} else if (widget.isMultiSelected) {
  // Multi-selected: use tertiaryContainer (different color)
  backgroundColor = colorScheme.tertiaryContainer;
} else if (_isHovered && widget.isSelectable) {
  // Hover: one step up the tonal ladder, not an alpha tint
  backgroundColor = colorScheme.surfaceContainerHighest;
}
```

**BaseButton** - Disabled state. The component no longer paints this itself;
it delegates to `FilledButton`/`OutlinedButton`/`TextButton`, so the M3
disabled treatment applies unchanged — container `onSurface` at **12 %**
(`filled_button.dart:550`), content `onSurface` at **38 %**
(`filled_button.dart:559`). Both are asserted as conforming by
`test/conformance/components/base_button_conformance_test.dart` (tokens
`BaseButton.disabled.containerColor` and `BaseButton.disabled.foregroundColor`).

The snippet that used to stand here showed a `surfaceContainerHighest`
disabled container, which was the pre-rework hand-painted behaviour and is
**not** the M3 treatment:

```dart
// ❌ Historical, no longer the implementation
backgroundColor = colorScheme.surfaceContainerHighest;
// ✅ What M3 specifies, and what the component now renders
backgroundColor = colorScheme.onSurface.withValues(alpha: 0.12);
foregroundColor = colorScheme.onSurface.withValues(alpha: 0.38);
```

**Input Fields** - Hint text:
```dart
inputDecorationTheme: InputDecorationTheme(
  hintStyle: theme.textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurface.withValues(alpha: 0.6), // 60% hint
  ),
)
```

### Why Not Custom Opacities?

**Rejected approach:**
```dart
// ❌ Avoid custom opacities
.withValues(alpha: 0.45)  // Custom, not standard
.withValues(alpha: 0.75)  // Custom, not standard
```

**Problems with custom opacities:**
1. Not tested for accessibility
2. Don't match Material Design expectations
3. Create visual inconsistency
4. Harder to maintain

**Better approach:**
```dart
// ✅ Use MD3 surface containers instead of an alpha blend
backgroundColor: colorScheme.surfaceContainerLow
backgroundColor: colorScheme.surfaceContainer
backgroundColor: colorScheme.surfaceContainerHigh
backgroundColor: colorScheme.surfaceContainerHighest
```

The "5% / 8% / 11% / 12% blend" annotations that used to sit beside these
roles were invented. Surface containers are not alpha blends at all — they are
**tones of the neutral palette**, at tone 96 / 94 / 92 / 90 in light and
10 / 12 / 17 / 22 in dark (`material_color_utilities` 0.13.0,
`lib/dynamiccolor/material_dynamic_colors.dart:117-159`). That is why the
ladder still separates correctly in dark mode, where an alpha blend of the
same percentages would not.

---

## Why Git Semantic Colors

Flutter GitUI uses **color psychology** for git status indicators:

The **hue** choices below are still the rationale. The **values** are not:
the `AppTheme.gitAdded`/`branchLocal`/… constants listed here no longer exist,
and the single-hex-per-role design they embodied was abandoned because it
could not hold WCAG AA in both brightnesses. The current palette is
`GitSemanticColors` in `lib/shared/theme/git_semantic_colors.dart`, a
brightness-aware `ThemeExtension` with a light and a dark value per role
(`:65-110`), reached through `context.gitColors`.

```dart
// ❌ Historical — these constants were removed
static const Color gitAdded     = Color(0xFF4CAF50); // Green
static const Color gitModified  = Color(0xFFFF9800); // Orange
static const Color gitDeleted   = Color(0xFFF44336); // Red
static const Color gitRenamed   = Color(0xFF2196F3); // Blue
static const Color gitUntracked = Color(0xFF9E9E9E); // Grey
static const Color gitConflict  = Color(0xFFE91E63); // Pink/Magenta

// ✅ Current — one value per role per brightness
context.gitColors.added      // #006318 light / #59BC5B dark
context.gitColors.modified   // #7D4800 light / #FF9800 dark
context.gitColors.deleted    // #A70007 light / #FF8272 dark
context.gitColors.renamed    // #005794 light / #58ACFF dark
context.gitColors.untracked  // #555656 light / #A8A8A8 dark
context.gitColors.conflict   // #A40040 light / #FF7E98 dark
```

### Color Psychology

**Green (Added, Local Branch)**
- Meaning: Growth, addition, safety, go
- Why: Files added are "new growth" in the repository
- Psychology: Positive, non-threatening, encouraging

**Orange (Modified, Tag)**
- Meaning: Caution, change, attention
- Why: Files changed need attention (review changes)
- Psychology: Warning without alarm, "proceed with awareness"

**Red (Deleted)**
- Meaning: Removal, danger, stop
- Why: Files deleted are gone (destructive)
- Psychology: High attention, permanent action

**Blue (Renamed, Remote Branch)**
- Meaning: Information, transformation, remote/cloud
- Why: Renamed = transformed, remote = elsewhere
- Psychology: Calm, trustworthy, distant

**Grey (Untracked)**
- Meaning: Neutral, unimportant, inactive
- Why: Untracked files aren't part of repository yet
- Psychology: Low priority, backgrounded

**Pink/Magenta (Conflict)**
- Meaning: Error, requires immediate action
- Why: Conflicts must be resolved before proceeding
- Psychology: Urgent but not destructive (not red)

### Why These Exact Shades?

**Material Design Palette (historical):**

The removed constants were the Material 500 shades — Green 500 `#4CAF50`,
Orange 500 `#FF9800`, Red 500 `#F44336`, Blue 500 `#2196F3`, Grey 500
`#9E9E9E`, Pink 500 `#E91E63`. The current values keep those **hues** but move
their **tone** per brightness, via HCT tone mapping, so that the contrast
requirement can actually be met.

**Accessibility:**

The claim that used to stand here — "All colors meet WCAG AA contrast ratios:
against white 3:1+, against dark 7:1+" — was **false, and had never been
measured**. When measured, all six status roles failed 4.5:1 as text on the
light surface, `gitConflict` failed in both brightnesses, three also missed
the looser 3:1 non-text threshold, and the worst case was **1.41:1**. A 500
shade is tuned to be vivid, not to be readable as text on a near-white
surface; the two goals conflict.

What is true today, and is **asserted** by
`test/conformance/a11y/git_colors_contrast_test.dart` across every selectable
scheme and both brightnesses:

- every text role holds **≥ 4.5:1** on all six painted surfaces, on its own
  12 % diff-row tint and on its own 15 % badge tint;
- the black-or-white foreground chosen for a filled badge or button holds
  **≥ 4.5:1** on the solid role colour;
- the eight commit-graph lane colours hold **≥ 3:1** (SC 1.4.11 — a 2 px line
  is a graphic, not text).

See `docs/ACCESSIBILITY.md` for the full breakdown.

**Colorblind-Friendly — unverified:**

The palette is *intended* to work for the common deficiencies (deuteranopia,
protanopia, tritanopia), but **nothing measures this**: no test simulates a
colour-vision deficiency, and the contrast test compares each role against
*surfaces*, never against another role. Treat the "Color + Icon" rule in
`docs/ACCESSIBILITY.md` as the actual safeguard.

### Usage Examples

```dart
// File status indicator
Icon(
  PhosphorIconsRegular.file,
  color: _getStatusColor(context, file.status),
)

Color _getStatusColor(BuildContext context, FileChangeType status) {
  final colors = context.gitColors;
  switch (status) {
    case FileChangeType.added:
      return colors.added;      // Green
    case FileChangeType.modified:
      return colors.modified;   // Orange
    case FileChangeType.deleted:
      return colors.deleted;    // Red
    case FileChangeType.renamed:
      return colors.renamed;    // Blue
    case FileChangeType.untracked:
      return colors.untracked;  // Grey
    case FileChangeType.conflicted:
      return colors.conflict;   // Pink
  }
}

// Branch type indicator
Icon(
  PhosphorIconsRegular.gitBranch,
  color: branch.isLocal
      ? context.gitColors.branchLocal   // Green
      : context.gitColors.branchRemote  // Blue
)
```

---

## Why Typography Hierarchy

Flutter GitUI uses a **desktop-tuned derivative** of the Material Design 3
type scale, with enhanced rendering.

**The block that used to stand here listed the M3 sizes and presented them as
the app's sizes. They are not the same numbers.** Nine of the fifteen roles
render smaller than M3 specifies. Both columns below are asserted, role by
role, by `test/conformance/theme/text_theme_conformance_test.dart`, which
measures `AppTheme.lightTheme().textTheme` against
`Typography.englishLike2021` (Flutter 3.44.4
`packages/flutter/lib/src/material/typography.dart:2096-2112`).

| Role | **This app** (`AppFontSize.medium`) | Material 3 | Register |
|---|---|---|---|
| `displayLarge` | **45** | 57 | `TYPE-001` |
| `displayMedium` | **36** | 45 | `TYPE-002` |
| `displaySmall` | **32** | 36 | `TYPE-003` |
| `headlineLarge` | **28** | 32 | `TYPE-004` |
| `headlineMedium` | **24** | 28 | `TYPE-005` |
| `headlineSmall` | **22** | 24 | `TYPE-006` |
| `titleLarge` | **20** | 22 | `TYPE-007` |
| `titleMedium` | 16 | 16 | conforms |
| `titleSmall` | 14 | 14 | conforms |
| `bodyLarge` | **15** | 16 | `TYPE-008` |
| `bodyMedium` | **13** | 14 | `TYPE-009` |
| `bodySmall` | 12 | 12 | conforms |
| `labelLarge` | 14 | 14 | conforms |
| `labelMedium` | 12 | 12 | conforms |
| `labelSmall` | 11 | 11 | conforms |

App values are `lib/shared/theme/app_theme.dart:286-377`; the reasons for each
reduction are in `docs/deviation_register.yaml` under the `TYPE-*` ids. Every
role keeps the M3 `letterSpacing` and line `height` unchanged — only the size
moves.

### Why a derivative rather than the M3 scale verbatim?

**1. Tested hierarchy, phone-first proportions**

The M3 scale is well tested, but it is tuned for phone hero surfaces at
phone viewing distance. On a dense desktop Git client a 57 px display line
dwarfs the rows around it. The reductions preserve the *ramp* — each role
stays strictly larger than the one below it — while compressing the top of it.

**2. Mathematical progression**

The app's ramp, medium setting:
- 11 → 12 → 13 → 14 → 15 → 16 → 20 → 22 → 24 → 28 → 32 → 36 → 45

(The M3 ramp, for comparison, is 11 → 12 → 14 → 16 → 22 → 24 → 28 → 32 → 36 →
45 → 57.)

**3. Optical sizing**

- **Tiny (11px)**: Dense information (badges, timestamps)
- **Small (12-14px)**: Body text, captions
- **Medium (15-22px)**: Titles, emphasized text
- **Large (24-36px)**: Headers, section dividers
- **Display (36-45px)**: Hero content, branding

### Enhanced Rendering

Flutter GitUI adds font features for better rendering:

```dart
final fontFeatures = <FontFeature>[
  const FontFeature.enable('kern'), // Kerning (letter spacing)
  const FontFeature.enable('liga'), // Ligatures (fi, fl)
  const FontFeature.enable('clig'), // Contextual ligatures
];

// For monospace fonts (code)
const FontFeature.enable('zero'),   // Slashed zero (0 vs O)
```

**Why these features?**

| Feature | Purpose | Example |
|---------|---------|---------|
| `kern` | Better letter spacing | "AWAY" looks natural, not "A W A Y" |
| `liga` | Combined glyphs | "fi" → "fi" (one glyph) |
| `clig` | Context-aware ligatures | "=>" → "⇒" in code |
| `zero` | Distinguish 0 from O | "O0O" → "O0O" (clear difference) |

### BaseLabel Components

Instead of using `Text()` directly, use semantic label components:

```dart
// ✅ Good: Semantic labels
TitleLargeLabel('Section Header')      // titleLarge style
TitleMediumLabel('Card Title')         // titleMedium style
BodyMediumLabel('Standard text')       // bodyMedium style
BodySmallLabel('Caption text')         // bodySmall style
LabelSmallLabel('Badge text')          // labelSmall style

// ❌ Bad: Direct Text widgets
Text('Section Header', style: TextStyle(fontSize: 22))  // Inconsistent
Text('Caption', style: Theme.of(context).textTheme.bodySmall)  // Verbose
```

**Benefits:**
1. Consistent styling across app
2. Automatic color from theme
3. Single place to update all labels
4. Type-safe (catch typos at compile time)

### Font Size Settings

Users can adjust font size while maintaining hierarchy:

The setting is a **single multiplier** applied to every role's medium size and
rounded to whole logical pixels (`app_theme.dart:231-236`, `:279`) — not a
fixed pixel offset, and `medium` is this app's baseline, not the M3 baseline:

```dart
enum AppFontSize {
  tiny,    // x0.85
  small,   // x0.92
  medium,  // x1.00 - this app's baseline (see the table above)
  large,   // x1.10 - accessibility
}

// Hierarchy is maintained at all sizes, e.g. bodyMedium / titleLarge /
// headlineLarge:
// Medium: 13px body -> 20px title -> 28px headline
// Large:  14px body -> 22px title -> 31px headline
```

The factors are chosen so that after rounding no two settings collapse to the
same pixel size for any role.

---

## "Extend, Don't Bypass" Philosophy

This is the core principle of Flutter GitUI's component system.

### What It Means

**Extend** = Build on top of base components
```dart
// ✅ Extend: Create specialized components using base components
class SaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const SaveButton({this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return BaseButton(
      label: 'Save',
      variant: ButtonVariant.primary,
      leadingIcon: PhosphorIconsRegular.floppyDisk,
      isLoading: isLoading,
      onPressed: onPressed,
    );
  }
}
```

**Bypass** = Ignore base components and use Flutter widgets directly
```dart
// ❌ Bypass: Using Flutter widgets directly
ElevatedButton(
  onPressed: onPressed,
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: Row(
    children: [
      Icon(Icons.save),
      SizedBox(width: 8),
      Text('Save'),
    ],
  ),
)
```

### When to Extend

Create a specialized component when:

1. **Pattern repeats 3+ times**
```dart
// If you write this 3 times, extract it
BaseButton(
  label: 'Delete',
  variant: ButtonVariant.danger,
  leadingIcon: PhosphorIconsRegular.trash,
  onPressed: onPressed,
)

// Becomes
class DeleteButton extends StatelessWidget { /* ... */ }
```

2. **Business logic is embedded**
```dart
// ✅ Good: Extract confirmation logic
class ConfirmDeleteButton extends StatelessWidget {
  final String itemName;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return BaseButton(
      label: 'Delete',
      variant: ButtonVariant.danger,
      onPressed: () => _confirmAndDelete(context),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDestructiveDialog(
      context: context,
      title: 'Delete $itemName?',
      message: 'This action cannot be undone.',
    );
    if (confirmed) onConfirmed();
  }
}
```

3. **Feature-specific styling**
```dart
// ✅ Good: Feature-specific component
class BranchListTile extends StatelessWidget {
  final GitBranch branch;

  @override
  Widget build(BuildContext context) {
    return BaseListItem(
      leading: Icon(
        branch.isLocal
            ? PhosphorIconsRegular.folder
            : PhosphorIconsRegular.cloud,
        color: branch.isLocal
            ? context.gitColors.branchLocal
            : context.gitColors.branchRemote,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitleMediumLabel(branch.name),
          if (branch.upstream != null)
            BodySmallLabel('Tracks: ${branch.upstream}'),
        ],
      ),
      isSelected: branch.isCurrent,
    );
  }
}
```

### When to Use Base Components Directly

Use base components directly when:

1. **One-off usage** - Button appears only once
2. **Already specialized** - BaseButton with custom parameters is enough
3. **Prototype/experiment** - Not sure if pattern will repeat

```dart
// ✅ Good: Direct usage for one-off
BaseButton(
  label: 'Export Debug Log',
  variant: ButtonVariant.secondary,
  leadingIcon: PhosphorIconsRegular.export,
  onPressed: () => exportLog(),
)
```

### When Bypass is Acceptable

There are **rare cases** where bypassing is okay:

1. **Platform-specific features**
```dart
// ✅ Acceptable: Using platform-specific widget
if (Platform.isWindows) {
  return WindowsNativeButton(...); // No base equivalent
}
```

2. **Third-party integration**
```dart
// ✅ Acceptable: Third-party package requires specific widget
return DragTarget(  // From desktop_drop package
  builder: (context, candidateData, rejectedData) {
    return BaseButton(...); // Still use base components inside
  },
)
```

3. **Performance optimization**
```dart
// ✅ Acceptable: Performance-critical code
return CustomPaint(  // Direct rendering for performance
  painter: DiffViewerPainter(...),
)
```

### Examples from Codebase

**Good Extension:**
```dart
// lib/features/branches/widgets/branch_list_tile.dart
class BranchListTile extends StatelessWidget {
  final GitBranch branch;

  @override
  Widget build(BuildContext context) {
    return BaseListItem(  // ✅ Extends BaseListItem
      content: _buildContent(),
      leading: _buildIcon(),
      isSelected: branch.isCurrent,
      contextMenuItems: _buildContextMenu(),
    );
  }
}
```

**Good Direct Usage:**
```dart
// lib/features/settings/settings_screen.dart
BaseButton(  // ✅ Direct usage (one-off)
  label: 'Reset to Defaults',
  variant: ButtonVariant.dangerSecondary,
  onPressed: () => _resetDefaults(),
)
```

### Anti-Patterns to Avoid

**❌ Don't wrap in unnecessary abstraction:**
```dart
// ❌ Bad: Pointless wrapper
class MyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BaseButton(  // Adds no value
      label: label,
      onPressed: onPressed,
    );
  }
}

// ✅ Good: Just use BaseButton directly
BaseButton(label: 'Click', onPressed: () {})
```

**❌ Don't copy-paste Base component code:**
```dart
// ❌ Bad: Copying BaseButton implementation
class CustomButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(  // Duplicates BaseButton logic
      color: Colors.blue,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(label),
        ),
      ),
    );
  }
}

// ✅ Good: Extend BaseButton instead
class CustomButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseButton(
      label: label,
      variant: ButtonVariant.primary,
      onPressed: onPressed,
    );
  }
}
```

### Summary

The "Extend, Don't Bypass" philosophy ensures:
- ✅ Consistent UI across the app
- ✅ Single source of truth for updates
- ✅ Enforced accessibility and best practices
- ✅ Easier maintenance and refactoring
- ✅ New developers can onboard faster
- ✅ Design system is self-documenting

**Golden Rule:** If you're about to use `ElevatedButton`, `AlertDialog`, or `Text` directly, ask yourself: "Is there a Base* component for this?" The answer is usually yes.
