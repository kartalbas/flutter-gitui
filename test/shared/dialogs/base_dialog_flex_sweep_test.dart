// Every BaseDialog user pumped once in its data-bearing state, asserting the
// layout throws nothing (#370). BaseDialog scrolls its content, a scroll view
// hands its child unbounded height, and a Column with unbounded height has no
// remaining space to distribute - so a direct Expanded, Spacer or tight
// Flexible child of the content Column is a RenderFlex error, not a layout.
// The repository switcher (Ctrl+R) shipped exactly that and crashed on every
// open; this sweep is the assertion that would have caught it the day it was
// written, applied to the whole dialog population. It found the same defect
// in the reflog dialog, the running-bisect view and the mid-rebase view (a
// Spacer, which no grep for Expanded shows), plus a different layout error:
// the update dialog's three actions overflowed BaseDialog's actions row.
//
// Dialogs deliberately not pumped here:
// - DetectToolsDialog probes the machine for git/diff tools in initState;
//   its content is flex-free by inspection.
// - Dialogs built inline inside screens (settings, repositories, workspaces,
//   changes, conflict resolution, git commands, file tree, blame panel) carry
//   plain label or text-field content and are unreachable without pumping the
//   whole screen; all verified flex-free by inspection.
// - SelectHostedRepositoryDialog bounds its content with a fixed SizedBox,
//   which makes its inner Expanded legal.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// The Override type moved out of the main entrypoint in Riverpod 3.
import 'package:riverpod/misc.dart' show Override;

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/diff/diff_providers.dart';
import 'package:flutter_gitui/core/diff/models/diff_tool.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/bisect_state.dart';
import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/rebase_state.dart';
import 'package:flutter_gitui/core/git/models/reflog_entry.dart';
import 'package:flutter_gitui/core/git/models/remote.dart';
import 'package:flutter_gitui/core/git/models/stash.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/core/git/widgets/git_output_dialog.dart';
import 'package:flutter_gitui/core/services/update_service.dart';
import 'package:flutter_gitui/core/services/version_service.dart';
import 'package:flutter_gitui/core/workspace/models/repository_status.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';
import 'package:flutter_gitui/core/workspace/repository_status_provider.dart';
import 'package:flutter_gitui/core/workspace/selected_workspace_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_list_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_provider.dart';
import 'package:flutter_gitui/features/about/about_dialog.dart';
import 'package:flutter_gitui/features/branches/dialogs/delete_branch_dialog.dart';
import 'package:flutter_gitui/features/branches/dialogs/merge_branch_dialog.dart'
    as branches;
import 'package:flutter_gitui/features/branches/dialogs/rename_branch_dialog.dart';
import 'package:flutter_gitui/features/branches/dialogs/search_branches_dialog.dart';
import 'package:flutter_gitui/features/repositories/dialogs/batch_operation_progress_dialog.dart';
import 'package:flutter_gitui/features/repositories/dialogs/create_branch_dialog.dart';
import 'package:flutter_gitui/features/repositories/dialogs/create_pull_request_dialog.dart';
import 'package:flutter_gitui/features/repositories/dialogs/project_dialog.dart';
import 'package:flutter_gitui/features/repositories/repository_batch_error_provider.dart';
import 'package:flutter_gitui/features/repositories/services/batch_operations_service.dart';
import 'package:flutter_gitui/features/stashes/dialogs/create_branch_from_stash_dialog.dart';
import 'package:flutter_gitui/features/stashes/dialogs/create_stash_dialog.dart';
import 'package:flutter_gitui/features/tags/dialogs/advanced_filters_dialog.dart';
import 'package:flutter_gitui/features/tags/dialogs/checkout_tag_dialog.dart';
import 'package:flutter_gitui/features/tags/dialogs/create_branch_from_tag_dialog.dart';
import 'package:flutter_gitui/features/tags/dialogs/delete_tags_dialog.dart';
import 'package:flutter_gitui/features/tags/dialogs/select_remote_dialog.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_button.dart';
import 'package:flutter_gitui/shared/dialogs/background_activity_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/batch_result_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/bisect_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/branch_switcher_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/clone_repository_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/create_tag_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/diff_tools_config_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/edit_remote_url_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/initialize_repository_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/merge_branch_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/merge_branches_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/prune_remote_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/rebase_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/reflog_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/rename_remote_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/repository_switcher_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/update_available_dialog.dart';

/// Serves scripted repositories without touching the on-disk config.
class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  _FakeWorkspaceNotifier(this._repositories);

  final List<WorkspaceRepository> _repositories;

  @override
  List<WorkspaceRepository> build() => _repositories;

  @override
  Future<void> markAccessed(String path) async {}
}

/// Keeps the startup auto-assignment away from the on-disk config.
class _FakeProjectNotifier extends ProjectNotifier {
  _FakeProjectNotifier(super.ref);

  @override
  Future<void> assignUnassignedRepositories(
    List<String> allRepoPaths,
    String projectId,
  ) async {}
}

/// No selected project, so the repository switcher lists the whole
/// workspace instead of filtering it down to a project's repositories.
class _NoProjectSelectedNotifier extends SelectedProjectNotifier {
  _NoProjectSelectedNotifier(super.ref) {
    state = null;
  }
}

/// Serves settled statuses so no row animates forever.
class _FakeStatusNotifier extends RepositoryStatusNotifier {
  _FakeStatusNotifier(super.ref, Map<String, RepositoryStatus> statuses) {
    state = statuses;
  }
}

/// Answers the version without the PackageInfo platform channel.
class _FakeVersionService extends VersionService {
  @override
  Future<String> getCurrentVersion() async => '9.9.9';
}

// --- Fixtures ---------------------------------------------------------------

WorkspaceRepository _repo(String name) => WorkspaceRepository(
  path: '/repos/$name',
  name: name,
  lastAccessed: DateTime(2026),
);

const _master = GitBranch(
  name: 'master',
  fullName: 'refs/heads/master',
  isLocal: true,
  isRemote: false,
  isCurrent: true,
);

const _feature = GitBranch(
  name: 'feature',
  fullName: 'refs/heads/feature',
  isLocal: true,
  isRemote: false,
  isCurrent: false,
);

GitCommit _commit(String hash, String subject) => GitCommit(
  hash: hash,
  shortHash: hash.substring(0, 7),
  author: 'author',
  authorEmail: 'author@example.com',
  authorDate: DateTime(2026),
  committer: 'author',
  committerEmail: 'author@example.com',
  committerDate: DateTime(2026),
  subject: subject,
  body: '',
  parents: const [],
  refs: const [],
);

final _tag = GitTag(
  name: 'v1.0.0',
  commitHash: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
  type: GitTagType.annotated,
  message: 'First release',
  date: DateTime(2026),
);

const _remote = GitRemote(
  name: 'origin',
  fetchUrl: 'https://example.com/repo.git',
  pushUrl: 'https://example.com/repo.git',
);

final _stash = GitStash(
  ref: 'stash@{0}',
  index: 0,
  hash: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
  branch: 'master',
  message: 'WIP on master',
  timestamp: DateTime(2026),
);

// --- Harness ----------------------------------------------------------------

/// Pumps [dialog] with in-memory config and no open repository, gives async
/// providers two frames to resolve, and returns the first exception the
/// framework caught - null when the dialog laid out cleanly.
Future<Object?> _pumpDialog(
  WidgetTester tester,
  Widget dialog, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configProvider.overrideWith(
          (ref) => ConfigNotifier.withConfig(ref, AppConfig.defaults),
        ),
        currentRepositoryPathProvider.overrideWith((ref) => null),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: dialog,
      ),
    ),
  );
  var exception = tester.takeException();
  if (exception != null) return exception;

  // Overridden FutureProviders deliver their value a microtask later; the
  // data-bearing branch (the one that held the broken flex child) only
  // builds on the following frames.
  await tester.pump();
  exception = tester.takeException();
  if (exception != null) return exception;

  await tester.pump(const Duration(milliseconds: 100));
  return tester.takeException();
}

void main() {
  testWidgets('RepositorySwitcherDialog (Ctrl+R) shows the list and throws '
      'nothing', (tester) async {
    final repositories = [_repo('alpha'), _repo('beta')];
    final exception = await _pumpDialog(
      tester,
      const RepositorySwitcherDialog(),
      overrides: [
        workspaceProvider.overrideWith(
          () => _FakeWorkspaceNotifier(repositories),
        ),
        projectProvider.overrideWith((ref) => _FakeProjectNotifier(ref)),
        selectedProjectProvider.overrideWith(
          (ref) => _NoProjectSelectedNotifier(ref),
        ),
      ],
    );
    expect(exception, isNull);
    // The issue's acceptance: the repository list is actually visible.
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('BranchSwitcherDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const BranchSwitcherDialog(),
      overrides: [
        localBranchesProvider.overrideWith((ref) async => [_master, _feature]),
        remoteBranchesProvider.overrideWith((ref) async => <GitBranch>[]),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('CreateTagDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const CreateTagDialog(),
      overrides: [
        commitHistoryProvider.overrideWith(
          (ref) async => [_commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'x')],
        ),
        tagsProvider.overrideWith((ref) async => [_tag]),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('MergeBranchDialog (shared) lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const MergeBranchDialog(),
      overrides: [
        allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
        currentBranchProvider.overrideWith((ref) async => 'master'),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('MergeBranchesDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const MergeBranchesDialog(),
      overrides: [
        allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
        currentBranchProvider.overrideWith((ref) async => 'master'),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('RebaseDialog lays out while idle', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const RebaseDialog(),
      overrides: [
        rebaseStateProvider.overrideWith((ref) async => RebaseState.idle()),
        currentBranchProvider.overrideWith((ref) async => 'master'),
        allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('RebaseDialog lays out mid-rebase with conflicts', (
    tester,
  ) async {
    final exception = await _pumpDialog(
      tester,
      const RebaseDialog(),
      overrides: [
        rebaseStateProvider.overrideWith(
          (ref) async => const RebaseState(
            isActive: true,
            ontoBranch: 'master',
            currentCommit: 'a1b2c3d',
            totalSteps: 3,
            currentStep: 1,
            hasConflicts: true,
          ),
        ),
        currentBranchProvider.overrideWith((ref) async => 'feature'),
        allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('BisectDialog lays out on the start step', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const BisectDialog(),
      overrides: [
        bisectStateProvider.overrideWith((ref) async => BisectState.idle()),
        commitHistoryProvider.overrideWith(
          (ref) async => [
            _commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'good'),
            _commit('b1b2c3d4e5f60718293a4b5c6d7e8f901234', 'bad'),
          ],
        ),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('BisectDialog lays out while a bisect is running', (
    tester,
  ) async {
    final exception = await _pumpDialog(
      tester,
      const BisectDialog(),
      overrides: [
        bisectStateProvider.overrideWith(
          (ref) async => const BisectState(
            isActive: true,
            currentCommit: 'c1d2e3f',
            stepsRemaining: 3,
            goodCommits: ['a1b2c3d'],
            badCommits: ['b1c2d3e'],
          ),
        ),
        commitHistoryProvider.overrideWith((ref) async => <GitCommit>[]),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('ReflogDialog lays out with entries', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const ReflogDialog(),
      overrides: [
        reflogProvider.overrideWith(
          (ref) async => [
            ReflogEntry(
              hash: 'a1b2c3d',
              selector: 'HEAD@{0}',
              action: 'commit',
              message: 'commit: fix the thing',
              timestamp: DateTime(2026),
            ),
            ReflogEntry(
              hash: 'b1c2d3e',
              selector: 'HEAD@{1}',
              action: 'checkout',
              message: 'checkout: moving from master to feature',
              timestamp: DateTime(2026),
            ),
          ],
        ),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('BackgroundActivityDialog lays out', (tester) async {
    final repositories = [_repo('alpha'), _repo('beta')];
    final exception = await _pumpDialog(
      tester,
      const BackgroundActivityDialog(),
      overrides: [
        workspaceProvider.overrideWith(
          () => _FakeWorkspaceNotifier(repositories),
        ),
        workspaceRepositoryStatusProvider.overrideWith(
          (ref) => _FakeStatusNotifier(ref, {
            for (final repo in repositories)
              repo.path: const RepositoryStatus(exists: true, isValidGit: true),
          }),
        ),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('UpdateAvailableDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      UpdateAvailableDialog(
        updateInfo: UpdateInfo(
          version: '9.9.9',
          downloadUrl: 'https://example.com/app.zip',
          changelog: 'Notes',
          releaseDate: DateTime(2026),
          fileSize: 1024,
          platform: 'windows',
        ),
      ),
    );
    expect(exception, isNull);
  });

  testWidgets('InitializeRepositoryDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const InitializeRepositoryDialog(),
    );
    expect(exception, isNull);
  });

  testWidgets('CloneRepositoryDialog lays out', (tester) async {
    final exception = await _pumpDialog(tester, const CloneRepositoryDialog());
    expect(exception, isNull);
  });

  testWidgets('DiffToolsConfigDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const DiffToolsConfigDialog(),
      overrides: [
        availableDiffToolsProvider.overrideWith(
          (ref) async => const [
            DiffTool(
              type: DiffToolType.kdiff3,
              executablePath: '/usr/bin/kdiff3',
              diffArgs: '',
              mergeArgs: '',
              isAvailable: true,
            ),
          ],
        ),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('SearchBranchesDialog lays out', (tester) async {
    final exception = await _pumpDialog(tester, const SearchBranchesDialog());
    expect(exception, isNull);
  });

  testWidgets('RenameRemoteDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const RenameRemoteDialog(remote: _remote),
    );
    expect(exception, isNull);
  });

  testWidgets('EditRemoteUrlDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const EditRemoteUrlDialog(remote: _remote),
    );
    expect(exception, isNull);
  });

  testWidgets('PruneRemoteDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const PruneRemoteDialog(remote: _remote),
    );
    expect(exception, isNull);
  });

  testWidgets('BatchResultDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      BatchResultDialog(
        repositoryName: 'alpha',
        result: const RepositoryBatchResult(success: true, message: 'Done'),
        onDismiss: () {},
      ),
    );
    expect(exception, isNull);
  });

  testWidgets('GitOutputDialog lays out on success with output', (
    tester,
  ) async {
    final exception = await _pumpDialog(
      tester,
      GitOutputDialog(
        // No auto-close: its countdown timer would outlive the test.
        autoCloseOnSuccess: false,
        result: GitCommandResult(
          command: 'status',
          stdout: 'On branch master',
          stderr: '',
          exitCode: 0,
          executionTime: const Duration(milliseconds: 5),
        ),
      ),
    );
    expect(exception, isNull);
  });

  testWidgets('GitOutputDialog lays out on failure', (tester) async {
    final exception = await _pumpDialog(
      tester,
      GitOutputDialog(
        autoCloseOnSuccess: false,
        result: GitCommandResult(
          command: 'push',
          stdout: '',
          stderr: 'fatal: remote unreachable',
          exitCode: 1,
          executionTime: const Duration(milliseconds: 5),
        ),
      ),
    );
    expect(exception, isNull);
  });

  testWidgets('AppAboutDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const AppAboutDialog(),
      overrides: [
        versionServiceProvider.overrideWith((ref) => _FakeVersionService()),
      ],
    );
    expect(exception, isNull);
  });

  testWidgets('RenameBranchDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const RenameBranchDialog(branch: _feature),
    );
    expect(exception, isNull);
  });

  testWidgets('DeleteBranchDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const DeleteBranchDialog(branch: _feature),
    );
    expect(exception, isNull);
  });

  testWidgets('MergeBranchDialog (branches) lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const branches.MergeBranchDialog(branch: _feature),
      overrides: [currentBranchProvider.overrideWith((ref) async => 'master')],
    );
    expect(exception, isNull);
  });

  testWidgets('SelectRemoteDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const SelectRemoteDialog(remotes: ['origin', 'upstream']),
    );
    expect(exception, isNull);
  });

  testWidgets('AdvancedFiltersDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      AdvancedFiltersDialog(allTags: [_tag]),
    );
    expect(exception, isNull);
  });

  testWidgets('DeleteTagsDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const DeleteTagsDialog(tagNames: {'v1.0.0'}, hasRemotes: true),
    );
    expect(exception, isNull);
  });

  testWidgets('CheckoutTagDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const CheckoutTagDialog(tagName: 'v1.0.0'),
    );
    expect(exception, isNull);
  });

  testWidgets('CreateBranchFromTagDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const CreateBranchFromTagDialog(tagName: 'v1.0.0'),
    );
    expect(exception, isNull);
  });

  testWidgets('CreateStashDialog lays out', (tester) async {
    final exception = await _pumpDialog(tester, const CreateStashDialog());
    expect(exception, isNull);
  });

  testWidgets('CreateBranchFromStashDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      CreateBranchFromStashDialog(stash: _stash),
    );
    expect(exception, isNull);
  });

  testWidgets('ProjectDialog lays out', (tester) async {
    final exception = await _pumpDialog(tester, const ProjectDialog());
    expect(exception, isNull);
  });

  testWidgets('the create-branch dialog lays out', (tester) async {
    // Private widget: reachable only through its show function.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => BaseButton(
              label: 'open',
              onPressed: () {
                showCreateBranchDialog(context, repositories: [_repo('alpha')]);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('BatchOperationProgressDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      BatchOperationProgressDialog(
        title: 'Pull Repositories',
        repositories: [_repo('alpha'), _repo('beta')],
        operation: (onProgress) =>
            Completer<List<BatchOperationResult>>().future,
      ),
    );
    expect(exception, isNull);
  });

  testWidgets('CreatePullRequestDialog lays out', (tester) async {
    final exception = await _pumpDialog(
      tester,
      const CreatePullRequestDialog(
        currentBranch: 'feature',
        availableBranches: [_feature, _master],
      ),
    );
    expect(exception, isNull);
  });
}
