import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

/// Git file status
enum FileStatusType {
  added,
  modified,
  deleted,
  renamed,
  copied,
  untracked,
  ignored,
  unchanged;

  /// Display name
  String get displayName {
    switch (this) {
      case FileStatusType.added:
        return 'Added';
      case FileStatusType.modified:
        return 'Modified';
      case FileStatusType.deleted:
        return 'Deleted';
      case FileStatusType.renamed:
        return 'Renamed';
      case FileStatusType.copied:
        return 'Copied';
      case FileStatusType.untracked:
        return 'Untracked';
      case FileStatusType.ignored:
        return 'Ignored';
      case FileStatusType.unchanged:
        return 'Unchanged';
    }
  }

  /// Color for this status
  Color get color {
    switch (this) {
      case FileStatusType.added:
        return AppTheme.gitAdded;
      case FileStatusType.modified:
        return AppTheme.gitModified;
      case FileStatusType.deleted:
        return AppTheme.gitDeleted;
      case FileStatusType.renamed:
        return AppTheme.gitRenamed;
      case FileStatusType.copied:
        return AppTheme.gitRenamed;
      case FileStatusType.untracked:
        return AppTheme.gitUntracked;
      case FileStatusType.ignored:
        return AppTheme.gitUntracked;
      case FileStatusType.unchanged:
        return AppTheme.gitUntracked;
    }
  }

  /// Short code (like Git uses)
  String get code {
    switch (this) {
      case FileStatusType.added:
        return 'A';
      case FileStatusType.modified:
        return 'M';
      case FileStatusType.deleted:
        return 'D';
      case FileStatusType.renamed:
        return 'R';
      case FileStatusType.copied:
        return 'C';
      case FileStatusType.untracked:
        return '?';
      case FileStatusType.ignored:
        return '!';
      case FileStatusType.unchanged:
        return ' ';
    }
  }
}

/// Represents a file's status in the working directory
class FileStatus {
  final String path;
  final FileStatusType indexStatus; // Staged status
  final FileStatusType workTreeStatus; // Unstaged status
  final String? oldPath; // For renames

  const FileStatus({
    required this.path,
    required this.indexStatus,
    required this.workTreeStatus,
    this.oldPath,
  });

  /// Whether this file is staged
  bool get isStaged =>
      indexStatus != FileStatusType.unchanged &&
      indexStatus != FileStatusType.untracked;

  /// Whether this file has unstaged changes
  bool get hasUnstagedChanges => workTreeStatus != FileStatusType.unchanged;

  /// Whether this file is untracked
  bool get isUntracked =>
      indexStatus == FileStatusType.untracked &&
      workTreeStatus == FileStatusType.untracked;

  /// Display status (e.g., "M " = modified in index, " M" = modified in work tree)
  String get displayStatus {
    return '${indexStatus.code}${workTreeStatus.code}';
  }

  /// Primary status to display
  FileStatusType get primaryStatus {
    if (isStaged) return indexStatus;
    return workTreeStatus;
  }

  @override
  String toString() => '$displayStatus $path';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileStatus &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          indexStatus == other.indexStatus &&
          workTreeStatus == other.workTreeStatus;

  @override
  int get hashCode => path.hashCode ^ indexStatus.hashCode ^ workTreeStatus.hashCode;
}
