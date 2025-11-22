import 'package:riverpod/legacy.dart';

import 'models/git_command_log.dart';

/// Maximum number of command logs to keep in memory
const int _maxLogEntries = 500;

/// State notifier for managing Git command logs
class GitCommandLogNotifier extends StateNotifier<List<GitCommandLog>> {
  GitCommandLogNotifier() : super([]);

  /// Add a new command log entry
  void addLog(GitCommandLog log) {
    state = [...state, log];

    // Keep only the most recent entries
    if (state.length > _maxLogEntries) {
      state = state.sublist(state.length - _maxLogEntries);
    }
  }

  /// Clear all logs
  void clear() {
    state = [];
  }

  /// Get logs filtered by success/failure
  List<GitCommandLog> getFiltered({bool? success}) {
    if (success == null) return state;
    return state.where((log) => log.isSuccess == success).toList();
  }
}

/// Provider for Git command logs
final gitCommandLogProvider =
    StateNotifierProvider<GitCommandLogNotifier, List<GitCommandLog>>((ref) {
      return GitCommandLogNotifier();
    });

/// Provider for the command log panel visibility
final commandLogPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Provider for the command log panel width
final commandLogPanelWidthProvider = StateProvider<double>((ref) => 600.0);
