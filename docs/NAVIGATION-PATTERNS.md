# Navigation Patterns

This document describes Flutter GitUI's navigation architecture and screen structure patterns.

## 5-Layer Navigation Architecture

Flutter GitUI uses a layered navigation approach providing multiple access paths for all features:

### Layer 1: Navigation Rail (Primary Navigation)

The left-side navigation rail provides access to main features. Located in `app_shell.dart`:

```dart
NavigationRail(
  extended: isRailExtended,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
  selectedIndex: destination.index,
  onDestinationSelected: (index) {
    ref.read(navigationDestinationProvider.notifier).state =
        AppDestination.values[index];
  },
  destinations: AppDestination.values.map((dest) {
    return NavigationRailDestination(
      icon: Icon(dest.icon),
      selectedIcon: Icon(dest.iconSelected),
      label: MenuItemLabel(dest.label(context)),
    );
  }).toList(),
)
```

**Features:**
- Collapsible rail (72px collapsed, 256px extended)
- Badge support for notifications (uncommitted changes, stash count)
- Keyboard shortcuts (Ctrl+1 through Ctrl+8)
- Material Design 3 surfaces and colors

**Destinations:**
1. Workspaces (Ctrl+1)
2. Repositories (Ctrl+2)
3. Changes (Ctrl+3)
4. History (Ctrl+4)
5. Browse (Ctrl+5)
6. Branches (Ctrl+6)
7. Stashes (Ctrl+7)
8. Tags (Ctrl+8)
9. Settings (Ctrl+,)

### Layer 2: Command Palette (Quick Actions)

Accessible via keyboard shortcut (Ctrl+K) or search icon:

```dart
const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
  _showCommandPalette(context);
},
```

**Features:**
- Modal bottom sheet with search
- Fuzzy search across all available commands
- Keyboard navigation (arrow keys, Enter)
- Context-aware actions based on current screen

### Layer 3: Contextual Actions (Top Bar)

Quick action buttons in the top bar provide context-specific operations:

```dart
// Git operations (Fetch, Pull, Push)
if (currentRepoPath != null) ...[
  _buildGitOperationButton(
    context,
    ref,
    PhosphorIconsRegular.arrowClockwise,
    AppLocalizations.of(context)!.fetch,
    () => _performFetch(ref),
  ),
  // ... Pull, Push buttons
]
```

**Common Actions:**
- Workspace/Repository/Branch switchers
- Create Branch / Create PR buttons
- Git operations (Fetch, Pull, Push, Merge)
- Quick settings menu
- Language selector

### Layer 4: Quick Action Bar (Screen-Level)

Each screen has screen-specific actions in the app bar:

```dart
appBar: StandardAppBar(
  title: AppDestination.branches.label(context),
  onRefresh: () => ref.read(gitActionsProvider).refreshBranches(),
  moreMenuItems: [
    PopupMenuItem(
      child: MenuItemContent(
        icon: PhosphorIconsRegular.plus,
        label: l10n.createBranch,
      ),
      onTap: () => _showCreateBranchDialog(context),
    ),
  ],
),
```

**Standard Actions:**
- Refresh button (refresh current view)
- More menu (3-dot menu with screen-specific actions)
- View mode toggles (grid/list)
- Filter chips

### Layer 5: FAB (Floating Action Button)

Some screens use FABs for primary actions (e.g., Changes screen has draggable Speed Dial FAB).

```dart
// Example: Draggable FAB in Changes screen
SpeedDial(
  icon: PhosphorIconsRegular.plus,
  activeIcon: PhosphorIconsRegular.x,
  children: [
    SpeedDialChild(
      child: Icon(PhosphorIconsRegular.file),
      label: 'Stage All',
      onTap: () => _stageAll(),
    ),
    // ... more actions
  ],
)
```

---

## Screen Structure Pattern

All screens follow this consistent structure:

### 1. Standard Scaffold Layout

```dart
class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  @override
  Widget build(BuildContext context) {
    final repositoryPath = ref.watch(currentRepositoryPathProvider);

    // No repository open - show empty state
    if (repositoryPath == null) {
      return const NoRepositoryEmptyState();
    }

    return Scaffold(
      appBar: StandardAppBar(
        title: AppDestination.branches.label(context),
        onRefresh: () => ref.read(gitActionsProvider).refreshBranches(),
        moreMenuItems: [ /* actions */ ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: /* content */,
      ),
    );
  }
}
```

### 2. AsyncValue Pattern

Use `AsyncValue.when()` for loading/error/data states:

```dart
final branchesAsync = ref.watch(localBranchesProvider);

return branchesAsync.when(
  data: (branches) {
    if (branches.isEmpty) {
      return BranchesEmptyState(isLocal: true);
    }
    return /* list view */;
  },
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stack) => BranchesErrorState(error: error),
);
```

### 3. StandardAppBar Component

Provides consistent header across all screens:

```dart
StandardAppBar(
  title: 'Screen Title',           // Required
  onRefresh: () => refresh(),      // Optional refresh callback
  additionalActions: [             // Optional custom widgets
    SegmentedButton(...),
  ],
  moreMenuItems: [                 // Optional 3-dot menu
    PopupMenuItem(...),
  ],
)
```

---

## Feature Directory Organization

Each feature follows this structure:

```
features/
  branches/
    screens/                    # Main screen(s)
      branches_screen.dart
    dialogs/                    # Feature-specific dialogs
      create_branch_dialog.dart
      delete_branch_dialog.dart
    widgets/                    # Reusable widgets
      branch_list_tile.dart
      branches_empty_state.dart
      branches_error_state.dart
    services/                   # Business logic
      branches_service.dart
    providers/                  # State management
      branches_provider.dart
    models/                     # Data models
      branch.dart
```

### Key Files

**screens/** - Main feature screens
- Must extend `ConsumerStatefulWidget` for Riverpod state
- Handle navigation, user interactions
- Delegate business logic to services

**dialogs/** - Feature-specific dialogs
- Use `BaseDialog` component
- Return data via `Navigator.pop(context, result)`
- Include form validation

**widgets/** - Reusable UI components
- Empty states (when no data)
- Error states (when loading fails)
- List tiles (item renderers)
- Status indicators

**services/** - Business logic
- Pure Dart classes (no Flutter dependencies)
- Repository pattern for data access
- Validation and filtering logic

**providers/** - State management
- Riverpod providers
- AsyncValue for async data
- State notifiers for mutable state

**models/** - Data classes
- Freezed for immutability
- JSON serialization
- Validation logic

---

## Empty State Pattern

Use `EmptyStateWidget` for all empty states:

```dart
class BranchesEmptyState extends StatelessWidget {
  final bool isLocal;

  const BranchesEmptyState({super.key, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.gitBranch,
      title: isLocal ? 'No Local Branches' : 'No Remote Branches',
      message: isLocal
          ? 'Create your first branch to get started'
          : 'No remote branches found. Try fetching from remote.',
      actionLabel: isLocal ? 'Create Branch' : 'Fetch',
      actionIcon: isLocal
          ? PhosphorIconsRegular.plus
          : PhosphorIconsRegular.arrowClockwise,
      onActionPressed: () => /* action */,
    );
  }
}
```

**Empty State Variants:**

### No Repository State
```dart
// Pre-configured component
const NoRepositoryEmptyState()

// Or custom message
EmptyStateWidget(
  icon: PhosphorIconsRegular.folderOpen,
  title: 'No Repository Open',
  message: 'Open a repository to see changes',
  action: BaseButton(
    label: 'Open Repository',
    variant: ButtonVariant.primary,
    leadingIcon: PhosphorIconsRegular.folderOpen,
    onPressed: () => _openRepository(),
  ),
)
```

### Empty List State
```dart
EmptyStateWidget(
  icon: PhosphorIconsRegular.gitBranch,
  title: 'No Branches',
  message: 'Create your first branch to get started',
  actionLabel: 'Create Branch',
  actionIcon: PhosphorIconsRegular.plus,
  onActionPressed: () => _createBranch(),
)
```

### Clean State (No Changes)
```dart
class ChangesCleanState extends StatelessWidget {
  const ChangesCleanState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.check,
      title: 'No Changes',
      message: 'Your working directory is clean',
    );
  }
}
```

---

## Error State Pattern

Use dedicated error state widgets:

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
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel('Error Loading Branches'),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(
            error.toString(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

**Error State Guidelines:**
- Always show error icon (PhosphorIconsRegular.warningCircle)
- Display error message in BodySmallLabel
- Use error color from theme
- Consider adding retry button for recoverable errors

---

## Loading State Pattern

Use `CircularProgressIndicator` for async loading:

```dart
branchesAsync.when(
  data: (branches) => /* content */,
  loading: () => const Center(
    child: CircularProgressIndicator(),
  ),
  error: (error, stack) => /* error state */,
)
```

**Loading with Message:**
```dart
const LoadingState(message: 'Loading branches...')

// Or custom
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: AppTheme.paddingL),
      BodyMediumLabel('Loading branches...'),
    ],
  ),
)
```

---

## Batch Operations Pattern

Use `BaseListItem` with multi-selection for batch operations:

### 1. Multi-Select Provider

```dart
// State provider for selected items
final repositoryMultiSelectProvider =
    StateNotifierProvider<RepositoryMultiSelectNotifier, Set<String>>((ref) {
  return RepositoryMultiSelectNotifier();
});

class RepositoryMultiSelectNotifier extends StateNotifier<Set<String>> {
  RepositoryMultiSelectNotifier() : super({});

  void toggleSelection(WorkspaceRepository repository) {
    if (state.contains(repository.path)) {
      state = {...state}..remove(repository.path);
    } else {
      state = {...state, repository.path};
    }
  }

  void clearSelection() {
    state = {};
  }

  void selectAll(List<WorkspaceRepository> repositories) {
    state = repositories.map((r) => r.path).toSet();
  }
}
```

### 2. BaseListItem with Selection

```dart
BaseListItem(
  content: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TitleMediumLabel(repo.displayName),
      BodySmallLabel(repo.path),
    ],
  ),
  leading: Checkbox(
    value: isMultiSelected,
    onChanged: (_) => onToggleSelection(),
  ),
  isSelected: isSelected,          // Primary selection (current repo)
  isMultiSelected: isMultiSelected, // Secondary selection (batch ops)
  onTap: () {
    // If multi-select active, toggle selection
    if (selectedPaths.isNotEmpty) {
      onToggleSelection();
    } else {
      // Otherwise, switch to this repository
      _switchToRepository(repo);
    }
  },
)
```

### 3. Batch Operation Execution

```dart
Future<void> _performBatchOperation(WidgetRef ref) async {
  final selectedPaths = ref.read(repositoryMultiSelectProvider);
  final allRepositories = ref.read(workspaceProvider);

  // Get selected repositories
  final repositories = allRepositories
      .where((repo) => selectedPaths.contains(repo.path))
      .toList();

  if (repositories.isEmpty) return;

  // Execute batch operation
  final results = await showBatchOperationProgressDialog(
    context,
    title: 'Fetching ${repositories.length} Repositories',
    repositories: repositories,
    operation: (onProgress) => service.fetchAll(
      repositories,
      onProgress: onProgress,
    ),
  );

  // Clear selection after operation
  ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
}
```

### 4. Selection UI Feedback

```dart
// Show selection count in filter chips area
if (selectedRepositories.isNotEmpty) ...[
  Chip(
    avatar: Icon(PhosphorIconsRegular.checkCircle),
    label: Text('${selectedRepositories.length} selected'),
    onDeleted: () {
      ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
    },
  ),
]
```

---

## Keyboard Navigation

Global keyboard shortcuts defined in `app_shell.dart`:

```dart
Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
  return {
    // Command Palette
    const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
      _showCommandPalette(context);
    },

    // Toggle Command Log
    const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
      ref.read(commandLogPanelVisibleProvider.notifier).state =
          !ref.read(commandLogPanelVisibleProvider);
    },

    // Repository Switcher
    const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
      _showRepositorySwitcher(context);
    },

    // Navigation shortcuts (1-8)
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
      _navigateTo(AppDestination.workspaces);
    },
    // ... etc
  };
}
```

**Implementing Keyboard Shortcuts in Screens:**

```dart
return CallbackShortcuts(
  bindings: {
    const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
      _createNew();
    },
    const SingleActivator(LogicalKeyboardKey.delete): () {
      _deleteSelected();
    },
  },
  child: Focus(
    autofocus: true,
    child: /* content */,
  ),
);
```

---

## Screen Layout Templates

### Template 1: List Screen with Tabs

```dart
class BranchesScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: 'Branches',
        onRefresh: () => refresh(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          children: [
            // Search bar
            InlineSearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Local', icon: Icon(PhosphorIconsRegular.folder)),
                Tab(text: 'Remote', icon: Icon(PhosphorIconsRegular.cloud)),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLocalBranches(),
                  _buildRemoteBranches(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Template 2: Grid/List Toggle Screen

```dart
class RepositoriesScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(repositoriesViewModeProvider);

    return Scaffold(
      appBar: StandardAppBar(
        title: 'Repositories',
        additionalActions: [
          SegmentedButton<RepositoriesViewMode>(
            segments: const [
              ButtonSegment(
                value: RepositoriesViewMode.grid,
                icon: Icon(PhosphorIconsRegular.gridFour),
              ),
              ButtonSegment(
                value: RepositoriesViewMode.list,
                icon: Icon(PhosphorIconsRegular.listBullets),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (newMode) {
              ref.read(configProvider.notifier)
                  .setRepositoriesViewMode(newMode.first);
            },
          ),
        ],
      ),
      body: viewMode == RepositoriesViewMode.grid
          ? _buildGrid()
          : _buildList(),
    );
  }
}
```

### Template 3: Split View Screen

```dart
class ChangesScreen extends ConsumerStatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(title: 'Changes'),
      body: Row(
        children: [
          // Left: File tree
          Expanded(
            flex: 1,
            child: GitStatusTreeView(
              stagedFiles: stagedFiles,
              unstagedFiles: unstagedFiles,
              onToggleStage: (file, staged) => _toggleStage(file, staged),
            ),
          ),

          // Divider
          const VerticalDivider(width: 1),

          // Right: Diff viewer
          Expanded(
            flex: 2,
            child: DiffViewer(selectedFile: selectedFile),
          ),
        ],
      ),
    );
  }
}
```

---

## Navigation State Management

### Current Repository Provider

```dart
// Track currently selected repository
final currentRepositoryPathProvider = StateProvider<String?>((ref) => null);

// Use in screens
final repositoryPath = ref.watch(currentRepositoryPathProvider);
if (repositoryPath == null) {
  return const NoRepositoryEmptyState();
}
```

### Navigation Destination Provider

```dart
// Track current navigation destination
final navigationDestinationProvider =
    StateProvider<AppDestination>((ref) => AppDestination.repositories);

// Navigate programmatically
ref.read(navigationDestinationProvider.notifier).state =
    AppDestination.changes;
```

### Navigation Rail Extended State

```dart
// Track rail expanded/collapsed state
final navigationRailExtendedProvider = StateProvider<bool>((ref) {
  final config = ref.watch(configProvider);
  return config.ui.navigationRailExtended;
});

// Toggle
ref.read(configProvider.notifier)
    .setNavigationRailExtended(!isRailExtended);
```

---

## Best Practices

1. **Always handle empty repository state** - Every screen should check for `currentRepositoryPathProvider == null`

2. **Use StandardAppBar** - Provides consistent header and refresh functionality

3. **Follow AsyncValue pattern** - Use `.when()` for loading/error/data states

4. **Organize by feature** - Keep related screens, dialogs, widgets together

5. **Provide keyboard shortcuts** - Add shortcuts for primary actions

6. **Support multi-selection** - Use BaseListItem with isMultiSelected for batch operations

7. **Show contextual actions** - Display relevant actions in app bar and context menus

8. **Use consistent spacing** - Follow AppTheme padding constants (XS/S/M/L/XL)

9. **Provide feedback** - Use NotificationService for operation results

10. **Handle errors gracefully** - Show error states with retry options
