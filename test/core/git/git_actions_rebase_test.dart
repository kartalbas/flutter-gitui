// GitActions.rebaseBranch owns the refresh contract for a history rewrite
// (#374): after a rebase through the wrapper the commit log, the paged commit
// window built over it, the rebase state, the working-tree status and the
// branch list all reload - no dialog needs to hand-roll its own invalidation
// set. The refresh also runs when the rebase stops on a conflict, because a
// conflicted rebase has already replayed part of history and dirtied the
// working tree, and continuing a conflicted rebase runs the same contract
// because continuing is what completes the rewrite.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_cancellation.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/git/models/rebase_state.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/features/history/providers/history_search_provider.dart';

import '../../features/history/support/scripted_git_service.dart';

/// A [GitService] whose rebase calls are scripted and whose read calls are
/// counted, so the test can prove which providers actually re-queried git
/// after the wrapper ran - a provider that was not invalidated serves its
/// cached value and never calls back in.
class _RecordingGitService extends GitService {
  _RecordingGitService() : super('.');

  bool rebased = false;
  String? lastOntoBranch;
  bool? lastInteractive;
  bool? lastPreserveMerges;
  Result<void> rebaseResult = const Success(null);

  bool continued = false;

  int getLogCalls = 0;
  int getStatusCalls = 0;
  int getRebaseStateCalls = 0;
  int getCurrentBranchCalls = 0;
  int branchListCalls = 0;

  @override
  Future<Result<void>> rebaseBranch({
    required String ontoBranch,
    bool interactive = false,
    bool preserveMerges = false,
  }) async {
    rebased = true;
    lastOntoBranch = ontoBranch;
    lastInteractive = interactive;
    lastPreserveMerges = preserveMerges;
    return rebaseResult;
  }

  @override
  Future<Result<void>> continueRebase() async {
    continued = true;
    rebased = true;
    return const Success(null);
  }

  /// The log flips from the pre-rebase to the rewritten commit once a rebase
  /// ran, so a history view showing 'rewritten' proves it re-fetched.
  @override
  Future<Result<List<GitCommit>>> getLog({
    int? limit,
    String? branch,
    String? filePath,
    String? grepMessage,
    String? author,
    String? since,
    String? until,
    bool allMatch = false,
    bool topoOrder = false,
    List<String> startPoints = const [],
    GitCancellationToken? cancellationToken,
  }) async {
    getLogCalls++;
    return Success([commit(rebased ? 'rewritten' : 'original')]);
  }

  @override
  Future<Result<List<FileStatus>>> getStatus() async {
    getStatusCalls++;
    return const Success([]);
  }

  @override
  Future<RebaseState> getRebaseState() async {
    getRebaseStateCalls++;
    return RebaseState.idle();
  }

  @override
  Future<Result<String>> getCurrentBranch() async {
    getCurrentBranchCalls++;
    return const Success('feature');
  }

  @override
  Future<Result<List<GitBranch>>> getAllBranches() async {
    branchListCalls++;
    return const Success([]);
  }

  @override
  Future<Result<List<GitBranch>>> getLocalBranches() async {
    branchListCalls++;
    return const Success([]);
  }

  @override
  Future<Result<List<GitBranch>>> getRemoteBranches() async {
    branchListCalls++;
    return const Success([]);
  }
}

void main() {
  late _RecordingGitService git;
  late ProviderContainer container;

  setUp(() {
    git = _RecordingGitService();
    container = ProviderContainer(
      overrides: [
        gitServiceProvider.overrideWith((ref) => git),
        // No active repository path: the status refresh skips the
        // workspace-badge update, which is not under test here.
        currentRepositoryPathProvider.overrideWith((ref) => null),
        defaultCommitLimitProvider.overrideWith((ref) => 50),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Reads every provider of the history-rewrite refresh contract once, so
  /// each holds a cached value the wrapper must invalidate.
  Future<void> primeProviders() async {
    await container.read(commitHistoryProvider.future);
    await container.read(commitWindowProvider.future);
    await container.read(repositoryStatusProvider.future);
    await container.read(rebaseStateProvider.future);
    await container.read(allBranchesProvider.future);
    await container.read(localBranchesProvider.future);
    await container.read(remoteBranchesProvider.future);
    await container.read(currentBranchProvider.future);
  }

  test(
    'rebase through the wrapper reloads everything a rewrite moves',
    () async {
      await primeProviders();
      expect(hashesOf(await container.read(commitHistoryProvider.future)), [
        'original',
      ]);

      final statusCalls = git.getStatusCalls;
      final rebaseStateCalls = git.getRebaseStateCalls;
      final branchCalls = git.branchListCalls;
      final currentBranchCalls = git.getCurrentBranchCalls;

      await container
          .read(gitActionsProvider)
          .rebaseBranch(ontoBranch: 'main', interactive: true);

      expect(git.lastOntoBranch, 'main');
      expect(git.lastInteractive, isTrue);
      expect(git.lastPreserveMerges, isFalse);

      // The commit log was invalidated: it re-queries git and now carries the
      // rewritten commit instead of the cached pre-rebase one.
      expect(hashesOf(await container.read(commitHistoryProvider.future)), [
        'rewritten',
      ]);

      // The paged commit window follows the same signal (it watches the log),
      // so the history view shows the rewritten commits without manual refresh.
      final window = await container.read(commitWindowProvider.future);
      expect(hashesOf(window.commits), ['rewritten']);

      // Rebase state, working-tree status and the branch lists re-query too.
      await container.read(rebaseStateProvider.future);
      expect(git.getRebaseStateCalls, rebaseStateCalls + 1);
      await container.read(repositoryStatusProvider.future);
      expect(git.getStatusCalls, statusCalls + 1);
      await container.read(allBranchesProvider.future);
      await container.read(localBranchesProvider.future);
      await container.read(remoteBranchesProvider.future);
      expect(git.branchListCalls, branchCalls + 3);
      await container.read(currentBranchProvider.future);
      expect(git.getCurrentBranchCalls, currentBranchCalls + 1);
    },
  );

  test(
    'a conflicted rebase still refreshes, then surfaces the error',
    () async {
      await primeProviders();
      git.rebaseResult = const Failure('CONFLICT (content): fix it');

      final statusCalls = git.getStatusCalls;
      final rebaseStateCalls = git.getRebaseStateCalls;

      await expectLater(
        container.read(gitActionsProvider).rebaseBranch(ontoBranch: 'main'),
        throwsException,
      );

      // A rebase that stopped on a conflict has already moved HEAD and dirtied
      // the tree, so the refresh must not be skipped on failure.
      await container.read(rebaseStateProvider.future);
      expect(git.getRebaseStateCalls, rebaseStateCalls + 1);
      await container.read(repositoryStatusProvider.future);
      expect(git.getStatusCalls, statusCalls + 1);
      expect(hashesOf(await container.read(commitHistoryProvider.future)), [
        'rewritten',
      ]);
    },
  );

  test('continuing a rebase runs the same refresh contract', () async {
    await primeProviders();
    expect(hashesOf(await container.read(commitHistoryProvider.future)), [
      'original',
    ]);

    final rebaseStateCalls = git.getRebaseStateCalls;

    await container.read(gitActionsProvider).continueRebase();

    expect(git.continued, isTrue);
    // Continuing is what completes the rewrite, so the history and the
    // rebase state must reload here as well.
    expect(hashesOf(await container.read(commitHistoryProvider.future)), [
      'rewritten',
    ]);
    await container.read(rebaseStateProvider.future);
    expect(git.getRebaseStateCalls, rebaseStateCalls + 1);
  });
}
