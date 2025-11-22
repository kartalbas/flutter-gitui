/// Git branch model
class GitBranch {
  final String name;
  final String fullName;
  final bool isLocal;
  final bool isRemote;
  final bool isCurrent;
  final bool isProtected;
  final String? upstreamBranch;
  final int? aheadBy;
  final int? behindBy;
  final String? lastCommitHash;
  final String? lastCommitMessage;
  final String? lastCommitAuthor;
  final DateTime? lastCommitDate;

  const GitBranch({
    required this.name,
    required this.fullName,
    required this.isLocal,
    required this.isRemote,
    required this.isCurrent,
    this.isProtected = false,
    this.upstreamBranch,
    this.aheadBy,
    this.behindBy,
    this.lastCommitHash,
    this.lastCommitMessage,
    this.lastCommitAuthor,
    this.lastCommitDate,
  });

  /// Get short name (without refs/heads/ or refs/remotes/)
  String get shortName {
    if (fullName.startsWith('refs/heads/')) {
      return fullName.substring('refs/heads/'.length);
    } else if (fullName.startsWith('refs/remotes/')) {
      return fullName.substring('refs/remotes/'.length);
    }
    return name;
  }

  /// Get remote name for remote branches (e.g., "origin" from "origin/main")
  String? get remoteName {
    if (!isRemote) return null;
    final parts = shortName.split('/');
    return parts.isNotEmpty ? parts[0] : null;
  }

  /// Get branch name without remote prefix (e.g., "main" from "origin/main")
  String get branchNameWithoutRemote {
    if (!isRemote) return shortName;
    final parts = shortName.split('/');
    return parts.length > 1 ? parts.sublist(1).join('/') : shortName;
  }

  /// Check if branch has upstream tracking
  bool get hasUpstream => upstreamBranch != null;

  /// Check if branch is ahead of upstream
  bool get isAhead => (aheadBy ?? 0) > 0;

  /// Check if branch is behind upstream
  bool get isBehind => (behindBy ?? 0) > 0;

  /// Check if branch is diverged (both ahead and behind)
  bool get isDiverged => isAhead && isBehind;

  /// Get tracking status text
  String? get trackingStatus {
    if (!hasUpstream) return null;

    if (isDiverged) {
      return 'ahead $aheadBy, behind $behindBy';
    } else if (isAhead) {
      return 'ahead $aheadBy';
    } else if (isBehind) {
      return 'behind $behindBy';
    } else {
      return 'up to date';
    }
  }

  /// Check if a branch name matches any protected branch patterns
  /// @param branchName The branch name to check (can be local or remote like "origin/main")
  /// @param protectedBranches List of protected branch names from config
  static bool isProtectedBranch(String branchName, List<String> protectedBranches) {
    final normalized = branchName.toLowerCase().trim();

    // Check each protected branch name
    for (final protectedName in protectedBranches) {
      final normalizedProtected = protectedName.toLowerCase().trim();

      // Exact match (e.g., "main" == "main")
      if (normalized == normalizedProtected) {
        return true;
      }

      // Remote branch match (e.g., "origin/main" ends with "/main")
      if (normalized.endsWith('/$normalizedProtected')) {
        return true;
      }
    }

    return false;
  }

  @override
  String toString() => 'GitBranch(name: $name, isCurrent: $isCurrent, isLocal: $isLocal, isRemote: $isRemote)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitBranch &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName;

  @override
  int get hashCode => fullName.hashCode;
}
