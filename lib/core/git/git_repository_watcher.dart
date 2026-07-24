import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';

import '../services/logger_service.dart';

/// Watches a Git repository for file system changes
///
/// This service provides real-time notifications when files in the repository
/// or Git metadata changes, eliminating the need for polling.
class GitRepositoryWatcher {
  final String repositoryPath;
  final void Function() onRepositoryChanged;

  DirectoryWatcher? _repoWatcher;
  DirectoryWatcher? _gitWatcher;
  StreamSubscription? _repoSubscription;
  StreamSubscription? _gitSubscription;

  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  // start() awaits Directory.exists() before subscribing, so a stop() (repo
  // switch, dispose) can land mid-start. Bail on this flag after each await so a
  // superseded start() never installs a subscription nothing will cancel.
  bool _disposed = false;

  GitRepositoryWatcher({
    required this.repositoryPath,
    required this.onRepositoryChanged,
  });

  /// Start watching the repository for changes
  Future<void> start() async {
    await stop(); // Clean up any existing watchers
    _disposed = false;

    try {
      // Watch the entire repository directory (for file changes)
      final repoDir = Directory(repositoryPath);
      if (await repoDir.exists()) {
        if (_disposed) return;
        _repoWatcher = DirectoryWatcher(repositoryPath);
        _repoSubscription = _repoWatcher!.events.listen(
          _handleFileEvent,
          onError: _handleWatchError,
        );
      }

      // Watch the .git directory specifically (for branch changes, commits, etc.)
      // Forward slashes are accepted by dart:io on every target including
      // Windows, so the path stays valid however repositoryPath is spelled.
      final gitDir = Directory('$repositoryPath/.git');
      if (await gitDir.exists()) {
        if (_disposed) return;
        _gitWatcher = DirectoryWatcher(gitDir.path);
        _gitSubscription = _gitWatcher!.events.listen(
          _handleFileEvent,
          onError: _handleWatchError,
        );
      }

      Logger.info('File watcher started for: $repositoryPath');
    } catch (e) {
      Logger.error('Failed to start file watcher', e);
    }
  }

  /// Stop watching the repository
  Future<void> stop() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _repoSubscription?.cancel();
    await _gitSubscription?.cancel();

    _repoWatcher = null;
    _gitWatcher = null;
    _repoSubscription = null;
    _gitSubscription = null;
  }

  /// The platform watchers deliver failures asynchronously on the events stream
  /// (a Windows change-buffer overflow that the package then self-heals, a Linux
  /// inotify exhaustion), after start()'s try/catch has already returned.
  /// Without an onError these would escalate to the root zone and surface an
  /// alarming platform-error notification, so log and swallow them here; the
  /// watcher keeps (or resumes) working, and status stays refreshable on demand.
  void _handleWatchError(Object error, StackTrace stackTrace) {
    Logger.warning('Repository watcher error (recovering)', error);
  }

  /// Handle file system events with debouncing
  void _handleFileEvent(WatchEvent event) {
    // Ignore events in .git/objects and other noisy directories
    if (shouldIgnorePath(event.path)) {
      return;
    }

    // Debounce rapid file changes (e.g., when saving multiple files)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      Logger.debug('Repository changed: ${event.type} - ${event.path}');
      onRepositoryChanged();
    });
  }

  /// Whether a watched path is noise that must not trigger a status refresh.
  ///
  /// `.git/objects` is where git writes thousands of loose objects and packs on
  /// commit/fetch/gc; letting those through is the app's biggest source of
  /// wasted refreshes and CPU. The check is separator-agnostic: the `watcher`
  /// package emits native separators (backslashes on Windows), and the watched
  /// root may itself be spelled with either separator, so both are normalized
  /// to forward slashes before matching. Static and pure so the cross-platform
  /// behavior can be pinned by a test.
  static bool shouldIgnorePath(String path) {
    final normalized = path.replaceAll('\\', '/');

    const ignoredDirectories = [
      '.git/objects',
      '.git/logs',
      '.git/hooks',
      '.git/info',
      '.git/refs/remotes',
    ];

    const ignoredLockFiles = [
      '.git/index.lock',
      '.git/HEAD.lock',
      '.git/config.lock',
      '.git/packed-refs.lock',
      '.git/COMMIT_EDITMSG.lock',
    ];

    return ignoredDirectories.any(normalized.contains) ||
        ignoredLockFiles.any(normalized.endsWith);
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}
