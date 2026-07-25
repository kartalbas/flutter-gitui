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

  /// Whether the check never ran because no git executable is configured
  final bool isGitNotConfigured;

  /// When the remote was last contacted for this repository, or null if it
  /// never was in this session.
  ///
  /// The ahead/behind counts come from the local remote-tracking ref, which
  /// only moves on a fetch. Without one they describe the last known remote
  /// state, not the current one - so a repository with incoming commits still
  /// counts as zero behind. This timestamp is what separates "verified in sync"
  /// from "not checked yet", so the card can stop claiming the former for the
  /// latter.
  final DateTime? remoteCheckedAt;

  const RepositoryStatus({
    this.commitsAhead = 0,
    this.commitsBehind = 0,
    this.exists = false,
    this.isValidGit = false,
    this.hasUncommittedChanges = false,
    this.currentBranch,
    this.hasRemote = false,
    this.isLoading = false,
    this.isGitNotConfigured = false,
    this.remoteCheckedAt,
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

  /// Status for repositories that could not be checked because no git
  /// executable is configured; not loading, so the card stops spinning, and not
  /// broken, since nothing is known to be wrong with the repository itself.
  static const RepositoryStatus gitNotConfigured = RepositoryStatus(
    exists: true,
    isValidGit: true,
    isGitNotConfigured: true,
  );

  /// Whether the repository is broken (doesn't exist or invalid git)
  bool get isBroken => !exists || !isValidGit;

  /// Whether the sync state is unverified: the repository tracks a remote that
  /// has not been contacted, so the ahead/behind counts cannot be trusted and
  /// the card must not report being in sync.
  bool get isRemoteUnchecked =>
      hasRemote && remoteCheckedAt == null && !isBroken && !isGitNotConfigured;

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
