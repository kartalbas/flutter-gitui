/// Status of a repository including sync state and health
class RepositoryStatus {
  /// Number of commits ahead of remote (unpushed)
  final int commitsAhead;

  /// Number of commits behind remote (unpulled)
  final int commitsBehind;

  /// Whether the repository directory exists
  final bool exists;

  /// Whether the repository has a valid .git folder
  final bool isValidGit;

  /// Whether there are uncommitted changes
  final bool hasUncommittedChanges;

  /// Name of the current branch
  final String? currentBranch;

  /// Whether the repository has a remote configured
  final bool hasRemote;

  /// Whether the status is currently being checked
  final bool isLoading;

  const RepositoryStatus({
    this.commitsAhead = 0,
    this.commitsBehind = 0,
    this.exists = false,
    this.isValidGit = false,
    this.hasUncommittedChanges = false,
    this.currentBranch,
    this.hasRemote = false,
    this.isLoading = false,
  });

  /// Default status for broken/invalid repositories
  static const RepositoryStatus broken = RepositoryStatus(
    exists: false,
    isValidGit: false,
  );

  /// Default status for repositories that haven't been checked yet
  static const RepositoryStatus unknown = RepositoryStatus(
    exists: true,
    isValidGit: true,
    isLoading: true,
  );

  /// Whether the repository is broken (doesn't exist or invalid git)
  bool get isBroken => !exists || !isValidGit;

  /// Whether there are incoming changes (commits to pull)
  bool get hasIncoming => commitsBehind > 0;

  /// Whether there are outgoing changes (commits to push)
  bool get hasOutgoing => commitsAhead > 0;

  /// Whether the repository needs attention (broken, out of sync, or uncommitted changes)
  bool get needsAttention =>
      isBroken || hasIncoming || hasOutgoing || hasUncommittedChanges;

  /// Total number of sync issues (incoming + outgoing)
  int get totalSyncIssues => commitsAhead + commitsBehind;

  @override
  String toString() =>
      'RepositoryStatus(ahead: $commitsAhead, behind: $commitsBehind, '
      'exists: $exists, valid: $isValidGit, branch: $currentBranch)';
}
