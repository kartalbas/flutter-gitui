# Error Handling Patterns

This document describes Flutter GitUI's error handling strategies and patterns.

---

## Overview

Flutter GitUI handles errors at multiple levels:

1. **Dialog Errors** - Critical errors requiring user acknowledgment
2. **Inline Errors** - Form validation and input errors
3. **SnackBar Errors** - Transient operation errors
4. **Network Errors** - Connectivity and timeout issues
5. **Git Command Failures** - Git operation errors
6. **Error States** - Screen-level error displays
7. **Empty Error States** - No data due to error

---

## 1. Dialog Error Messages

Use `BaseDialog` with `DialogVariant.destructive` for critical errors:

### Basic Error Dialog

```dart
await BaseDialog.show(
  context: context,
  dialog: BaseDialog(
    title: 'Git Command Failed',
    variant: DialogVariant.destructive,
    icon: PhosphorIconsRegular.warning,
    content: BodyMediumLabel(
      'Failed to execute git command:\n\n$errorMessage',
    ),
    actions: [
      BaseButton(
        label: 'Dismiss',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  ),
);
```

### Error Dialog with Retry

```dart
final shouldRetry = await BaseDialog.show<bool>(
  context: context,
  dialog: BaseDialog(
    title: 'Operation Failed',
    variant: DialogVariant.destructive,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyMediumLabel('Failed to push to remote:'),
        const SizedBox(height: AppTheme.paddingM),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: SelectableText(
            errorMessage,
            style: AppTheme.monoTextTheme().bodySmall,
          ),
        ),
      ],
    ),
    actions: [
      BaseButton(
        label: 'Cancel',
        variant: ButtonVariant.tertiary,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      BaseButton(
        label: 'Retry',
        variant: ButtonVariant.primary,
        leadingIcon: PhosphorIconsRegular.arrowClockwise,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  ),
);

if (shouldRetry == true) {
  await _retryOperation();
}
```

### Error Dialog with Details

```dart
await BaseDialog.show(
  context: context,
  dialog: BaseDialog(
    title: 'Repository Validation Failed',
    variant: DialogVariant.destructive,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyMediumLabel('The following repositories are invalid:'),
        const SizedBox(height: AppTheme.paddingM),
        // Error list
        ...invalidRepos.map((repo) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.paddingXS),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.xCircle,
                size: AppTheme.iconS,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppTheme.paddingS),
              Expanded(
                child: BodySmallLabel(
                  '${repo.displayName}\n${repo.errorMessage}',
                ),
              ),
            ],
          ),
        )),
      ],
    ),
    actions: [
      BaseButton(
        label: 'Remove Invalid',
        variant: ButtonVariant.danger,
        onPressed: () {
          Navigator.of(context).pop();
          _removeInvalidRepos(invalidRepos);
        },
      ),
    ],
  ),
);
```

---

## 2. Inline Error States

Use `InputDecoration.errorText` for form validation errors:

### Text Field Validation

```dart
TextField(
  controller: _branchNameController,
  decoration: InputDecoration(
    labelText: 'Branch Name',
    hintText: 'feature/my-branch',
    errorText: _branchNameError,  // Show validation error
    helperText: 'Use lowercase with dashes',
    prefixIcon: Icon(PhosphorIconsRegular.gitBranch),
  ),
  onChanged: (value) {
    setState(() {
      _branchNameError = _validateBranchName(value);
    });
  },
)

String? _validateBranchName(String value) {
  if (value.isEmpty) {
    return 'Branch name is required';
  }
  if (value.contains(' ')) {
    return 'Branch name cannot contain spaces';
  }
  if (!RegExp(r'^[a-zA-Z0-9/_-]+$').hasMatch(value)) {
    return 'Branch name contains invalid characters';
  }
  return null;  // No error
}
```

### Form-Level Validation

```dart
class CommitDialogState extends ConsumerState<CommitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String? _messageError;

  Future<void> _submit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;  // Show inline errors
    }

    // Validate commit message
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        _messageError = 'Commit message is required';
      });
      return;
    }

    // All valid - proceed
    await _commit(message);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Commit Message',
              errorText: _messageError,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Commit message is required';
              }
              return null;
            },
            maxLines: 5,
          ),
          // Submit button
          BaseButton(
            label: 'Commit',
            variant: ButtonVariant.primary,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
```

### Real-Time Validation

```dart
class CreateBranchDialogState extends State<CreateBranchDialog> {
  final _nameController = TextEditingController();
  String? _nameError;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    // Debounced validation
    _nameController.addListener(_validateBranchName);
  }

  Timer? _debounceTimer;

  void _validateBranchName() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() => _nameError = null);
        return;
      }

      setState(() => _isValidating = true);

      // Check if branch exists
      final exists = await _checkBranchExists(name);

      setState(() {
        _isValidating = false;
        _nameError = exists ? 'Branch already exists' : null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Branch Name',
        errorText: _nameError,
        suffixIcon: _isValidating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _nameError != null
                ? Icon(
                    PhosphorIconsRegular.xCircle,
                    color: Theme.of(context).colorScheme.error,
                  )
                : Icon(
                    PhosphorIconsRegular.checkCircle,
                    color: AppTheme.gitAdded,
                  ),
      ),
    );
  }
}
```

---

## 3. SnackBar Errors

Use `NotificationService` for transient errors:

### Basic Error SnackBar

```dart
try {
  await ref.read(gitActionsProvider).stageFile(filePath);
} catch (e) {
  if (context.mounted) {
    NotificationService.showError(
      context,
      'Failed to stage file: $e',
    );
  }
}
```

**Features of NotificationService.showError:**
- Automatically copies error to clipboard
- Shows copy icon indicator
- Requires manual dismissal (doesn't auto-hide)
- Red background with error icon

### Success vs Error SnackBars

```dart
// Success (auto-dismisses after 2 seconds)
NotificationService.showSuccess(
  context,
  'Branch created successfully',
);

// Error (requires manual dismissal)
NotificationService.showError(
  context,
  'Failed to create branch: Branch already exists',
);

// Warning (requires manual dismissal)
NotificationService.showWarning(
  context,
  'Some repositories failed validation',
);

// Info (auto-dismisses after 2 seconds)
NotificationService.showInfo(
  context,
  'Fetching from remote...',
);
```

### Error with Context

```dart
try {
  await ref.read(gitActionsProvider).commitChanges(message);

  if (context.mounted) {
    NotificationService.showSuccess(
      context,
      'Committed ${stagedCount} files',
    );
  }
} catch (e) {
  if (context.mounted) {
    // Include operation context in error message
    NotificationService.showError(
      context,
      'Failed to commit ${stagedCount} files: $e',
    );
  }
}
```

---

## 4. Network Error Pattern

Handle network connectivity and timeout errors:

### Fetch Error with Retry

```dart
Future<void> _performFetch() async {
  try {
    await ref.read(gitActionsProvider).fetch();

    if (context.mounted) {
      NotificationService.showSuccess(
        context,
        'Fetched successfully',
      );
    }
  } catch (e) {
    if (context.mounted) {
      // Detect network errors
      final isNetworkError = e.toString().contains('network') ||
                             e.toString().contains('timeout') ||
                             e.toString().contains('connection refused');

      if (isNetworkError) {
        final shouldRetry = await BaseDialog.show<bool>(
          context: context,
          dialog: BaseDialog(
            title: 'Network Error',
            variant: DialogVariant.destructive,
            icon: PhosphorIconsRegular.wifiX,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyMediumLabel('Failed to connect to remote:'),
                const SizedBox(height: AppTheme.paddingM),
                BodySmallLabel(
                  e.toString(),
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppTheme.paddingM),
                BodyMediumLabel('Check your internet connection and try again.'),
              ],
            ),
            actions: [
              BaseButton(
                label: 'Cancel',
                variant: ButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              BaseButton(
                label: 'Retry',
                variant: ButtonVariant.primary,
                leadingIcon: PhosphorIconsRegular.arrowClockwise,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (shouldRetry == true) {
          await _performFetch();  // Recursive retry
        }
      } else {
        // Non-network error - show simple notification
        NotificationService.showError(context, 'Fetch failed: $e');
      }
    }
  }
}
```

### Offline Indicator

```dart
class NetworkStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(networkStatusProvider);

    if (isOnline) {
      return const SizedBox.shrink();  // Hidden when online
    }

    // Show offline banner
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.wifiX,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: BodyMediumLabel(
              'You are offline. Some features may not work.',
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          BaseButton(
            label: 'Retry',
            variant: ButtonVariant.secondary,
            size: ButtonSize.small,
            onPressed: () => ref.read(networkStatusProvider.notifier).check(),
          ),
        ],
      ),
    );
  }
}
```

---

## 5. Git Command Failures

Handle git command errors with detailed output:

### Git Error with Output Display

```dart
try {
  await gitService.push();
} catch (e) {
  if (e is GitException) {
    if (context.mounted) {
      final shouldRetry = await _showGitErrorDialog(
        context: context,
        title: 'Push Failed',
        error: e,
      );

      if (shouldRetry) {
        await _retryPush();
      }
    }
  } else {
    // Non-git error
    if (context.mounted) {
      NotificationService.showError(context, 'Push failed: $e');
    }
  }
}

Future<bool> _showGitErrorDialog({
  required BuildContext context,
  required String title,
  required GitException error,
}) async {
  return await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      variant: DialogVariant.destructive,
      icon: PhosphorIconsRegular.gitBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error message
          BodyMediumLabel(error.message),
          const SizedBox(height: AppTheme.paddingM),

          // Git command output (if available)
          if (error.stderr != null && error.stderr!.isNotEmpty) ...[
            TitleSmallLabel('Git Output:'),
            const SizedBox(height: AppTheme.paddingS),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  error.stderr!,
                  style: AppTheme.monoTextTheme().bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.paddingM),
          ],

          // Copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BaseButton(
                label: 'Copy Error',
                variant: ButtonVariant.tertiary,
                size: ButtonSize.small,
                leadingIcon: PhosphorIconsRegular.copy,
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: '${error.message}\n\n${error.stderr ?? ''}',
                  ));
                  NotificationService.showInfo(context, 'Error copied to clipboard');
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        BaseButton(
          label: 'Cancel',
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: 'Retry',
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.arrowClockwise,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  ) ?? false;
}
```

### Windows Filename Validation Error

Special handling for Windows reserved filenames:

```dart
Future<void> _handleStagingError(
  BuildContext context,
  String filePath,
  String errorMessage,
) async {
  // Check if this is a Windows reserved filename error
  if (WindowsFilenameValidator.isReservedNameError(errorMessage)) {
    final problematicFile = WindowsFilenameValidator
        .extractFilenameFromError(errorMessage) ?? filePath;

    await BaseDialog.show(
      context: context,
      dialog: BaseDialog(
        title: 'Windows Reserved Filename',
        variant: DialogVariant.destructive,
        icon: PhosphorIconsRegular.warningCircle,
        content: BodyMediumLabel(
          WindowsFilenameValidator.getErrorMessage(problematicFile, context),
        ),
        actions: [
          BaseButton(
            label: 'OK',
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  } else {
    // Regular staging error
    NotificationService.showError(
      context,
      'Failed to stage file: $errorMessage',
    );
  }
}
```

---

## 6. Error State in Lists/Views

Display errors when data loading fails:

### Basic Error State

```dart
class BranchesErrorState extends StatelessWidget {
  final Object error;

  const BranchesErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: AppTheme.iconSizeXL,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel('Error Loading Branches'),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            error.toString(),
            textAlign: TextAlign.center,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
```

### Error State with Retry

```dart
class ChangesErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ChangesErrorState({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: AppTheme.iconSizeXL,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.paddingL),
            TitleLargeLabel('Error Loading Status'),
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              error.toString(),
              textAlign: TextAlign.center,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.paddingL),
              BaseButton(
                label: 'Retry',
                variant: ButtonVariant.primary,
                leadingIcon: PhosphorIconsRegular.arrowClockwise,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### AsyncValue Error Pattern

```dart
final branchesAsync = ref.watch(localBranchesProvider);

return branchesAsync.when(
  data: (branches) {
    if (branches.isEmpty) {
      return BranchesEmptyState(isLocal: true);
    }
    return _buildBranchList(branches);
  },
  loading: () => const Center(
    child: CircularProgressIndicator(),
  ),
  error: (error, stack) => BranchesErrorState(
    error: error,
    onRetry: () {
      // Invalidate provider to retry
      ref.invalidate(localBranchesProvider);
    },
  ),
);
```

---

## 7. Empty Error States

When no data is available due to an error:

### No Repository Due to Error

```dart
class RepositoriesErrorState extends StatelessWidget {
  final String errorMessage;

  const RepositoriesErrorState({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      iconSize: AppTheme.iconSizeXL,
      title: 'Failed to Load Repositories',
      message: errorMessage,
      actionLabel: 'Retry',
      actionIcon: PhosphorIconsRegular.arrowClockwise,
      onActionPressed: () => _retry(),
    );
  }
}
```

### Validation Failed State

```dart
EmptyStateWidget(
  icon: PhosphorIconsRegular.xCircle,
  title: 'Repository Validation Failed',
  message: 'This directory is not a valid Git repository.',
  actions: [
    EmptyStateAction(
      label: 'Initialize Repository',
      icon: PhosphorIconsRegular.folderPlus,
      onPressed: () => _initializeRepo(),
      isPrimary: true,
    ),
    EmptyStateAction(
      label: 'Choose Different Folder',
      icon: PhosphorIconsRegular.folderOpen,
      onPressed: () => _chooseFolder(),
      isPrimary: false,
    ),
  ],
)
```

---

## Error Handling Best Practices

### 1. Always Check Context Mounted

```dart
try {
  await performOperation();
} catch (e) {
  // ✅ Always check context.mounted before showing UI
  if (context.mounted) {
    NotificationService.showError(context, 'Operation failed: $e');
  }
}
```

### 2. Provide Actionable Errors

```dart
// ❌ Bad: Vague error
'An error occurred'

// ✅ Good: Specific error with action
'Failed to push to remote: Authentication failed. Check your credentials.'
```

### 3. Include Error Context

```dart
// ❌ Bad: No context
NotificationService.showError(context, e.toString());

// ✅ Good: With context
NotificationService.showError(
  context,
  'Failed to stage file "${file.path}": $e',
);
```

### 4. Use Appropriate Error Level

```dart
// Critical errors - Dialog
await BaseDialog.show(/* destructive dialog */);

// Operation failures - SnackBar with retry
NotificationService.showError(context, 'Failed to fetch: $e');

// Validation errors - Inline
TextField(decoration: InputDecoration(errorText: _error));

// State errors - Error state widget
return BranchesErrorState(error: error);
```

### 5. Preserve Error Stack Traces

```dart
try {
  await operation();
} catch (e, stackTrace) {
  // Log full error for debugging
  Logger.error('Operation failed', e, stackTrace);

  // Show user-friendly message
  if (context.mounted) {
    NotificationService.showError(
      context,
      'Operation failed: ${e.toString()}',
    );
  }
}
```

### 6. Handle Async Errors Properly

```dart
// ✅ Good: Proper async error handling
Future<void> _performOperation() async {
  try {
    final result = await gitService.fetch();
    if (context.mounted) {
      NotificationService.showSuccess(context, 'Fetched successfully');
    }
  } catch (e) {
    if (context.mounted) {
      NotificationService.showError(context, 'Fetch failed: $e');
    }
  }
}

// ❌ Bad: No error handling
Future<void> _performOperation() async {
  final result = await gitService.fetch();  // May throw!
  NotificationService.showSuccess(context, 'Done');  // Never reached if error
}
```

### 7. Graceful Degradation

```dart
// ✅ Good: Graceful degradation
final branches = await gitService.getBranches().catchError((e) {
  Logger.error('Failed to load branches', e);
  return <GitBranch>[];  // Return empty list instead of crashing
});

// Show appropriate state
if (branches.isEmpty) {
  return BranchesEmptyState(
    isLocal: true,
    errorMessage: 'Failed to load branches. Try refreshing.',
  );
}
```

### 8. User-Friendly Error Messages

```dart
// ❌ Bad: Technical error
'GitException: remote: Repository not found. fatal: repository does not exist'

// ✅ Good: User-friendly error
'Remote repository not found. Check the URL and try again.'

// Transform technical errors
String _getUserFriendlyError(Object error) {
  final errorStr = error.toString().toLowerCase();

  if (errorStr.contains('authentication failed')) {
    return 'Authentication failed. Check your credentials.';
  }
  if (errorStr.contains('repository not found')) {
    return 'Remote repository not found. Check the URL.';
  }
  if (errorStr.contains('network') || errorStr.contains('timeout')) {
    return 'Network error. Check your connection and try again.';
  }

  // Fallback to original error
  return error.toString();
}
```

---

## Common Error Scenarios

### Repository Not Found

```dart
try {
  await gitService.openRepository(path);
} catch (e) {
  if (context.mounted) {
    await BaseDialog.show(
      context: context,
      dialog: BaseDialog(
        title: 'Repository Not Found',
        variant: DialogVariant.destructive,
        content: BodyMediumLabel(
          'The directory at "$path" is not a valid Git repository.\n\n'
          'Would you like to initialize a new repository here?',
        ),
        actions: [
          BaseButton(
            label: 'Cancel',
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.pop(context),
          ),
          BaseButton(
            label: 'Initialize',
            variant: ButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context);
              _initializeRepository(path);
            },
          ),
        ],
      ),
    );
  }
}
```

### Merge Conflict

```dart
try {
  await gitService.merge(branch);
} catch (e) {
  if (e.toString().contains('CONFLICT')) {
    if (context.mounted) {
      await BaseDialog.show(
        context: context,
        dialog: BaseDialog(
          title: 'Merge Conflict',
          variant: DialogVariant.destructive,
          icon: PhosphorIconsRegular.warning,
          content: BodyMediumLabel(
            'Merge conflicts detected. Please resolve conflicts and commit.',
          ),
          actions: [
            BaseButton(
              label: 'Resolve Conflicts',
              variant: ButtonVariant.primary,
              onPressed: () {
                Navigator.pop(context);
                ref.read(navigationDestinationProvider.notifier).state =
                    AppDestination.changes;
              },
            ),
          ],
        ),
      );
    }
  }
}
```

### Permission Denied

```dart
try {
  await gitService.deleteFile(path);
} catch (e) {
  if (e.toString().contains('permission denied')) {
    if (context.mounted) {
      NotificationService.showError(
        context,
        'Permission denied. Run as administrator or check file permissions.',
      );
    }
  } else {
    if (context.mounted) {
      NotificationService.showError(context, 'Failed to delete: $e');
    }
  }
}
```

---

## Summary

Flutter GitUI's error handling follows these principles:

1. **User-First** - Show clear, actionable error messages
2. **Context-Aware** - Include operation context in errors
3. **Recoverable** - Provide retry/recovery options when possible
4. **Informative** - Show technical details when helpful
5. **Accessible** - Copy errors to clipboard automatically
6. **Graceful** - Degrade gracefully instead of crashing
7. **Consistent** - Use standard error components across app

**Error Levels:**
- **Critical** → BaseDialog with destructive variant
- **Operation** → NotificationService.showError (SnackBar)
- **Validation** → Inline error text (TextField)
- **State** → Dedicated error state widgets
