import '../../git/models/git_remote_identity.dart';
import 'remote_check_failure.dart';

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

  /// Why the last attempt to reach the remote failed, if it did.
  ///
  /// Failing quietly kept the app from interrupting the user, but reporting
  /// every failure as merely "not checked" hid the reason and left nothing to
  /// act on. A repository that only needs a sign-in is the one case the user
  /// can resolve, so it has to be told apart from being offline.
  final RemoteCheckFailure remoteCheckFailure;

  /// URL of the remote this repository tracks, as git reports it.
  ///
  /// Kept raw so the identity can be derived on demand; a workspace spanning
  /// several providers otherwise gives no way to tell which account a
  /// repository needs when its check fails for credentials.
  final String? remoteUrl;

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
    this.remoteCheckFailure = RemoteCheckFailure.none,
    this.remoteUrl,
  });

  /// Where the remote lives, or null for a local-only repository.
  GitRemoteIdentity? get remoteIdentity => parseRemoteIdentity(remoteUrl);

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

  /// A copy with individual fields replaced.
  ///
  /// Marking a repository as refreshing has to keep what the card already
  /// knows - its branch, its counts - so it spins in place instead of blanking
  /// out and flickering back.
  RepositoryStatus copyWith({
    int? commitsAhead,
    int? commitsBehind,
    bool? exists,
    bool? isValidGit,
    bool? hasUncommittedChanges,
    String? currentBranch,
    bool? hasRemote,
    bool? isLoading,
    bool? isGitNotConfigured,
    DateTime? remoteCheckedAt,
    RemoteCheckFailure? remoteCheckFailure,
    String? remoteUrl,
  }) {
    return RepositoryStatus(
      commitsAhead: commitsAhead ?? this.commitsAhead,
      commitsBehind: commitsBehind ?? this.commitsBehind,
      exists: exists ?? this.exists,
      isValidGit: isValidGit ?? this.isValidGit,
      hasUncommittedChanges:
          hasUncommittedChanges ?? this.hasUncommittedChanges,
      currentBranch: currentBranch ?? this.currentBranch,
      hasRemote: hasRemote ?? this.hasRemote,
      isLoading: isLoading ?? this.isLoading,
      isGitNotConfigured: isGitNotConfigured ?? this.isGitNotConfigured,
      remoteCheckedAt: remoteCheckedAt ?? this.remoteCheckedAt,
      remoteCheckFailure: remoteCheckFailure ?? this.remoteCheckFailure,
      remoteUrl: remoteUrl ?? this.remoteUrl,
    );
  }

  /// Whether the repository is broken (doesn't exist or invalid git)
  bool get isBroken => !exists || !isValidGit;

  /// Whether the remote tracks something the app could not verify, for any
  /// reason: the counts cannot be trusted, so the card must not report sync.
  bool get isRemoteUnverified =>
      hasRemote && remoteCheckedAt == null && !isBroken && !isGitNotConfigured;

  /// Unverified because the attempt has not happened yet, as opposed to having
  /// been tried and failed. Only this one is genuinely "not checked".
  bool get isRemoteUnchecked =>
      isRemoteUnverified && remoteCheckFailure == RemoteCheckFailure.none;

  /// The remote refused the app because it had no credentials to offer. The
  /// one failure the user can resolve, so the card offers to sign in.
  bool get needsSignIn =>
      isRemoteUnverified &&
      remoteCheckFailure == RemoteCheckFailure.authenticationRequired;

  /// The remote could not be reached at all - offline, DNS, server down.
  bool get isRemoteUnreachable =>
      isRemoteUnverified &&
      remoteCheckFailure == RemoteCheckFailure.unreachable;

  /// Tried, failed, and the reason did not match a known shape.
  bool get remoteCheckFailedUnknown =>
      isRemoteUnverified && remoteCheckFailure == RemoteCheckFailure.failed;

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
