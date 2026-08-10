import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

import '../../../shared/theme/app_theme.dart';

/// Type of file change in a commit
enum FileChangeType {
  added, // A - Added
  modified, // M - Modified
  deleted, // D - Deleted
  renamed, // R - Renamed
  copied, // C - Copied
  typeChanged, // T - Type changed
  unmerged, // U - Unmerged
  unknown; // X - Unknown

  /// Colour for this change type, resolved against the active theme.
  Color colorOf(BuildContext context) {
    final colors = context.gitColors;
    switch (this) {
      case FileChangeType.added:
        return colors.added;
      case FileChangeType.modified:
        return colors.modified;
      case FileChangeType.deleted:
        return colors.deleted;
      case FileChangeType.renamed:
        return colors.renamed;
      case FileChangeType.copied:
        return colors.renamed;
      case FileChangeType.typeChanged:
        return colors.modified;
      case FileChangeType.unmerged:
        return colors.conflict;
      case FileChangeType.unknown:
        return colors.untracked;
    }
  }

  /// What this change MEANS, for anything that says it in words - the same
  /// map as [FileStatusType.toneOf], one model over. Deliberately
  /// meaning-identical to [colorOf], arm for arm - even where that method
  /// approximated (an unknown change wearing the untracked colour, a type
  /// change wearing modified), the tone says the same thing, so the
  /// human-verified pixels hold while the vocabulary takes over the saying.
  /// [colorOf] survives beside it only for the fills and glyphs that have
  /// not migrated yet, and goes with them.
  Tone get toneOf => switch (this) {
    FileChangeType.added => Tone.gitAdded,
    FileChangeType.modified || FileChangeType.typeChanged => Tone.gitModified,
    FileChangeType.deleted => Tone.gitDeleted,
    // A copy is a rename that kept its source, and git reports both with the
    // same similarity index, so they share a meaning as well as a colour.
    FileChangeType.renamed || FileChangeType.copied => Tone.gitRenamed,
    FileChangeType.unmerged => Tone.gitConflicted,
    FileChangeType.unknown => Tone.gitUntracked,
  };
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
  int get addedFiles =>
      files.where((f) => f.type == FileChangeType.added).length;
  int get modifiedFiles =>
      files.where((f) => f.type == FileChangeType.modified).length;
  int get deletedFiles =>
      files.where((f) => f.type == FileChangeType.deleted).length;
  int get renamedFiles =>
      files.where((f) => f.type == FileChangeType.renamed).length;

  int get totalAdditions => files.fold(0, (sum, f) => sum + f.additions);
  int get totalDeletions => files.fold(0, (sum, f) => sum + f.deletions);
  int get totalChanges => totalAdditions + totalDeletions;

  bool get isEmpty => files.isEmpty;
  bool get isNotEmpty => files.isNotEmpty;
}
