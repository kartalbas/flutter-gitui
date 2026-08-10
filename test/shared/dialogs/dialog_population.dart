// The app's dialog population: every dialog the sweeps hold to a rule,
// assembled once in a data-bearing state with the provider overrides each one
// needs, plus the census that keeps the list honest.
//
// This file exists so there is exactly ONE enumeration of "all dialogs".
// Two sweeps consume it - base_dialog_flex_sweep_test.dart (the layout
// invariant of #370) and dialog_keyboard_contract_sweep_test.dart (the
// keyboard contract of #290) - and a second list would drift from the first
// the day someone adds a dialog and only remembers one of them. Adding a case
// here therefore covers a new dialog in both sweeps at once, and the census
// below fails when a dialog source file exists that no case covers and no
// documented exclusion accounts for.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// The Override type moved out of the main entrypoint in Riverpod 3.
import 'package:riverpod/misc.dart' show Override;

import '../../skin/pump_under_skin.dart';

import 'package:flutter_gitui/core/navigation/command_palette.dart';
import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/diff/diff_providers.dart';
import 'package:flutter_gitui/core/diff/models/diff_tool.dart';
import 'package:flutter_gitui/core/git/destructive_action.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/bisect_state.dart';
import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/git/models/git_remote_identity.dart';
import 'package:flutter_gitui/core/git/models/rebase_state.dart';
import 'package:flutter_gitui/core/git/models/reflog_entry.dart';
import 'package:flutter_gitui/core/git/models/remote.dart';
import 'package:flutter_gitui/core/git/models/stash.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/core/git/widgets/git_output_dialog.dart';
import 'package:flutter_gitui/core/hosting/hosted_repository.dart';
import 'package:flutter_gitui/core/hosting/hosting_providers.dart';
import 'package:flutter_gitui/core/models/changelog_release.dart';
import 'package:flutter_gitui/core/services/changelog_service.dart';
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
import 'package:flutter_gitui/features/browse/widgets/viewers/csv_viewer_dialog.dart';
import 'package:flutter_gitui/features/browse/widgets/viewers/image_viewer_dialog.dart';
import 'package:flutter_gitui/features/browse/widgets/viewers/markdown_viewer_dialog.dart';
import 'package:flutter_gitui/features/changelog/changelog_dialog.dart';
import 'package:flutter_gitui/features/changes/widgets/commit_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/advanced_search_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/branch_switch_error_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/compare_commits_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/create_branch_from_commit_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/reset_mode_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/squash_commits_dialog.dart';
import 'package:flutter_gitui/features/history/dialogs/uncommitted_changes_dialog.dart';
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
import 'package:flutter_gitui/shared/dialogs/blame_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/branch_switcher_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/clone_repository_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/confirm_destructive.dart';
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
import 'package:flutter_gitui/shared/dialogs/select_hosted_repository_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/unified_diff_dialog.dart';
import 'package:flutter_gitui/shared/dialogs/update_available_dialog.dart';
import 'package:flutter_gitui/shared/widgets/branch_switcher.dart';

// --- What Enter must do ------------------------------------------------------

/// What pressing Enter inside a dialog is expected to do.
///
/// The rule is [EnterExpectation.claimedByTheDialog]; every other value is a
/// deliberate exception, named and reasoned so that a dialog which quietly
/// lost its Enter fails the sweep instead of being waved through by a skip.
/// Changing a case to one of them is therefore a decision on the record, not
/// a way to silence a failure.
enum EnterExpectation {
  /// The dialog claims Enter and fires its primary action, from wherever
  /// focus sits inside it. This is the [BaseDialog.onSubmit] contract, and
  /// for the list pickers it is the navigable list's activation binding -
  /// from the user's side both are "Enter finishes this dialog".
  claimedByTheDialog,

  /// The autofocused field is multiline, so Enter belongs to the field: it
  /// inserts a newline there, and a dialog-level Enter would make the field
  /// impossible to fill. `focusedEditableKeepsEnter()` in
  /// lib/shared/components/base_dialog.dart is the rule; the sweep proves
  /// both halves of it, that Enter is left alone inside the field AND that
  /// the dialog does claim it once focus moves off the field.
  ownedByAMultilineEditable,

  /// A destructive prompt keeps Enter dead on purpose, so the key repeat of
  /// the keystroke that opened it can never wave the loss through. See
  /// `showDestructiveDialog` and the permanent tier of `confirmDestructive`.
  withheldSoEnterCannotDestroy,

  /// The remote-permanent (tier 3) gate arms Enter, but routes it through the
  /// type-to-confirm check: it does nothing until the user has retyped the
  /// `confirmationToken` exactly. No key repeat can type a ref name, which is
  /// why arming it is safe here and not on the permanent tier above.
  gatedByTheConfirmationToken,

  /// The dialog offers no single primary action - a viewer with nothing to
  /// confirm, or a fork where every action is equally primary (reset soft /
  /// mixed / hard). Enter must then do nothing rather than pick one for the
  /// user.
  noPrimaryAction,

  /// The dialog has a primary action but nothing to run it on yet: it opens
  /// with no branch picked, no commit chosen, no setting changed. Enter must
  /// stay inert until the choice is made, or it would act on an empty
  /// selection. The state the sweep opens is exactly that "nothing chosen
  /// yet" state, which is why these cases are named after it.
  inertUntilSomethingIsChosen,
}

/// What pressing Escape inside a dialog is expected to do.
enum EscapeExpectation {
  /// Escape closes the dialog and reports cancellation - never a
  /// confirmation. The rule for every dialog.
  cancels,

  /// The dialog is running an operation that cannot be abandoned half-way, so
  /// it declares itself non-dismissible for the duration and Escape must not
  /// close it. Today only the batch progress dialog, via
  /// `barrierDismissible: !_isRunning`.
  withheldWhileTheOperationRuns,
}

// --- A case ------------------------------------------------------------------

/// One dialog in one data-bearing state.
///
/// A dialog with two materially different states (a rebase that is idle vs.
/// mid-conflict) contributes two cases pointing at the same [source]; the
/// census counts source files, not cases.
class DialogCase {
  const DialogCase({
    required this.name,
    required this.source,
    required this.open,
    this.overrides = const <Override>[],
    this.expectedTexts = const <String>[],
    this.enter = EnterExpectation.claimedByTheDialog,
    this.escape = EscapeExpectation.cancels,
  });

  /// Reads as the test name, so a failure names the dialog.
  final String name;

  /// The lib/ file this case covers, slash-separated and relative to the
  /// package root. The census matches on it.
  final String source;

  /// Opens the dialog and hands back the route's future, so a sweep can check
  /// what closing it reported. [ref] is there for the dialogs that are shown
  /// through a helper needing one (`confirmDestructive`).
  final Future<Object?> Function(BuildContext context, WidgetRef ref) open;

  /// Provider overrides that put this dialog into its data-bearing state.
  final List<Override> overrides;

  /// Text that must be on screen once the dialog settled - the acceptance of
  /// the issue that motivated the case, where it had one.
  final List<String> expectedTexts;

  final EnterExpectation enter;
  final EscapeExpectation escape;
}

// --- Fakes -------------------------------------------------------------------

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

/// Answers without the PackageInfo and SharedPreferences platform channels,
/// which no widget test has.
class _FakeVersionService extends VersionService {
  @override
  Future<String> getCurrentVersion() async => '9.9.9';

  @override
  Future<bool> isWhatsNewDialogDisabled() async => false;

  @override
  Future<void> disableWhatsNewDialog() async {}

  @override
  Future<void> enableWhatsNewDialog() async {}
}

// --- Fixtures ----------------------------------------------------------------

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

/// The branch list the bulk-delete case is populated with: long enough that
/// the dialog's own 300 dp list really scrolls.
///
/// The count is the point of the fixture, not an arbitrary number. About
/// seven dense rows fit in that box, so a two-branch fixture pins the dialog
/// in the one state it has when there is nothing worth bulk-deleting, and the
/// traversal ring is then trivially correct. Tab's default policy re-sorts the
/// ring from the current geometry on every press, so the failure this fixture
/// has to be able to see - rows scrolled above the title row overtaking it and
/// being visited twice per cycle - only exists once the list scrolls.
List<GitBranch> _bulkDeleteBranches() => [
  for (var index = 0; index < 12; index++)
    GitBranch(
      name: 'feature/work-$index',
      fullName: 'refs/heads/feature/work-$index',
      isLocal: true,
      isRemote: false,
      isCurrent: false,
    ),
];

GitCommit _commit(
  String hash,
  String subject, {
  List<String> parents = const [],
}) => GitCommit(
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
  parents: parents,
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

const _hostedSource = RepositorySource(
  host: 'github.com',
  provider: GitHostingProvider.gitHub,
);

const _hostedRepositories = [
  HostedRepository(
    fullName: 'acme/alpha-app',
    cloneUrl: 'https://github.com/acme/alpha-app.git',
  ),
];

/// A 1x1 transparent PNG, so the image viewer decodes a real image instead of
/// an error state - the viewer has no error branch of its own.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Directory? _fixtureDirectory;

/// Files the three file viewers read from disk. Created once per test file
/// through [prepareDialogFixtures]; the viewers take a path, so there is no
/// provider to override instead.
late final String markdownFixturePath;
late final String csvFixturePath;
late final String imageFixturePath;

/// Creates the on-disk fixtures the file viewers need. Call from `setUpAll`.
void prepareDialogFixtures() {
  final directory = Directory.systemTemp.createTempSync('gitui_dialog_sweep');
  _fixtureDirectory = directory;
  final markdown = File('${directory.path}/notes.md')
    ..writeAsStringSync('# Notes\n\nA paragraph.\n');
  final csv = File('${directory.path}/rows.csv')
    ..writeAsStringSync('name,value\nalpha,1\nbeta,2\n');
  final image = File('${directory.path}/pixel.png')
    ..writeAsBytesSync(base64Decode(_onePixelPng));
  markdownFixturePath = markdown.path;
  csvFixturePath = csv.path;
  imageFixturePath = image.path;
}

/// Removes them again. Call from `tearDownAll`.
void disposeDialogFixtures() {
  final directory = _fixtureDirectory;
  if (directory != null && directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
  _fixtureDirectory = null;
}

// --- The population ----------------------------------------------------------

/// Opens [dialog] on the root navigator, the way `showDialog` does everywhere
/// in the app, and hands back the route's future.
///
/// [barrierDismissible] mirrors what the dialog's own show function passes: it
/// is a property of the route, not of the dialog widget, so a case whose
/// production call site says false has to say false here too - otherwise the
/// route's Escape-to-dismiss would answer a key the dialog deliberately
/// refuses, and the sweep would be testing a dialog the app never shows.
Future<Object?> _show(
  BuildContext context,
  Widget dialog, {
  bool barrierDismissible = true,
}) {
  return showDialog<Object?>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => dialog,
  );
}

/// Every dialog the sweeps cover, in one state each unless a second state is
/// materially different.
///
/// Built lazily (a function, not a `const` list) because the cases close over
/// the on-disk fixture paths, which only exist after `setUpAll` ran.
List<DialogCase> dialogPopulation() => <DialogCase>[
  // --- lib/shared/dialogs ---------------------------------------------------
  DialogCase(
    name: 'RepositorySwitcherDialog (Ctrl+R)',
    source: 'lib/shared/dialogs/repository_switcher_dialog.dart',
    open: (context, ref) => _show(context, const RepositorySwitcherDialog()),
    // The issue's acceptance: the repository list is actually visible.
    expectedTexts: const ['alpha', 'beta'],
    overrides: [
      workspaceProvider.overrideWith(
        () => _FakeWorkspaceNotifier([_repo('alpha'), _repo('beta')]),
      ),
      projectProvider.overrideWith((ref) => _FakeProjectNotifier(ref)),
      selectedProjectProvider.overrideWith(
        (ref) => _NoProjectSelectedNotifier(ref),
      ),
    ],
  ),
  DialogCase(
    name: 'CommandPalette',
    source: 'lib/core/navigation/command_palette.dart',
    // It became a dialog when it stopped being a Material bottom sheet
    // (#412), so it enters the sweeps that hold every dialog to the same
    // keyboard contract - which is the coverage it never had while it was a
    // sheet with its own key handling.
    open: (context, ref) => _show(context, const CommandPalette()),
  ),
  DialogCase(
    name: 'BranchSwitcherDialog',
    source: 'lib/shared/dialogs/branch_switcher_dialog.dart',
    open: (context, ref) => _show(context, const BranchSwitcherDialog()),
    overrides: [
      localBranchesProvider.overrideWith((ref) async => [_master, _feature]),
      remoteBranchesProvider.overrideWith((ref) async => <GitBranch>[]),
    ],
  ),
  DialogCase(
    name: 'CreateTagDialog',
    source: 'lib/shared/dialogs/create_tag_dialog.dart',
    open: (context, ref) => _show(context, const CreateTagDialog()),
    overrides: [
      commitHistoryProvider.overrideWith(
        (ref) async => [_commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'x')],
      ),
      tagsProvider.overrideWith((ref) async => [_tag]),
    ],
  ),
  DialogCase(
    name: 'MergeBranchDialog (shared) before a branch is picked',
    source: 'lib/shared/dialogs/merge_branch_dialog.dart',
    open: (context, ref) => _show(context, const MergeBranchDialog()),
    // Nothing is selected on open, so there is no merge for Enter to start.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
    overrides: [
      allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
      currentBranchProvider.overrideWith((ref) async => 'master'),
    ],
  ),
  DialogCase(
    name: 'MergeBranchesDialog before source and target are picked',
    source: 'lib/shared/dialogs/merge_branches_dialog.dart',
    open: (context, ref) => _show(context, const MergeBranchesDialog()),
    // Neither side of the merge is chosen on open.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
    overrides: [
      allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
      currentBranchProvider.overrideWith((ref) async => 'master'),
    ],
  ),
  DialogCase(
    name: 'RebaseDialog before a target branch is picked',
    source: 'lib/shared/dialogs/rebase_dialog.dart',
    open: (context, ref) => _show(context, const RebaseDialog()),
    // No target branch is chosen on open, so there is no rebase to start;
    // once one is picked Enter starts it (the mid-rebase case below shows the
    // armed half of the same dialog).
    enter: EnterExpectation.inertUntilSomethingIsChosen,
    overrides: [
      rebaseStateProvider.overrideWith((ref) async => RebaseState.idle()),
      currentBranchProvider.overrideWith((ref) async => 'master'),
      allBranchesProvider.overrideWith((ref) async => [_master, _feature]),
    ],
  ),
  DialogCase(
    name: 'RebaseDialog mid-rebase with conflicts',
    source: 'lib/shared/dialogs/rebase_dialog.dart',
    open: (context, ref) => _show(context, const RebaseDialog()),
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
  ),
  DialogCase(
    name: 'BisectDialog before the good and bad commits are picked',
    source: 'lib/shared/dialogs/bisect_dialog.dart',
    open: (context, ref) => _show(context, const BisectDialog()),
    // A bisect needs both ends before it can start.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
    overrides: [
      bisectStateProvider.overrideWith((ref) async => BisectState.idle()),
      commitHistoryProvider.overrideWith(
        (ref) async => [
          _commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'good'),
          _commit('b1b2c3d4e5f60718293a4b5c6d7e8f901234', 'bad'),
        ],
      ),
    ],
  ),
  DialogCase(
    name: 'BisectDialog while a bisect is running',
    source: 'lib/shared/dialogs/bisect_dialog.dart',
    open: (context, ref) => _show(context, const BisectDialog()),
    // Good, Bad and Skip are peers while the bisect runs: answering for the
    // user would corrupt the search, so Enter stays inert by design.
    enter: EnterExpectation.noPrimaryAction,
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
  ),
  DialogCase(
    name: 'ReflogDialog with entries',
    source: 'lib/shared/dialogs/reflog_dialog.dart',
    open: (context, ref) => _show(context, const ReflogDialog()),
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
  ),
  DialogCase(
    name: 'BackgroundActivityDialog',
    source: 'lib/shared/dialogs/background_activity_dialog.dart',
    open: (context, ref) => _show(context, const BackgroundActivityDialog()),
    overrides: [
      workspaceProvider.overrideWith(
        () => _FakeWorkspaceNotifier([_repo('alpha'), _repo('beta')]),
      ),
      workspaceRepositoryStatusProvider.overrideWith(
        (ref) => _FakeStatusNotifier(ref, {
          for (final name in ['alpha', 'beta'])
            '/repos/$name': const RepositoryStatus(
              exists: true,
              isValidGit: true,
            ),
        }),
      ),
    ],
  ),
  DialogCase(
    name: 'UpdateAvailableDialog',
    source: 'lib/shared/dialogs/update_available_dialog.dart',
    open: (context, ref) => _show(
      context,
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
    ),
  ),
  DialogCase(
    name: 'InitializeRepositoryDialog',
    source: 'lib/shared/dialogs/initialize_repository_dialog.dart',
    open: (context, ref) => _show(context, const InitializeRepositoryDialog()),
  ),
  DialogCase(
    name: 'CloneRepositoryDialog',
    source: 'lib/shared/dialogs/clone_repository_dialog.dart',
    open: (context, ref) => _show(context, const CloneRepositoryDialog()),
  ),
  DialogCase(
    name: 'DiffToolsConfigDialog',
    source: 'lib/shared/dialogs/diff_tools_config_dialog.dart',
    open: (context, ref) => _show(context, const DiffToolsConfigDialog()),
    // Nothing has been edited yet, so `_hasChanges` is false: Enter must not
    // "save" a configuration the user has not touched.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
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
  ),
  DialogCase(
    name: 'RenameRemoteDialog',
    source: 'lib/shared/dialogs/rename_remote_dialog.dart',
    open: (context, ref) =>
        _show(context, const RenameRemoteDialog(remote: _remote)),
  ),
  DialogCase(
    name: 'EditRemoteUrlDialog',
    source: 'lib/shared/dialogs/edit_remote_url_dialog.dart',
    open: (context, ref) =>
        _show(context, const EditRemoteUrlDialog(remote: _remote)),
  ),
  DialogCase(
    name: 'PruneRemoteDialog',
    source: 'lib/shared/dialogs/prune_remote_dialog.dart',
    open: (context, ref) =>
        _show(context, const PruneRemoteDialog(remote: _remote)),
  ),
  DialogCase(
    name: 'BatchResultDialog',
    source: 'lib/shared/dialogs/batch_result_dialog.dart',
    open: (context, ref) => _show(
      context,
      BatchResultDialog(
        repositoryName: 'alpha',
        result: const RepositoryBatchResult(success: true, message: 'Done'),
        onDismiss: () {},
      ),
    ),
  ),
  DialogCase(
    name: 'confirmDestructive on a reflog-recoverable action',
    source: 'lib/shared/dialogs/confirm_destructive.dart',
    open: (context, ref) => confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.deleteLocalBranch,
      title: 'Delete branch',
      message: 'The reflog keeps it for about 90 days.',
    ),
    overrides: [confirmDestructiveActionsProvider.overrideWith((ref) => true)],
  ),
  DialogCase(
    name: 'confirmDestructive on a permanently destructive action',
    source: 'lib/shared/dialogs/confirm_destructive.dart',
    open: (context, ref) => confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.resetHard,
      title: 'Discard everything',
      message: 'There is no reflog to recover this from.',
    ),
    enter: EnterExpectation.withheldSoEnterCannotDestroy,
    overrides: [confirmDestructiveActionsProvider.overrideWith((ref) => true)],
  ),
  DialogCase(
    name: 'confirmDestructive on a remote-permanent action (type to confirm)',
    source: 'lib/shared/dialogs/confirm_destructive.dart',
    open: (context, ref) => confirmDestructive(
      context: context,
      ref: ref,
      action: DestructiveAction.forcePush,
      title: 'Force push',
      message: 'This rewrites history other people have.',
      confirmationToken: 'origin/main',
    ),
    enter: EnterExpectation.gatedByTheConfirmationToken,
    overrides: [confirmDestructiveActionsProvider.overrideWith((ref) => true)],
  ),
  DialogCase(
    name: 'UnifiedDiffDialog',
    source: 'lib/shared/dialogs/unified_diff_dialog.dart',
    open: (context, ref) =>
        _show(context, UnifiedDiffDialog.file(filePath: 'lib/main.dart')),
    // A viewer: reading the diff is the whole interaction, and "copy all" and
    // "open externally" are peers, so no single action owns Enter.
    enter: EnterExpectation.noPrimaryAction,
  ),
  DialogCase(
    name: 'BlameDialog',
    source: 'lib/shared/dialogs/blame_dialog.dart',
    open: (context, ref) =>
        _show(context, const BlameDialog(filePath: 'lib/main.dart')),
    // A pure viewer with no actions at all.
    enter: EnterExpectation.noPrimaryAction,
    overrides: [fileBlameProvider.overrideWith((ref, path) async => null)],
  ),
  DialogCase(
    name: 'BulkDeleteBranchesDialog',
    source: 'lib/shared/widgets/branch_switcher.dart',
    open: (context, ref) => _show(
      context,
      BulkDeleteBranchesDialog(
        branches: _bulkDeleteBranches(),
        // Every other row merged, so the list carries both pills and the
        // selection keeps unmerged branches in it - which is what puts the
        // force opt-in on screen.
        deletableWithoutForce: {
          for (var index = 0; index < 12; index += 2) 'feature/work-$index',
        },
      ),
    ),
    // The most destructive prompt in the app: Enter must stay dead so the key
    // repeat of the keystroke that opened it can never delete a set of
    // branches (#397). Cancel is the way out, and no action is affirmative.
    enter: EnterExpectation.withheldSoEnterCannotDestroy,
  ),
  DialogCase(
    name: 'SelectHostedRepositoryDialog',
    source: 'lib/shared/dialogs/select_hosted_repository_dialog.dart',
    open: (context, ref) =>
        _show(context, const SelectHostedRepositoryDialog()),
    overrides: [
      repositorySourcesProvider.overrideWith((ref) => const [_hostedSource]),
      sourceRepositoriesProvider.overrideWith(
        (ref, source) async =>
            const SourceRepositories.loaded(_hostedRepositories),
      ),
    ],
  ),

  // --- lib/core -------------------------------------------------------------
  DialogCase(
    name: 'GitOutputDialog on success with output',
    source: 'lib/core/git/widgets/git_output_dialog.dart',
    open: (context, ref) => _show(
      context,
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
    ),
  ),
  DialogCase(
    name: 'GitOutputDialog on failure',
    source: 'lib/core/git/widgets/git_output_dialog.dart',
    open: (context, ref) => _show(
      context,
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
    ),
  ),

  // --- lib/features ---------------------------------------------------------
  DialogCase(
    name: 'AppAboutDialog',
    source: 'lib/features/about/about_dialog.dart',
    open: (context, ref) => _show(context, const AppAboutDialog()),
    overrides: [
      versionServiceProvider.overrideWith((ref) => _FakeVersionService()),
    ],
  ),
  DialogCase(
    name: 'ChangelogDialog',
    source: 'lib/features/changelog/changelog_dialog.dart',
    open: (context, ref) => _show(context, const ChangelogDialog()),
    overrides: [
      versionServiceProvider.overrideWith((ref) => _FakeVersionService()),
      changelogDataProvider.overrideWith(
        (ref) async => const ChangelogData(
          releases: [
            ChangelogRelease(
              version: '9.9.9',
              date: '2026-01-01',
              changelog: '## Features\n- Something',
              commit: 'a1b2c3d',
            ),
          ],
        ),
      ),
    ],
  ),
  DialogCase(
    name: 'RenameBranchDialog',
    source: 'lib/features/branches/dialogs/rename_branch_dialog.dart',
    open: (context, ref) =>
        _show(context, const RenameBranchDialog(branch: _feature)),
  ),
  DialogCase(
    name: 'DeleteBranchDialog',
    source: 'lib/features/branches/dialogs/delete_branch_dialog.dart',
    open: (context, ref) =>
        _show(context, const DeleteBranchDialog(branch: _feature)),
    enter: EnterExpectation.withheldSoEnterCannotDestroy,
  ),
  DialogCase(
    name: 'MergeBranchDialog (branches)',
    source: 'lib/features/branches/dialogs/merge_branch_dialog.dart',
    open: (context, ref) =>
        _show(context, const branches.MergeBranchDialog(branch: _feature)),
    overrides: [currentBranchProvider.overrideWith((ref) async => 'master')],
  ),
  DialogCase(
    name: 'SearchBranchesDialog',
    source: 'lib/features/branches/dialogs/search_branches_dialog.dart',
    open: (context, ref) => _show(context, const SearchBranchesDialog()),
  ),
  DialogCase(
    name: 'SelectRemoteDialog',
    source: 'lib/features/tags/dialogs/select_remote_dialog.dart',
    open: (context, ref) =>
        _show(context, const SelectRemoteDialog(remotes: ['origin', 'up'])),
  ),
  DialogCase(
    name: 'AdvancedFiltersDialog',
    source: 'lib/features/tags/dialogs/advanced_filters_dialog.dart',
    open: (context, ref) =>
        _show(context, AdvancedFiltersDialog(allTags: [_tag])),
  ),
  DialogCase(
    name: 'DeleteTagsDialog',
    source: 'lib/features/tags/dialogs/delete_tags_dialog.dart',
    open: (context, ref) => _show(
      context,
      const DeleteTagsDialog(tagNames: {'v1.0.0'}, hasRemotes: true),
    ),
    enter: EnterExpectation.withheldSoEnterCannotDestroy,
  ),
  DialogCase(
    name: 'CheckoutTagDialog',
    source: 'lib/features/tags/dialogs/checkout_tag_dialog.dart',
    open: (context, ref) =>
        _show(context, const CheckoutTagDialog(tagName: 'v1.0.0')),
  ),
  DialogCase(
    name: 'CreateBranchFromTagDialog',
    source: 'lib/features/tags/dialogs/create_branch_from_tag_dialog.dart',
    open: (context, ref) =>
        _show(context, const CreateBranchFromTagDialog(tagName: 'v1.0.0')),
  ),
  DialogCase(
    name: 'CreateStashDialog before any file is selected',
    source: 'lib/features/stashes/dialogs/create_stash_dialog.dart',
    open: (context, ref) => _show(context, const CreateStashDialog()),
    // Nothing is picked to stash on open, so Enter has no stash to create.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
  ),
  DialogCase(
    name: 'CreateBranchFromStashDialog',
    source: 'lib/features/stashes/dialogs/create_branch_from_stash_dialog.dart',
    open: (context, ref) =>
        _show(context, CreateBranchFromStashDialog(stash: _stash)),
  ),
  DialogCase(
    name: 'ProjectDialog',
    source: 'lib/features/repositories/dialogs/project_dialog.dart',
    open: (context, ref) => _show(context, const ProjectDialog()),
  ),
  DialogCase(
    name: 'the create-branch dialog',
    source: 'lib/features/repositories/dialogs/create_branch_dialog.dart',
    // A private widget: reachable only through its show function.
    open: (context, ref) =>
        showCreateBranchDialog(context, repositories: [_repo('alpha')]),
  ),
  DialogCase(
    name: 'BatchOperationProgressDialog while the batch runs',
    source:
        'lib/features/repositories/dialogs/batch_operation_progress_dialog.dart',
    open: (context, ref) => _show(
      context,
      BatchOperationProgressDialog(
        title: 'Pull Repositories',
        repositories: [_repo('alpha'), _repo('beta')],
        operation: (onProgress) =>
            Completer<List<BatchOperationResult>>().future,
      ),
      // What showBatchOperationProgressDialog passes: the route must not be
      // dismissible either, or Escape would fall through to the route and
      // abandon the batch the dialog just refused to abandon.
      barrierDismissible: false,
    ),
    // A batch that is mid-flight cannot be abandoned by a stray keystroke: the
    // dialog declares itself non-dismissible while it runs, so neither Escape
    // nor Enter may leave it.
    enter: EnterExpectation.inertUntilSomethingIsChosen,
    escape: EscapeExpectation.withheldWhileTheOperationRuns,
  ),
  DialogCase(
    name: 'CreatePullRequestDialog',
    source: 'lib/features/repositories/dialogs/create_pull_request_dialog.dart',
    open: (context, ref) => _show(
      context,
      const CreatePullRequestDialog(
        currentBranch: 'feature',
        availableBranches: [_feature, _master],
      ),
    ),
  ),
  DialogCase(
    name: 'AdvancedSearchDialog',
    source: 'lib/features/history/dialogs/advanced_search_dialog.dart',
    open: (context, ref) => _show(context, const AdvancedSearchDialog()),
    overrides: [
      commitHistoryProvider.overrideWith(
        (ref) async => [_commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'x')],
      ),
    ],
  ),
  DialogCase(
    name: 'BranchSwitchErrorDialog',
    source: 'lib/features/history/dialogs/branch_switch_error_dialog.dart',
    open: (context, ref) => _show(
      context,
      const BranchSwitchErrorDialog(branchName: 'feature', error: 'denied'),
    ),
  ),
  DialogCase(
    name: 'CompareCommitsDialog',
    source: 'lib/features/history/dialogs/compare_commits_dialog.dart',
    open: (context, ref) => _show(
      context,
      CompareCommitsDialog(
        newer: _commit('b1b2c3d4e5f60718293a4b5c6d7e8f901234', 'newer'),
        older: _commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'older'),
      ),
    ),
    // A viewer over `git log older..newer`: there is nothing to confirm.
    enter: EnterExpectation.noPrimaryAction,
  ),
  DialogCase(
    name: 'CreateBranchFromCommitDialog',
    source:
        'lib/features/history/dialogs/create_branch_from_commit_dialog.dart',
    open: (context, ref) => _show(
      context,
      CreateBranchFromCommitDialog(
        commit: _commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'subject'),
      ),
    ),
  ),
  DialogCase(
    name: 'ResetModeDialog',
    source: 'lib/features/history/dialogs/reset_mode_dialog.dart',
    open: (context, ref) => _show(
      context,
      ResetModeDialog(
        commit: _commit('a1b2c3d4e5f60718293a4b5c6d7e8f901234', 'subject'),
      ),
    ),
    // Soft, mixed and hard are three different resets, one of which discards
    // work: none of them may be the one Enter picks for the user.
    enter: EnterExpectation.noPrimaryAction,
  ),
  DialogCase(
    name: 'UncommittedChangesDialog',
    source: 'lib/features/history/dialogs/uncommitted_changes_dialog.dart',
    open: (context, ref) =>
        _show(context, const UncommittedChangesDialog(changeCount: 3)),
  ),
  DialogCase(
    name: 'the squash-commits dialog',
    source: 'lib/features/history/dialogs/squash_commits_dialog.dart',
    // A private widget: reachable only through its show function.
    open: (context, ref) => showSquashCommitsDialog(
      context,
      selectedCommits: [
        _commit(
          'b1b2c3d4e5f60718293a4b5c6d7e8f901234',
          'newer',
          parents: ['a1b2c3d4e5f60718293a4b5c6d7e8f901234'],
        ),
        _commit(
          'a1b2c3d4e5f60718293a4b5c6d7e8f901234',
          'older',
          parents: ['c1b2c3d4e5f60718293a4b5c6d7e8f901234'],
        ),
      ],
    ),
    enter: EnterExpectation.ownedByAMultilineEditable,
  ),
  DialogCase(
    name: 'CommitDialog',
    source: 'lib/features/changes/widgets/commit_dialog.dart',
    open: (context, ref) => _show(context, const CommitDialog()),
    enter: EnterExpectation.ownedByAMultilineEditable,
    overrides: [
      stagedFilesProvider.overrideWith((ref) => const <FileStatus>[]),
    ],
  ),
  DialogCase(
    name: 'MarkdownViewerDialog',
    source: 'lib/features/browse/widgets/viewers/markdown_viewer_dialog.dart',
    open: (context, ref) =>
        _show(context, MarkdownViewerDialog(filePath: markdownFixturePath)),
    enter: EnterExpectation.noPrimaryAction,
  ),
  DialogCase(
    name: 'CsvViewerDialog',
    source: 'lib/features/browse/widgets/viewers/csv_viewer_dialog.dart',
    open: (context, ref) =>
        _show(context, CsvViewerDialog(filePath: csvFixturePath)),
    enter: EnterExpectation.noPrimaryAction,
  ),
  DialogCase(
    name: 'ImageViewerDialog',
    source: 'lib/features/browse/widgets/viewers/image_viewer_dialog.dart',
    open: (context, ref) =>
        _show(context, ImageViewerDialog(filePath: imageFixturePath)),
    enter: EnterExpectation.noPrimaryAction,
  ),
];

// --- The harness -------------------------------------------------------------

/// The host page the dialogs are opened over.
///
/// It carries three real buttons, so a sweep can prove that Tab never escapes
/// the dialog onto the screen behind the modal barrier: if traversal leaked,
/// focus would land on one of these.
const List<String> backgroundControlLabels = [
  'open the dialog',
  'background one',
  'background two',
];

// --- The census --------------------------------------------------------------

/// Why a dialog source file is not in the population.
enum DialogExclusionKind {
  /// One of the two dialog components themselves, covered through every case
  /// that is built on it.
  theComponentItself,

  /// A dialog that cannot be pumped in a widget test without reaching outside
  /// the process, so a sweep over it would assert against the machine.
  unpumpable,

  /// A dialog built inline inside a screen or widget method rather than as a
  /// dialog class of its own, and therefore only reachable by pumping that
  /// whole surface - which is what that surface's own keyboard test does. A
  /// file under a `dialogs/` directory may never take this kind; the census
  /// enforces that, so a new dialog cannot be kept out of the sweep by being
  /// written inline.
  inlineInASurface,
}

class DialogExclusion {
  const DialogExclusion(this.kind, this.reason);

  final DialogExclusionKind kind;
  final String reason;
}

/// Files under lib/ that construct a dialog but are deliberately not in the
/// population, each with the reason it cannot be - or need not be - pumped.
///
/// An entry here is a claim that has to stay true; the census fails when a
/// file listed here has stopped constructing dialogs, so a stale exclusion
/// cannot quietly outlive its reason.
const Map<String, DialogExclusion> dialogSourceExclusions = {
  'lib/shared/components/base_dialog.dart': DialogExclusion(
    DialogExclusionKind.theComponentItself,
    'The component itself, exercised through every case in the population and '
    'directly by test/shared/components/base_dialog_keyboard_test.dart.',
  ),
  'lib/shared/components/base_viewer_dialog.dart': DialogExclusion(
    DialogExclusionKind.theComponentItself,
    'The other component, likewise covered through its users.',
  ),
  'lib/shared/dialogs/detect_tools_dialog.dart': DialogExclusion(
    DialogExclusionKind.unpumpable,
    'Probes the machine from initState: a `where`/`which` lookup for git plus '
    'one for each of eleven editors. Pumping it runs real subprocesses '
    'whose results differ per machine, so the sweep would be asserting '
    'against whatever happens to be installed on the runner.',
  ),

  'lib/core/navigation/git_commands.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline confirmation prompts inside the git-command runner.',
  ),
  'lib/features/browse/widgets/file_blame_panel.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline viewer and confirmation built by the blame panel; covered by '
    'test/features/browse/browse_screen_keyboard_test.dart.',
  ),
  'lib/features/browse/widgets/file_history_panel.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline viewer built by the file-history panel.',
  ),
  'lib/features/browse/widgets/file_tree_view.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline rename/create/delete prompts of the file tree; covered by '
    'test/features/browse/file_tree_view_test.dart.',
  ),
  'lib/features/changes/changes_screen.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the changes screen; covered by '
    'test/features/changes/changes_screen_keyboard_test.dart.',
  ),
  'lib/features/merge/conflict_resolution_screen.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the conflict resolution screen.',
  ),
  'lib/features/repositories/repositories_screen.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the repositories screen; covered by '
    'test/features/repositories/repositories_keyboard_test.dart.',
  ),
  'lib/features/settings/settings_screen.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the settings screen; covered by '
    'test/features/settings/settings_keyboard_test.dart.',
  ),
  'lib/features/settings/widgets/config_and_logs_section.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the settings config/logs section.',
  ),
  'lib/features/workspaces/workspaces_screen.dart': DialogExclusion(
    DialogExclusionKind.inlineInASurface,
    'Inline prompts of the workspaces screen; covered by '
    'test/features/workspaces/workspaces_keyboard_test.dart.',
  ),
};

/// The package root, found by walking up to the nearest pubspec.yaml - the
/// same resolution
/// packages/gitui_skin_material/test/conformance/support/deviation_register.dart
/// uses, so the census works no matter which directory the runner was
/// started from.
Directory packageRoot() {
  Directory directory = Directory.current;
  for (int i = 0; i < 10; i++) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) return directory;
    final Directory parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'Could not find the package root above ${Directory.current.path}.',
  );
}

/// Every file under lib/ that constructs a `BaseDialog` or a
/// `BaseViewerDialog`, as slash-separated paths relative to the package root.
///
/// This is the population's ground truth: a dialog cannot exist in this app
/// without one of those two constructions, so the set is complete by
/// construction rather than by anyone remembering to update a list.
///
/// The unit is the file, which is the unit a new dialog arrives in here -
/// every dialog class lives in its own file under a `dialogs/` directory. A
/// second dialog smuggled into an already-covered file would not be caught by
/// the census; writing it inline inside a screen would not help either,
/// because a file under a `dialogs/` directory may not take the
/// inline-in-a-surface exclusion.
List<String> dialogSourceFilesUnderLib() {
  final root = packageRoot();
  final lib = Directory('${root.path}/lib');
  final pattern = RegExp(r'\b(BaseDialog|BaseViewerDialog)\s*\(');
  final files = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (!pattern.hasMatch(entity.readAsStringSync())) continue;
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll(r'\', '/');
    files.add(relative);
  }
  files.sort();
  return files;
}

/// Builds the [ProviderScope] + [MaterialApp] host a dialog case is opened
/// over, so both sweeps open every dialog exactly the same way: through
/// `showDialog` on the root navigator, over a screen with focusable controls
/// of its own, behind the real modal barrier.
///
/// [appBuilder] is inserted through `MaterialApp.builder`, which puts it
/// *below* the app's own `Shortcuts` and *above* the navigator - the one place
/// from which a listener sees exactly the keys that no focus node inside a
/// dialog claimed. The keyboard sweep uses it for that; the flex sweep passes
/// nothing.
Widget dialogHostApp({
  required DialogCase dialogCase,
  required void Function(Future<Object?> result) onOpened,
  Widget Function(BuildContext context, Widget child)? appBuilder,
}) {
  return ProviderScope(
    overrides: [
      configProvider.overrideWith(
        (ref) => ConfigNotifier.withConfig(ref, AppConfig.defaults),
      ),
      currentRepositoryPathProvider.overrideWith((ref) => null),
      ...dialogCase.overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The skin is installed here, beneath the one application root and above
      // the navigator, exactly as `main.dart` installs it - so a dialog opened
      // by this host reaches the same design language, in the same place, as
      // one opened by the running application. The caller's own builder runs
      // FIRST and the skin wraps its result, which keeps the keyboard sweep's
      // listener at the depth it was placed at relative to the navigator.
      builder: (context, child) => installSkinUnderTest(
        appBuilder == null ? child! : appBuilder(context, child!),
      ),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              BaseButton(
                label: backgroundControlLabels[0],
                onPressed: () => onOpened(dialogCase.open(context, ref)),
              ),
              BaseButton(label: backgroundControlLabels[1], onPressed: () {}),
              BaseButton(label: backgroundControlLabels[2], onPressed: () {}),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opens the dialog of the pumped case and gives it the frames it needs,
/// returning the first exception the framework caught - null when the dialog
/// opened cleanly.
///
/// Deliberately not `pumpAndSettle`: several dialogs in the population run an
/// indicator that never stops (a batch mid-flight, a diff that stays loading),
/// and settling on those would hang instead of failing. The fixed schedule
/// covers the route transition plus the two frames an overridden
/// FutureProvider needs to deliver its value and rebuild into its data branch
/// - the branch that held every layout defect this sweep has found so far.
Future<Object?> openDialogOfCase(WidgetTester tester) async {
  await tester.tap(find.text(backgroundControlLabels[0]));
  for (final duration in const [
    Duration.zero,
    Duration(milliseconds: 400),
    Duration.zero,
    Duration(milliseconds: 100),
  ]) {
    await tester.pump(duration);
    final exception = tester.takeException();
    if (exception != null) return exception;
  }
  return null;
}
