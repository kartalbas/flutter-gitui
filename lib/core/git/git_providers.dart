import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import 'git_service.dart';
import 'git_command_log_provider.dart';
import 'git_repository_watcher.dart';
import 'git_batch_context.dart';
import '../services/progress_service.dart';
import '../services/logger_service.dart';
import 'models/file_status.dart';
import 'models/commit.dart';
import 'models/branch.dart';
import 'models/remote.dart';
import 'models/stash.dart';
import 'models/tag.dart';
import 'models/merge_conflict.dart';
import 'models/reflog_entry.dart';
import 'models/bisect_state.dart';
import 'models/rebase_state.dart';
import 'models/file_change.dart';
import 'models/blame.dart';
import '../config/config_providers.dart';
import '../workspace/repository_status_provider.dart';
import '../workspace/workspace_provider.dart';

/// Git service provider (depends on repository path)
final gitServiceProvider = Provider<GitService?>((ref) {
  final repoPath = ref.watch(currentRepositoryPathProvider);
  if (repoPath == null) return null;

  // Get git executable path from config
  final gitExecutablePath = ref.watch(gitExecutablePathProvider);

  // Get protected branches from config
  final config = ref.watch(configProvider);
  final protectedBranches = config.git.protectedBranches;

  // Wire up command logging and progress tracking
  return GitService(
    repoPath,
    gitExecutablePath: gitExecutablePath,
    protectedBranches: protectedBranches,
    onCommandExecuted: (log) {
      // Add to command log provider for UI display
      ref.read(gitCommandLogProvider.notifier).addLog(log);

      // Also log to git.log file
      Logger.git(
        command: log.command,
        timestamp: log.timestamp,
        duration: log.duration ?? Duration.zero,
        output: log.output,
        error: log.error,
        exitCode: log.exitCode,
      );
    },
    onProgressUpdate: (operationName, isComplete) {
      // Global progress tracking for all git operations
      // Schedule the progress update asynchronously to avoid modifying
      // providers during another provider's initialization
      Future.microtask(() {
        if (isComplete) {
          ref.read(progressProvider.notifier).completeOperation();
        } else {
          ref.read(progressProvider.notifier).startOperation(
                operationName,
                0,
                isIndeterminate: true,
              );
        }
      });
    },
  );
});

/// Repository file watcher provider
/// Watches for file system changes and automatically refreshes the status
final repositoryWatcherProvider = Provider<GitRepositoryWatcher?>((ref) {
  final repoPath = ref.watch(currentRepositoryPathProvider);
  if (repoPath == null) return null;

  // Create watcher that auto-refreshes on changes
  final watcher = GitRepositoryWatcher(
    repositoryPath: repoPath,
    onRepositoryChanged: () {
      // Automatically refresh status when repository changes
      ref.read(gitActionsProvider).refreshStatus();
    },
  );

  // Start watching
  watcher.start();

  // Cleanup when provider is disposed
  ref.onDispose(() {
    watcher.dispose();
  });

  return watcher;
});

/// Current branch name provider
final currentBranchProvider = FutureProvider<String?>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return null;

  try {
    return await gitService.getCurrentBranch();
  } catch (e) {
    return null;
  }
});

/// Repository status provider (file changes)
final repositoryStatusProvider = FutureProvider<List<FileStatus>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getStatus();
  } catch (e) {
    return [];
  }
});

/// Staged files provider
final stagedFilesProvider = Provider<List<FileStatus>>((ref) {
  final allStatuses = ref.watch(repositoryStatusProvider).value ?? [];
  return allStatuses.where((s) => s.isStaged).toList();
});

/// Unstaged files provider
final unstagedFilesProvider = Provider<List<FileStatus>>((ref) {
  final allStatuses = ref.watch(repositoryStatusProvider).value ?? [];
  return allStatuses.where((s) => s.hasUnstagedChanges || s.isUntracked).toList();
});

/// Repository is clean provider
final isRepositoryCleanProvider = Provider<bool>((ref) {
  final allStatuses = ref.watch(repositoryStatusProvider).value ?? [];
  return allStatuses.isEmpty;
});

/// Check if Git is installed
final isGitInstalledProvider = FutureProvider<bool>((ref) async {
  return await GitService.isGitInstalled();
});

/// Commit history provider
final commitHistoryProvider = FutureProvider<List<GitCommit>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  final limit = ref.watch(defaultCommitLimitProvider);

  try {
    return await gitService.getLog(limit: limit);
  } catch (e) {
    return [];
  }
});

/// Commit history with limit provider
final commitHistoryLimitProvider = FutureProvider.family<List<GitCommit>, int>((ref, limit) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getLog(limit: limit);
  } catch (e) {
    return [];
  }
});

/// File history provider
final fileHistoryProvider = FutureProvider.family<List<GitCommit>, String>((ref, filePath) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getFileHistory(filePath);
  } catch (e) {
    return [];
  }
});

/// File blame provider (who changed what when at line level)
///
/// Provides line-by-line authorship information for a file.
/// Returns [FileBlame] with all line information including:
/// - Commit hash, author, date for each line
/// - Line content
/// - Summary of commit that changed each line
///
/// Parameters:
/// - [filePath]: Path to the file relative to repository root
final fileBlameProvider = FutureProvider.family<FileBlame?, String>((ref, filePath) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return null;

  try {
    return await gitService.getBlame(filePath);
  } catch (e) {
    // Return null on error (file doesn't exist, etc.)
    return null;
  }
});

/// All branches provider (local and remote)
final allBranchesProvider = FutureProvider<List<GitBranch>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getAllBranches();
  } catch (e) {
    return [];
  }
});

/// Local branches provider
final localBranchesProvider = FutureProvider<List<GitBranch>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getLocalBranches();
  } catch (e) {
    return [];
  }
});

/// Remote branches provider
final remoteBranchesProvider = FutureProvider<List<GitBranch>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getRemoteBranches();
  } catch (e) {
    return [];
  }
});

/// Current branch object provider (detailed info)
final currentBranchObjectProvider = Provider<GitBranch?>((ref) {
  final currentBranchName = ref.watch(currentBranchProvider).value;
  final localBranches = ref.watch(localBranchesProvider).value ?? [];

  if (currentBranchName == null) return null;

  try {
    return localBranches.firstWhere((b) => b.isCurrent);
  } catch (e) {
    return null;
  }
});

/// All remotes provider
final remotesProvider = FutureProvider<List<GitRemote>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getRemotes();
  } catch (e) {
    return [];
  }
});

/// Remote names provider
final remoteNamesProvider = FutureProvider<List<String>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getRemoteNames();
  } catch (e) {
    return [];
  }
});

/// All stashes provider
final stashesProvider = FutureProvider<List<GitStash>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getStashes();
  } catch (e) {
    return [];
  }
});

/// Stash count provider
final stashCountProvider = Provider<int>((ref) {
  final stashes = ref.watch(stashesProvider).value ?? [];
  return stashes.length;
});

/// All tags provider
final tagsProvider = FutureProvider<List<GitTag>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getTags();
  } catch (e) {
    return [];
  }
});

/// Tag count provider
final tagCountProvider = Provider<int>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return tags.length;
});

/// Annotated tags provider
final annotatedTagsProvider = Provider<List<GitTag>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return tags.where((tag) => tag.isAnnotated).toList();
});

/// Lightweight tags provider
final lightweightTagsProvider = Provider<List<GitTag>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? [];
  return tags.where((tag) => tag.isLightweight).toList();
});

/// Local-only tags provider (tags not pushed to remote)
final localOnlyTagsProvider = FutureProvider<Set<String>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return {};

  // Get the first available remote, default to 'origin'
  final remotes = await ref.watch(remoteNamesProvider.future);
  if (remotes.isEmpty) return {};

  final remoteName = remotes.contains('origin') ? 'origin' : remotes.first;

  try {
    return await gitService.getLocalOnlyTags(remoteName);
  } catch (e) {
    return {};
  }
});

/// Count of local-only tags
final localOnlyTagsCountProvider = Provider<int>((ref) {
  final localOnlyTags = ref.watch(localOnlyTagsProvider).value ?? {};
  return localOnlyTags.length;
});

/// Remote-only tags provider (tags on remote but not local)
final remoteOnlyTagsProvider = FutureProvider<Set<String>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return {};

  // Get the first available remote, default to 'origin'
  final remotes = await ref.watch(remoteNamesProvider.future);
  if (remotes.isEmpty) return {};

  final remoteName = remotes.contains('origin') ? 'origin' : remotes.first;

  try {
    return await gitService.getRemoteOnlyTags(remoteName);
  } catch (e) {
    return {};
  }
});

/// Count of remote-only tags
final remoteOnlyTagsCountProvider = Provider<int>((ref) {
  final remoteOnlyTags = ref.watch(remoteOnlyTagsProvider).value ?? {};
  return remoteOnlyTags.length;
});

/// Merge state provider
final mergeStateProvider = FutureProvider<MergeState>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return const MergeState.empty();

  try {
    return await gitService.getMergeState();
  } catch (e) {
    return const MergeState.empty();
  }
});

/// Check if merge is in progress
final isMergeInProgressProvider = Provider<bool>((ref) {
  final mergeState = ref.watch(mergeStateProvider).value;
  return mergeState?.isInProgress ?? false;
});

/// Merge conflicts provider
final mergeConflictsProvider = Provider<List<MergeConflict>>((ref) {
  final mergeState = ref.watch(mergeStateProvider).value;
  return mergeState?.conflicts ?? [];
});

/// Unresolved conflicts count provider
final unresolvedConflictsCountProvider = Provider<int>((ref) {
  final mergeState = ref.watch(mergeStateProvider).value;
  return mergeState?.unresolvedCount ?? 0;
});

// ============================================
// Reflog
// ============================================

/// Reflog entries provider
final reflogProvider = FutureProvider<List<ReflogEntry>>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getReflog();
  } catch (e) {
    return [];
  }
});

/// Reflog entries count provider
final reflogCountProvider = Provider<int>((ref) {
  final reflog = ref.watch(reflogProvider).value;
  return reflog?.length ?? 0;
});

/// Actions provider for Git operations
class GitActions {
  final Ref ref;

  GitActions(this.ref);

  // Batch operation support
  GitBatchContext? _batchContext;

  /// Start a batch operation
  void beginBatch({String? name, int? totalOperations}) {
    _batchContext = ref.read(gitBatchContextProvider);
    _batchContext!.begin(name: name, totalOperations: totalOperations);
  }

  /// End batch operation and execute pending refreshes
  Future<void> endBatch() async {
    if (_batchContext == null || !_batchContext!.isActive) return;

    final pending = _batchContext!.getPendingRefreshes();
    _batchContext!.end();
    _batchContext = null;

    // Execute all pending refreshes
    await batchRefresh(
      status: pending.contains(RefreshType.status),
      branches: pending.contains(RefreshType.branches),
      stashes: pending.contains(RefreshType.stashes),
      tags: pending.contains(RefreshType.tags),
      remotes: pending.contains(RefreshType.remotes),
      history: pending.contains(RefreshType.history),
      mergeState: pending.contains(RefreshType.mergeState),
    );
  }

  /// Execute consolidated batch refresh
  Future<void> batchRefresh({
    bool status = false,
    bool branches = false,
    bool stashes = false,
    bool tags = false,
    bool remotes = false,
    bool history = false,
    bool mergeState = false,
  }) async {
    if (status) await refreshStatus();
    if (branches) await refreshBranches();
    if (stashes) ref.invalidate(stashesProvider);
    if (tags) ref.invalidate(tagsProvider);
    if (remotes) ref.invalidate(remotesProvider);
    if (history) ref.invalidate(commitHistoryProvider);
    if (mergeState) ref.invalidate(mergeStateProvider);
  }

  /// Helper to mark refresh for batch or execute immediately
  Future<void> _refreshOrQueue(RefreshType type, Future<void> Function() refreshFn) async {
    if (_batchContext != null && _batchContext!.isActive) {
      _batchContext!.markForRefresh(type);
    } else {
      await refreshFn();
    }
  }

  /// Refresh repository status
  Future<void> refreshStatus() async {
    ref.invalidate(repositoryStatusProvider);
    ref.invalidate(currentBranchProvider);

    // Also refresh workspace repository status for navigation badge
    final currentRepoPath = ref.read(currentRepositoryPathProvider);
    if (currentRepoPath != null) {
      // Get the repository object and refresh its status
      final repositories = ref.read(workspaceProvider);
      final repository = repositories.where((r) => r.path == currentRepoPath).firstOrNull;
      if (repository != null) {
        await ref.read(workspaceRepositoryStatusProvider.notifier).refreshStatus(repository);
      }
    }
  }

  /// Stage a file
  Future<void> stageFile(String path, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.stageFile(path);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Unstage a file
  Future<void> unstageFile(String path, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.unstageFile(path);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Stage all files
  Future<void> stageAll() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.stageAll();
    await refreshStatus();
  }

  /// Unstage all files
  Future<void> unstageAll() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.unstageAll();
    await refreshStatus();
  }

  /// Commit staged changes
  Future<void> commit(String message, {bool amend = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.commit(message, amend: amend);
    await refreshStatus();

    // Also refresh workspace repository status for navigation badge
    final currentRepoPath = ref.read(currentRepositoryPathProvider);
    if (currentRepoPath != null) {
      // Get the repository object and refresh its status
      final repositories = ref.read(workspaceProvider);
      final repository = repositories.where((r) => r.path == currentRepoPath).firstOrNull;
      if (repository != null) {
        await ref.read(workspaceRepositoryStatusProvider.notifier).refreshStatus(repository);
      }
    }
  }

  /// Discard changes in a file
  Future<void> discardFile(String path, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.discardFile(path);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Discard all changes
  Future<void> discardAll() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.discardAll();
    await refreshStatus();
  }

  /// Delete untracked file
  Future<void> deleteUntrackedFile(String path, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.deleteUntrackedFile(path);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Stage multiple files in batch
  Future<void> stageFiles(List<String> paths) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final path in paths) {
      await gitService.stageFile(path);
    }
    await refreshStatus();
  }

  /// Unstage multiple files in batch
  Future<void> unstageFiles(List<String> paths) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final path in paths) {
      await gitService.unstageFile(path);
    }
    await refreshStatus();
  }

  /// Discard changes in multiple files
  Future<void> discardFiles(List<String> paths) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final path in paths) {
      await gitService.discardFile(path);
    }
    await refreshStatus();
  }

  /// Delete multiple untracked files
  Future<void> deleteUntrackedFiles(List<String> paths) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final path in paths) {
      await gitService.deleteUntrackedFile(path);
    }
    await refreshStatus();
  }

  /// Open repository
  Future<bool> openRepository(String path) async {
    // Check if valid repository
    if (!await GitService.isGitRepository(path)) {
      return false;
    }

    // Set current repository path
    await ref.read(configProvider.notifier).setCurrentRepository(path);

    // Refresh status
    await refreshStatus();

    return true;
  }

  /// Close current repository
  Future<void> closeRepository() async {
    await ref.read(configProvider.notifier).setCurrentRepository(null);
  }

  // Branch Actions

  /// Refresh branch list
  Future<void> refreshBranches() async {
    ref.invalidate(allBranchesProvider);
    ref.invalidate(localBranchesProvider);
    ref.invalidate(remoteBranchesProvider);
    ref.invalidate(currentBranchProvider);
  }

  /// Create a new branch
  Future<void> createBranch(
    String branchName, {
    String? startPoint,
    bool checkout = false,
    bool skipRefresh = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.createBranch(
      branchName,
      startPoint: startPoint,
      checkout: checkout,
    );

    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.branches, refreshBranches);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Delete a branch
  Future<void> deleteBranch(String branchName, {bool force = false, bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.deleteBranch(branchName, force: force);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.branches, refreshBranches);
    }
  }

  /// Delete a remote branch
  Future<void> deleteRemoteBranch(String remoteName, String branchName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.deleteRemoteBranch(remoteName, branchName);
    await refreshBranches();
  }

  /// Checkout (switch to) a branch
  Future<void> switchBranch(String branchName, {bool createIfMissing = false, bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.checkoutBranch(branchName, createIfMissing: createIfMissing);

    if (!skipRefresh) {
      // Invalidate all relevant providers to ensure UI updates
      await _refreshOrQueue(RefreshType.branches, refreshBranches);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
      if (_batchContext != null && _batchContext!.isActive) {
        _batchContext!.markForRefresh(RefreshType.history);
        _batchContext!.markForRefresh(RefreshType.stashes);
        _batchContext!.markForRefresh(RefreshType.tags);
        _batchContext!.markForRefresh(RefreshType.mergeState);
      } else {
        ref.invalidate(commitHistoryProvider);
        ref.invalidate(stashesProvider);
        ref.invalidate(tagsProvider);
        ref.invalidate(mergeStateProvider);
      }
    }
  }

  /// Rename a branch
  Future<void> renameBranch(
    String newName, {
    String? oldName,
    bool force = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.renameBranch(newName, oldName: oldName, force: force);
    await refreshBranches();
  }

  /// Merge a branch into the current branch
  Future<void> mergeBranch(
    String branchName, {
    bool fastForwardOnly = false,
    bool noFastForward = false,
    bool squash = false,
    String? message,
    bool skipRefresh = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.mergeBranch(
      branchName,
      fastForwardOnly: fastForwardOnly,
      noFastForward: noFastForward,
      squash: squash,
      message: message,
    );

    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.branches, refreshBranches);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
      await _refreshOrQueue(RefreshType.mergeState, refreshMergeState);
    }
  }

  /// Set upstream tracking branch
  Future<void> setUpstream(String upstreamBranch, {String? branchName}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.setUpstream(upstreamBranch, branchName: branchName);
    await refreshBranches();
  }

  /// Unset upstream tracking branch
  Future<void> unsetUpstream({String? branchName}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.unsetUpstream(branchName: branchName);
    await refreshBranches();
  }

  // Remote Actions

  /// Refresh remotes list
  Future<void> refreshRemotes() async {
    ref.invalidate(remotesProvider);
    ref.invalidate(remoteNamesProvider);
  }

  /// Add a new remote
  Future<void> addRemote(String name, String url) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.addRemote(name, url);
    await refreshRemotes();
  }

  /// Remove a remote
  Future<void> removeRemote(String name) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.removeRemote(name);
    await refreshRemotes();
    await refreshBranches(); // Remote branches may have changed
  }

  /// Rename a remote
  Future<void> renameRemote(String oldName, String newName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.renameRemote(oldName, newName);
    await refreshRemotes();
    await refreshBranches();
  }

  /// Set remote URL
  Future<void> setRemoteUrl(String name, String url, {bool push = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.setRemoteUrl(name, url, push: push);
    await refreshRemotes();
  }

  /// Fetch from remote
  Future<void> fetchRemote({
    String? remote,
    String? branch,
    bool prune = false,
    bool all = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.fetch(
      remote: remote,
      branch: branch,
      prune: prune,
      all: all,
    );
    await refreshBranches();
    await refreshStatus();
  }

  /// Pull from remote
  Future<void> pullRemote({
    String? remote,
    String? branch,
    bool rebase = false,
    bool ffOnly = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.pull(
      remote: remote,
      branch: branch,
      rebase: rebase,
      ffOnly: ffOnly,
    );
    await refreshBranches();
    await refreshStatus();
  }

  /// Push to remote
  Future<void> pushRemote({
    String? remote,
    String? branch,
    bool force = false,
    bool setUpstream = false,
    bool all = false,
    bool tags = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.push(
      remote: remote,
      branch: branch,
      force: force,
      setUpstream: setUpstream,
      all: all,
      tags: tags,
    );
    await refreshBranches();
  }

  /// Prune remote tracking branches
  Future<void> pruneRemote(String remote) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.pruneRemote(remote);
    await refreshBranches();
  }

  // Stash Actions

  /// Refresh stashes list
  Future<void> refreshStashes() async {
    ref.invalidate(stashesProvider);
  }

  /// Create a new stash
  Future<void> createStash({
    String? message,
    bool includeUntracked = false,
    bool keepIndex = false,
    List<String>? files,
    bool skipRefresh = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.createStash(
      message: message,
      includeUntracked: includeUntracked,
      keepIndex: keepIndex,
      files: files,
    );
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.stashes, refreshStashes);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Apply a stash
  Future<void> applyStash(String stashRef, {bool index = false, bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.applyStash(stashRef, index: index);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.stashes, refreshStashes);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Pop a stash (apply and remove)
  Future<void> popStash(String stashRef, {bool index = false, bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.popStash(stashRef, index: index);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.stashes, refreshStashes);
      await _refreshOrQueue(RefreshType.status, refreshStatus);
    }
  }

  /// Drop a stash
  Future<void> dropStash(String stashRef, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.dropStash(stashRef);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.stashes, refreshStashes);
    }
  }

  /// Clear all stashes
  Future<void> clearStashes() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.clearStashes();
    await refreshStashes();
  }

  /// Create branch from stash
  Future<void> branchFromStash(String branchName, String stashRef) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.branchFromStash(branchName, stashRef);
    await refreshStashes();
    await refreshBranches();
    await refreshStatus();
  }

  // Tag Actions

  /// Refresh tags list
  Future<void> refreshTags() async {
    ref.invalidate(tagsProvider);
    ref.invalidate(localOnlyTagsProvider);
    ref.invalidate(remoteOnlyTagsProvider);
  }

  /// Create a lightweight tag
  Future<void> createLightweightTag(String tagName, {String? commitHash, bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.createLightweightTag(tagName, commitHash: commitHash);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.tags, refreshTags);
    }
  }

  /// Create an annotated tag
  Future<void> createAnnotatedTag(
    String tagName, {
    required String message,
    String? commitHash,
    bool skipRefresh = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.createAnnotatedTag(
      tagName,
      message: message,
      commitHash: commitHash,
    );
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.tags, refreshTags);
    }
  }

  /// Delete a tag (local)
  Future<void> deleteTag(String tagName, {bool skipRefresh = false}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.deleteTag(tagName);
    if (!skipRefresh) {
      await _refreshOrQueue(RefreshType.tags, refreshTags);
    }
  }

  /// Delete a remote tag
  Future<void> deleteRemoteTag(String remoteName, String tagName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.deleteRemoteTag(remoteName, tagName);
    await refreshTags();
  }

  /// Push a tag to remote
  /// Note: Progress tracking is handled by batch operations in TagsScreen
  Future<void> pushTag(String remoteName, String tagName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.pushTag(remoteName, tagName);
  }

  /// Push all tags to remote
  Future<void> pushAllTags(String remoteName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.pushAllTags(remoteName);
  }

  /// Fetch tags from remote
  Future<void> fetchTags({String? remoteName}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.fetchTags(remoteName: remoteName);
    await refreshTags();
  }

  /// Checkout a tag
  Future<void> checkoutTag(String tagName) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.checkoutTag(tagName);
    await refreshBranches();
    await refreshStatus();
  }

  /// Push multiple tags to remote in batch
  Future<void> pushTags(String remoteName, List<String> tagNames) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final tagName in tagNames) {
      await gitService.pushTag(remoteName, tagName);
    }
    ref.invalidate(tagsProvider);
  }

  /// Delete multiple tags in batch
  Future<void> deleteTags(List<String> tagNames, {bool deleteFromRemote = false, String? remoteName}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    for (final tagName in tagNames) {
      await gitService.deleteTag(tagName);
      if (deleteFromRemote && remoteName != null) {
        await gitService.deleteRemoteTag(remoteName, tagName);
      }
    }
    ref.invalidate(tagsProvider);
  }

  // ============================================
  // Merge Operations
  // ============================================

  /// Refresh merge state
  Future<void> refreshMergeState() async {
    ref.invalidate(mergeStateProvider);
  }

  /// Resolve a merge conflict
  Future<void> resolveConflict(
    String filePath, {
    required ResolutionChoice choice,
    String? manualContent,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.resolveConflict(
      filePath,
      choice: choice,
      manualContent: manualContent,
    );

    await refreshStatus();
    await refreshMergeState();
  }

  /// Abort merge
  Future<void> abortMerge() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.abortMerge();

    await refreshStatus();
    await refreshBranches();
    await refreshMergeState();
  }

  /// Continue merge after resolving all conflicts
  Future<void> continueMerge({String? message}) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.continueMerge(message: message);

    await refreshStatus();
    await refreshBranches();
    await refreshMergeState();
  }

  /// Get file versions during merge
  Future<Map<String, String?>> getMergeFileVersions(String filePath) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return {};

    return await gitService.getMergeFileVersions(filePath);
  }

  // ============================================
  // Advanced Commit Operations
  // ============================================

  /// Amend the last commit
  Future<void> amendCommit({
    String? newMessage,
    bool noEdit = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.amendCommit(
      newMessage: newMessage,
      noEdit: noEdit,
    );

    await refreshStatus();
    // Refresh history to show updated commit
    ref.invalidate(commitHistoryProvider);
  }

  /// Cherry-pick a commit
  Future<void> cherryPickCommit(
    String commitHash, {
    bool noCommit = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.cherryPickCommit(
      commitHash,
      noCommit: noCommit,
    );

    await refreshStatus();
    if (!noCommit) {
      ref.invalidate(commitHistoryProvider);
    }
  }

  /// Squash commits into one
  Future<void> squashCommits({
    required String fromCommit,
    required String toCommit,
    required String newMessage,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.squashCommits(
      fromCommit: fromCommit,
      toCommit: toCommit,
      newMessage: newMessage,
    );

    await refreshStatus();
    ref.invalidate(commitHistoryProvider);
  }

  /// Revert a commit
  Future<void> revertCommit(
    String commitHash, {
    bool noCommit = false,
    String? message,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.revertCommit(
      commitHash,
      noCommit: noCommit,
      message: message,
    );

    await refreshStatus();
    if (!noCommit) {
      ref.invalidate(commitHistoryProvider);
    }
  }

  /// Reset to a specific commit
  Future<void> resetToCommit(
    String commitHash, {
    required ResetMode mode,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.resetToCommit(
      commitHash,
      mode: mode,
    );

    await refreshStatus();
    await refreshBranches();
    ref.invalidate(commitHistoryProvider);
  }

  /// Clean working directory
  Future<void> cleanWorkingDirectory({
    bool directories = false,
    bool force = false,
    bool dryRun = false,
  }) async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) return;

    await gitService.cleanWorkingDirectory(
      directories: directories,
      force: force,
      dryRun: dryRun,
    );

    if (!dryRun) {
      await refreshStatus();
    }
  }
}

/// Git actions provider
final gitActionsProvider = Provider<GitActions>((ref) => GitActions(ref));

/// Bisect state provider
final bisectStateProvider = FutureProvider<BisectState>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return BisectState.idle();

  try {
    return await gitService.getBisectState();
  } catch (e) {
    return BisectState.idle();
  }
});

/// Check if bisect is active
final isBisectActiveProvider = Provider<bool>((ref) {
  final bisectState = ref.watch(bisectStateProvider).value;
  return bisectState?.isActive ?? false;
});

/// Rebase state provider
final rebaseStateProvider = FutureProvider<RebaseState>((ref) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return RebaseState.idle();

  try {
    return await gitService.getRebaseState();
  } catch (e) {
    return RebaseState.idle();
  }
});

/// Check if rebase is active
final isRebaseActiveProvider = Provider<bool>((ref) {
  final rebaseState = ref.watch(rebaseStateProvider).value;
  return rebaseState?.isActive ?? false;
});

// ============================================
// Commit Details
// ============================================

/// Provider for selected commit hash (used by commit details)
final selectedCommitHashProvider = StateProvider<String?>((ref) => null);

/// Provider for changed files in a specific commit
final commitChangedFilesProvider = FutureProvider.family<List<FileChange>, String>((ref, commitHash) async {
  final gitService = ref.watch(gitServiceProvider);
  if (gitService == null) return [];

  try {
    return await gitService.getCommitChangedFiles(commitHash);
  } catch (e) {
    return [];
  }
});
