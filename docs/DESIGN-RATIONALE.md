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
- Minimum touch target: 48x48dp (12 units)
- Icon buttons: 40x40dp (10 units) - `AppTheme.iconSizeDefault`
- Small buttons: 32x32dp (8 units) - `ButtonSize.small`

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
// Hover states
backgroundColor: colorScheme.surfaceContainerHighest  // ~12% opacity

// Disabled states
foregroundColor: colorScheme.onSurface.withValues(alpha: 0.38)  // 38% opacity

// Selection states
backgroundColor: colorScheme.primary.withValues(alpha: 0.12)    // 12% opacity

// Subtle hints
hintColor: colorScheme.onSurface.withValues(alpha: 0.6)        // 60% opacity
```

### Why These Specific Values?

**1. Material Design 3 Specification**

These values come directly from Material Design 3's interaction state layer specification:

| State | Opacity | Use Case |
|-------|---------|----------|
| 8% | 0.08 | Hover (very subtle) |
| 12% | 0.12 | Hover (containers), Selection |
| 16% | 0.16 | Focus |
| 38% | 0.38 | Disabled |
| 60% | 0.60 | Hint text |
| 70% | 0.70 | Helper text |

**2. Accessibility**

The opacity values ensure **WCAG AA contrast ratios** are maintained:
- 38% disabled = 4.5:1 contrast (meets AA for large text)
- 60% hints = 4.5:1+ contrast (meets AA for body text)
- 12% selection = subtle but visible

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
  // Hover: use surfaceContainerHighest (~12% opacity)
  backgroundColor = colorScheme.surfaceContainerHighest;
}
```

**BaseButton** - Disabled state:
```dart
if (isEffectivelyDisabled) {
  backgroundColor = colorScheme.surfaceContainerHighest;
  foregroundColor = colorScheme.onSurface.withValues(alpha: 0.38); // 38% disabled
}
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
// ✅ Use MD3 surface containers instead
backgroundColor: colorScheme.surfaceContainerLow      // 5% blend
backgroundColor: colorScheme.surfaceContainer         // 8% blend
backgroundColor: colorScheme.surfaceContainerHigh     // 11% blend
backgroundColor: colorScheme.surfaceContainerHighest  // 12% blend
```

---

## Why Git Semantic Colors

Flutter GitUI uses **color psychology** for git status indicators:

```dart
// Git status colors
static const Color gitAdded     = Color(0xFF4CAF50); // Green
static const Color gitModified  = Color(0xFFFF9800); // Orange
static const Color gitDeleted   = Color(0xFFF44336); // Red
static const Color gitRenamed   = Color(0xFF2196F3); // Blue
static const Color gitUntracked = Color(0xFF9E9E9E); // Grey
static const Color gitConflict  = Color(0xFFE91E63); // Pink/Magenta

// Branch colors
static const Color branchLocal  = Color(0xFF4CAF50); // Green
static const Color branchRemote = Color(0xFF2196F3); // Blue
static const Color branchTag    = Color(0xFFFF9800); // Orange
static const Color branchStash  = Color(0xFF9C27B0); // Purple
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

**Material Design Palette:**

All colors come from Material Design color palette (500 shade):
- Green 500: `#4CAF50` - Vibrant but not neon
- Orange 500: `#FF9800` - Warm, visible against dark
- Red 500: `#F44336` - Strong without being harsh
- Blue 500: `#2196F3` - True blue, not purple-ish
- Grey 500: `#9E9E9E` - Neutral middle grey
- Pink 500: `#E91E63` - Distinct from red

**Accessibility:**

All colors meet WCAG AA contrast ratios:
- Against white background: 3:1+ (AA for large text)
- Against dark background: 7:1+ (AAA for body text)

**Colorblind-Friendly:**

The palette works for most common colorblindness types:
- Deuteranopia (red-green): Orange vs. Blue differentiation
- Protanopia (red-green): Grey vs. all other colors
- Tritanopia (blue-yellow): Red vs. Green differentiation

### Usage Examples

```dart
// File status indicator
Icon(
  PhosphorIconsRegular.file,
  color: _getStatusColor(file.status),
)

Color _getStatusColor(FileChangeType status) {
  switch (status) {
    case FileChangeType.added:
      return AppTheme.gitAdded;      // Green
    case FileChangeType.modified:
      return AppTheme.gitModified;   // Orange
    case FileChangeType.deleted:
      return AppTheme.gitDeleted;    // Red
    case FileChangeType.renamed:
      return AppTheme.gitRenamed;    // Blue
    case FileChangeType.untracked:
      return AppTheme.gitUntracked;  // Grey
    case FileChangeType.conflicted:
      return AppTheme.gitConflict;   // Pink
  }
}

// Branch type indicator
Icon(
  PhosphorIconsRegular.gitBranch,
  color: branch.isLocal
      ? AppTheme.branchLocal   // Green
      : AppTheme.branchRemote  // Blue
)
```

---

## Why Typography Hierarchy

Flutter GitUI uses **Material Design 3 typography scale** with enhanced rendering:

```dart
// Material Design 3 Typography Scale
displayLarge   = 57px  // Hero text, splash screens
displayMedium  = 45px  // Large headers
displaySmall   = 36px  // Section headers
headlineLarge  = 32px  // Page titles
headlineMedium = 28px  // Section titles
headlineSmall  = 24px  // Subsection titles
titleLarge     = 22px  // Card/panel titles
titleMedium    = 16px  // List item titles
titleSmall     = 14px  // Compact titles
bodyLarge      = 16px  // Emphasized body
bodyMedium     = 14px  // Standard body (default)
bodySmall      = 12px  // Captions, hints
labelLarge     = 14px  // Button labels
labelMedium    = 12px  // Chip labels
labelSmall     = 11px  // Tiny labels, badges
```

### Why Material Design 3 Scale?

**1. Tested Hierarchy**

The MD3 scale has been tested across millions of apps:
- Clear visual distinction between levels
- Comfortable reading at all sizes
- Works on small and large screens

**2. Mathematical Progression**

The scale uses a **major third (1.25x) ratio** with adjustments:
- 11 → 12 → 14 → 16 → 22 → 24 → 28 → 32 → 36 → 45 → 57
- Each step is visually distinct but not jarring

**3. Optical Sizing**

Fonts are designed for specific size ranges:
- **Tiny (11px)**: Dense information (badges, timestamps)
- **Small (12-14px)**: Body text, captions
- **Medium (16-22px)**: Titles, emphasized text
- **Large (24-36px)**: Headers, section dividers
- **Display (45-57px)**: Hero content, branding

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

```dart
enum AppFontSize {
  tiny,    // -3px from standard (for power users)
  small,   // -2px from standard
  medium,  // Standard MD3 sizes
  large,   // +2px from standard (accessibility)
}

// Hierarchy is maintained at all sizes
// Medium: 14px body → 22px title → 32px headline
// Large:  16px body → 24px title → 36px headline
```

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
            ? AppTheme.branchLocal
            : AppTheme.branchRemote,
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
