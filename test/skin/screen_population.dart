// The app's screen population: every screen the #249 leak checks are pointed
// at, assembled once in a data-bearing state with the provider overrides each
// one needs.
//
// ## Why this file exists
//
// The blueprint's five checks (docs/SKIN-CONTRACT.md §3) all have the same
// prerequisite: a rendered screen. T1 counts the pixels of one, T3 walks the
// element tree of one, T5 diffs two renders of one. None of them can find a
// leak on a screen nobody rendered, so the coverage of this file is a hard
// ceiling on what the whole instrument can ever see - a hardcoded amber
// `Container` on the repositories screen is invisible to every check in the
// programme until the repositories screen is in this list.
//
// What was there before is stated honestly in the design (§5.2): three
// *fragments* of screens, in
// packages/gitui_skin_material/test/conformance/goldens/screen_scenes.dart,
// reconstructed toolbar-by-toolbar because the real screens could not be
// instantiated. They stay where they are - they are Material's golden
// baselines and they measure a different thing, the width arithmetic of a bar
// under a constraint. This file is the other half: whole screens, built from
// the real screen widgets, driven by the real providers.
//
// ## Why whole screens rather than more fragments
//
// A fragment is a reconstruction, and a reconstruction cannot leak: it only
// contains what the person writing it put there. The leak this programme
// hunts is by definition somewhere nobody looked - the status chip nested four
// widgets deep inside a list row inside a scroll view. Only the real screen
// contains it.
//
// This is also why the scenes take the same shape as
// test/shared/dialogs/dialog_population.dart: one enumeration, consumed by
// every sweep that needs it, with a census that fails when a screen exists in
// lib/ that no scene covers. A second list would drift from the first on the
// day somebody adds a screen and remembers only one of them.
//
// ## The rule every scene obeys: no scene runs git, and no scene touches the
// user's machine
//
// `gitServiceProvider` is overridden for every scene, so a scene physically
// cannot shell out; `configProvider` is overridden for every scene, so no
// scene reads or writes the developer's real configuration; the two screens
// that genuinely need a filesystem get a temp directory created per run and
// deleted afterwards.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// flutter_riverpod does not re-export the Override type an override list is
// typed with.
import 'package:riverpod/misc.dart' show Override;

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/diff/models/diff_tool.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/git_service.dart';
import 'package:flutter_gitui/core/git/models/branch.dart';
import 'package:flutter_gitui/core/git/models/commit.dart';
import 'package:flutter_gitui/core/git/models/file_change.dart';
import 'package:flutter_gitui/core/git/models/file_status.dart';
import 'package:flutter_gitui/core/git/models/merge_conflict.dart';
import 'package:flutter_gitui/core/git/models/stash.dart';
import 'package:flutter_gitui/core/git/models/tag.dart';
import 'package:flutter_gitui/core/navigation/app_shell.dart';
import 'package:flutter_gitui/core/navigation/navigation_item.dart';
import 'package:flutter_gitui/core/utils/result.dart';
import 'package:flutter_gitui/core/workspace/models/repository_status.dart';
import 'package:flutter_gitui/core/workspace/models/workspace.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';
import 'package:flutter_gitui/core/workspace/repository_status_provider.dart';
import 'package:flutter_gitui/core/workspace/selected_workspace_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_list_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_provider.dart';
import 'package:flutter_gitui/features/branches/branches_screen.dart';
import 'package:flutter_gitui/features/browse/browse_screen.dart';
import 'package:flutter_gitui/features/changes/changes_screen.dart';
import 'package:flutter_gitui/features/history/history_screen.dart';
import 'package:flutter_gitui/features/merge/conflict_resolution_screen.dart';
import 'package:flutter_gitui/features/repositories/repositories_screen.dart';
import 'package:flutter_gitui/features/settings/settings_screen.dart';
import 'package:flutter_gitui/features/stashes/stashes_screen.dart';
import 'package:flutter_gitui/features/tags/tags_screen.dart';
import 'package:flutter_gitui/features/workspaces/workspaces_screen.dart';

import 'pump_under_skin.dart';

// --- A scene -----------------------------------------------------------------

/// How long a scene needs before it is showing what it is supposed to show.
enum SceneSettle {
  /// Everything the scene draws comes from a provider this file overrode, so
  /// it arrives inside the test's own fake-async zone and a fixed schedule of
  /// pumped frames is enough. True of every scene but one.
  onScheduledFrames,

  /// The scene does real work off the isolate before it has anything to draw.
  /// `dart:io` never completes inside fake async, so no number of pumps
  /// produces the result; only real elapsed time under `runAsync` does.
  onRealFilesystemWork,
}

/// One screen of the application, in one data-bearing state.
///
/// A screen with two materially different states worth rendering (a merge that
/// is idle vs. mid-conflict) contributes two scenes pointing at the same
/// [source]; the census counts source files, not scenes.
class ScreenScene {
  ScreenScene({
    required this.name,
    required this.source,
    required this.build,
    required this.expectedTexts,
    this.overrides = _noOverrides,
    this.surface = kDesktopSurface,
    this.settle = SceneSettle.onScheduledFrames,
  }) : assert(
         expectedTexts.isNotEmpty,
         'A scene with nothing to assert is a scene that can render an empty '
         'error state and still pass, and an empty screen is exactly where a '
         'leak cannot show up. Name at least one string the fixture puts on '
         'screen.',
       );

  /// Reads as the test name, so a failure names the screen.
  final String name;

  /// The lib/ file this scene covers, slash-separated and relative to the
  /// package root. The census matches on it.
  final String source;

  /// Builds the screen widget. A closure rather than a value because a scene
  /// is built once per test and a `StatefulWidget` instance must not be
  /// shared between two pumps.
  final Widget Function() build;

  /// Provider overrides that put this screen into its data-bearing state.
  ///
  /// A closure rather than a list, for two reasons that both bite. The
  /// fixtures two scenes need (a temp working tree, repositories with a real
  /// `.git` directory) only exist once `prepareScreenFixtures` has run, which
  /// is after the population is enumerated to declare the tests; and an
  /// override that captures a notifier instance would otherwise hand the same
  /// instance to two tests, so state left behind by the first would arrive in
  /// the second.
  final List<Override> Function() overrides;

  /// Text the fixture puts on screen once the scene has settled.
  ///
  /// Deliberately fixture text - a branch name, a repository name, a file path
  /// this file chose - rather than localised chrome wherever possible, so the
  /// assertion says "the screen rendered the data it was given" and not "the
  /// screen rendered a title".
  final List<String> expectedTexts;

  /// The window the scene is laid out in.
  final Size surface;

  /// What it takes to get the scene onto the screen; see [SceneSettle].
  final SceneSettle settle;
}

/// The default for a scene that needs no overrides beyond the baseline.
/// Declared as a top-level function so the constructor stays const-friendly
/// and the default reads as "nothing", not as "an empty list somebody may
/// mutate".
List<Override> _noOverrides() => const <Override>[];

// --- Fakes -------------------------------------------------------------------

/// Git without git.
///
/// Every screen in the population reaches the service for something, and the
/// real one shells out to `git` in a subprocess: a scene that reached it would
/// run a git command against a path that does not exist, on the developer's
/// machine, from a unit test. Each method below answers the shape its caller
/// expects and nothing else.
class _SceneGitService extends GitService {
  _SceneGitService(super.repoPath);

  @override
  Future<Result<List<String>>> getIgnoredPaths() async =>
      const Success(<String>[]);

  @override
  Future<Result<String>> getDiff(
    String filePath, {
    bool staged = false,
  }) async =>
      Success('diff --git a/$filePath b/$filePath\n@@ -0,0 +1,1 @@\n+x\n');

  @override
  Future<String?> getFileContent(String filePath) async => 'x\n';

  @override
  Future<Result<List<GitCommit>>> getFileHistory(String filePath) async =>
      const Success(<GitCommit>[]);

  @override
  Future<List<FileChange>> getCommitChangedFiles(String commitHash) async =>
      const <FileChange>[];
}

/// Serves the scripted repositories and swallows the last-accessed write,
/// which would otherwise reach the on-disk config from a test.
class _SceneWorkspaceNotifier extends WorkspaceNotifier {
  _SceneWorkspaceNotifier(this._repositories);

  final List<WorkspaceRepository> _repositories;

  @override
  List<WorkspaceRepository> build() => _repositories;

  @override
  Future<void> markAccessed(String path) async {}
}

/// Keeps the startup auto-assignment away from the on-disk config, and serves
/// the scripted workspaces where a scene supplies them.
class _SceneProjectNotifier extends ProjectNotifier {
  _SceneProjectNotifier(super.ref, [List<Workspace>? projects]) {
    if (projects != null) state = projects;
  }

  @override
  Future<void> assignUnassignedRepositories(
    List<String> allRepoPaths,
    String projectId,
  ) async {}
}

/// Selects in memory only; the real notifier persists the selection to the
/// on-disk config, which a test must never reach.
class _SceneSelectedProjectNotifier extends SelectedProjectNotifier {
  _SceneSelectedProjectNotifier(super.ref) {
    state = null;
  }

  @override
  Future<void> selectProject(Workspace project) async {
    state = project;
  }
}

/// Serves settled, healthy statuses so no row shows the indeterminate loading
/// spinner - which would leave the screen mid-animation in every render, and
/// therefore different in every render.
class _SceneStatusNotifier extends RepositoryStatusNotifier {
  _SceneStatusNotifier(super.ref, Map<String, RepositoryStatus> statuses) {
    state = statuses;
  }
}

// --- Fixtures ----------------------------------------------------------------

const String _kRepositoryPath = '/repo';

GitBranch _branch(String name, {bool isCurrent = false}) => GitBranch(
  name: name,
  fullName: 'refs/heads/$name',
  isLocal: true,
  isRemote: false,
  isCurrent: isCurrent,
);

GitCommit _commit(
  String hash,
  String subject, {
  List<String> parents = const [],
}) => GitCommit(
  hash: hash,
  shortHash: hash.substring(0, 7),
  author: 'Ada Lovelace',
  authorEmail: 'ada@example.com',
  authorDate: DateTime(2026, 3, 14),
  committer: 'Ada Lovelace',
  committerEmail: 'ada@example.com',
  committerDate: DateTime(2026, 3, 14),
  subject: subject,
  body: '',
  parents: parents,
  refs: const <String>[],
);

GitTag _tag(String name, String hash, DateTime date) => GitTag(
  name: name,
  commitHash: hash,
  type: GitTagType.annotated,
  commitMessage: 'commit for $name',
  message: 'release $name',
  date: date,
);

GitStash _stash(int index, String message) => GitStash(
  ref: 'stash@{$index}',
  index: index,
  hash: 'abcdef${index}0000000000000000000000000000',
  branch: 'master',
  message: message,
  timestamp: DateTime(2026, 3, 14),
);

FileStatus _modified(String path) => FileStatus(
  path: path,
  indexStatus: FileStatusType.unchanged,
  workTreeStatus: FileStatusType.modified,
);

Workspace _workspace(String id, String name) => Workspace(
  id: id,
  name: name,
  description: 'the $name workspace',
  color: const Color(0xFF2196F3),
  repositoryPaths: const <String>[],
  createdAt: DateTime(2026),
);

/// A fully configured app, so the settings screen shows the controls that only
/// exist once a tool is set. The paths point at nothing: startup validation
/// asks VersionDetector for a version, which returns null for a file that does
/// not exist without launching a process.
final AppConfig _configuredApp = AppConfig.defaults.copyWith(
  git: const GitConfig(
    executablePath: '/tools/git',
    gitVersion: '2.43.0',
    defaultUserName: 'Ada Lovelace',
    defaultUserEmail: 'ada@example.com',
  ),
  tools: const ToolsConfig(
    textEditor: '/tools/editor',
    diffTool: DiffToolType.vscode,
    diffToolPath: '/tools/diff',
    mergeTool: DiffToolType.vscode,
    mergeToolPath: '/tools/merge',
  ),
);

Directory? _fixtureRoot;

/// The working tree the browse scene walks. Real files, because the file tree
/// reads the filesystem and there is no provider to override instead.
late String browseFixturePath;

/// Repositories with a real `.git` directory, because the repositories screen
/// checks the filesystem before it lets a repository be opened.
late List<WorkspaceRepository> repositoryFixtures;

/// Creates the on-disk fixtures and installs the platform fakes the screens
/// need. Call once per test file, from `setUpAll`.
///
/// The three platform mocks are not optional decoration: shared_preferences
/// backs the settings sections' expanded state, package_info_plus backs the
/// update section's version read, and `desktop_drop` has no host in a widget
/// test, so each would throw asynchronously mid-scene.
void prepareScreenFixtures() {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  PackageInfo.setMockInitialValues(
    appName: 'flutter_gitui',
    packageName: 'dev.kartalbas.flutter_gitui',
    version: '0.5.14-alpha',
    buildNumber: '',
    buildSignature: '',
  );

  final Directory root = Directory.systemTemp.createTempSync('skin_scenes');
  _fixtureRoot = root;

  final Directory browse = Directory(p.join(root.path, 'working-tree'))
    ..createSync(recursive: true);
  Directory(p.join(browse.path, 'lib')).createSync(recursive: true);
  File(
    p.join(browse.path, 'lib', 'main.dart'),
  ).writeAsStringSync('void main() {}\n');
  File(p.join(browse.path, 'README.md')).writeAsStringSync('# fixture\n');
  browseFixturePath = browse.path;

  repositoryFixtures = <WorkspaceRepository>[
    for (int index = 1; index <= 4; index++)
      () {
        final Directory git = Directory(p.join(root.path, 'repo$index', '.git'))
          ..createSync(recursive: true);
        return WorkspaceRepository(
          path: git.parent.path,
          name: 'fixture-repo-$index',
          lastAccessed: DateTime(2026),
        );
      }(),
  ];
}

/// Removes what [prepareScreenFixtures] wrote. Call from `tearDownAll`.
void disposeScreenFixtures() {
  final Directory? root = _fixtureRoot;
  if (root != null && root.existsSync()) root.deleteSync(recursive: true);
  _fixtureRoot = null;
}

/// Answers the `desktop_drop` channel, which has no host in a widget test, so
/// `DropTarget`'s initialisation cannot fail asynchronously under a scene.
void silenceDesktopDrop(TestDefaultBinaryMessenger messenger) {
  messenger.setMockMethodCallHandler(
    const MethodChannel('desktop_drop'),
    (MethodCall call) async => null,
  );
}

// --- The baseline every scene starts from ------------------------------------

/// The three overrides no scene may be without: an in-memory configuration, a
/// repository path that is a fixture rather than the developer's checkout, and
/// a git service that cannot start a process.
List<Override> _baseline({
  String? repositoryPath = _kRepositoryPath,
  AppConfig? config,
}) => <Override>[
  configProvider.overrideWith(
    (Ref ref) => ConfigNotifier.withConfig(ref, config ?? AppConfig.defaults),
  ),
  currentRepositoryPathProvider.overrideWith((Ref ref) => repositoryPath),
  gitServiceProvider.overrideWith(
    (Ref ref) =>
        repositoryPath == null ? null : _SceneGitService(repositoryPath),
  ),
];

// --- The population ----------------------------------------------------------

/// Every screen the leak checks are pointed at.
///
/// Ordered the way the navigation rail orders them, so the list reads as the
/// application does.
List<ScreenScene> screenPopulation() => <ScreenScene>[
  ScreenScene(
    name: 'shell',
    source: 'lib/core/navigation/app_shell.dart',
    build: () => const AppShell(),
    // The shell is the one scene whose expected text is chrome rather than
    // fixture data: it draws no data of its own, it draws the frame around a
    // destination. The rail labels are that frame.
    expectedTexts: const <String>['Workspaces', 'Settings'],
    overrides: () => <Override>[
      ..._baseline(config: _configuredApp),
      // The command log panel must be built for the frame to be complete;
      // it is one of the four regions of the shell's Tab cycle.
      commandLogPanelVisibleProvider.overrideWithValue(true),
      // Reads real version state through a platform channel otherwise.
      whatsNewDialogCheckedProvider.overrideWith((Ref ref) => true),
      navigationDestinationProvider.overrideWith(
        (Ref ref) => AppDestination.settings,
      ),
      projectProvider.overrideWith((Ref ref) => _SceneProjectNotifier(ref)),
      selectedProjectProvider.overrideWith(
        (Ref ref) => _SceneSelectedProjectNotifier(ref),
      ),
    ],
  ),

  ScreenScene(
    name: 'workspaces',
    source: 'lib/features/workspaces/workspaces_screen.dart',
    build: () => const WorkspacesScreen(),
    expectedTexts: const <String>['Alpha Workspace', 'Beta Workspace'],
    overrides: () => <Override>[
      ..._baseline(repositoryPath: null),
      projectProvider.overrideWith(
        (Ref ref) => _SceneProjectNotifier(ref, <Workspace>[
          _workspace('alpha', 'Alpha Workspace'),
          _workspace('beta', 'Beta Workspace'),
          _workspace('gamma', 'Gamma Workspace'),
        ]),
      ),
      selectedProjectProvider.overrideWith(
        (Ref ref) => _SceneSelectedProjectNotifier(ref),
      ),
      projectsViewModeProvider.overrideWith((Ref ref) => ProjectsViewMode.list),
    ],
  ),

  ScreenScene(
    name: 'repositories',
    source: 'lib/features/repositories/repositories_screen.dart',
    build: () => const RepositoriesScreen(),
    expectedTexts: const <String>['fixture-repo-1', 'fixture-repo-4'],
    overrides: () => <Override>[
      ..._baseline(repositoryPath: null),
      projectProvider.overrideWith((Ref ref) => _SceneProjectNotifier(ref)),
      selectedProjectProvider.overrideWith(
        (Ref ref) => _SceneSelectedProjectNotifier(ref),
      ),
      workspaceProvider.overrideWith(
        () => _SceneWorkspaceNotifier(repositoryFixtures),
      ),
      workspaceRepositoryStatusProvider.overrideWith(
        (Ref ref) => _SceneStatusNotifier(ref, <String, RepositoryStatus>{
          for (final WorkspaceRepository repo in repositoryFixtures)
            repo.path: const RepositoryStatus(exists: true, isValidGit: true),
        }),
      ),
      repositoriesViewModeProvider.overrideWith(
        (Ref ref) => RepositoriesViewMode.list,
      ),
    ],
  ),

  ScreenScene(
    name: 'changes',
    source: 'lib/features/changes/changes_screen.dart',
    build: () => const ChangesScreen(),
    expectedTexts: const <String>['alpha.md', 'beta.md'],
    overrides: () => <Override>[
      ..._baseline(),
      repositoryStatusProvider.overrideWith(
        (Ref ref) async => <FileStatus>[
          _modified('docs/alpha.md'),
          _modified('docs/beta.md'),
        ],
      ),
      currentBranchProvider.overrideWith((Ref ref) async => 'master'),
    ],
  ),

  ScreenScene(
    name: 'history',
    source: 'lib/features/history/history_screen.dart',
    build: () => const HistoryScreen(),
    expectedTexts: const <String>['the first commit', 'the second commit'],
    // The history screen is three columns and the list footer alone needs
    // some 560 logical pixels of the left one, so it is the screen that
    // decides how wide "desktop" has to be here.
    surface: const Size(2400, 1200),
    overrides: () => <Override>[
      ..._baseline(),
      commitHistoryProvider.overrideWith(
        (Ref ref) async => <GitCommit>[
          _commit(
            'a1b2c3d4e5f6a7b8',
            'the first commit',
            parents: <String>['b2c3d4e5f6a7b8c9'],
          ),
          _commit('b2c3d4e5f6a7b8c9', 'the second commit'),
        ],
      ),
      currentBranchProvider.overrideWith((Ref ref) async => 'master'),
      defaultCommitLimitProvider.overrideWith((Ref ref) => 10),
    ],
  ),

  ScreenScene(
    name: 'browse',
    source: 'lib/features/browse/browse_screen.dart',
    build: () => const BrowseScreen(),
    expectedTexts: const <String>['README.md'],
    // The one scene that reads a real directory: the file tree walks the
    // working tree through dart:io, which never completes inside a widget
    // test's fake-async zone.
    settle: SceneSettle.onRealFilesystemWork,
    overrides: () => <Override>[
      ..._baseline(repositoryPath: browseFixturePath),
      currentBranchProvider.overrideWith((Ref ref) async => 'master'),
      repositoryStatusProvider.overrideWith(
        (Ref ref) async => const <FileStatus>[],
      ),
    ],
  ),

  ScreenScene(
    name: 'branches',
    source: 'lib/features/branches/branches_screen.dart',
    build: () => const BranchesScreen(),
    expectedTexts: const <String>['feature/alpha', 'feature/beta'],
    overrides: () => <Override>[
      ..._baseline(),
      localBranchesProvider.overrideWith(
        (Ref ref) async => <GitBranch>[
          _branch('master', isCurrent: true),
          _branch('feature/alpha'),
          _branch('feature/beta'),
        ],
      ),
      remoteBranchesProvider.overrideWith(
        (Ref ref) async => const <GitBranch>[],
      ),
      currentBranchProvider.overrideWith((Ref ref) async => 'master'),
    ],
  ),

  ScreenScene(
    name: 'stashes',
    source: 'lib/features/stashes/stashes_screen.dart',
    build: () => const StashesScreen(),
    expectedTexts: const <String>['WIP on the parser', 'WIP on the toolbar'],
    overrides: () => <Override>[
      ..._baseline(),
      stashesProvider.overrideWith(
        (Ref ref) async => <GitStash>[
          _stash(0, 'WIP on the parser'),
          _stash(1, 'WIP on the toolbar'),
        ],
      ),
    ],
  ),

  ScreenScene(
    name: 'tags',
    source: 'lib/features/tags/tags_screen.dart',
    build: () => const TagsScreen(),
    expectedTexts: const <String>['v2.0.0', 'v1.0.0'],
    surface: const Size(1600, 1200),
    overrides: () => <Override>[
      ..._baseline(),
      tagsProvider.overrideWith(
        (Ref ref) async => <GitTag>[
          _tag('v1.0.0', 'aaaaaaa1111111', DateTime(2026, 1, 1)),
          _tag('v1.1.0', 'bbbbbbb2222222', DateTime(2026, 2, 1)),
          _tag('v2.0.0', 'ccccccc3333333', DateTime(2026, 3, 1)),
        ],
      ),
      localOnlyTagsProvider.overrideWith((Ref ref) async => <String>{}),
      remoteOnlyTagsProvider.overrideWith((Ref ref) async => <String>{}),
      remoteNamesProvider.overrideWith((Ref ref) async => const <String>[]),
    ],
  ),

  ScreenScene(
    name: 'settings',
    source: 'lib/features/settings/settings_screen.dart',
    build: () => const SettingsScreen(),
    // The six section headings the screen builds unconditionally
    // (settings_screen.dart:76-101), not the app-bar title.
    //
    // It used to name only 'Settings', and that string comes from
    // `StandardAppBar` - so an empty screen under the same bar passed the
    // scene's whole assertion, which was measured rather than suspected. Every
    // other scene here names fixture data and could not have gone wrong that
    // way; this is the one scene that needs no fixtures, which is exactly why
    // nobody noticed. Naming the sections means a settings form that fell back
    // to an error placeholder reddens instead of handing T1, T3 and T5 a
    // screen that is nothing but chrome.
    expectedTexts: const <String>[
      'Git Configuration',
      'Appearance',
      'Animations',
      'History',
      'Updates',
      'Config and Logs',
    ],
    // Tall enough that all six sections are laid out: the form is deliberately
    // not a lazy list (see the comment at settings_screen.dart:53), so they are
    // all built either way, but a scene that asserts what is on SCREEN should
    // be looking at a window the sections fit in.
    surface: const Size(1600, 2000),
    overrides: () => <Override>[..._baseline(config: _configuredApp)],
  ),

  ScreenScene(
    name: 'merge_conflicts',
    source: 'lib/features/merge/conflict_resolution_screen.dart',
    build: () => const ConflictResolutionScreen(),
    expectedTexts: const <String>['alpha.dart', 'beta.md'],
    overrides: () => <Override>[
      ..._baseline(),
      mergeStateProvider.overrideWith(
        (Ref ref) async => const MergeState(
          isInProgress: true,
          mergingBranch: 'feature/alpha',
          currentBranch: 'master',
          conflicts: <MergeConflict>[
            MergeConflict(
              filePath: 'lib/alpha.dart',
              type: ConflictType.bothModified,
            ),
            MergeConflict(
              filePath: 'docs/beta.md',
              type: ConflictType.deletedByThem,
            ),
          ],
        ),
      ),
    ],
  ),
];

// --- The census --------------------------------------------------------------

/// Screens in lib/ that no scene covers, each with the reason.
///
/// An entry here is a decision on the record: it says the leak checks will
/// never look at this screen, and why that is acceptable. Anything not listed
/// and not covered fails the census.
const Map<String, String> kScreensNoSceneCovers = <String, String>{
  'lib/core/screens/repository_screen.dart':
      'not a screen but the abstract base class the repository-dependent '
      'screens extend (RepositoryScreen / RepositoryScreenState). It cannot '
      'be instantiated, and everything it draws - the "no repository" empty '
      'state - is drawn through subclasses that ARE in the population.',
  'lib/features/repositories/screens/icon_comparison_screen.dart':
      'a temporary comparison sheet for choosing a repository glyph, with '
      'zero references anywhere in lib/: nothing routes to it and no user can '
      'reach it. Rendering it would measure a screen the application does not '
      'have. It should be deleted rather than covered, and when it is, this '
      'entry fails the census as stale and goes with it.',
};
