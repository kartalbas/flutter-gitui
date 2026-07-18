/// Model representing a Git merge conflict
class MergeConflict {
  /// File path with conflict
  final String filePath;

  /// Conflict status (both modified, deleted by us, deleted by them, etc.)
  final ConflictType type;

  /// Content from current branch (ours)
  final String? oursContent;

  /// Content from merging branch (theirs)
  final String? theirsContent;

  /// Content from common ancestor (base)
  final String? baseContent;

  /// Conflict markers content (if unresolved)
  final String? conflictMarkersContent;

  /// Whether conflict is resolved
  final bool isResolved;

  /// Resolution choice (if resolved programmatically)
  final ResolutionChoice? resolutionChoice;

  const MergeConflict({
    required this.filePath,
    required this.type,
    this.oursContent,
    this.theirsContent,
    this.baseContent,
    this.conflictMarkersContent,
    this.isResolved = false,
    this.resolutionChoice,
  });

  /// Get file name from path
  String get fileName {
    final parts = filePath.split('/');
    return parts.last;
  }

  /// Get directory path
  String get directory {
    final parts = filePath.split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  /// Get display string for conflict type
  String get typeDisplay {
    switch (type) {
      case ConflictType.bothModified:
        return 'Both modified';
      case ConflictType.deletedByUs:
        return 'Deleted by us';
      case ConflictType.deletedByThem:
        return 'Deleted by them';
      case ConflictType.addedByUs:
        return 'Added by us';
      case ConflictType.addedByThem:
        return 'Added by them';
      case ConflictType.bothAdded:
        return 'Both added';
    }
  }

  /// Copy with resolution
  MergeConflict copyWith({
    bool? isResolved,
    ResolutionChoice? resolutionChoice,
    String? conflictMarkersContent,
  }) {
    return MergeConflict(
      filePath: filePath,
      type: type,
      oursContent: oursContent,
      theirsContent: theirsContent,
      baseContent: baseContent,
      conflictMarkersContent: conflictMarkersContent ?? this.conflictMarkersContent,
      isResolved: isResolved ?? this.isResolved,
      resolutionChoice: resolutionChoice ?? this.resolutionChoice,
    );
  }

  @override
  String toString() => 'MergeConflict($filePath: $typeDisplay)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MergeConflict && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}

/// Type of merge conflict
enum ConflictType {
  /// Both branches modified the same file
  bothModified,

  /// File was deleted in current branch
  deletedByUs,

  /// File was deleted in merging branch
  deletedByThem,

  /// File was added in current branch
  addedByUs,

  /// File was added in merging branch
  addedByThem,

  /// File was added in both branches
  bothAdded,
}

/// How the conflict was resolved
enum ResolutionChoice {
  /// Accept current branch version
  ours,

  /// Accept merging branch version
  theirs,

  /// Accept base (ancestor) version
  base,

  /// Manually resolved
  manual,

  /// Keep both changes (if applicable)
  both,
}

/// Merge state information
class MergeState {
  /// Whether a merge is in progress
  final bool isInProgress;

  /// Branch being merged (source branch)
  final String? mergingBranch;

  /// Current branch (target branch)
  final String? currentBranch;

  /// List of conflicts
  final List<MergeConflict> conflicts;

  /// Merge message
  final String? message;

  const MergeState({
    required this.isInProgress,
    this.mergingBranch,
    this.currentBranch,
    this.conflicts = const [],
    this.message,
  });

  /// Empty merge state (no merge in progress)
  const MergeState.empty()
      : isInProgress = false,
        mergingBranch = null,
        currentBranch = null,
        conflicts = const [],
        message = null;

  /// Number of conflicts
  int get conflictCount => conflicts.length;

  /// Number of resolved conflicts
  int get resolvedCount => conflicts.where((c) => c.isResolved).length;

  /// Number of unresolved conflicts
  int get unresolvedCount => conflictCount - resolvedCount;

  /// Whether all conflicts are resolved
  bool get allResolved => conflictCount > 0 && unresolvedCount == 0;

  /// Display string for merge status
  String get statusDisplay {
    if (!isInProgress) return 'No merge in progress';
    if (conflictCount == 0) return 'Merging ${mergingBranch ?? "branch"}';
    return '$unresolvedCount of $conflictCount conflicts unresolved';
  }

  @override
  String toString() => 'MergeState($statusDisplay)';
}
