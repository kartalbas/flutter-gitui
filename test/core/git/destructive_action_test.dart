// The confirmation gate reads only the tier of a DestructiveAction, so the
// classification and the tier behaviour that drives it (which tiers can be
// silenced, which use the red destructive styling) are pinned here.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/destructive_action.dart';

void main() {
  group('DangerTier behaviour', () {
    test('only the recoverable local tiers can be silenced', () {
      expect(DangerTier.newCommit.isSilenceable, isTrue);
      expect(DangerTier.reflogRecoverable.isSilenceable, isTrue);
      expect(DangerTier.permanent.isSilenceable, isFalse);
      expect(DangerTier.remotePermanent.isSilenceable, isFalse);
    });

    test('only the permanent and remote tiers use the destructive styling', () {
      expect(DangerTier.newCommit.usesDestructiveStyle, isFalse);
      expect(DangerTier.reflogRecoverable.usesDestructiveStyle, isFalse);
      expect(DangerTier.permanent.usesDestructiveStyle, isTrue);
      expect(DangerTier.remotePermanent.usesDestructiveStyle, isTrue);
    });
  });

  group('DestructiveAction classification', () {
    test('revert and cherry-pick are the trivially reversible tier', () {
      expect(DestructiveAction.revert.tier, DangerTier.newCommit);
      expect(DestructiveAction.cherryPick.tier, DangerTier.newCommit);
    });

    test('history-rewriting local actions are reflog-recoverable', () {
      for (final action in [
        DestructiveAction.resetSoft,
        DestructiveAction.resetMixed,
        DestructiveAction.amend,
        DestructiveAction.squash,
        DestructiveAction.rebase,
        DestructiveAction.forceRenameBranch,
        DestructiveAction.deleteLocalBranch,
        DestructiveAction.deleteLocalTag,
      ]) {
        expect(action.tier, DangerTier.reflogRecoverable, reason: action.name);
      }
    });

    test('work-destroying local actions are permanent', () {
      for (final action in [
        DestructiveAction.resetHard,
        DestructiveAction.cleanWorkingDirectory,
        DestructiveAction.discardFile,
        DestructiveAction.discardAll,
        DestructiveAction.deleteUntrackedFile,
        DestructiveAction.dropStash,
        DestructiveAction.clearStashes,
      ]) {
        expect(action.tier, DangerTier.permanent, reason: action.name);
      }
    });

    test('actions that touch the remote are the remote tier', () {
      for (final action in [
        DestructiveAction.forcePush,
        DestructiveAction.deleteRemoteBranch,
        DestructiveAction.deleteRemoteTag,
      ]) {
        expect(action.tier, DangerTier.remotePermanent, reason: action.name);
      }
    });
  });
}
