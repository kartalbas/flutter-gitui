import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show Tone;

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

  /// Unmerged: the file has conflicts from a merge, rebase or cherry-pick.
  unmerged,
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
      case FileStatusType.unmerged:
        return 'Unmerged';
      case FileStatusType.unchanged:
        return 'Unchanged';
    }
  }

  /// Colour for this status, resolved against the active theme so light and
  /// dark mode each get their contrast-conformant value.
  Color colorOf(BuildContext context) {
    final colors = context.gitColors;
    switch (this) {
      case FileStatusType.added:
        return colors.added;
      case FileStatusType.modified:
        return colors.modified;
      case FileStatusType.deleted:
        return colors.deleted;
      case FileStatusType.renamed:
        return colors.renamed;
      case FileStatusType.copied:
        return colors.renamed;
      case FileStatusType.untracked:
        return colors.untracked;
      case FileStatusType.ignored:
        return colors.untracked;
      case FileStatusType.unmerged:
        // Conflicts must stand out; the delete colour is the strongest signal
        // the palette carries for a file that blocks the commit.
        return colors.deleted;
      case FileStatusType.unchanged:
        return colors.untracked;
    }
  }

  /// What this status MEANS, for anything that says it in words.
  ///
  /// The sibling above is a meaning-to-colour map; this is the same map with
  /// its answer left to the skin, which is the whole of #249 in one method. It
  /// is not a duplicate of [colorOf] wearing a different type: the two differ
  /// where [colorOf] had to approximate. An unmerged file is [Tone.gitConflicted]
  /// here while [colorOf] returns the DELETE colour, because Material's palette
  /// had no conflict slot the day that line was written and the strongest
  /// available signal was borrowed — precisely the substitution the vocabulary
  /// removes, and the reason a conflicted file now renders in the conflict
  /// colour instead of the deletion one.
  ///
  /// [colorOf] survives beside it only for the fills and glyphs that have not
  /// migrated yet, and goes with them.
  Tone get toneOf => switch (this) {
    FileStatusType.added => Tone.gitAdded,
    FileStatusType.modified => Tone.gitModified,
    FileStatusType.deleted => Tone.gitDeleted,
    // A copy is a rename that kept its source, and git reports both with the
    // same similarity index, so they share a meaning as well as a colour.
    FileStatusType.renamed || FileStatusType.copied => Tone.gitRenamed,
    FileStatusType.untracked => Tone.gitUntracked,
    FileStatusType.ignored => Tone.gitIgnored,
    FileStatusType.unmerged => Tone.gitConflicted,
    // Nothing happened to it. "Untracked" is the quietest thing the vocabulary
    // says, which is what this status wants and what colorOf already gave it.
    FileStatusType.unchanged => Tone.gitUntracked,
  };

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
      case FileStatusType.unmerged:
        return 'U';
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

  /// Whether only part of this file's changes are staged (porcelain 'MM'): the
  /// index holds an earlier version while newer edits sit in the work tree.
  /// Treating such a file as plain staged hides the newer edits and drops them
  /// from the commit.
  bool get isPartiallyStaged => isStaged && hasUnstagedChanges;

  /// Whether every change to this file is in the index, i.e. a commit would
  /// capture the file exactly as it is on disk.
  bool get isFullyStaged => isStaged && !hasUnstagedChanges;

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
  int get hashCode =>
      path.hashCode ^ indexStatus.hashCode ^ workTreeStatus.hashCode;
}
