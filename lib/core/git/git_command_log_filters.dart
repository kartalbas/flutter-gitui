/// Pure filtering and grouping helpers for the command log panel.
///
/// Kept free of Flutter imports so the panel's row selection can be verified
/// in plain unit tests instead of through a widget tree.
library;

import 'models/git_command_log.dart';

/// Returns the entries that survive the failures-only toggle and the
/// case-insensitive command substring search, preserving input order.
List<GitCommandLog> filterCommandLogs(
  List<GitCommandLog> logs, {
  bool failuresOnly = false,
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return logs.where((log) {
    if (failuresOnly && !log.isFailure) return false;
    if (normalizedQuery.isNotEmpty &&
        !log.command.toLowerCase().contains(normalizedQuery)) {
      return false;
    }
    return true;
  }).toList();
}

/// A run of adjacent log entries sharing the same command and exit code.
class GitCommandLogGroup {
  const GitCommandLogGroup(this.entries);

  /// The grouped entries in the order they were supplied.
  final List<GitCommandLog> entries;

  /// The entry whose metadata stands for the whole group in a collapsed row.
  GitCommandLog get representative => entries.first;

  /// How many runs the group collapses.
  int get count => entries.length;
}

/// Collapses adjacent entries into groups without reordering anything.
///
/// Entries only merge when both the command and the exit code match, so a
/// failed run never disappears inside a burst of successful runs of the same
/// command.
List<GitCommandLogGroup> groupConsecutiveCommandLogs(List<GitCommandLog> logs) {
  final groups = <GitCommandLogGroup>[];
  var start = 0;
  for (var i = 1; i <= logs.length; i++) {
    final isBoundary =
        i == logs.length ||
        logs[i].command != logs[start].command ||
        logs[i].exitCode != logs[start].exitCode;
    if (isBoundary) {
      groups.add(GitCommandLogGroup(logs.sublist(start, i)));
      start = i;
    }
  }
  return groups;
}
