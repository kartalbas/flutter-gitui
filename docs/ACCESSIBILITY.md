# Accessibility Guidelines

Flutter GitUI is committed to providing an accessible experience for all users. This document outlines our accessibility standards, implementation patterns, and testing procedures.

> **How to read this document.** Every claim below is marked as either
> **Asserted** — a named test in `test/` fails if it stops being true — or
> **Aspirational** — the intent, with nothing enforcing it yet. An earlier
> version of this document asserted WCAG 2.1 AA compliance flatly and
> documented the git status colours as compliant; **that had never been
> measured, and when it finally was, all six roles failed.** The markers exist
> so that mistake cannot be repeated silently. If you add an accessibility
> requirement here, either add the test or mark it Aspirational.

## Table of Contents

1. [WCAG 2.1 AA Compliance](#wcag-21-aa-compliance)
2. [Color and Contrast](#color-and-contrast)
3. [Keyboard Navigation](#keyboard-navigation)
4. [Screen Reader Support](#screen-reader-support)
5. [Touch Targets](#touch-targets)
6. [Focus Indicators](#focus-indicators)
7. [Motion Sensitivity](#motion-sensitivity)
8. [Text Scaling](#text-scaling)
9. [Colorblind Considerations](#colorblind-considerations)
10. [Testing with Assistive Technologies](#testing-with-assistive-technologies)
11. [Accessibility Checklist for PRs](#accessibility-checklist-for-prs)

---

## WCAG 2.1 AA Compliance

Flutter GitUI **targets** WCAG 2.1 Level AA across all features. It has **not**
been audited against WCAG 2.1 AA as a whole, and this document does not claim
that it conforms. What follows is the target, criterion by criterion, with the
current evidence for each.

### Key Success Criteria

| Criterion | Requirement | Status | Evidence |
|---|---|---|---|
| **1.4.3 Contrast (Minimum)** | Text ≥ 4.5:1 | **Asserted for the git semantic palette only** | `test/conformance/a11y/git_colors_contrast_test.dart` |
| **1.4.11 Non-text Contrast** | UI components ≥ 3:1 | **Asserted for the commit-graph lanes only** | same test |
| **2.1.1 Keyboard** | All functionality operable by keyboard | **Asserted for `BaseButton` and `BaseIconButton`** (Tab reaches them, Enter and Space both activate); **Aspirational app-wide** | `test/conformance/components/base_button_conformance_test.dart`, `..._icon_button_...` — group `keyboard operation` |
| **2.1.2 No Keyboard Trap** | Focus can always leave | **Aspirational** — nothing asserts it | — |
| **2.4.7 Focus Visible** | Focus is always visible | **Asserted for `BaseButton`/`BaseIconButton`** (the M3 focus state layer is measured in the ink paint stream); **deliberately absent on `BaseCard`/`BaseListItem`**, whose collection owns the Tab stop — registered as `CARD-003` and `LIST-002`; **Aspirational elsewhere** | same suites, group `keyboard operation`; `docs/deviation_register.yaml` |
| **3.2.4 Consistent Identification** | Components identified consistently | **Aspirational** — enforced socially by the `Base*` layer, not by a test | — |
| **4.1.2 Name, Role, Value** | Name/role/state exposed to AT | **Asserted for `BaseIconButton` with a tooltip** (`labeledTapTargetGuideline`); **Aspirational elsewhere** | `test/conformance/components/base_icon_button_conformance_test.dart` — `the tooltip labels the tap target` |

There is no app-level accessibility audit, no golden-based check, and no use of
Flutter's `textContrastGuideline` anywhere in the suite — the contrast that
*is* measured is measured numerically against the theme, not by sampling
rendered pixels.

### Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)

---

## Color and Contrast

### Text Contrast Requirements

All text must meet minimum contrast ratios:

- **Normal text** (< 18pt / 14pt bold): **4.5:1** minimum
- **Large text** (≥ 18pt / 14pt bold): **3:1** minimum
- **UI components**: **3:1** minimum against adjacent colors

### Implementation

Use Flutter's `ColorScheme`. A tonal `ColorScheme` pairs each `on*` role with
its container so that the pair is contrast-safe **by construction** — but note
that this is a property of the Material colour system, not something this
repository measures: no test in `test/` asserts the contrast of any
`ColorScheme` role pair. Only the git semantic palette below is measured.

```dart
// ✅ DO - use the on* role that belongs to the surface you are painting on
Text(
  'Repository Name',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface, // High contrast
  ),
)

// ✅ DO - Use appropriate contrast levels
BodySmallLabel(
  'Last updated 2 hours ago',
  color: Theme.of(context).colorScheme.onSurfaceVariant, // Medium contrast
)

// ❌ DON'T - Hardcode low-contrast colors
Text(
  'Important message',
  style: TextStyle(color: Colors.grey), // May fail contrast ratio
)
```

### Git Status Colors — **Asserted**

**History, because it is the reason this section is worded the way it is.**
Until the rework, `AppTheme` carried one fixed hex per git role — `gitAdded`
`#4CAF50`, `gitModified` `#FF9800`, `gitDeleted` `#F44336`, `gitRenamed`
`#2196F3`, `gitUntracked` `#9E9E9E`, `gitConflict` `#E91E63` — used
identically in light and dark, and this document described them as WCAG AA
compliant. They were not. When the claim was finally measured, **all six
failed 4.5:1 as text on the light surface**, `gitConflict` failed in **both**
brightnesses, and three of them also missed the looser 3:1 non-text threshold.
The worst case was 1.41:1. One fixed hex per role cannot clear 4.5:1 on both a
near-white and a near-black surface; the problem was structural, not a matter
of picking better greens.

**What exists today.** `GitSemanticColors`
(`lib/shared/theme/git_semantic_colors.dart`) is a `ThemeExtension` carrying a
light and a dark value per role, and `AppTheme` registers the preset matching
the theme's brightness. The values are derived from the previous palette's
hues by HCT tone mapping.

**What is asserted, and by which test.**
`test/conformance/a11y/git_colors_contrast_test.dart` — a single test that
iterates **every** `AppColorScheme` value × **both** brightnesses and checks:

1. every text role holds **≥ 4.5:1** against each of six painted surfaces —
   `scaffoldBackgroundColor`, `surface`, `surfaceContainerLow`,
   `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`;
2. every text role holds **≥ 4.5:1** against its own 12 % tint over
   `surfaceContainerHigh` — the diff-row background
   (`base_diff_viewer.dart`);
3. every text role holds **≥ 4.5:1** against its own 15 % tint over
   `surfaceContainerHighest` — the badge background (`base_badge.dart`);
4. `GitSemanticColors.foregroundOn(role)` — the black-or-white label picked
   for a filled button or badge — holds **≥ 4.5:1** on the solid role colour;
5. all **8** commit-graph lane colours hold **≥ 3:1** against the same six
   surfaces (SC 1.4.11: a 2 px line is a graphic, not text);
6. the theme actually registers the extension, and registers the preset that
   matches its own brightness.

The ratio is computed with the WCAG 2.x formula on relative luminance, and
tints are flattened with `Color.alphaBlend` — i.e. against the colour the
compositor really produces, not against the nominal surface.

```dart
// Access via the BuildContext extension; never hardcode a git colour.
Icon(PhosphorIconsRegular.plus, color: context.gitColors.added)
BodySmallLabel('Modified', color: context.gitColors.modified)
```

| Role | Light | Dark |
|---|---|---|
| added | `#006318` | `#59BC5B` |
| modified | `#7D4800` | `#FF9800` |
| deleted | `#A70007` | `#FF8272` |
| renamed | `#005794` | `#58ACFF` |
| untracked | `#555656` | `#A8A8A8` |
| conflict | `#A40040` | `#FF7E98` |
| branchLocal | `#006318` | `#59BC5B` |
| branchRemote | `#005794` | `#58ACFF` |
| branchTag | `#7D4800` | `#FF9800` |
| branchStash | `#8C10A1` | `#ED76FD` |

Values are `git_semantic_colors.dart:65-110`. The four branch roles are
covered by the same 4.5:1 assertions as the six status roles.

**What is *not* asserted.** The eight lane colours are held to 3:1, not 4.5:1
— they are lines, and must never be the sole carrier of information that is
also needed as text. And the palette's colourblind safety is **Aspirational**:
see [Colorblind Considerations](#colorblind-considerations), which no test
covers.

---

## Keyboard Navigation

All functionality must be accessible via keyboard without requiring a mouse.

> **Asserted:** Tab moves focus onto a `BaseButton`/`BaseIconButton`, the M3
> focus state layer paints, and **Enter and Space each fire `onPressed`**
> (`test/conformance/components/base_button_conformance_test.dart` and
> `..._icon_button_...`, group `keyboard operation`).
>
> **Aspirational — everything else in this section.** No test asserts that
> Escape closes a dialog, that focus is trapped inside a modal, that focus is
> placed when a dialog opens, that Tab order follows reading order, or that
> arrow keys navigate a list or tree. The table and examples below describe
> the intended contract, not a verified one. `BaseCard` and `BaseListItem`
> deliberately do **not** take a Tab stop (`CARD-003`, `LIST-002` in
> `docs/deviation_register.yaml`) — the surrounding collection is the single
> Tab stop and the arrow keys move the highlight within it, so an unfocusable
> row is by design, not a defect.

### Standard Keyboard Shortcuts

| Key | Action | Context |
|-----|--------|---------|
| **Tab** | Move focus forward | Global |
| **Shift+Tab** | Move focus backward | Global |
| **Enter** / **Space** | Activate focused element | Buttons, checkboxes, menu items |
| **Escape** | Close dialog/modal | Dialogs, menus, overlays |
| **Arrow Up/Down** | Navigate list items | Lists, trees, dropdowns |
| **Arrow Left/Right** | Collapse/expand tree nodes | Tree views |
| **Ctrl/Cmd+A** | Select all | Multi-select lists |
| **Delete** / **Backspace** | Delete selected item | File lists (with confirmation) |

### Implementation Examples

#### Tree View with Arrow Key Navigation

```dart
class _GitStatusTreeViewState extends ConsumerState<GitStatusTreeView> {
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() => _selectedIndex = (_selectedIndex + 1).clamp(0, _maxIndex));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() => _selectedIndex = (_selectedIndex - 1).clamp(0, _maxIndex));
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space) {
            _toggleSelection();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ListView.builder(...),
    );
  }
}
```

#### Dialog with Escape Key Handling

```dart
// BaseDialog automatically handles Escape key
await showDialog(
  context: context,
  builder: (context) => BaseDialog(
    title: 'Confirm Delete',
    variant: DialogVariant.destructive,
    content: BodyMediumLabel('This action cannot be undone.'),
    actions: [
      BaseButton(
        label: 'Cancel',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.pop(context), // Also triggered by Escape
      ),
      BaseButton(
        label: 'Delete',
        variant: ButtonVariant.danger,
        onPressed: () => _performDelete(),
      ),
    ],
  ),
);
```

### Tab Order Best Practices

1. **Natural reading order**: Tab order follows visual layout (top-to-bottom, left-to-right)
2. **Skip to main content**: Provide focus shortcuts to bypass navigation
3. **Modal focus trapping**: When dialog opens, focus stays within until dismissed
4. **Logical grouping**: Related controls are adjacent in tab order

---

## Screen Reader Support

All interactive elements must be properly labeled for screen readers.

> **Asserted:** exactly one thing — a `BaseIconButton` carrying a `tooltip`
> satisfies `labeledTapTargetGuideline`
> (`test/conformance/components/base_icon_button_conformance_test.dart`).
>
> **Aspirational:** everything else in this section. No test walks the
> semantics tree of a screen, and no screen reader has been run against a
> build as part of CI. In particular the "Screen reader announces: …" comment
> in the `BaseListItem` example below is an illustration of the intent, not a
> recorded output.

### Semantics Widget Usage

Flutter's `Semantics` widget provides accessibility metadata to screen readers.

#### Button Semantics

```dart
// ✅ BaseButton automatically provides semantics
BaseButton(
  label: 'Commit Changes', // Used as semantic label
  leadingIcon: PhosphorIconsRegular.check,
  onPressed: () => _commit(),
)

// If creating custom widgets, add Semantics manually:
Semantics(
  label: 'Commit Changes',
  button: true,
  enabled: canCommit,
  child: InkWell(
    onTap: canCommit ? _commit : null,
    child: Row(
      children: [
        Icon(PhosphorIconsRegular.check),
        Text('Commit Changes'),
      ],
    ),
  ),
)
```

#### List Item Semantics

```dart
// ✅ BaseListItem provides automatic semantics
BaseListItem(
  leading: Icon(PhosphorIconsRegular.gitBranch),
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BodyMediumLabel('feature/new-ui', isBold: true),
      BodySmallLabel('Updated 2 hours ago'),
    ],
  ),
  isSelected: isSelected,
  onTap: () => _selectBranch(),
)

// Screen reader announces: "feature/new-ui, Updated 2 hours ago, selected, button"
```

#### Status Indicators

```dart
// Add semantic descriptions for visual-only information
Row(
  children: [
    Semantics(
      label: '5 files modified',
      child: Badge(
        label: '5',
        backgroundColor: context.gitColors.modified,
      ),
    ),
    Semantics(
      label: '2 files added',
      child: Badge(
        label: '2',
        backgroundColor: context.gitColors.added,
      ),
    ),
  ],
)
```

#### Images and Icons

```dart
// Decorative icons - exclude from screen reader
Semantics(
  excludeSemantics: true, // Screen reader skips this
  child: Icon(PhosphorIconsRegular.folder),
)

// Meaningful icons - provide label
Semantics(
  label: 'Error: Failed to fetch',
  child: Icon(PhosphorIconsRegular.warning, color: context.gitColors.deleted),
)
```

### Semantic Labels Best Practices

1. **Be descriptive**: "Delete branch 'feature/login'" not "Delete"
2. **Include state**: "Selected", "Expanded", "Disabled"
3. **Avoid redundancy**: Don't repeat visible text unnecessarily
4. **Use sentence case**: "Commit changes" not "COMMIT CHANGES"
5. **Context-aware**: Provide enough context to understand the action

---

## Touch Targets

All interactive elements must meet minimum touch target sizes.

### Minimum Size Requirements

The two platform figures are **44×44** (iOS HIG,
`flutter_test/lib/src/accessibility.dart:800-801`, `iOSTapTargetGuideline`)
and **48×48** (Android/Material,
`flutter_test/lib/src/accessibility.dart:785-786`,
`androidTapTargetGuideline`; the same value as
`kMinInteractiveDimension = 48.0`, `flutter/lib/src/material/constants.dart:27`).

**This app enforces the stricter 48×48**, not 44×44. An earlier version of
this section named 44×44 as the requirement and 48×48 as merely "recommended";
that undersold what the suite actually checks and would let a 44 dp control
pass review while failing the test.

- **Minimum touch target**: **48×48 logical pixels** — `androidTapTargetGuideline`
- **Spacing between targets**: At least **8px** to prevent mis-taps
  (*Aspirational* — no test measures spacing)

### Implementation

**Asserted.** Both button components pass `meetsGuideline(androidTapTargetGuideline)`
at **every** `ButtonSize`, and the `small` size is additionally checked to keep
its compact painted container *inside* a ≥ 48 dp hit area:

- `test/conformance/components/base_button_conformance_test.dart` — group `tap targets`
- `test/conformance/components/base_icon_button_conformance_test.dart` — group `tap targets`

This is the distinction that matters: the *painted container* is 32 / 40 / 48
dp (registered as `BTN-002`, `BTN-005`, `ICO-002`, `ICO-005` in
`docs/deviation_register.yaml`), while the *layout box* is inflated to ≥ 48 dp
by Material's padded tap-target mechanism. A component that hard-codes a
`Container(width:, height:)` instead of delegating to `ButtonStyleButton`
discards that mechanism and ships a sub-48 dp target — which is exactly how
the pre-rework `BaseIconButton` came to have no call site meeting the minimum.

```dart
// ✅ Asserted: BaseButton's hit area is >= 48x48 at every size
BaseButton(
  label: 'Save',
  variant: ButtonVariant.primary,
  onPressed: () => _save(),
)

// ⚠️ Aspirational: BaseListItem's height is NOT covered by a tap-target
// assertion. The suite measures its M3 minimum tile height (56 dp, matching
// ListTile) but does not run meetsGuideline on it.
BaseListItem(
  leading: Icon(PhosphorIconsRegular.file),
  content: BodyMediumLabel('README.md'),
  onTap: () => _openFile(),
)

// For custom widgets, size the hit area to 48, not 44:
SizedBox(
  width: 48,
  height: 48,
  child: InkWell(
    onTap: () => _action(),
    child: Icon(PhosphorIconsRegular.x),
  ),
)
```

### Icon-Only Buttons

Icon buttons without text labels require extra care:

**Asserted:** `BaseIconButton` with a `tooltip` passes
`meetsGuideline(labeledTapTargetGuideline)`
(`test/conformance/components/base_icon_button_conformance_test.dart` — `the
tooltip labels the tap target`). A `BaseIconButton` **without** a tooltip has
no asserted label; the tooltip is what supplies it.

```dart
// ✅ DO - Tooltip + Semantics + Minimum size
Tooltip(
  message: 'Close panel',
  child: Semantics(
    label: 'Close panel',
    button: true,
    child: SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        onTap: () => _closePanel(),
        child: Icon(PhosphorIconsRegular.x),
      ),
    ),
  ),
)

// ❌ DON'T - Too small, no label
IconButton(
  icon: Icon(PhosphorIconsRegular.x, size: 16),
  onPressed: () => _closePanel(),
  // No tooltip, no semantic label, potentially too small
)
```

---

## Focus Indicators

Keyboard focus must be clearly visible at all times.

> **Asserted for the two button components only.** After Tab, `BaseButton` and
> `BaseIconButton` paint the Material 3 **focus state layer** — the focus
> overlay colour at **10 %**, read back out of the ink paint stream and
> compared against the SDK oracle (`_FilledButtonDefaultsM3.overlayColor`,
> Flutter 3.44.4 `filled_button.dart:574`; `_IconButtonDefaultsM3`,
> `icon_button.dart:1106`). See the `keyboard operation` group in each suite.
>
> **Aspirational for everything else**, and the 2 px-border pattern shown
> below is a *different* mechanism from the M3 state layer. Use the state
> layer that the component's `ButtonStyle` already supplies wherever one
> exists; hand-rolling a border is for containers that genuinely have no
> `ButtonStyle`.

### Default Focus Behavior

Flutter provides focus indicators through the component's `ButtonStyle`
overlay. A bare `InkWell` with no style falls back to `ThemeData.focusColor`
(12 % black/white, `theme_data.dart:467`), which is **not** an M3 focus state
layer — see `docs/UI-CONCEPT.md` §3.5.

### Custom Focus Indicators

```dart
// BaseButton automatically provides focus indicators
// For custom widgets:
class CustomWidget extends StatefulWidget {
  @override
  State<CustomWidget> createState() => _CustomWidgetState();
}

class _CustomWidgetState extends State<CustomWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: InkWell(onTap: () => _action()),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
```

### Focus Visibility Standards — **Aspirational**

House style for containers that must draw their own focus ring. No test
measures any of these four numbers, and none of them is a Material 3 token.

- **Width**: At least **2px** border or outline
- **Color**: High contrast (typically `colorScheme.primary`)
- **Offset**: **2-4px** from element edge (for clarity)
- **Shape**: Follows element's border radius

---

## Motion Sensitivity

Users with vestibular disorders or motion sensitivity need reduced motion options.

### AppAnimationSpeed System

Flutter GitUI provides four animation speed settings:

```dart
enum AppAnimationSpeed {
  none,    // 0ms - no animation (accessibility)
  fast,    // 0.7x speed - quicker feel
  normal,  // 1.0x speed - default
  slow,    // 1.5x speed - easier to follow
}
```

### Respecting User Preferences

```dart
// ✅ Always use AppTheme animation helpers
AnimatedContainer(
  duration: context.standardAnimation, // Respects user preference
  curve: Curves.easeInOut,
  height: isExpanded ? 200 : 0,
)

// ✅ Use AppAnimationSpeed directly
final animSpeed = ref.watch(uiConfigProvider).animationSpeed;
AnimatedOpacity(
  duration: AppTheme.getStandardAnimation(animSpeed),
  opacity: isVisible ? 1.0 : 0.0,
  child: content,
)

// ❌ DON'T - Hardcoded duration ignores user preference
AnimatedContainer(
  duration: Duration(milliseconds: 250), // Always animates
  height: isExpanded ? 200 : 0,
)
```

### When to Disable Animations

Even with `AppAnimationSpeed.none`, some animations should remain:

- **Progress indicators**: Spinning loaders (indicates activity)
- **Live updates**: Real-time data changes
- **Drag feedback**: Visual feedback during drag operations

Disable for:

- **Page transitions**: Instant navigation
- **Dialogs**: Instant open/close
- **Hover effects**: Instant state changes
- **Expand/collapse**: Instant size changes

```dart
// Check for animation preference
final shouldAnimate = animSpeed != AppAnimationSpeed.none;

if (shouldAnimate) {
  // Animated transition
  Navigator.push(context, PageRouteBuilder(...));
} else {
  // Instant transition
  Navigator.push(context, MaterialPageRoute(...));
}
```

---

## Text Scaling — **Aspirational**

Respect user font size preferences at the system level. Nothing in `test/`
renders the app at an increased text scale, so no claim in this section is
verified.

### Flutter's Text Scaling Support

Flutter automatically scales text when users change system font size settings.

### Testing Text Scaling

```dart
// Test with different text scale factors.
// Note: MediaQueryData.textScaleFactor is deprecated in current Flutter;
// use TextScaler.
MaterialApp(
  builder: (context, child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2.0), // 200% scale
      ),
      child: child!,
    );
  },
)
```

### Best Practices

1. **Avoid fixed heights**: Use `intrinsicHeight` or `mainAxisSize: MainAxisSize.min`
2. **Flexible layouts**: Use `Flexible`, `Expanded` to adapt to text size
3. **Test at 200% scale**: Ensure UI doesn't break
4. **Minimum font size**: the smallest size the app can render is
   `labelSmall` at `AppFontSize.tiny` — 11 × 0.85 = **9px**, not the "10px
   minimum" this line used to claim (`app_theme.dart:231-236` for the factor,
   `:371-376` for the role)

```dart
// ✅ DO - Flexible layout adapts to text scale
Column(
  mainAxisSize: MainAxisSize.min, // Adapts to content
  children: [
    BodyMediumLabel('This text can scale up'),
    BaseButton(label: 'Action'), // Button height adapts
  ],
)

// ❌ DON'T - Fixed height clips scaled text
SizedBox(
  height: 40, // Fixed - clips text at large scale
  child: BodyMediumLabel('This might clip'),
)
```

### Font Size Settings

Users can configure app font size independently. The setting is a **single
multiplier** applied to every role's `medium` size and rounded to whole
logical pixels — not a fixed pixel offset, and the `medium` column is **not**
the Material 3 default (`app_theme.dart:231-236` and `:264-378`; the
departures from M3 are registered as `TYPE-001`..`TYPE-009` in
`docs/deviation_register.yaml` and asserted by
`test/conformance/theme/text_theme_conformance_test.dart`).

```dart
enum AppFontSize {
  tiny,    // ×0.85
  small,   // ×0.92
  medium,  // ×1.00 (this app's baseline, not the M3 baseline)
  large,   // ×1.10
}
```

Worked example for the two most common body roles:

| Role | tiny | small | medium | large | M3 default |
|---|---|---|---|---|---|
| `bodyLarge` | 13 | 14 | **15** | 17 | 16 |
| `bodyMedium` | 11 | 12 | **13** | 14 | 14 |

The old "-3px / -2px / 16px / +2px" description of this enum was wrong in
every column.

---

## Colorblind Considerations — **Aspirational**

Git semantic colors are *intended* to work for most types of colorblindness.

### Why Git Colors Work

**This has never been measured.** No test simulates a colour-vision
deficiency, and `test/conformance/a11y/git_colors_contrast_test.dart` checks
luminance contrast against surfaces only — it says nothing about whether two
git roles are distinguishable *from each other* under any deficiency. The
three lines below are design intent, not a result:

- **Protanopia** (red-weak): Green vs. blue are distinguishable
- **Deuteranopia** (green-weak): Orange vs. blue are distinguishable
- **Tritanopia** (blue-weak): Red vs. green are distinguishable

Because this is unverified, the "Color + Icon" rule immediately below is not a
nicety — it is the only thing actually protecting these users.

### Color + Icon Strategy

Never rely on color alone. Always pair color with an icon or text label:

```dart
// ✅ DO - Color + Icon + Text
Row(
  children: [
    Icon(PhosphorIconsRegular.plus, color: context.gitColors.added),
    SizedBox(width: AppTheme.paddingXS),
    BodySmallLabel('Added', color: context.gitColors.added),
  ],
)

// ❌ DON'T - Color only
Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(
    color: context.gitColors.added, // No context without icon/text
    shape: BoxShape.circle,
  ),
)
```

### File Status Icons

Each git status has a unique icon:

- **Added**: `PhosphorIconsRegular.plus` (Green)
- **Modified**: `PhosphorIconsRegular.pencil` (Orange)
- **Deleted**: `PhosphorIconsRegular.trash` (Red)
- **Renamed**: `PhosphorIconsRegular.arrowsLeftRight` (Blue)
- **Conflict**: `PhosphorIconsRegular.warning` (Pink)

---

## Testing with Assistive Technologies

### Screen Reader Testing

#### macOS - VoiceOver

1. Enable: **System Preferences → Accessibility → VoiceOver → Enable**
2. Shortcut: **Cmd+F5** to toggle
3. Navigate: **VO+Right/Left Arrow** (VO = Ctrl+Option)

#### Windows - NVDA (Free)

1. Download: [nvaccess.org](https://www.nvaccess.org/)
2. Enable: **Ctrl+Alt+N** to start
3. Navigate: **Arrow keys** or **Tab**

#### Test Checklist

- [ ] All buttons announce their label
- [ ] List items announce title and state (selected/unselected)
- [ ] Form fields announce label and validation errors
- [ ] Dialogs announce title when opened
- [ ] Focus moves logically through UI
- [ ] No "unlabeled" or "button" announcements

### Keyboard Navigation Testing

Test without using mouse:

1. **Tab through entire UI**: Can you reach every interactive element?
2. **Activate elements**: Do Enter/Space work on all buttons?
3. **Close dialogs**: Does Escape dismiss modals?
4. **Navigate lists**: Do arrow keys work in trees/lists?
5. **Focus visibility**: Is focus indicator always visible?

### Contrast Ratio Testing

Use browser DevTools or online tools:

- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Chrome DevTools: **Elements → Styles → Color Picker → Contrast Ratio**

### Color Blindness Simulation

- [Coblis - Color Blindness Simulator](https://www.color-blindness.com/coblis-color-blindness-simulator/)
- macOS: **System Preferences → Accessibility → Display → Color Filters**

---

## Accessibility Checklist for PRs

Before submitting a PR with UI changes, verify:

### Required

- [ ] **Keyboard navigation**: All actions accessible via Tab/Enter/Escape
- [ ] **Screen reader labels**: All interactive elements have meaningful labels
      (for an icon-only control, that means a `tooltip`)
- [ ] **Touch targets**: Minimum **48×48px** for all tappable elements — the
      `androidTapTargetGuideline` value the suite enforces, not the 44×44 this
      checklist used to name
- [ ] **Focus indicators**: Visible focus states on all interactive elements,
      *except* rows and cards inside a collection that owns the Tab stop
      (`CARD-003`, `LIST-002`)
- [ ] **Color contrast**: Text meets 4.5:1, non-text UI meets 3:1
- [ ] **Animation speed**: Animations use `AppTheme.getAnimation*()` helpers
- [ ] **Base* components**: Using wrapper components (no raw Material widgets)
- [ ] **Theme colors**: Using `ColorScheme` (no hardcoded colors)
- [ ] **If a `Base*` component or the theme changed**:
      `flutter test test/conformance/` is green — that is the only part of
      this checklist a machine verifies

### Recommended

- [ ] **Text scaling**: Test at 200% text scale factor
- [ ] **Screen reader test**: Test with VoiceOver/NVDA
- [ ] **Keyboard-only test**: Navigate entire flow without mouse
- [ ] **Motion sensitivity**: Test with `AppAnimationSpeed.none`
- [ ] **Dark mode**: Test in both light and dark themes
- [ ] **Color blind test**: Verify icons/text supplement color

### Documentation

- [ ] **Accessibility notes**: Document any custom keyboard shortcuts
- [ ] **Screen reader guidance**: Note complex interactions for screen reader users
- [ ] **Known limitations**: Document any temporary accessibility gaps

---

## Resources

### Guidelines

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design/overview)
- [Apple Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

### Tools

- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [axe DevTools](https://www.deque.com/axe/devtools/) (Browser extension)
- [Color Oracle](https://colororacle.org/) (Color blindness simulator)

### Testing

- [NVDA Screen Reader](https://www.nvaccess.org/) (Windows - Free)
- [JAWS Screen Reader](https://www.freedomscientific.com/products/software/jaws/) (Windows - Paid)
- [VoiceOver](https://www.apple.com/accessibility/voiceover/) (macOS/iOS - Built-in)
- [TalkBack](https://support.google.com/accessibility/android/answer/6283677) (Android - Built-in)

---

## Questions?

For accessibility questions or to report accessibility issues, please:

1. Check this guide first — and note whether the relevant claim is marked
   **Asserted** or **Aspirational**
2. Review `docs/UI-CONCEPT.md` §5.2 for component patterns and the conformance
   suite, and `docs/deviation_register.yaml` for approved departures
3. Open a GitHub issue with label `accessibility`
4. Include details about the assistive technology used (screen reader, keyboard, etc.)

Accessibility is everyone's responsibility. Thank you for helping make Flutter GitUI inclusive for all users!
