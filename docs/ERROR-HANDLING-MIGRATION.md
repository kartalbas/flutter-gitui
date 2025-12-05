# Error Handling Migration Guide

This document provides guidance for migrating code to use the `Result<T>` pattern for consistent, type-safe error handling.

## Overview

**Goal**: Replace inconsistent error handling patterns (null returns, empty collections, boolean flags) with a unified `Result<T>` approach.

**Benefits**:
- Type-safe error handling (compiler enforces error handling)
- Preserves error information (no more lost error context)
- Clear distinction between "no data" vs "error occurred"
- Consistent API across all services

## Quick Reference

### Available Methods

```dart
// Helper functions
Result<T> runCatching<T>(T Function() operation)
Future<Result<T>> runCatchingAsync<T>(Future<T> Function() operation)

// Core methods
result.when(success: (value) => ..., failure: (msg, err, stack) => ...)
result.map((value) => transformed)
result.flatMap((value) => anotherResult)
result.unwrap() // Throws on failure
result.unwrapOr(defaultValue)

// Extensions
result.onSuccess((value) => ...)
result.onFailure((msg, err, stack) => ...)
result.showInSnackBar(context) // Shows error notifications only
```

## Migration Patterns

### Pattern 1: Nullable Returns

**Before**:
```dart
Future<String?> getCurrentBranch() async {
  try {
    final result = await _execute('branch --show-current');
    final branch = result.stdout.toString().trim();
    return branch.isEmpty ? null : branch;
  } catch (e) {
    return null; // ❌ Lost error information
  }
}

// Usage
final branch = await getCurrentBranch();
if (branch != null) {
  print('Current branch: $branch');
} else {
  // Was there an error, or is there no branch? Unknown!
}
```

**After**:
```dart
Future<Result<String>> getCurrentBranch() async {
  return runCatchingAsync(() async {
    final result = await _execute('branch --show-current');
    final branch = result.stdout.toString().trim();

    // Detached HEAD is a valid state, not an error
    if (branch.isEmpty) {
      return 'HEAD';
    }

    return branch;
  });
}

// Usage
final result = await getCurrentBranch();
result.when(
  success: (branch) => print('Current branch: $branch'),
  failure: (msg, error, stackTrace) {
    NotificationService.showError(context, msg);
  },
);

// Or unwrap with default
final branch = (await getCurrentBranch()).unwrapOr('main');
```

---

### Pattern 2: Boolean Returns for Operations

**Before**:
```dart
Future<bool> isClean() async {
  try {
    final result = await _execute('status --porcelain');
    return result.stdout.toString().trim().isEmpty;
  } catch (e) {
    return false; // ❌ Error or actually dirty? Can't tell!
  }
}

// Usage
if (await isClean()) {
  print('Working directory is clean');
} else {
  // Did it fail, or is it dirty? Unknown!
}
```

**After**:
```dart
Future<Result<bool>> isClean() async {
  return runCatchingAsync(() async {
    final result = await _execute('status --porcelain');
    return result.stdout.toString().trim().isEmpty;
  });
}

// Usage
final result = await isClean();
result.when(
  success: (isClean) {
    if (isClean) {
      print('Working directory is clean');
    } else {
      print('Working directory has changes');
    }
  },
  failure: (msg, error, stackTrace) {
    NotificationService.showError(context, 'Failed to check status: $msg');
  },
);
```

---

### Pattern 3: Empty Collections for Errors

**Before**:
```dart
Future<List<GitTag>> getTags() async {
  try {
    final result = await _execute('for-each-ref refs/tags ...');
    return TagParser.parseTagList(result.stdout.toString());
  } catch (e) {
    return []; // ❌ Error or no tags? Can't tell!
  }
}

// Usage
final tags = await getTags();
if (tags.isEmpty) {
  // No tags, or error occurred? Unknown!
  print('No tags found');
}
```

**After**:
```dart
Future<Result<List<GitTag>>> getTags() async {
  return runCatchingAsync(() async {
    final result = await _execute('for-each-ref refs/tags ...');
    return TagParser.parseTagList(result.stdout.toString());
  });
}

// Usage
final result = await getTags();
result.when(
  success: (tags) {
    if (tags.isEmpty) {
      print('No tags found'); // Definitely no tags
    } else {
      print('Found ${tags.length} tags');
    }
  },
  failure: (msg, error, stackTrace) {
    NotificationService.showError(context, 'Failed to load tags: $msg');
  },
);
```

**Important**: Empty collections are valid data, not errors. Return `Success([])`, not `Failure`.

---

### Pattern 4: Void Operations

**Before**:
```dart
Future<void> stageFile(String filePath) async {
  await _execute('add "$filePath"');
  // If it throws, the exception propagates
}

// Usage - caller must catch
try {
  await stageFile('file.txt');
  print('File staged successfully');
} catch (e) {
  print('Failed to stage file: $e');
}
```

**After**:
```dart
Future<Result<void>> stageFile(String filePath) async {
  return runCatchingAsync(() async {
    await _execute('add "$filePath"');
  });
}

// Usage
final result = await stageFile('file.txt');
result.when(
  success: (_) => print('File staged successfully'),
  failure: (msg, error, stackTrace) {
    NotificationService.showError(context, 'Failed to stage file: $msg');
  },
);

// Or show error only
await stageFile('file.txt').showInSnackBar(context);
```

---

### Pattern 5: Multiple Return Types

**Before**:
```dart
Future<String?> getRepositoryRoot() async {
  try {
    final result = await _execute('rev-parse --show-toplevel');
    return result.stdout.toString().trim();
  } catch (e) {
    return null;
  }
}

Future<bool> isGitRepository(String path) async {
  try {
    final gitDir = Directory('$path/.git');
    return await gitDir.exists();
  } catch (e) {
    return false;
  }
}
```

**After**:
```dart
Future<Result<String>> getRepositoryRoot() async {
  return runCatchingAsync(() async {
    final result = await _execute('rev-parse --show-toplevel');
    return result.stdout.toString().trim();
  });
}

Future<Result<bool>> isGitRepository(String path) async {
  return runCatching(() {
    final gitDir = Directory('$path/.git');
    return gitDir.existsSync();
  });
}
```

**Note**: Use `runCatching()` for sync operations, `runCatchingAsync()` for async.

---

## UI Integration Patterns

### Pattern 1: Providers (Riverpod)

**Before**:
```dart
final currentBranchProvider = StreamProvider.autoDispose<String?>((ref) async* {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) {
    yield null;
    return;
  }

  final branch = await gitService.getCurrentBranch();
  yield branch; // null on error or detached HEAD
});
```

**After**:
```dart
final currentBranchProvider = StreamProvider.autoDispose<String?>((ref) async* {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) {
    yield null;
    return;
  }

  final result = await gitService.getCurrentBranch();
  result.when(
    success: (branch) => yield branch,
    failure: (msg, error, stackTrace) {
      Logger.error('Failed to get current branch: $msg', error);
      yield null; // Provider yields null to indicate error state
    },
  );
});
```

**Note**: Providers can still yield `null` to represent error states - this is fine. The key is that the *service* uses Result<T>.

---

### Pattern 2: Widget State

**Before**:
```dart
class _MyWidgetState extends State<MyWidget> {
  String? _currentBranch;

  Future<void> _loadBranch() async {
    final branch = await gitService.getCurrentBranch();
    if (mounted) {
      setState(() {
        _currentBranch = branch;
      });
    }
  }
}
```

**After**:
```dart
class _MyWidgetState extends State<MyWidget> {
  String? _currentBranch;

  Future<void> _loadBranch() async {
    final result = await gitService.getCurrentBranch();
    if (!mounted) return;

    result.when(
      success: (branch) {
        setState(() {
          _currentBranch = branch;
        });
      },
      failure: (msg, error, stackTrace) {
        NotificationService.showError(context, msg);
      },
    );
  }
}
```

---

### Pattern 3: FutureBuilder

**Before**:
```dart
FutureBuilder<String?>(
  future: gitService.getCurrentBranch(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final branch = snapshot.data;
      return Text(branch ?? 'No branch');
    } else if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    return CircularProgressIndicator();
  },
)
```

**After**:
```dart
FutureBuilder<Result<String>>(
  future: gitService.getCurrentBranch(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return snapshot.data!.when(
        success: (branch) => Text(branch),
        failure: (msg, _, __) => Text('Error: $msg'),
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

## Parser Migration

Parsers should throw exceptions instead of returning null. Callers wrap them in `runCatchingAsync()`.

**Before**:
```dart
class BranchParser {
  static GitBranch? _parseBranchLine(String line) {
    try {
      // Parse logic...
      return GitBranch(...);
    } catch (e) {
      return null; // ❌ Silent failure
    }
  }

  static List<GitBranch> parseVerbose(String output) {
    final branches = <GitBranch>[];
    for (final line in output.split('\n')) {
      final branch = _parseBranchLine(line);
      if (branch != null) {
        branches.add(branch);
      }
    }
    return branches;
  }
}
```

**After**:
```dart
class BranchParser {
  static GitBranch _parseBranchLine(String line) {
    // Parse logic...
    if (invalidData) {
      throw GitException('Invalid branch line: $line');
    }
    return GitBranch(...);
  }

  static List<GitBranch> parseVerbose(String output) {
    final branches = <GitBranch>[];
    for (final line in output.split('\n')) {
      try {
        final branch = _parseBranchLine(line);
        branches.add(branch);
      } catch (e) {
        // Log and skip invalid lines, but continue parsing
        Logger.warning('Failed to parse branch line: $line', e);
      }
    }
    return branches;
  }
}

// Service wraps parser in Result
Future<Result<List<GitBranch>>> getLocalBranches() async {
  return runCatchingAsync(() async {
    final result = await _execute('branch -vv');
    return BranchParser.parseVerbose(result.stdout.toString());
  });
}
```

---

## Chaining Operations

Use `flatMap()` to chain multiple Result-returning operations:

```dart
Future<Result<String>> getRemoteUrl() async {
  // Get current branch
  final branchResult = await getCurrentBranch();

  // Chain to get upstream
  return branchResult.flatMap((branch) async {
    final upstreamResult = await getUpstream(branch);

    // Chain to get URL
    return upstreamResult.flatMap((upstream) async {
      return getUrlForRemote(upstream);
    });
  });
}

// Usage
final result = await getRemoteUrl();
result.when(
  success: (url) => print('Remote URL: $url'),
  failure: (msg, _, __) => print('Failed: $msg'),
);
```

---

## Common Pitfalls

### ❌ DON'T: Return Failure for valid edge cases

```dart
// ❌ WRONG
Future<Result<String>> getCurrentBranch() async {
  return runCatchingAsync(() async {
    final result = await _execute('branch --show-current');
    final branch = result.stdout.toString().trim();

    if (branch.isEmpty) {
      throw GitException('No current branch'); // ❌ Detached HEAD is valid!
    }

    return branch;
  });
}
```

```dart
// ✅ CORRECT
Future<Result<String>> getCurrentBranch() async {
  return runCatchingAsync(() async {
    final result = await _execute('branch --show-current');
    final branch = result.stdout.toString().trim();

    // Empty branch means detached HEAD - valid state
    return branch.isEmpty ? 'HEAD' : branch;
  });
}
```

---

### ❌ DON'T: Use Result<T> everywhere

```dart
// ❌ WRONG - Pure computations don't need Result
Result<int> add(int a, int b) {
  return Success(a + b);
}

// ✅ CORRECT - Use Result for operations that can fail
int add(int a, int b) {
  return a + b;
}

Future<Result<ProcessResult>> executeGitCommand(String command) async {
  return runCatchingAsync(() async {
    return await _execute(command);
  });
}
```

**Rule**: Only use `Result<T>` for operations that interact with external systems (files, network, processes, databases).

---

### ❌ DON'T: Swallow errors silently

```dart
// ❌ WRONG
final result = await getCurrentBranch();
// Do nothing with result... error lost!
```

```dart
// ✅ CORRECT
final result = await getCurrentBranch();
result.when(
  success: (branch) => updateUI(branch),
  failure: (msg, err, stack) {
    NotificationService.showError(context, msg);
    Logger.error('Failed to get branch', err);
  },
);
```

---

## Migration Checklist

For each method you migrate:

- [ ] Update method signature to return `Result<T>`
- [ ] Wrap operation in `runCatching()` or `runCatchingAsync()`
- [ ] Remove `return null` for errors
- [ ] Remove `return []` for errors
- [ ] Remove `return false` for errors
- [ ] Return meaningful values for valid edge cases (e.g., 'HEAD' for detached HEAD)
- [ ] Update all call sites to handle `Result<T>`
- [ ] Add/update tests for both success and failure cases
- [ ] Update method documentation

---

## Need Help?

- See `lib/core/utils/result.dart` for all available Result<T> methods
- See `docs/CONTRIBUTING.md` for error handling standards
- See `docs/ERROR-HANDLING-PATTERNS.md` for UI error handling patterns
- Ask the team in #engineering channel

---

## Migration Status Tracking

Track your migration progress:

**Phase 1**: Foundation ✅
- [x] Result<T> class enhanced
- [x] Migration guide created
- [ ] CONTRIBUTING.md updated

**Phase 2**: Git Service - Critical Operations
- [ ] Branch operations (getCurrentBranch, getLocalBranches, etc.)
- [ ] Status operations (getStatus, isClean)
- [ ] Commit operations (commit, getLog)

**Phase 3-8**: See main migration plan in `C:\Users\mkadm\.claude\plans\stateful-napping-scroll.md`
