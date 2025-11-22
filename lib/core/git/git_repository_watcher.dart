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

  GitRepositoryWatcher({
    required this.repositoryPath,
    required this.onRepositoryChanged,
  });

  /// Start watching the repository for changes
  Future<void> start() async {
    await stop(); // Clean up any existing watchers

    try {
      // Watch the entire repository directory (for file changes)
      final repoDir = Directory(repositoryPath);
      if (await repoDir.exists()) {
        _repoWatcher = DirectoryWatcher(repositoryPath);
        _repoSubscription = _repoWatcher!.events.listen(_handleFileEvent);
      }

      // Watch the .git directory specifically (for branch changes, commits, etc.)
      final gitDir = Directory('$repositoryPath${Platform.pathSeparator}.git');
      if (await gitDir.exists()) {
        _gitWatcher = DirectoryWatcher(gitDir.path);
        _gitSubscription = _gitWatcher!.events.listen(_handleFileEvent);
      }

      Logger.info('File watcher started for: $repositoryPath');
    } catch (e) {
      Logger.error('Failed to start file watcher', e);
    }
  }

  /// Stop watching the repository
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _repoSubscription?.cancel();
    await _gitSubscription?.cancel();

    _repoWatcher = null;
    _gitWatcher = null;
    _repoSubscription = null;
    _gitSubscription = null;
  }

  /// Handle file system events with debouncing
  void _handleFileEvent(WatchEvent event) {
    // Ignore events in .git/objects and other noisy directories
    if (_shouldIgnoreEvent(event.path)) {
      return;
    }

    // Debounce rapid file changes (e.g., when saving multiple files)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      Logger.debug('Repository changed: ${event.type} - ${event.path}');
      onRepositoryChanged();
    });
  }

  /// Check if an event should be ignored to reduce noise
  bool _shouldIgnoreEvent(String path) {
    // Ignore changes in noisy Git directories
    final ignoredPaths = [
      '.git${Platform.pathSeparator}objects',
      '.git${Platform.pathSeparator}logs',
      '.git${Platform.pathSeparator}hooks',
      '.git${Platform.pathSeparator}info',
      '.git${Platform.pathSeparator}refs${Platform.pathSeparator}remotes',
    ];

    // Ignore temporary Git lock files
    final ignoredFiles = [
      '.git${Platform.pathSeparator}index.lock',
      '.git${Platform.pathSeparator}HEAD.lock',
      '.git${Platform.pathSeparator}config.lock',
      '.git${Platform.pathSeparator}packed-refs.lock',
      '.git${Platform.pathSeparator}COMMIT_EDITMSG.lock',
    ];

    return ignoredPaths.any((ignored) => path.contains(ignored)) ||
           ignoredFiles.any((ignored) => path.endsWith(ignored));
  }

  /// Dispose of resources
  void dispose() {
    stop();
  }
}
