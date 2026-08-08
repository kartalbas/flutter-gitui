// The toolbar in the "workspace selected, no repository open" state at the
// owner's reported window size (870x785). The switcher area used to be capped
// at half the bar and scrolled beyond that; nothing marked the scroll, and the
// viewport cut the last switcher mid-widget into a bordered, seemingly empty
// sliver wedged against the git action icons (its render rectangle extended
// underneath them and only the paint clip hid the overlap). The switchers now
// shrink with ellipsized labels instead, so every switcher stays a whole,
// readable control and nothing is ever clipped mid-widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/navigation/app_shell.dart';
import 'package:flutter_gitui/core/navigation/navigation_item.dart';
import 'package:flutter_gitui/core/workspace/models/repository_status.dart';
import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';
import 'package:flutter_gitui/core/workspace/repository_status_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_list_provider.dart';
import 'package:flutter_gitui/core/workspace/workspace_provider.dart';
import 'package:flutter_gitui/features/repositories/providers/global_branch_provider.dart';
import 'package:flutter_gitui/features/repositories/widgets/global_branch_switcher.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_switcher.dart';
import 'package:flutter_gitui/shared/widgets/branch_switcher.dart';
import 'package:flutter_gitui/shared/widgets/overflow_action_bar.dart';
import 'package:flutter_gitui/shared/widgets/repository_switcher.dart';
import 'package:flutter_gitui/shared/widgets/workspace_switcher.dart';
import '../../skin/pump_under_skin.dart';

/// Serves the scripted repositories and swallows the last-accessed write,
/// which would otherwise reach the on-disk config from a test.
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

/// Serves settled statuses and swallows the shell's startup fetch sweep, so
/// no real git or filesystem check runs from a test.
class _FakeStatusNotifier extends RepositoryStatusNotifier {
  _FakeStatusNotifier(super.ref, Map<String, RepositoryStatus> statuses) {
    state = statuses;
  }

  @override
  Future<void> refreshAll({bool fetchRemote = false}) async {}

  @override
  Future<void> refreshStatus(
    WorkspaceRepository repository, {
    bool fetchRemote = false,
    bool allowPrompts = false,
  }) async {}
}

const _repoPaths = [
  'D:/repos/yilmaz/backend-service',
  'D:/repos/yilmaz/frontend-app',
  'D:/repos/yilmaz/shared-libs',
];

Future<void> _pumpShell(WidgetTester tester, {double width = 870}) async {
  // The default is the owner's reported window: ~870x785 logical pixels at
  // DPR 1, well above the 800px minimum window width, so the bar must lay
  // out cleanly here. The width sweep below pumps other widths.
  tester.view.physicalSize = Size(width, 785);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repositories = [
    for (final path in _repoPaths)
      WorkspaceRepository(
        path: path,
        name: path.split('/').last,
        lastAccessed: DateTime(2026),
      ),
  ];

  // The reported state: workspace "yilmaz" is selected, it owns repositories,
  // but none of them is open.
  final config = AppConfig.defaults.copyWith(
    workspace: const WorkspaceConfig(
      workspaces: [
        WorkspaceConfigEntry(
          id: 'default',
          name: 'Default',
          color: 0xFF2196F3,
          repositoryPaths: [],
          createdAt: '2026-01-01T00:00:00.000',
        ),
        WorkspaceConfigEntry(
          id: 'yilmaz',
          name: 'yilmaz',
          color: 0xFF4CAF50,
          repositoryPaths: _repoPaths,
          createdAt: '2026-01-01T00:00:00.000',
        ),
      ],
      selectedWorkspaceId: 'yilmaz',
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configProvider.overrideWith(
          (ref) => ConfigNotifier.withConfig(ref, config),
        ),
        projectProvider.overrideWith((ref) => _FakeProjectNotifier(ref)),
        workspaceProvider.overrideWith(
          () => _FakeWorkspaceNotifier(repositories),
        ),
        workspaceRepositoryStatusProvider.overrideWith(
          (ref) => _FakeStatusNotifier(ref, {
            for (final repo in repositories)
              repo.path: const RepositoryStatus(
                exists: true,
                isValidGit: true,
                currentBranch: 'develop',
              ),
          }),
        ),
        // No repository is open.
        currentRepositoryPathProvider.overrideWith((ref) => null),
        // What the real provider computes from git in this state: "master" is
        // available to switch to across the workspace repositories.
        globalBranchesProvider.overrideWith(
          (ref) => Future.value([
            GlobalBranchInfo(
              branchName: 'master',
              repositoryCount: 3,
              totalRepositories: 3,
              repositoryPaths: _repoPaths,
              repositoryNames: [
                for (final path in _repoPaths) path.split('/').last,
              ],
            ),
          ]),
        ),
        whatsNewDialogCheckedProvider.overrideWith((ref) => true),
        navigationDestinationProvider.overrideWith(
          (ref) => AppDestination.workspaces,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // This suite builds its own root on purpose - it measures the shell
        // at an exact window size - but from the moment the shell's
        // components render through the contract it still has to install the
        // skin, exactly as pump_under_skin.dart documents: a migrated
        // component below reaches its design language through SkinScope and
        // fails loudly without one.
        builder: (BuildContext context, Widget? child) =>
            installSkinUnderTest(child ?? const SizedBox.shrink()),
        home: const AppShell(),
      ),
    ),
  );

  // Let the deferred config validation and the global-branches future settle.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'at 870x785 with a workspace selected and no repository open, every '
    'switcher is a whole visible control and nothing reaches under the git '
    'actions',
    (tester) async {
      await _pumpShell(tester);
      expect(tester.takeException(), isNull);

      // The three switchers of this state are present; the branch switcher
      // hides itself because no repository is open.
      final workspaceRect = tester.getRect(find.byType(WorkspaceSwitcher));
      final repositoryRect = tester.getRect(find.byType(RepositorySwitcher));
      final globalRect = tester.getRect(find.byType(GlobalBranchSwitcher));
      expect(tester.getSize(find.byType(BranchSwitcher)).width, 0);

      // The reported "empty box" was never an empty control: the repository
      // switcher carries its no-repository label in this state.
      expect(find.text('No Repository'), findsOneWidget);

      // The switchers are no longer inside an unmarked horizontal scroll
      // viewport - the mechanism that cut the last one into a sliver.
      expect(
        find.ancestor(
          of: find.byType(WorkspaceSwitcher),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );

      // Every switcher keeps at least the width its chrome and an ellipsized
      // label need: none is squeezed into a meaningless sliver.
      for (final rect in [workspaceRect, repositoryRect, globalRect]) {
        expect(
          rect.width,
          greaterThanOrEqualTo(BaseSwitcher.minShrunkWidth),
          reason: 'a switcher was squeezed below its minimum: $rect',
        );
      }

      // Reading order holds and nothing overlaps: workspace, repository,
      // global branch, then the git actions, all inside the window.
      final gitBarRect = tester.getRect(find.byType(OverflowActionBar).first);
      expect(workspaceRect.right, lessThanOrEqualTo(repositoryRect.left));
      expect(repositoryRect.right, lessThanOrEqualTo(globalRect.left));
      expect(
        globalRect.right,
        lessThanOrEqualTo(gitBarRect.left),
        reason:
            'a switcher extends under the git actions - the geometry the '
            'owner reported as overlapping controls',
      );
      expect(gitBarRect.right, lessThanOrEqualTo(870));

      // The git actions stay reachable: whatever did not fit as an icon is in
      // the overflow menu, so the bar always renders at least that button.
      expect(
        gitBarRect.width,
        greaterThanOrEqualTo(OverflowActionBar.menuExtent),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'from the 800px minimum window upward the toolbar never overflows and no '
    'visible switcher falls below its minimum width',
    (tester) async {
      // The sweep that would have caught the original defect: at every width
      // from the minimum window upward the bar lays out without a single
      // overflow, every visible switcher keeps at least the width its chrome
      // and an ellipsized label need, and the git actions always render at
      // least their overflow menu button inside the window.
      for (final width in const [
        800.0,
        820.0,
        850.0,
        870.0,
        900.0,
        950.0,
        1000.0,
        1100.0,
        1280.0,
        1600.0,
      ]) {
        await _pumpShell(tester, width: width);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the toolbar overflowed at a window width of $width',
        );

        final switchers = {
          'workspace': find.byType(WorkspaceSwitcher),
          'repository': find.byType(RepositorySwitcher),
          'branch': find.byType(BranchSwitcher),
          'global branch': find.byType(GlobalBranchSwitcher),
        };
        for (final entry in switchers.entries) {
          final switcherWidth = tester.getSize(entry.value).width;
          // A switcher that hides itself takes no space; every visible one
          // keeps its minimum instead of being squeezed into a sliver.
          if (switcherWidth == 0) continue;
          expect(
            switcherWidth,
            greaterThanOrEqualTo(BaseSwitcher.minShrunkWidth),
            reason:
                'the ${entry.key} switcher fell below its minimum at a '
                'window width of $width',
          );
        }

        final gitBarRect = tester.getRect(find.byType(OverflowActionBar).first);
        expect(
          gitBarRect.width,
          greaterThanOrEqualTo(OverflowActionBar.menuExtent),
          reason:
              'the git actions lost even their overflow menu button at a '
              'window width of $width',
        );
        expect(
          gitBarRect.right,
          lessThanOrEqualTo(width),
          reason:
              'the git actions reach past the window at a window width of '
              '$width',
        );
      }
    },
  );
}
