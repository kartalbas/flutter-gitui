# Contributing to Flutter GitUI

Thank you for your interest in contributing to Flutter GitUI! This guide will help you understand our UI development standards and workflow.

## 🎯 Quick Start for UI Development

### Rule #1: Always Use Base* Components

**NEVER** use raw Material widgets directly. **ALWAYS** use our Base* wrapper components.

#### ❌ DON'T Use These:

```dart
// ❌ Buttons
FilledButton(...)
ElevatedButton(...)
TextButton(...)
OutlinedButton(...)
IconButton(...)

// ❌ Lists
ListTile(...)

// ❌ Forms
TextField(...)
TextFormField(...)

// ❌ Dialogs
SimpleDialog(...)
AlertDialog(...)
Dialog(...)

// ❌ Text with manual styling
Text('Hello', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
```

#### ✅ DO Use These:

```dart
// ✅ Buttons
BaseButton(
  label: 'Click Me',
  variant: ButtonVariant.primary,
  onPressed: () => action(),
)

// ✅ Lists
BaseListItem(
  leading: Icon(...),
  content: BodyMediumLabel('Title'),
  trailing: Icon(...),
  onTap: () => select(),
)

// ✅ Forms
BaseTextField(
  label: 'Username',
  variant: TextFieldVariant.outlined,
  validator: (value) => ...,
)

// ✅ Dialogs
BaseDialog(
  title: 'Confirm',
  variant: DialogVariant.confirmation,
  content: BodyMediumLabel('Are you sure?'),
  actions: [...],
)

// ✅ Text
BodyMediumLabel('Hello', isBold: true)
TitleLargeLabel('Heading')
```

---

### Rule #2: Use AppTheme Constants

**NEVER** hardcode spacing, colors, or border radius. **ALWAYS** use theme constants.

#### ❌ DON'T:

```dart
SizedBox(height: 8)                          // Hardcoded spacing
SizedBox(height: 16)                         // Hardcoded spacing
Padding(padding: EdgeInsets.all(24))         // Hardcoded padding
BorderRadius.circular(12)                    // Hardcoded radius
Colors.red                                   // Hardcoded color
Colors.white                                 // Hardcoded color
Icon(icon, size: 24)                         // Hardcoded icon size
```

#### ✅ DO:

```dart
SizedBox(height: AppTheme.paddingS)          // 8px
SizedBox(height: AppTheme.paddingM)          // 16px
Padding(padding: EdgeInsets.all(AppTheme.paddingL))  // 24px
BorderRadius.circular(AppTheme.radiusL)      // 12px
Theme.of(context).colorScheme.error          // Theme color
Theme.of(context).colorScheme.onPrimary      // Theme color
Icon(icon, size: AppTheme.iconL)             // 24px
```

**Spacing Scale:**
- `paddingXS = 4px` - Same logical group (icon + text)
- `paddingS = 8px` - Related elements
- `paddingM = 16px` - Standard spacing (default)
- `paddingL = 24px` - Section spacing
- `paddingXL = 32px` - Major breaks

**Git Semantic Colors:**
```dart
context.gitColors.added      // Green - added files
context.gitColors.modified   // Orange - modified files
context.gitColors.deleted    // Red - deleted files
context.gitColors.renamed    // Blue - renamed files
context.gitColors.conflict   // Pink - merge conflicts
```

---

### Rule #3: Read UI-CONCEPT.md

**`docs/UI-CONCEPT.md` is the SINGLE SOURCE OF TRUTH** for all UI development.

- All design patterns documented
- Component decision trees
- Complete Base* component reference
- Migration philosophy
- When in doubt, consult UI-CONCEPT.md

**Do NOT reference archived documentation** in `docs/archived-do-not-read/` - it's outdated and superseded.

---

## 📚 Quick Reference Guides

- **Component Quick Reference:** `docs/COMPONENT-QUICK-REFERENCE.md` - Fast lookup of all components
- **Navigation Patterns:** `docs/NAVIGATION-PATTERNS.md` - Screen structure and navigation
- **Design Rationale:** `docs/DESIGN-RATIONALE.md` - Why we made these decisions
- **Error Handling:** `docs/ERROR-HANDLING-PATTERNS.md` - How to display errors
- **Accessibility:** `docs/ACCESSIBILITY.md` - A11y standards and requirements
- **Animations:** `docs/ANIMATION-GUIDELINES.md` - Animation timing and usage

---

## 🎨 Common Patterns

### Dialog with Actions

```dart
await showDialog(
  context: context,
  builder: (context) => BaseDialog(
    title: 'Confirm Delete',
    variant: DialogVariant.destructive,
    icon: PhosphorIconsRegular.trash,
    content: BodyMediumLabel('This action cannot be undone.'),
    actions: [
      BaseButton(
        label: 'Cancel',
        variant: ButtonVariant.tertiary,  // Always tertiary for cancel
        onPressed: () => Navigator.pop(context),
      ),
      BaseButton(
        label: 'Delete',
        variant: ButtonVariant.danger,    // Danger for destructive
        onPressed: () {
          performDelete();
          Navigator.pop(context);
        },
      ),
    ],
  ),
);
```

### List Item with Title and Subtitle

```dart
BaseListItem(
  leading: Icon(PhosphorIconsRegular.folder, size: AppTheme.iconM),
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
  isSelected: isSelected,
  onTap: () => selectItem(),
)
```

### Form with Validation

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    BaseTextField(
      label: 'Repository Name',
      variant: TextFieldVariant.outlined,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Name is required';
        }
        return null;
      },
    ),
    const SizedBox(height: AppTheme.paddingM),
    BaseTextField(
      label: 'Description',
      variant: TextFieldVariant.outlined,
      maxLines: 3,
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
          label: 'Create',
          variant: ButtonVariant.primary,
          onPressed: () => submit(),
        ),
      ],
    ),
  ],
)
```

### Empty State

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        PhosphorIconsRegular.fileX,
        size: AppTheme.iconXL * 2,  // 64px
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(height: AppTheme.paddingL),
      TitleLargeLabel('No Items Found'),
      const SizedBox(height: AppTheme.paddingS),
      BodyMediumLabel(
        'Get started by creating a new item',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppTheme.paddingXL),
      BaseButton(
        label: 'Create Item',
        variant: ButtonVariant.primary,
        leadingIcon: PhosphorIconsRegular.plus,
        onPressed: () => createItem(),
      ),
    ],
  ),
)
```

---

## 🔍 Decision Trees

### Which Button Variant?

```
Is it a primary action? (Save, Create, Commit)
  → ButtonVariant.primary

Is it a destructive action? (Delete, Discard, Remove)
  → ButtonVariant.danger

Is it a cancel/dismiss action?
  → ButtonVariant.tertiary

Is it an alternative action? (Export, View Details)
  → ButtonVariant.secondary

Is it a subtle action? (Collapse, Minimize)
  → ButtonVariant.ghost

Is it a positive confirmation? (Mark as Good in bisect)
  → ButtonVariant.success
```

### Which Dialog Variant?

```
Is it informational or input? (90% of dialogs)
  → DialogVariant.normal

Does it require explicit confirmation? (Irreversible action)
  → DialogVariant.confirmation

Is it destructive? (Delete, Remove)
  → DialogVariant.destructive
```

### Which Typography Component?

```
Dialog title or main heading?
  → TitleLargeLabel (22px)

Section header?
  → TitleMediumLabel (16px)

List item title or body text?
  → BodyMediumLabel (14px)

List item subtitle or description?
  → BodySmallLabel (12px)

Timestamp or helper text?
  → LabelSmallLabel (11px)

Button or chip label?
  → Handled automatically by BaseButton/BaseFilterChip
```

---

## ✅ Pull Request Checklist

Before submitting a PR with UI changes:

- [ ] Uses Base* components (no raw Material widgets)
- [ ] Uses AppTheme constants (no hardcoded spacing/colors)
- [ ] Follows patterns in UI-CONCEPT.md
- [ ] Passes `flutter analyze` with no warnings
- [ ] Screenshots attached (for visual changes)
- [ ] Tested in **both light AND dark mode**
- [ ] Keyboard navigation works (all actions accessible via Tab/Enter/Escape)
- [ ] Screen reader accessible (meaningful labels, proper semantics)
- [ ] Animation respects user preferences (AppAnimationSpeed)

---

## 🚫 Common Violations to Avoid

### ❌ Using Text() Instead of BaseLabel

```dart
// ❌ DON'T
Text(
  'Title',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  ),
)

// ✅ DO
TitleMediumLabel('Title')
```

### ❌ Hardcoding Spacing

```dart
// ❌ DON'T
SizedBox(height: 16)
Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4))

// ✅ DO
SizedBox(height: AppTheme.paddingM)
Padding(padding: EdgeInsets.symmetric(
  horizontal: AppTheme.paddingS,
  vertical: AppTheme.paddingXS,
))
```

### ❌ Using Colors.* Constants

```dart
// ❌ DON'T
backgroundColor: Colors.red
color: Colors.white

// ✅ DO
backgroundColor: Theme.of(context).colorScheme.error
color: Theme.of(context).colorScheme.onPrimary
// Or for git-specific colors:
backgroundColor: context.gitColors.deleted
```

### ❌ Bypassing Base* Components

```dart
// ❌ DON'T - Adding features to Material widget
TextButton(
  style: ButtonStyle(padding: ...),
  onPressed: () => action(),
  child: Text('Click'),
)

// ✅ DO - Extend BaseButton if feature is missing
// Open an issue/PR to add the feature to BaseButton
BaseButton(
  label: 'Click',
  variant: ButtonVariant.tertiary,
  onPressed: () => action(),
)
```

---

## 🛠️ Development Workflow

### 1. Before You Start

```bash
# Ensure you have the latest code
git pull origin master

# Run analysis to see current state
flutter analyze

# Check UI-CONCEPT.md for relevant patterns
```

### 2. During Development

- Consult `docs/COMPONENT-QUICK-REFERENCE.md` for component APIs
- Follow patterns in `docs/NAVIGATION-PATTERNS.md` for screen structure
- Check `docs/ERROR-HANDLING-PATTERNS.md` for error states
- Use `docs/ACCESSIBILITY.md` for a11y requirements

### 3. Before Committing

```bash
# Format code
dart format .

# Run analysis
flutter analyze

# Run tests
flutter test

# Test in both themes
# Settings → Appearance → Theme → Light/Dark
```

### 4. Creating a PR

- Fill out the PR template completely
- Include before/after screenshots for UI changes
- Reference relevant issues
- Check all items in the PR checklist

---

## 🎓 Learning Resources

### Essential Reading
1. **UI-CONCEPT.md** - Complete UI design system (SINGLE SOURCE OF TRUTH)
2. **COMPONENT-QUICK-REFERENCE.md** - Fast component lookup
3. **UI-MIGRATION-STATUS.md** - Migration progress and philosophy

### Design Philosophy
- **docs/DESIGN-RATIONALE.md** - Why we made these decisions
- **Extend, Don't Bypass** - If Base* component lacks a feature, extend it. Never revert to Material widget.

### Material Design 3
- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Material 3 Documentation](https://docs.flutter.dev/ui/design/material)

---

## 🤝 Getting Help

- **Questions about UI patterns?** Check UI-CONCEPT.md first, then ask in issues
- **Missing component feature?** Open an issue to extend the Base* component
- **Not sure which component?** Use the decision trees above
- **Found a violation?** Submit a PR to fix it

---

## 📜 License

By contributing to Flutter GitUI, you agree that your contributions will be licensed under the project's license.

---

**Thank you for helping maintain our UI consistency! 🎨**
