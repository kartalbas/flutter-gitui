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
| `avoid_hardcoded_spacing` | Whole-number literals `4`/`8`/`16`/`24`/`32` in `SizedBox`/`EdgeInsets` constructors | `AppTheme.paddingXS/S/M/L/XL` |
| `avoid_hardcoded_radius` | Numeric literals or non-radius `AppTheme.*` constants inside `BorderRadius`/`Radius` constructors | `AppTheme.radiusXS/S/M/L/XL` |
| `avoid_hardcoded_colors` | `Colors.*` usage | `Theme.of(context).colorScheme` or `AppTheme.*` |
| `avoid_text_with_style` | `Text()` with a `style` parameter that is not a `copyWith(color:)` chain | `BaseLabel` subclasses (`BodyMediumLabel`, `TitleLargeLabel`, …) |

### Keyboard Rules

| Rule | Detects | Suggests |
|------|---------|----------|
| `avoid_raw_shortcuts` | `Shortcuts(...)` or `CallbackShortcuts(...)` constructed outside `lib/shared/` | Route keys through the shared keyboard layer — `additionalBindings` on the `KeyboardNavigable*` views, `onSubmit` on `BaseDialog`/`BaseViewerDialog`, `BaseDismissScope` — or extend that layer. All of it consults `focusedEditableOwnsKey`, the guard a raw shortcut widget bypasses. A genuinely global surface (today only the app shell's Ctrl/Meta chord map) is sanctioned by a two-place act: a `// sanctioned-shortcuts: <reason>` marker directly above the construction **and** an entry in the rule's sanctioned-files snapshot; either half alone still fails. Bare `// ignore: avoid_raw_shortcuts` is not accepted: CI fails on any ignore naming this rule under `lib/`, and `grep -rn "sanctioned-shortcuts:" lib/` audits every exception. |

### Safety Rules

| Rule | Detects | Suggests |
|------|---------|----------|
| `require_confirm_destructive` | Calls to destructive `GitService`/`GitActions` methods (the `DestructiveAction` catalogue) with no `confirmDestructive` call in the enclosing function, and any `DestructiveAction` enum constant missing from the rule's snapshot | Route the call through `confirmDestructive`; when the confirmation is a dedicated dialog or lives one call frame up, add a `// confirmed-by: <where>` marker directly above the statement. A marker may only sit in the same user-facing flow as the confirmation it names — the widget or dialog file where the user actually acted — never in a shared helper or service wrapper, which would invisibly exempt every future caller of that wrapper. Bare `// ignore: require_confirm_destructive` is not accepted: CI fails on any ignore naming this rule under `lib/`, so the marker is the only sanctioned exception and `grep -rn "confirmed-by:" lib/` audits all of them. When `DestructiveAction` gains a constant, add its method(s) to the rule's destructive set and update the snapshot. |

### Skin Contract Rules

These two guard the properties the whole #249 design rests on, and they are
scoped to `packages/gitui_skin_api` — the contract itself. They are permanent:
unlike the classifiers below, they have no end date, because the contract they
guard does not.

They exist because the guard everyone assumed was doing this job cannot. The
contract package imports `package:flutter/widgets.dart` and nothing else from
Flutter, and that fact was standing in for the spine rule — but the resolved
export namespace of `widgets.dart` contains `Color` (via `dart:ui`),
`EdgeInsets`, `TextStyle`, `ShapeBorder`, `IconData`, `BoxDecoration`,
`BorderRadius`, `Curve` and the whole `WidgetState` family, and `Duration` is
`dart:core`. Adding `final Color tint;` to a spec changes no import: analysis,
the workspace-isolation gate and `custom_lint` all stay green, and the
blueprint keeps compiling because a new spec *field* obliges a skin to
implement nothing. The import ban still earns its place — it makes every
Material-*named* type unnameable — it just cannot carry this claim.

| Rule | Detects | Suggests |
|------|---------|----------|
| `no_value_in_contract` | Any type annotation in `packages/gitui_skin_api/lib/**` whose **resolved** type is a design value — `Color`, `EdgeInsets`, `TextStyle`, `ShapeBorder`, `BorderRadius`, `BoxDecoration`, `Duration`, `IconData`, `Curve`, the `WidgetState*` family — and any `double` that is not in the rule's sanctioned list. Resolving the type rather than matching the identifier is what catches an alias, a generic argument (`ValueChanged<Color>`) and an import prefix; walking the AST is what keeps the doc comments *about* these types out of the count. | State the question, not the answer: `Tone` rather than `Color`, `Proximity`/`Inset` rather than a length, `TextRole` rather than a `TextStyle`, `IconRole` rather than an `IconData`, `MotionRole` rather than a `Duration`. A `double` that is genuinely a fraction, a scale or a coordinate the application owns goes in the sanctioned list **with its reason**, next to the rule it weakens. |
| `no_widget_in_contract` | Any `Widget`-typed parameter or field on a contract member that is not a `ContentPort`, including `List<Widget>`. | Declare it `ContentPort` and let the skin call `mount()` where the content should appear: that plants the `ContentPortBoundary` the attribution walk (T3) resumes at, in the one place it can be planted. A widget handed over any other way lands inside the pruned region and every leak in it is invisible — permanently, and silently. The rule ships with **one** exemption, `SkinChrome.wrapRoot`'s `child`, argued in the rule's own doc: its argument is never application-supplied, and typing it as a port would put the resume above the skin's own overlay frame and mis-attribute every skin-built popover, menu and notice surface to the application. |

### Migration Classifiers

These rules measure a migration that is under way instead of guarding an
invariant. Every site they report is legal code today, so they are **off by
default** and they are **deleted when their migration lands** — a migration lint
that outlives its migration becomes noise nobody dares remove, because nobody
remembers what question it was answering.

| Rule | Detects | Suggests |
|------|---------|----------|
| `token_read_is_mechanical` | Every `AppTheme.*` length read in `package:flutter_gitui/**` that a codemod cannot move on its own: a token inside an arithmetic expression (**design-bearing** — the application, not the skin, decided a length), and a bare token sitting in none of the seven positions the codemod rewrites (**unplaced** — `SizedBox` `width:`/`height:`, an `EdgeInsets`/`Radius`/`BorderRadius` argument, `size:`, `spacing:`, `runSpacing:`, `iconSize:`). Bare tokens in those positions are silent: a script moves them. First run: **1,230 mechanical : 49 design-bearing : 39 unplaced** out of 1,318 reads. | For a design-bearing read, pick the `Proximity`/`Inset` rung the expression really means, or move the measured layout into the skin, where numbers are legal. For an unplaced read, either widen the codemod's closed set (and `docs/SKIN-CONTRACT.md` §5.2 with it) or treat it as design-bearing. **Migration-only: deleted at P6 of #249**, when the last `AppTheme.*` read is gone. |

Turn a classifier on for a measurement — it is off in CI on purpose, so that
`dart run custom_lint --fatal-infos --fatal-warnings` keeps measuring the rules
that *are* invariants:

```yaml
custom_lint:
  rules:
    - token_read_is_mechanical
```

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
