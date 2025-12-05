# Contributing to Flutter GitUI

Thank you for your interest in contributing to Flutter GitUI! This document provides guidelines and standards for contributing to the project.

## Table of Contents

1. [Error Handling Standards](#error-handling-standards)
2. [Code Style](#code-style)
3. [Commit Guidelines](#commit-guidelines)
4. [Testing](#testing)
5. [Documentation](#documentation)
6. [Pull Request Process](#pull-request-process)

---

## Error Handling Standards

### **CRITICAL RULE**: Never Return Null

**All service methods MUST use the `Result<T>` pattern for error handling.**

**Rule**: NEVER return `null`, `false`, or empty collections to indicate errors.

###Why This Matters

- **Type Safety**: Compiler enforces error handling
- **Preserves Context**: Error messages and stack traces are never lost
- **Clear Semantics**: Distinguishes between "no data" (valid) and "error occurred" (failure)
- **Consistent API**: Every service method follows the same pattern

### Implementation

#### ✅ CORRECT: Use Result<T>

```dart
Future<Result<String>> getCurrentBranch() async {
  return runCatchingAsync(() async {
    final result = await _execute('branch --show-current');
    final branch = result.stdout.toString().trim();
    return branch.isEmpty ? 'HEAD' : branch;
  });
}

// Usage
final result = await gitService.getCurrentBranch();
result.when(
  success: (branch) => updateUI(branch),
  failure: (msg, error, stackTrace) {
    NotificationService.showError(context, msg);
  },
);
```

#### ❌ INCORRECT: Return null

```dart
Future<String?> getCurrentBranch() async {
  try {
    // ...
    return branch;
  } catch (e) {
    return null; // ❌ Lost error information!
  }
}
```

#### ❌ INCORRECT: Return empty list for error

```dart
Future<List<GitBranch>> getBranches() async {
  try {
    // ...
    return branches;
  } catch (e) {
    return []; // ❌ Error or no branches? Can't tell!
  }
}
```

#### ❌ INCORRECT: Return false for error

```dart
Future<bool> isClean() async {
  try {
    // ...
    return isClean;
  } catch (e) {
    return false; // ❌ Error or actually dirty? Can't tell!
  }
}
```

### UI Usage Pattern

```dart
// In widgets/controllers
final result = await gitService.someOperation();

result.when(
  success: (value) {
    // Handle success
    setState(() => data = value);
  },
  failure: (message, error, stackTrace) {
    // Always show errors to user
    NotificationService.showError(context, message);
  },
);

// Shorthand for unwrapping with default
final value = (await gitService.someOperation()).unwrapOr(defaultValue);
```

### Edge Cases

**Empty Collections**: Return `Success([])`, NOT `Failure`

```dart
Future<Result<List<GitTag>>> getTags() async {
  return runCatchingAsync(() async {
    final tags = TagParser.parseTagList(output);
    return tags; // Empty list is valid data, not an error
  });
}
```

**Boolean Results**: Use `Result<bool>`, NOT nullable or default false

```dart
Future<Result<bool>> isClean() async {
  return runCatchingAsync(() async {
    final result = await _execute('status --porcelain');
    return result.stdout.toString().trim().isEmpty;
  });
}
```

**Void Operations**: Use `Result<void>`

```dart
Future<Result<void>> stageFile(String filePath) async {
  return runCatchingAsync(() async {
    await _execute('add "$filePath"');
  });
}
```

### Exception Handling

Exceptions should ONLY be used for:
- Programming errors (assertions, invalid arguments)
- Unrecoverable errors (out of memory, corrupted state)

For expected errors (Git command failures, network issues, file not found), use `Result<T>`.

### Parser Guidelines

Parsers should throw `GitException` on parse errors instead of returning null:

```dart
// ✅ CORRECT
static GitBranch _parseBranchLine(String line) {
  if (invalidData) {
    throw GitException('Invalid branch line: $line');
  }
  return GitBranch(...);
}

// Service wraps parser in Result
Future<Result<List<GitBranch>>> getBranches() async {
  return runCatchingAsync(() async {
    final output = await _execute('branch -vv');
    return BranchParser.parseVerbose(output.stdout.toString());
  });
}
```

### Migration Guide

See [`docs/ERROR-HANDLING-MIGRATION.md`](./ERROR-HANDLING-MIGRATION.md) for detailed migration patterns and examples.

---

## Code Style

### General Principles

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` before committing
- Keep methods small and focused (< 50 lines preferred)
- Prefer composition over inheritance
- Write self-documenting code (clear variable/method names)

### Naming Conventions

**Files**: `snake_case.dart`
```
git_service.dart
branch_parser.dart
create_pull_request_dialog.dart
```

**Classes**: `PascalCase`
```dart
class GitService { }
class BranchParser { }
class CreatePullRequestDialog { }
```

**Methods/Variables**: `camelCase`
```dart
Future<Result<String>> getCurrentBranch() { }
final currentBranch = 'main';
```

**Constants**: `lowerCamelCase` or `SCREAMING_SNAKE_CASE` for compile-time constants
```dart
const defaultBranch = 'main';
const MAX_RETRIES = 3;
```

**Private members**: Prefix with `_`
```dart
String _privateMember;
void _privateMethod() { }
```

### Imports

Organize imports in this order:
1. Dart SDK imports
2. Flutter imports
3. Package imports
4. Project imports (relative)

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:riverpod/riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/git/git_service.dart';
import '../models/branch.dart';
```

### Documentation

**Public APIs**: Must have doc comments
```dart
/// Gets the current branch name.
///
/// Returns 'HEAD' if in detached HEAD state.
///
/// Throws [GitException] if git command fails.
Future<Result<String>> getCurrentBranch() async {
  // ...
}
```

**Complex Logic**: Add inline comments explaining "why", not "what"
```dart
// Check for detached HEAD state first - this prevents
// treating "(HEAD detached at abc123)" as a branch name
if (line.startsWith('* (HEAD detached')) {
  return GitBranch(name: 'HEAD', ...);
}
```

---

## Commit Guidelines

### **CRITICAL**: No Claude Attribution

**NEVER add Claude-related references in commits:**
- ❌ NO "Generated with Claude"
- ❌ NO "Co-Authored-By: Claude"
- ❌ NO Claude attribution footers

### Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, tooling

**Examples**:
```
feat(branches): Add bulk delete for branches

fix(git): Handle detached HEAD state correctly

refactor(error-handling): Migrate git_service to Result<T> pattern

docs(contributing): Add error handling standards
```

### Commit Best Practices

- Keep commits focused (one logical change per commit)
- Write clear, descriptive commit messages
- Reference issue numbers when applicable: `fix(git): Handle detached HEAD (#123)`
- Test your changes before committing

---

## Testing

### Test Coverage Requirements

- **New Features**: Must include tests
- **Bug Fixes**: Must include regression tests
- **Refactoring**: Ensure existing tests still pass

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/git/git_service_test.dart

# Run with coverage
flutter test --coverage
```

### Test Structure

```dart
void main() {
  group('GitService', () {
    late GitService gitService;

    setUp(() {
      gitService = GitService('/path/to/repo');
    });

    test('getCurrentBranch returns Success with branch name', () async {
      final result = await gitService.getCurrentBranch();

      expect(result.isSuccess, true);
      final branch = result.unwrap();
      expect(branch, isNotEmpty);
    });

    test('getCurrentBranch returns Failure on error', () async {
      // Set up error condition...
      final result = await gitService.getCurrentBranch();

      expect(result.isFailure, true);
    });
  });
}
```

---

## Documentation

### Where to Document

- **Public APIs**: Doc comments in code
- **Architecture**: `docs/ARCHITECTURE.md`
- **Error Handling**: `docs/ERROR-HANDLING-PATTERNS.md` and `docs/ERROR-HANDLING-MIGRATION.md`
- **Contributing**: This file
- **User-Facing**: `README.md`

### Documentation Standards

- Keep documentation up-to-date with code changes
- Use examples to illustrate complex concepts
- Link to related documentation
- Update changelog for user-facing changes

---

## Pull Request Process

### Before Submitting

1. **Test Your Changes**
   ```bash
   flutter test
   flutter analyze
   dart format .
   ```

2. **Update Documentation**
   - Update doc comments
   - Update relevant markdown files
   - Update CHANGELOG.md (for user-facing changes)

3. **Check Commit Messages**
   - Follow conventional commit format
   - No Claude attribution
   - Clear, descriptive messages

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation update

## Testing
Describe how you tested the changes

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Follows code style guidelines
- [ ] Follows error handling standards (Result<T>)
- [ ] No null returns for errors
- [ ] Conventional commit messages
- [ ] No Claude attribution
```

### Review Process

1. **Automated Checks**: CI must pass (tests, linting, format)
2. **Code Review**: At least one approval required
3. **Error Handling**: Verify Result<T> pattern usage
4. **Testing**: Verify adequate test coverage
5. **Documentation**: Verify docs are updated

---

## Project-Specific Guidelines

### Git Integration

- Use tag-based versioning: `v{major}.{minor}.{patch}`
- Targets Windows and Linux platforms
- All Git operations must use `git_service.dart`
- Never call `git` commands directly from UI

### State Management

- Use Riverpod for state management
- Providers should handle `Result<T>` from services
- UI should use `NotificationService` for error display

### Localization

- Multi-language support (8 languages: en, ar, de, es, fr, it, ru, tr, zh)
- All user-facing strings must be localized
- Add translations to all `lib/l10n/app_*.arb` files

### UI Components

- Use Material 3 design
- Use Phosphor icons (`phosphor_flutter`)
- Follow `AppTheme` constants for spacing/sizing
- Use existing base components (`BaseButton`, `BaseDialog`, etc.)

---

## Need Help?

- **Error Handling**: See `docs/ERROR-HANDLING-MIGRATION.md`
- **Architecture**: See `docs/ARCHITECTURE.md`
- **UI Patterns**: See `docs/ERROR-HANDLING-PATTERNS.md`
- **Questions**: Open an issue or ask in #engineering

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to Flutter GitUI!**
