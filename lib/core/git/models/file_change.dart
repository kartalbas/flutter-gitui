import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// Type of file change in a commit
enum FileChangeType {
  added,    // A - Added
  modified, // M - Modified
  deleted,  // D - Deleted
  renamed,  // R - Renamed
  copied,   // C - Copied
  typeChanged, // T - Type changed
  unmerged, // U - Unmerged
  unknown;  // X - Unknown

  /// Color for this change type
  Color get color {
    switch (this) {
      case FileChangeType.added:
        return AppTheme.gitAdded;
      case FileChangeType.modified:
        return AppTheme.gitModified;
      case FileChangeType.deleted:
        return AppTheme.gitDeleted;
      case FileChangeType.renamed:
        return AppTheme.gitRenamed;
      case FileChangeType.copied:
        return AppTheme.gitRenamed;
      case FileChangeType.typeChanged:
        return AppTheme.gitModified;
      case FileChangeType.unmerged:
        return AppTheme.gitConflict;
      case FileChangeType.unknown:
        return AppTheme.gitUntracked;
    }
  }
}

/// Represents a file change in a commit
class FileChange {
  final String path;
  final FileChangeType type;
  final String? oldPath; // For renamed/copied files
  final int additions;
  final int deletions;

  const FileChange({
    required this.path,
    required this.type,
    this.oldPath,
    this.additions = 0,
    this.deletions = 0,
  });

  /// Total changes (additions + deletions)
  int get totalChanges => additions + deletions;

  /// File extension
  String get extension {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1 || lastDot == path.length - 1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  /// File name without path
  String get fileName {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash == -1) return path;
    return path.substring(lastSlash + 1);
  }

  /// Directory path
  String get directory {
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return path.substring(0, lastSlash);
  }

  /// Parse file change type from git status character
  static FileChangeType parseType(String statusChar) {
    switch (statusChar.toUpperCase()) {
      case 'A':
        return FileChangeType.added;
      case 'M':
        return FileChangeType.modified;
      case 'D':
        return FileChangeType.deleted;
      case 'R':
        return FileChangeType.renamed;
      case 'C':
        return FileChangeType.copied;
      case 'T':
        return FileChangeType.typeChanged;
      case 'U':
        return FileChangeType.unmerged;
      default:
        return FileChangeType.unknown;
    }
  }

  /// Get display name for change type
  String get typeDisplayName {
    switch (type) {
      case FileChangeType.added:
        return 'Added';
      case FileChangeType.modified:
        return 'Modified';
      case FileChangeType.deleted:
        return 'Deleted';
      case FileChangeType.renamed:
        return 'Renamed';
      case FileChangeType.copied:
        return 'Copied';
      case FileChangeType.typeChanged:
        return 'Type Changed';
      case FileChangeType.unmerged:
        return 'Unmerged';
      case FileChangeType.unknown:
        return 'Unknown';
    }
  }

  @override
  String toString() => '$typeDisplayName: $path';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileChange &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          type == other.type;

  @override
  int get hashCode => path.hashCode ^ type.hashCode;
}

/// Statistics for file changes in a commit
class FileChangeStats {
  final List<FileChange> files;

  const FileChangeStats(this.files);

  int get totalFiles => files.length;
  int get addedFiles => files.where((f) => f.type == FileChangeType.added).length;
  int get modifiedFiles => files.where((f) => f.type == FileChangeType.modified).length;
  int get deletedFiles => files.where((f) => f.type == FileChangeType.deleted).length;
  int get renamedFiles => files.where((f) => f.type == FileChangeType.renamed).length;

  int get totalAdditions => files.fold(0, (sum, f) => sum + f.additions);
  int get totalDeletions => files.fold(0, (sum, f) => sum + f.deletions);
  int get totalChanges => totalAdditions + totalDeletions;

  bool get isEmpty => files.isEmpty;
  bool get isNotEmpty => files.isNotEmpty;
}
