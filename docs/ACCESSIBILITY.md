# Accessibility Guidelines

Flutter GitUI is committed to providing an accessible experience for all users. This document outlines our accessibility standards, implementation patterns, and testing procedures.

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

Flutter GitUI targets **WCAG 2.1 Level AA** compliance across all features.

### Key Success Criteria

- **1.4.3 Contrast (Minimum)**: Text has a contrast ratio of at least 4.5:1
- **1.4.11 Non-text Contrast**: UI components have a contrast ratio of at least 3:1
- **2.1.1 Keyboard**: All functionality is operable via keyboard
- **2.1.2 No Keyboard Trap**: Users can navigate away using only keyboard
- **2.4.7 Focus Visible**: Keyboard focus is always visible
- **3.2.4 Consistent Identification**: Components are identified consistently
- **4.1.2 Name, Role, Value**: UI components expose name, role, state to assistive tech

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

Use Flutter's `ColorScheme` for automatic contrast-safe colors:

```dart
// ✅ DO - Theme colors automatically meet contrast requirements
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

### Git Status Colors

Our semantic git colors (green, orange, red, blue) are designed with sufficient contrast for both light and dark themes:

```dart
// All git colors meet 3:1 contrast ratio
AppTheme.gitAdded      // Green - #4CAF50
AppTheme.gitModified   // Orange - #FF9800
AppTheme.gitDeleted    // Red - #F44336
AppTheme.gitRenamed    // Blue - #2196F3
AppTheme.gitConflict   // Pink - #E91E63
```

These colors work for most types of colorblindness (see [Colorblind Considerations](#colorblind-considerations)).

---

## Keyboard Navigation

All functionality must be accessible via keyboard without requiring a mouse.

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
        backgroundColor: AppTheme.gitModified,
      ),
    ),
    Semantics(
      label: '2 files added',
      child: Badge(
        label: '2',
        backgroundColor: AppTheme.gitAdded,
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
  child: Icon(PhosphorIconsRegular.warning, color: AppTheme.gitDeleted),
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

- **Minimum touch target**: **44×44 logical pixels** (iOS HIG, Android Material)
- **Comfortable touch target**: **48×48 logical pixels** (recommended)
- **Spacing between targets**: At least **8px** to prevent mis-taps

### Implementation

```dart
// ✅ BaseButton automatically enforces minimum touch targets
BaseButton(
  label: 'Save',
  variant: ButtonVariant.primary,
  onPressed: () => _save(),
  // Internal padding ensures 44×44px minimum, even for small labels
)

// ✅ BaseListItem has minimum 48px height
BaseListItem(
  leading: Icon(PhosphorIconsRegular.file),
  content: BodyMediumLabel('README.md'),
  onTap: () => _openFile(),
  // Automatically enforces 48×44px minimum
)

// For custom widgets, wrap in SizedBox with constraints:
SizedBox(
  width: 44,
  height: 44,
  child: InkWell(
    onTap: () => _action(),
    child: Icon(PhosphorIconsRegular.x),
  ),
)
```

### Icon-Only Buttons

Icon buttons without text labels require extra care:

```dart
// ✅ DO - Tooltip + Semantics + Minimum size
Tooltip(
  message: 'Close panel',
  child: Semantics(
    label: 'Close panel',
    button: true,
    child: SizedBox(
      width: 44,
      height: 44,
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

### Default Focus Behavior

Flutter automatically provides focus indicators, but they must be visible and high-contrast.

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

### Focus Visibility Standards

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

## Text Scaling

Respect user font size preferences at the system level.

### Flutter's Text Scaling Support

Flutter automatically scales text when users change system font size settings.

### Testing Text Scaling

```dart
// Test with different text scale factors
MaterialApp(
  builder: (context, child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 2.0, // Test at 200% scale
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
4. **Minimum font size**: Respect `AppFontSize.tiny` (10px minimum)

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

Users can configure app font size independently:

```dart
enum AppFontSize {
  tiny,    // -3px from standard (13px body text)
  small,   // -2px from standard (14px body text)
  medium,  // Material Design 3 standard (16px body text)
  large,   // +2px from standard (18px body text)
}
```

---

## Colorblind Considerations

Git semantic colors are designed to work for most types of colorblindness.

### Why Git Colors Work

Our color palette is distinguishable for common types of colorblindness:

- **Protanopia** (red-weak): Green vs. blue are distinguishable
- **Deuteranopia** (green-weak): Orange vs. blue are distinguishable
- **Tritanopia** (blue-weak): Red vs. green are distinguishable

### Color + Icon Strategy

Never rely on color alone. Always pair color with an icon or text label:

```dart
// ✅ DO - Color + Icon + Text
Row(
  children: [
    Icon(PhosphorIconsRegular.plus, color: AppTheme.gitAdded),
    SizedBox(width: AppTheme.paddingXS),
    BodySmallLabel('Added', color: AppTheme.gitAdded),
  ],
)

// ❌ DON'T - Color only
Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(
    color: AppTheme.gitAdded, // No context without icon/text
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
- [ ] **Touch targets**: Minimum 44×44px for all tappable elements
- [ ] **Focus indicators**: Visible focus states on all interactive elements
- [ ] **Color contrast**: Text meets 4.5:1, UI components meet 3:1
- [ ] **Animation speed**: Animations use `AppTheme.getAnimation*()` helpers
- [ ] **Base* components**: Using wrapper components (no raw Material widgets)
- [ ] **Theme colors**: Using `ColorScheme` (no hardcoded colors)

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

1. Check this guide first
2. Review `docs/UI-CONCEPT.md` for component patterns
3. Open a GitHub issue with label `accessibility`
4. Include details about the assistive technology used (screen reader, keyboard, etc.)

Accessibility is everyone's responsibility. Thank you for helping make Flutter GitUI inclusive for all users!
