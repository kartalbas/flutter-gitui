// The single, authoritative classification of every destructive Git action.
//
// A destructive action is dangerous along two axes: how far it reaches (only
// the local repository vs. the remote and other people) and how reversible it
// is (a new commit that is trivially undone -> recoverable through the reflog
// for ~90 days -> permanent data loss). The two axes collapse into four
// [DangerTier]s that decide how hard the confirmation gate pushes back.
//
// Every place that runs a destructive action names its [DestructiveAction]
// here and routes through `confirmDestructive`, so the danger of an action is
// described in exactly one place and a new action cannot be added without
// picking a tier.
//
// The custom_lint rule `require_confirm_destructive`
// (lint_rules/flutter_gitui_lint) enforces the routing: when an action is
// added here, add its method(s) to the rule's destructive set and extend the
// rule's snapshot of this enum — the rule reports any constant it does not
// know, so the two cannot drift apart silently.

/// How dangerous a destructive action is, from a barrier against a stray click
/// (top) to an irreversible change that also affects other people (bottom).
enum DangerTier {
  /// Local, only creates a new commit that undoes or replays work; the
  /// original commits stay reachable, so it is trivially undone.
  newCommit,

  /// Local and rewrites history or moves a ref, but the previous state stays
  /// in the reflog (~90 days) and can be recovered.
  reflogRecoverable,

  /// Local and permanently discards work with no reflog to fall back on
  /// (working-tree and index changes, untracked files, dropped stashes).
  permanent,

  /// Reaches the remote and permanently changes shared history; a stray click
  /// can destroy work that is not the user's own and cannot be undone alone.
  remotePermanent,
}

extension DangerTierBehavior on DangerTier {
  /// The two recoverable local tiers may be silenced through the
  /// "confirm destructive actions" setting. The permanent and remote tiers
  /// always ask: there is no reflog or local copy to recover from.
  bool get isSilenceable =>
      this == DangerTier.newCommit || this == DangerTier.reflogRecoverable;

  /// Permanent and remote actions use the red destructive dialog styling; the
  /// recoverable tiers use the softer confirmation styling.
  bool get usesDestructiveStyle =>
      this == DangerTier.permanent || this == DangerTier.remotePermanent;
}

/// Every destructive Git action, mapped to the tier that governs its
/// confirmation. Non-destructive actions (fetch, stage, commit, checkout of a
/// clean tree) are deliberately absent.
enum DestructiveAction {
  // Tier 0 - local, only a new commit.
  revert(DangerTier.newCommit),
  cherryPick(DangerTier.newCommit),

  // Tier 1 - local, recoverable through the reflog.
  resetSoft(DangerTier.reflogRecoverable),
  resetMixed(DangerTier.reflogRecoverable),
  amend(DangerTier.reflogRecoverable),
  squash(DangerTier.reflogRecoverable),
  rebase(DangerTier.reflogRecoverable),
  deleteLocalBranch(DangerTier.reflogRecoverable),
  deleteLocalTag(DangerTier.reflogRecoverable),

  // Tier 2 - local, permanent data loss.
  resetHard(DangerTier.permanent),
  cleanWorkingDirectory(DangerTier.permanent),
  discardFile(DangerTier.permanent),
  discardAll(DangerTier.permanent),
  deleteUntrackedFile(DangerTier.permanent),
  dropStash(DangerTier.permanent),
  clearStashes(DangerTier.permanent),

  // Tier 3 - remote, permanent, affects others.
  forcePush(DangerTier.remotePermanent),
  deleteRemoteBranch(DangerTier.remotePermanent),
  deleteRemoteTag(DangerTier.remotePermanent);

  const DestructiveAction(this.tier);

  final DangerTier tier;
}
