# Flutter GitUI Custom Lint Rules

Custom lint rules to enforce Base* component usage and design system consistency in Flutter GitUI.

## Overview

This package provides automated enforcement of UI development standards through static analysis. It prevents developers from bypassing Base* wrapper components and ensures consistent usage of AppTheme constants.

## Rules

### Button Rules

| Rule | Detects | Suggests |
|------|---------|----------|
| `avoid_filled_button` | `FilledButton` | `BaseButton` with `ButtonVariant.primary` |
| `avoid_text_button` | `TextButton` | `BaseButton` with `ButtonVariant.tertiary` |
| `avoid_elevated_button` | `ElevatedButton` | `BaseButton` with `ButtonVariant.primary` |
| `avoid_outlined_button` | `OutlinedButton` | `BaseButton` with `ButtonVariant.secondary` |
| `avoid_icon_button` | `IconButton` | `BaseButton` with `leadingIcon` |

### UI Component Rules

| Rule | Detects | Suggests |
|------|---------|----------|
| `avoid_list_tile` | `ListTile` | `BaseListItem` |
| `avoid_text_field` | `TextField`, `TextFormField` | `BaseTextField` |
| `avoid_simple_dialog` | `SimpleDialog` | `BaseDialog` |
| `avoid_alert_dialog` | `AlertDialog` | `BaseDialog` |

### Styling Rules

| Rule | Detects | Suggests |
|------|---------|----------|
| `avoid_hardcoded_spacing` | Numeric literals in `SizedBox`/`EdgeInsets` | `AppTheme.paddingXS/S/M/L/XL` |
| `avoid_hardcoded_colors` | `Colors.*` usage | `Theme.of(context).colorScheme` or `AppTheme.*` |
| `avoid_text_with_style` | `Text()` with `style` parameter | `BaseLabel` components |

## Installation

1. Add the lint package as a dev dependency in your project's `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.6.0
  flutter_gitui_lint:
    path: lint_rules/flutter_gitui_lint
```

2. Enable custom_lint in your `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

3. Run `flutter pub get` to install dependencies.

## Usage

### Running Lints

```bash
# Analyze your project with custom lints
flutter pub run custom_lint

# Or use the standard analyzer (if configured)
flutter analyze
```

### IDE Integration

Custom lint rules will automatically appear in your IDE (VS Code, Android Studio, IntelliJ) when the `custom_lint` plugin is enabled.

## Examples

### ❌ Before (Violations)

```dart
// ❌ Avoid FilledButton
FilledButton(
  onPressed: () => action(),
  child: Text('Click Me'),
)

// ❌ Avoid hardcoded spacing
SizedBox(height: 16)
Padding(padding: EdgeInsets.all(24))

// ❌ Avoid hardcoded colors
Container(color: Colors.red)

// ❌ Avoid Text with style
Text(
  'Title',
  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
)

// ❌ Avoid ListTile
ListTile(
  leading: Icon(Icons.folder),
  title: Text('Repository'),
  onTap: () => open(),
)
```

### ✅ After (Compliant)

```dart
// ✅ Use BaseButton
BaseButton(
  label: 'Click Me',
  variant: ButtonVariant.primary,
  onPressed: () => action(),
)

// ✅ Use AppTheme constants
SizedBox(height: AppTheme.paddingM)
Padding(padding: EdgeInsets.all(AppTheme.paddingL))

// ✅ Use theme colors
Container(color: Theme.of(context).colorScheme.error)

// ✅ Use BaseLabel components
TitleLargeLabel('Title')

// ✅ Use BaseListItem
BaseListItem(
  leading: Icon(PhosphorIconsRegular.folder),
  content: BodyMediumLabel('Repository'),
  onTap: () => open(),
)
```

## Configuration

### Disabling Rules

You can disable specific rules in your `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    - avoid_filled_button: false
    - avoid_hardcoded_spacing: false
```

### Ignoring Specific Instances

Use `// ignore:` comments to suppress warnings for specific cases:

```dart
// ignore: avoid_filled_button
FilledButton(...)

// ignore: avoid_hardcoded_spacing
SizedBox(height: 16)
```

### Documented Exceptions

Some violations are acceptable and documented in `UI-CONCEPT.md`:

- Command Palette uses native `TextField` (documented exception)
- Certain dialogs use `Dialog` wrapper for custom layouts (documented exception)

For these cases, add `// ignore:` comments with a reference to the documentation.

## Development

### Adding New Rules

1. Create a new file in `lib/src/lints/`
2. Implement the `DartLintRule` class
3. Add the rule to `lib/flutter_gitui_lint.dart`
4. Update this README with the new rule

### Testing Rules

```bash
cd lint_rules/flutter_gitui_lint
flutter pub get
flutter analyze
```

## Philosophy

These lint rules enforce the **"Extend, Don't Bypass"** philosophy:

- If a Base* component lacks a feature, extend it rather than reverting to Material widgets
- Maintain centralized theming through Base* wrapper components
- Ensure consistent spacing using AppTheme constants
- Use theme-aware colors instead of hardcoded values

## See Also

- **CONTRIBUTING.md** - UI development guidelines
- **docs/UI-CONCEPT.md** - Complete design system documentation
- **docs/COMPONENT-QUICK-REFERENCE.md** - Quick component lookup
- **docs/DESIGN-RATIONALE.md** - Why we made these decisions

## License

This package is part of Flutter GitUI and follows the same license.
