import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        DialogExtent,
        DialogRouteSpec,
        IconRole,
        Inset,
        Overlays,
        Proximity,
        TextRole,
        Tone;
import 'package:riverpod/legacy.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/command_log_panel.dart';
import '../../shared/widgets/workspace_switcher.dart';
import '../../shared/widgets/repository_switcher.dart';
import '../../shared/widgets/branch_switcher.dart';
import '../../shared/widgets/quick_settings_menu.dart';
import '../../features/repositories/widgets/global_branch_switcher.dart';
import '../../shared/widgets/language_selector.dart';
import '../../shared/widgets/progress_overlay.dart';
import '../../shared/widgets/overflow_action_bar.dart';
import '../../shared/widgets/base_focus_region.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_badge.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_shrinking_row.dart';
import '../../shared/components/base_switcher.dart';
import '../git/git_providers.dart';
import '../config/config_providers.dart';
import '../services/notification_service.dart';
import '../../shared/dialogs/repository_switcher_dialog.dart';
import '../workspace/repository_status_provider.dart';
import '../workspace/workspace_provider.dart';
import '../workspace/models/repository_status.dart';
import '../workspace/models/workspace_repository.dart';
import 'navigation_item.dart';
import '../../features/repositories/git_action_targets.dart';
import '../../features/repositories/repository_multi_select_provider.dart';
import '../../features/repositories/repository_batch_error_provider.dart';
import '../../features/repositories/services/batch_operations_service.dart';
import '../../features/repositories/dialogs/batch_operation_progress_dialog.dart';
import '../../features/repositories/dialogs/create_branch_dialog.dart';
import '../../features/repositories/dialogs/create_pull_request_dialog.dart';
import '../../shared/dialogs/merge_branches_dialog.dart';
import '../../shared/dialogs/clone_repository_dialog.dart';
import '../git/git_service.dart';
import '../git/git_platform_service.dart';
import '../git/models/branch.dart';
import 'command_palette.dart';
import 'git_commands.dart';
import '../../features/workspaces/workspaces_screen.dart';
import '../../features/repositories/repositories_screen.dart';
import '../../features/changes/changes_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/branches/branches_screen.dart';
import '../../features/stashes/stashes_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/changelog/changelog_dialog.dart';
import '../../shared/dialogs/update_available_dialog.dart';
import '../services/update_providers.dart';
import '../services/update_service.dart';
import '../../features/about/about_dialog.dart';
import '../../shared/components/base_layout.dart';

/// Provider to track if "What's New" dialog has been checked this session
/// This persists across widget rebuilds to prevent showing dialog multiple times
final whatsNewDialogCheckedProvider = StateProvider<bool>((ref) => false);

/// Localized label for a missing required setting
String _requiredSettingLabel(AppLocalizations l10n, RequiredSetting setting) {
  switch (setting) {
    case RequiredSetting.gitExecutablePath:
      return l10n.gitExecutablePath;
    case RequiredSetting.textEditor:
      return l10n.textEditor;
    case RequiredSetting.diffTool:
      return l10n.diffTool;
    case RequiredSetting.mergeTool:
      return l10n.mergeTool;
    case RequiredSetting.userName:
      return l10n.userName;
    case RequiredSetting.userEmail:
      return l10n.userEmail;
  }
}

/// App shell with navigation rail and main content area
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Width the utility actions need to all show as icons: command palette,
/// command log, and the update button when one is pending.
const int _utilityActionCount = 3;
const double _utilityActionBarWidth =
    _utilityActionCount * OverflowActionBar.itemExtent +
    (_utilityActionCount - 1) * OverflowActionBar.spacing;

class _AppShellState extends ConsumerState<AppShell> {
  bool _hasCheckedSettings = false;
  bool _hasShownConfigLoadWarning = false;
  bool _hasShownGitPathWarning = false;
  bool _whatsNewScheduled = false;
  bool _startupFetchSweepStarted = false;
  Timer? _autoFetchTimer;
  Duration? _autoFetchPeriod;

  @override
  void dispose() {
    _autoFetchTimer?.cancel();
    super.dispose();
  }

  /// Keeps the background fetch timer in sync with the behavior settings.
  ///
  /// The active period is remembered because the shell rebuilds constantly and
  /// restarting the timer on every rebuild would keep pushing the next fetch
  /// out of reach, so auto-fetch would never actually fire.
  void _syncAutoFetchTimer(bool enabled, int intervalMinutes) {
    final period = enabled && intervalMinutes > 0
        ? Duration(minutes: intervalMinutes)
        : null;
    if (period == _autoFetchPeriod) return;
    _autoFetchPeriod = period;
    _autoFetchTimer?.cancel();
    _autoFetchTimer = period == null
        ? null
        : Timer.periodic(period, (_) => _fetchWorkspaceInBackground());
  }

  /// Contacts every workspace repository's remote and refreshes the cards.
  ///
  /// The ahead/behind counts come from the local remote-tracking refs, so
  /// without this sweep a repository that has incoming commits still reports
  /// zero behind and its card claims to be in sync. Fetching only the active
  /// repository, as this used to, left every other card unverified.
  ///
  /// Runs quietly: an unreachable remote or a repository needing credentials
  /// must not raise anything the user did not ask for. Those repositories stay
  /// marked unverified instead of falsely reporting to be in sync.
  Future<void> _fetchWorkspaceInBackground() async {
    try {
      await ref
          .read(workspaceRepositoryStatusProvider.notifier)
          .refreshAll(fetchRemote: true);
    } catch (_) {
      // Deliberately silent; see above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(navigationDestinationProvider);
    final configLoading = ref.watch(configLoadingProvider);
    final configLoadFailed = ref.watch(configLoadFailureProvider);
    final gitPathInvalid = ref.watch(gitPathInvalidProvider);
    final allSettingsConfigured = ref.watch(
      allRequiredSettingsConfiguredProvider,
    );
    final missingSettings = ref.watch(missingRequiredSettingsProvider);
    final isRailExtended = ref.watch(navigationRailExtendedProvider);
    final whatsNewChecked = ref.watch(whatsNewDialogCheckedProvider);

    // IMPORTANT: Initialize workspaceRepositoryStatusProvider EARLY
    // This ensures the listener is set up BEFORE config finishes loading
    // so it can catch the config loading state change and trigger refreshAll()
    ref.watch(workspaceRepositoryStatusProvider);

    // IMPORTANT: Only enable repository watcher AFTER config is fully loaded
    // This prevents race condition where status checks start before git path is configured
    if (!configLoading) {
      // The single live file-system watcher, on the active repository only
      // (issue #312). It refreshes the active repository's detailed views and
      // its workspace-list badge; background repositories are no longer watched.
      ref.watch(repositoryWatcherProvider);

      // Verify the cards against the remotes once the configuration is usable.
      // Until this lands, every repository's sync state is only as fresh as its
      // last fetch, so the cards report unverified rather than in sync.
      if (!_startupFetchSweepStarted) {
        _startupFetchSweepStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchWorkspaceInBackground();
        });
      }

      // Auto-fetch is a background behavior of the whole app, so it is driven
      // from the shell instead of a screen that may not be open.
      _syncAutoFetchTimer(
        ref.watch(autoFetchProvider),
        ref.watch(autoFetchIntervalProvider),
      );
    }

    // Auto-navigate to settings if required settings are missing
    // Only check after config has finished loading (only check once)
    if (!_hasCheckedSettings && !configLoading && !allSettingsConfigured) {
      _hasCheckedSettings = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (destination != AppDestination.settings) {
          ref.read(navigationDestinationProvider.notifier).state =
              AppDestination.settings;
        }
      });
    }

    // Show warning if config failed to load
    if (!_hasShownConfigLoadWarning && !configLoading && configLoadFailed) {
      _hasShownConfigLoadWarning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Configuration could not be loaded. Using default settings.',
          );
        }
      });
    }

    // Show warning if git path is invalid
    if (!_hasShownGitPathWarning && !configLoading && gitPathInvalid) {
      _hasShownGitPathWarning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Git executable path is invalid or git is not installed. Please configure git in Settings.',
          );
        }
      });
    }

    // Show "What's New" dialog on app upgrade
    // IMPORTANT: Only trigger the check ONCE per app session using global provider
    // This persists across widget rebuilds, preventing dialog from showing multiple times
    // The actual check of whether to show is done by VersionService.shouldShowWhatsNew()
    // NOTE: We don't require allSettingsConfigured here because users should see release
    // notes even if they haven't finished setting up the app yet
    if (!whatsNewChecked && !_whatsNewScheduled && !configLoading) {
      // Latch synchronously: the provider is only updated inside the callback below,
      // so further rebuilds in the same frame would each queue another callback
      _whatsNewScheduled = true;
      // Mark as checked and show dialog AFTER build phase to prevent state modification error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(whatsNewDialogCheckedProvider.notifier).state = true;
        ChangelogDialog.showIfNeeded(context, ref);
      });
    }

    // An available update never announces itself with a popup: installing it
    // closes the application, so the user picks the moment (#294). The quiet
    // toolbar indicator below is the only signal.
    final updateAvailable = ref.watch(updateAvailableProvider);

    // Get currently selected repository path
    final currentRepoPath = ref.watch(currentRepositoryPathProvider);

    // One resolution drives both the git buttons' enabled state and their
    // handlers, so the toolbar can never promise a target set the handlers
    // would not act on (#303).
    final gitActionTargets = GitActionTargets(
      selectedPaths: ref.watch(repositoryMultiSelectProvider),
      currentRepositoryPath: currentRepoPath,
    );

    // Get status of selected repository (if any)
    final selectedRepoStatus = currentRepoPath != null
        ? ref.watch(repositoryStatusByPathProvider(currentRepoPath))
        : null;

    // The host carries the shell's keyboard frame: the four regions below
    // (rail, toolbar, content, command log) form one Tab cycle in that order,
    // F6 / Shift+F6 jump between them as panes, and the host's anchor node is
    // the shortcut anchor and focus of last resort. The anchor replaces the
    // Focus(autofocus: true) wrapper that used to sit here: as an ancestor it
    // registered its autofocus before any screen's and always won the race,
    // so a screen's own claim was silently discarded. The host claims focus
    // only after the autofocus pipeline settled with nothing focused, and its
    // node is skipTraversal, so it is never a Tab stop.
    //
    // sanctioned-shortcuts: the shell's global chord map is the app's one
    // legitimate raw shortcut surface (#382). Every binding _buildShortcuts
    // returns is a Ctrl/Meta chord, which no editable and no navigable
    // collection interprets, so it can never shadow text input or the shared
    // navigation semantics.
    return CallbackShortcuts(
      bindings: _buildShortcuts(),
      child: BaseFocusRegionHost(
        debugLabel: 'AppShell.anchor',
        child: Scaffold(
          body: Stack(
            children: [
              Row(
                children: [
                  // Navigation Rail
                  BaseFocusRegion(
                    order: 1,
                    debugLabel: 'AppShell.railRegion',
                    child: NavigationRail(
                      extended: isRailExtended,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                      selectedIndex: destination.index,
                      onDestinationSelected: (index) {
                        ref.read(navigationDestinationProvider.notifier).state =
                            AppDestination.values[index];
                      },
                      leading: Column(
                        children: [
                          const BaseGap(Proximity.grouped),
                          // App logo/title - double-tap to show About dialog
                          GestureDetector(
                            onDoubleTap: () {
                              Overlays.dialogFrom<void>(
                                context,
                                route: const DialogRouteSpec(
                                  // The dialog's own literal: the product
                                  // name is not translated.
                                  title: 'About Flutter GitUI',
                                ),
                                builder: (_) => const AppAboutDialog(),
                              );
                            },
                            child: Column(
                              children: [
                                // The application's brand mark, and a survivor
                                // three times over: the Bold stroke is a
                                // weight `IconRole` cannot carry (C3), 32 px
                                // is beyond every `ControlScale` rung
                                // (`prominent` is 24), and the accent is the
                                // brand's own statement rather than a row's.
                                // The rail is shell chrome; the mark converts
                                // with `chrome.shell` as one piece.
                                Icon(
                                  PhosphorIconsBold.gitBranch,
                                  size: AppTheme.iconXL,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                if (isRailExtended) ...[
                                  const BaseGap(Proximity.related),
                                  BaseLabel(
                                    AppLocalizations.of(context)!.appTitle,
                                    role: TextRole.sectionTitle,
                                    tone: Tone.accent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const BaseGap(Proximity.separate),
                        ],
                      ),
                      // The collapse control sits at the foot of the rail.
                      // Its bottom padding was a one-sided inset, which is a
                      // gap wearing a padding idiom: the distance belongs
                      // between the control and the rail's own edge, so the
                      // column states it after the control rather than the
                      // control carrying a side.
                      trailing: Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            BaseIconButton(
                              icon: isRailExtended
                                  ? IconRole.caretLeft
                                  : IconRole.caretRight,
                              onPressed: () {
                                ref
                                    .read(configProvider.notifier)
                                    .setNavigationRailExtended(!isRailExtended);
                              },
                              tooltip: isRailExtended
                                  ? AppLocalizations.of(context)!.collapse
                                  : AppLocalizations.of(context)!.expand,
                            ),
                            const BaseGap(Proximity.grouped),
                          ],
                        ),
                      ),
                      destinations: AppDestination.values.map((dest) {
                        // Show badges ONLY for selected repository
                        int? badgeCount;
                        if (selectedRepoStatus != null &&
                            !selectedRepoStatus.isLoading) {
                          // Only show badges when a repository is selected
                          if (dest == AppDestination.changes &&
                              selectedRepoStatus.hasUncommittedChanges) {
                            // Show actual count of changed files (staged + unstaged)
                            final allStatuses =
                                ref.watch(repositoryStatusProvider).value ?? [];
                            badgeCount = allStatuses.length;
                            // Don't show badge if count is 0
                            if (badgeCount == 0) badgeCount = null;
                          } else if (dest == AppDestination.stashes) {
                            // Show stash count badge
                            badgeCount = ref.watch(stashCountProvider);
                            // Don't show badge if count is 0
                            if (badgeCount == 0) badgeCount = null;
                          }
                        }

                        return NavigationRailDestination(
                          icon: _buildIconWithBadge(
                            context,
                            Icon(dest.icon),
                            badgeCount,
                          ),
                          selectedIcon: _buildIconWithBadge(
                            context,
                            Icon(dest.iconSelected),
                            badgeCount,
                          ),
                          // Deliberately a bare Text, not a BaseLabel, and
                          // **this moves a rendered size**: the rail styles
                          // its own labels with `labelMedium`, so each
                          // destination now draws at 12 px where the
                          // `BodyMediumLabel` that used to be here pinned 13
                          // (measured under both application themes; the
                          // tracking and line height move with it, 0.5/1.33
                          // against 0.25/1.43). That is the correct owner
                          // answering: the rail lerps this slot between its
                          // unselected and selected styles, so the text is
                          // part of a larger member and belongs to the shell
                          // chrome's own conversion at P4 - the same carve-out
                          // BaseLabel's doc names for a button's words. Until
                          // then, six destinations render one rung smaller,
                          // which is a declared consequence of handing the
                          // slot back rather than an oversight. A role-styled
                          // label here also re-lays out under the animating
                          // inherited colour and trips Flutter's paint-only
                          // fast path (TextPainter.paint,
                          // assert(debugSize == size)), which is how the
                          // misplacement was found.
                          label: Text(dest.label(context)),
                        );
                      }).toList(),
                    ),
                  ),

                  // Not `BaseSeparator`: the rail's edge rule at `width: 1`
                  // is a measurement - the rule takes no layout space, so the
                  // panes meet - which the separator member deliberately does
                  // not carry. It leaves with the shell chrome.
                  const VerticalDivider(thickness: 1, width: 1),

                  // Main content area
                  Expanded(
                    child: Column(
                      children: [
                        // Top bar with command log toggle
                        BaseFocusRegion(
                          order: 2,
                          debugLabel: 'AppShell.toolbarRegion',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            // Measured, because how much room the git actions may
                            // claim before collapsing into their overflow menu
                            // depends on the window width.
                            child: BaseInset(
                              x: Inset.normal,
                              y: Inset.tight,
                              child: LayoutBuilder(
                                builder: (context, constraints) => Row(
                                  children: [
                                    // The switchers and the git actions share
                                    // what the right-hand cluster leaves over.
                                    // Their split is measured rather than
                                    // flexed: an equal flex split hands each
                                    // side a quota regardless of need, which
                                    // squeezed every switcher into a bordered
                                    // sliver while the git icons kept room they
                                    // could have yielded to their overflow menu.
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, inner) => Row(
                                          children: [
                                            // The switchers get the width they
                                            // need before the git actions claim
                                            // any: they name the workspace,
                                            // repository and branch every other
                                            // control acts on, and a clipped
                                            // name says nothing, whereas an
                                            // action that no longer fits stays
                                            // reachable in its overflow menu.
                                            // Their ceiling reserves that menu's
                                            // button, so the actions can never
                                            // be squeezed out entirely. Within
                                            // the ceiling each switcher shrinks
                                            // to an ellipsized label - never
                                            // below the width its fixed chrome
                                            // needs - instead of the group
                                            // scrolling, which used to cut the
                                            // last switcher mid-widget into a
                                            // seemingly empty sliver whose
                                            // render box reached under the git
                                            // actions.
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth:
                                                    (inner.maxWidth -
                                                            AppTheme.paddingM -
                                                            OverflowActionBar
                                                                .menuExtent)
                                                        .clamp(
                                                          0.0,
                                                          inner.maxWidth,
                                                        ),
                                              ),
                                              child: const BaseShrinkingRow(
                                                spacing: AppTheme.paddingM,
                                                minChildWidth:
                                                    BaseSwitcher.minShrunkWidth,
                                                children: [
                                                  WorkspaceSwitcher(),
                                                  RepositorySwitcher(),
                                                  BranchSwitcher(),
                                                  GlobalBranchSwitcher(),
                                                ],
                                              ),
                                            ),
                                            const BaseGap(Proximity.grouped),
                                            // The git actions stay rendered
                                            // without a target and grey out with
                                            // a reason, so the toolbar never
                                            // shows an unexplained gap (#303).
                                            //
                                            // Expanded, so they take exactly
                                            // what the switchers leave - at
                                            // least their overflow menu button,
                                            // by the ceiling above - and hand
                                            // whatever no longer fits to that
                                            // menu. Aligned left so the group
                                            // stays attached to the switchers
                                            // it operates on.
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: OverflowActionBar(
                                                  actions: _buildGitActions(
                                                    context,
                                                    ref,
                                                    gitActionTargets,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const BaseGap(Proximity.related),
                                    // Capped like the git actions, so the utility
                                    // icons collapse into their own overflow menu
                                    // instead of claiming full width and pushing
                                    // the switchers off the bar (#359). Without a
                                    // cap this group is the only one that never
                                    // yields, and the row overflows.
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: (constraints.maxWidth * 0.25)
                                            .clamp(
                                              // Never below the overflow button
                                              // itself, or the bar cannot even
                                              // draw the menu it collapsed into.
                                              OverflowActionBar.menuExtent,
                                              _utilityActionBarWidth,
                                            ),
                                      ),
                                      child: OverflowActionBar(
                                        actions: _buildUtilityActions(
                                          context,
                                          ref,
                                          updateAvailable,
                                        ),
                                      ),
                                    ),
                                    const BaseGap(Proximity.related),
                                    // These two stay put: each is a popup menu of
                                    // its own rather than an action with a single
                                    // callback, so neither can be folded into the
                                    // overflow menu above. They are also the
                                    // narrowest controls in the bar.
                                    const QuickSettingsMenu(),
                                    const BaseGap(Proximity.related),
                                    const LanguageSelector(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The warning banner and the active screen form the
                        // content region together: the banner is part of what
                        // the user is working on, not part of the toolbar, so
                        // Tab and F6 treat them as one pane.
                        Expanded(
                          child: BaseFocusRegion(
                            order: 3,
                            debugLabel: 'AppShell.contentRegion',
                            child: Column(
                              children: [
                                // Warning banner for missing settings
                                if (!allSettingsConfigured)
                                  Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    // The banner paints its own fill, so it
                                    // states the foreground that pairs with
                                    // it once, here, instead of each label
                                    // inside restating it. Left unstated the
                                    // two labels would inherit the page's
                                    // `onSurface` and paint it over an error
                                    // container.
                                    child: BaseInset(
                                      all: Inset.normal,
                                      child: DefaultTextStyle.merge(
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                        ),
                                        child: Row(
                                          children: [
                                            // Survives with the banner it
                                            // sits in: the Bold stroke is a
                                            // weight `IconRole` cannot carry
                                            // (C3), and the banner painting
                                            // its own `errorContainer` fill
                                            // is a notice surface - fill,
                                            // paired foreground and mark all
                                            // leave together when it becomes
                                            // the notice member in P5.
                                            Icon(
                                              PhosphorIconsBold.warning,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            const BaseGap(Proximity.grouped),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  BaseLabel(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.requiredSettingsMissing,
                                                    role: TextRole.sectionTitle,
                                                  ),
                                                  const BaseGap(
                                                    Proximity.hairline,
                                                  ),
                                                  BaseLabel(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.pleaseConfigureSettings(
                                                      missingSettings
                                                          .map(
                                                            (
                                                              s,
                                                            ) => _requiredSettingLabel(
                                                              AppLocalizations.of(
                                                                context,
                                                              )!,
                                                              s,
                                                            ),
                                                          )
                                                          .join(', '),
                                                    ),
                                                    role: TextRole.detail,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (destination !=
                                                AppDestination.settings)
                                              BaseButton(
                                                label: AppLocalizations.of(
                                                  context,
                                                )!.goToSettings,
                                                variant: ButtonVariant.danger,
                                                onPressed: () {
                                                  ref
                                                      .read(
                                                        navigationDestinationProvider
                                                            .notifier,
                                                      )
                                                      .state = AppDestination
                                                      .settings;
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                // Content
                                Expanded(child: _buildContent(destination)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Command Log Panel
                  const BaseFocusRegion(
                    order: 4,
                    debugLabel: 'AppShell.commandLogRegion',
                    child: CommandLogPanel(),
                  ),
                ],
              ),

              // Global progress overlay
              const ProgressOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build keyboard shortcuts
  Map<ShortcutActivator, VoidCallback> _buildShortcuts() {
    final bindings = <ShortcutActivator, VoidCallback>{};

    // Control and Meta are both bound so the shortcuts follow the Command-key
    // convention on macOS without losing the Ctrl-based bindings that Windows
    // and Linux users expect.
    void bind(LogicalKeyboardKey key, VoidCallback callback) {
      bindings[SingleActivator(key, control: true)] = callback;
      bindings[SingleActivator(key, meta: true)] = callback;
    }

    // Command Palette
    bind(LogicalKeyboardKey.keyK, () {
      _showCommandPalette(context);
    });

    // Toggle Command Log
    bind(LogicalKeyboardKey.keyL, () {
      ref
          .read(configProvider.notifier)
          .setCommandLogPanelVisible(!ref.read(commandLogPanelVisibleProvider));
    });

    // Repository Switcher
    bind(LogicalKeyboardKey.keyR, () {
      _showRepositorySwitcher(context);
    });

    // Navigation shortcuts
    bind(LogicalKeyboardKey.digit1, () {
      _navigateTo(AppDestination.workspaces);
    });
    bind(LogicalKeyboardKey.digit2, () {
      _navigateTo(AppDestination.repositories);
    });
    bind(LogicalKeyboardKey.digit3, () {
      _navigateTo(AppDestination.changes);
    });
    bind(LogicalKeyboardKey.digit4, () {
      _navigateTo(AppDestination.history);
    });
    bind(LogicalKeyboardKey.digit5, () {
      _navigateTo(AppDestination.browse);
    });
    bind(LogicalKeyboardKey.digit6, () {
      _navigateTo(AppDestination.branches);
    });
    bind(LogicalKeyboardKey.digit7, () {
      _navigateTo(AppDestination.stashes);
    });
    bind(LogicalKeyboardKey.digit8, () {
      _navigateTo(AppDestination.tags);
    });
    bind(LogicalKeyboardKey.comma, () {
      _navigateTo(AppDestination.settings);
    });

    return bindings;
  }

  /// Navigate to destination
  void _navigateTo(AppDestination destination) {
    ref.read(navigationDestinationProvider.notifier).state = destination;
  }

  /// Show command palette
  void _showCommandPalette(BuildContext context) async {
    // The palette's own context and ref die with the sheet, so it returns the
    // chosen command and we execute it here with this State's long-lived ones.
    final command = await Overlays.dialogFrom<GitCommand>(
      context,
      // A palette takes the application away until the user answers and then
      // reports the answer - which is a dialog, and a browser-extent one: a
      // searchable list is a thing to look through. The sheet it used to
      // arrive in, transparent-backed and scroll-controlled, was Material's
      // shape for that stated in application code (#412).
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.commandPalette,
        extent: DialogExtent.browser,
      ),
      builder: (context) => const CommandPalette(),
    );
    if (command == null || !mounted) return;
    command.onExecute(this.context, ref);
  }

  /// Show repository switcher dialog
  void _showRepositorySwitcher(BuildContext context) {
    Overlays.dialogFrom<void>(
      context,
      route: DialogRouteSpec(
        title: AppLocalizations.of(context)!.switchRepository,
      ),
      builder: (context) => const RepositorySwitcherDialog(),
    );
  }

  /// Build content for current destination
  Widget _buildContent(AppDestination destination) {
    switch (destination) {
      case AppDestination.workspaces:
        return const WorkspacesScreen();
      case AppDestination.repositories:
        return const RepositoriesScreen();
      case AppDestination.changes:
        return const ChangesScreen();
      case AppDestination.history:
        return const HistoryScreen();
      case AppDestination.browse:
        return const BrowseScreen();
      case AppDestination.branches:
        return const BranchesScreen();
      case AppDestination.stashes:
        return const StashesScreen();
      case AppDestination.tags:
        return const TagsScreen();
      case AppDestination.settings:
        return const SettingsScreen();
    }
  }

  /// Build an icon with an optional badge
  Widget _buildIconWithBadge(BuildContext context, Widget icon, int? count) {
    if (count == null || count == 0) {
      return icon;
    }

    return BaseIconBadge(
      count: count,
      variant: BadgeVariant.danger,
      child: icon,
    );
  }

  /// Tooltip for a toolbar git action: its label while it can run, otherwise
  /// the reason it cannot, so a disabled button explains itself instead of
  /// leaving the user guessing why nothing happens (#303).
  String _gitActionTooltip(
    BuildContext context,
    GitActionBlock? block, {
    required String enabledLabel,
    String? unsupportedSelectionLabel,
  }) {
    switch (block) {
      case null:
        return enabledLabel;
      case GitActionBlock.noRepository:
        return AppLocalizations.of(context)!.openRepositoryToContinue;
      case GitActionBlock.unsupportedSelection:
        return unsupportedSelectionLabel ?? enabledLabel;
    }
  }

  /// The toolbar's utility actions, in the order they appear.
  ///
  /// Data rather than widgets for the same reason the git actions are: the bar
  /// decides which of them fit as icons and hands the rest to its overflow
  /// menu. Keeping them collapsible is what stops this group from being the
  /// one that never yields and pushes the switchers off the bar (#359).
  ///
  /// The quick settings and language menus are deliberately not here. Each is
  /// a popup menu of its own rather than an action with a single callback, so
  /// neither can be represented as a [ToolbarAction].
  List<ToolbarAction> _buildUtilityActions(
    BuildContext context,
    WidgetRef ref,
    UpdateInfo? updateAvailable,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return [
      ToolbarAction(
        icon: IconRole.magnifyingGlass,
        label: l10n.commandPaletteTooltip,
        tooltip: l10n.commandPaletteTooltip,
        onPressed: () => _showCommandPalette(context),
      ),
      ToolbarAction(
        icon: IconRole.terminal,
        label: l10n.toggleCommandLogTooltip,
        tooltip: l10n.toggleCommandLogTooltip,
        onPressed: () {
          ref
              .read(configProvider.notifier)
              .setCommandLogPanelVisible(
                !ref.read(commandLogPanelVisibleProvider),
              );
        },
      ),
      // A standing signal that an update is ready rather than a command, so it
      // keeps the primary emphasis it had as a standalone button.
      //
      // The mark is its own role and not `IconRole.downloadSimple`, which the
      // "Clone repository" action in the same toolbar row names
      // (`_buildGitActions` below). Both were written as `downloadSimple`
      // before the conversion, but this one was drawn SOLID and that one as
      // an outline, so collapsing them onto one role would have left the two
      // buttons pixel-identical and the emphasis carrying the whole
      // difference. The application says which MEANING this is; how loud the
      // mark for it is stays the skin's answer.
      if (updateAvailable != null)
        ToolbarAction(
          icon: IconRole.updateAvailable,
          label: l10n.updateReadyTooltip(updateAvailable.version),
          tooltip: l10n.updateReadyTooltip(updateAvailable.version),
          variant: ButtonVariant.primary,
          onPressed: () {
            Overlays.dialogFrom<void>(
              context,
              route: DialogRouteSpec(
                title: l10n.updateAvailableTitle,
                barrierDismissible: false,
              ),
              builder: (_) =>
                  UpdateAvailableDialog(updateInfo: updateAvailable),
            );
          },
        ),
    ];
  }

  /// Build a git operation button
  /// The toolbar's git actions, in the order they appear.
  ///
  /// Built as data rather than as widgets so the bar can decide which of them
  /// fit as icons and hand the rest to its overflow menu, where each carries
  /// its name. They stay listed even when unavailable: the tooltip then says
  /// why, which an omitted button could not (#303).
  List<ToolbarAction> _buildGitActions(
    BuildContext context,
    WidgetRef ref,
    GitActionTargets gitActionTargets,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final batchBlock = gitActionTargets.batchActionBlock;

    return [
      ToolbarAction(
        icon: IconRole.downloadSimple,
        label: l10n.cloneRepository,
        tooltip: l10n.cloneRepository,
        // Cloning brings a repository in rather than acting on one, so unlike
        // its neighbours it needs no target and is never blocked.
        onPressed: () => Overlays.dialogFrom(
          context,
          route: DialogRouteSpec(
            title: AppLocalizations.of(context)!.cloneRepository,
          ),
          builder: (context) => const CloneRepositoryDialog(),
        ),
      ),
      ToolbarAction(
        icon: IconRole.gitBranch,
        label: l10n.createBranch,
        tooltip: _gitActionTooltip(
          context,
          batchBlock,
          enabledLabel: l10n.createBranch,
        ),
        onPressed: batchBlock == null ? () => _performCreateBranch(ref) : null,
      ),
      ToolbarAction(
        icon: IconRole.gitPullRequest,
        label: l10n.createPr,
        tooltip: _gitActionTooltip(
          context,
          gitActionTargets.createPrBlock,
          enabledLabel: l10n.createPr,
          unsupportedSelectionLabel: l10n.selectOnlyOneRepoForPr,
        ),
        onPressed: gitActionTargets.createPrBlock == null
            ? () => _performCreatePR(ref)
            : null,
      ),
      ToolbarAction(
        icon: IconRole.gitMerge,
        label: l10n.mergeBranches,
        tooltip: _gitActionTooltip(
          context,
          gitActionTargets.mergeBlock,
          enabledLabel: l10n.mergeBranches,
          unsupportedSelectionLabel: l10n.mergeCurrentRepositoryOnly,
        ),
        onPressed: gitActionTargets.mergeBlock == null
            ? () => _performMergeBranches(context)
            : null,
      ),
      ToolbarAction(
        icon: IconRole.arrowClockwise,
        label: l10n.fetch,
        tooltip: _gitActionTooltip(
          context,
          batchBlock,
          enabledLabel: l10n.fetch,
        ),
        onPressed: batchBlock == null ? () => _performFetch(ref) : null,
      ),
      ToolbarAction(
        icon: IconRole.arrowDown,
        label: l10n.pull,
        tooltip: _gitActionTooltip(
          context,
          batchBlock,
          enabledLabel: l10n.pull,
        ),
        onPressed: batchBlock == null ? () => _performPull(ref) : null,
      ),
      ToolbarAction(
        icon: IconRole.arrowUp,
        label: l10n.push,
        tooltip: _gitActionTooltip(
          context,
          batchBlock,
          enabledLabel: l10n.push,
        ),
        onPressed: batchBlock == null ? () => _performPush(ref) : null,
      ),
    ];
  }

  /// Resolves the repositories the toolbar git actions act on through
  /// [GitActionTargets], so the handlers target exactly the set the buttons
  /// advertised when they were enabled.
  List<WorkspaceRepository> _resolveGitActionRepositories() {
    final allRepositories = ref.read(workspaceProvider);
    final targetPaths = GitActionTargets(
      selectedPaths: ref.read(repositoryMultiSelectProvider),
      currentRepositoryPath: ref.read(currentRepositoryPathProvider),
    ).effectivePaths.toSet();
    // Workspace entries carry the display metadata, so known paths resolve
    // to them in workspace order; the current repository can be open without
    // being registered, which is why leftover paths get an ad-hoc entry.
    final targets = allRepositories
        .where((repo) => targetPaths.contains(repo.path))
        .toList();
    final knownPaths = targets.map((repo) => repo.path).toSet();
    targets.addAll(
      targetPaths
          .where((path) => !knownPaths.contains(path))
          .map(WorkspaceRepository.fromPath),
    );
    return targets;
  }

  /// Perform fetch operation
  Future<void> _performFetch(WidgetRef ref) async {
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final repositoriesToFetch = _resolveGitActionRepositories();
    if (repositoriesToFetch.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToFetch) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(
      gitExecutablePath: gitExecutablePath,
    );

    final results = await showBatchOperationProgressDialog(
      context,
      title:
          'Fetch ${repositoriesToFetch.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToFetch,
      operation: (onProgress) => service.fetchAll(
        repositoriesToFetch,
        statuses,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }

      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Fetched successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }
    }
  }

  /// Perform pull operation
  Future<void> _performPull(WidgetRef ref) async {
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final repositoriesToPull = _resolveGitActionRepositories();
    if (repositoriesToPull.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToPull) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(
      gitExecutablePath: gitExecutablePath,
    );

    final results = await showBatchOperationProgressDialog(
      context,
      title:
          'Pull ${repositoriesToPull.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToPull,
      operation: (onProgress) =>
          service.pullAll(repositoriesToPull, statuses, onProgress: onProgress),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Pulled successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform push operation
  Future<void> _performPush(WidgetRef ref) async {
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final repositoriesToPush = _resolveGitActionRepositories();
    if (repositoriesToPush.isEmpty) return;

    // Get statuses for all repositories
    final statusesMap = ref.read(workspaceRepositoryStatusProvider);
    final statuses = <String, RepositoryStatus>{};
    for (final repo in repositoriesToPush) {
      final status = statusesMap[repo.path];
      if (status != null) {
        statuses[repo.path] = status;
      }
    }

    if (!context.mounted) return;

    // The toolbar button pushes every selected repository at once, which is the
    // operation the confirm-push setting is meant to guard.
    if (ref.read(confirmPushProvider)) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showConfirmationDialog(
        context: context,
        title: l10n.confirmPush,
        message: l10n.pushToRemote,
        confirmText: l10n.push,
      );
      if (!confirmed || !mounted) return;
    }

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(
      gitExecutablePath: gitExecutablePath,
    );

    final results = await showBatchOperationProgressDialog(
      context,
      title:
          'Push ${repositoriesToPush.length == 1 ? 'Repository' : 'Repositories'}',
      repositories: repositoriesToPush,
      operation: (onProgress) =>
          service.pushAll(repositoriesToPush, statuses, onProgress: onProgress),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Pushed successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform create branch operation
  Future<void> _performCreateBranch(WidgetRef ref) async {
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final repositoriesToCreateBranch = _resolveGitActionRepositories();
    if (repositoriesToCreateBranch.isEmpty) return;
    if (!context.mounted) return;

    // Show create branch dialog
    final result = await showCreateBranchDialog(
      context,
      repositories: repositoriesToCreateBranch,
    );

    if (result == null || !context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final service = BatchOperationsService(
      gitExecutablePath: gitExecutablePath,
    );

    final results = await showBatchOperationProgressDialog(
      context, // ignore: use_build_context_synchronously
      title: 'Creating Branch: ${result.fullBranchName}',
      repositories: repositoriesToCreateBranch,
      operation: (onProgress) => service.createBranch(
        repositoriesToCreateBranch,
        branchName: result.branchName,
        prefix: result.prefix,
        setUpstream: result.setUpstream,
        checkout: result.checkout,
        onProgress: onProgress,
      ),
    );

    if (results != null && context.mounted) {
      // Store results for all repositories (both success and failures)
      final resultNotifier = ref.read(repositoryBatchErrorProvider.notifier);
      final batchResults = <String, RepositoryBatchResult>{};
      for (final result in results) {
        final message = result.success
            ? (result.message ?? 'Branch created successfully')
            : (result.error ?? 'Unknown error');
        batchResults[result.repository.path] = RepositoryBatchResult(
          success: result.success,
          message: message,
        );
      }
      if (batchResults.isNotEmpty) {
        resultNotifier.setResults(batchResults);
      }

      // Refresh repository statuses after operation
      ref.read(workspaceRepositoryStatusProvider.notifier).refreshAll();

      // Refresh branch providers to update branch switcher
      ref.read(gitActionsProvider).refreshBranches();

      // Clear selection if multiple were selected
      if (selectedPaths.isNotEmpty) {
        ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
      }
    }
  }

  /// Perform create pull request operation
  Future<void> _performCreatePR(WidgetRef ref) async {
    // Get repository to operate on (only supports single repository)
    final selectedPaths = ref.read(repositoryMultiSelectProvider);
    final allRepositories = ref.read(workspaceProvider);

    WorkspaceRepository? repository;
    if (selectedPaths.isNotEmpty) {
      // Only support single repository selection for PR creation
      if (selectedPaths.length > 1) {
        if (context.mounted) {
          NotificationService.showWarning(
            context,
            'Pull request creation only supports single repository selection',
          );
        }
        return;
      }
      repository = allRepositories.firstWhere(
        (repo) => repo.path == selectedPaths.first,
        orElse: () => WorkspaceRepository.fromPath(selectedPaths.first),
      );
    } else {
      // Use current repository
      final currentPath = ref.read(currentRepositoryPathProvider);
      if (currentPath == null) return;

      repository = allRepositories.firstWhere(
        (repo) => repo.path == currentPath,
        orElse: () => WorkspaceRepository.fromPath(currentPath),
      );
    }

    if (!context.mounted) return;

    final gitExecutablePath = ref.read(gitExecutablePathProvider);
    final gitService = GitService(
      repository.path,
      gitExecutablePath: gitExecutablePath,
    );

    try {
      // Get current branch
      final branchResult = await gitService.getCurrentBranch();

      // Handle result
      String? currentBranch;
      branchResult.when(
        success: (branch) => currentBranch = branch,
        failure: (msg, error, stackTrace) {
          if (context.mounted) {
            NotificationService.showError(context, 'Cannot create PR: $msg');
          }
        },
      );

      // If branch retrieval failed, return early
      if (currentBranch == null) return;

      // Get available branches (including remote)
      final branchesResult = await gitService.getAllBranches();

      // Handle result
      List<GitBranch>? branches;
      branchesResult.when(
        success: (List<GitBranch> branchList) => branches = branchList,
        failure: (msg, error, stackTrace) {
          if (context.mounted) {
            NotificationService.showError(
              context,
              'Cannot load branches: $msg',
            );
          }
        },
      );

      // If branch loading failed, return early
      if (branches == null) return;

      // Show create PR dialog
      if (!context.mounted) return;
      final result = await showCreatePullRequestDialog(
        context, // ignore: use_build_context_synchronously
        currentBranch: currentBranch!,
        availableBranches: branches!,
      );

      if (result == null || !context.mounted) return;

      try {
        // Get remote URL for platform detection
        final remoteUrlResult = await gitService.getRemoteUrl('origin');
        final remoteUrl = remoteUrlResult.unwrapOr(null);
        if (remoteUrl == null || remoteUrl.isEmpty) {
          if (!context.mounted) return;
          NotificationService.showError(
            context, // ignore: use_build_context_synchronously
            'Cannot create PR: No remote URL found for origin',
          );
          return;
        }

        // Open PR creation in browser
        final success = await GitPlatformService.openPRCreation(
          remoteUrl: remoteUrl,
          sourceBranch: currentBranch!,
          targetBranch: result.baseBranch,
          title: result.title,
          description: result.description,
          draft: result.draft,
        );

        if (context.mounted) {
          // Clear selection after the current frame to avoid rebuilding while dialog is closing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(repositoryMultiSelectProvider.notifier).clearSelection();
            }
          });

          if (!success) {
            // Show error message
            NotificationService.showError(
              context, // ignore: use_build_context_synchronously
              'Failed to open pull request creation. Platform may not be supported or URL is invalid.',
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          // Show error message
          NotificationService.showError(
            context, // ignore: use_build_context_synchronously
            'Failed to create pull request: ${e.toString()}',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(
          context, // ignore: use_build_context_synchronously
          'Error: ${e.toString()}',
        );
      }
    }
  }

  /// Show merge branches dialog
  ///
  /// The result is the whole point and used to be discarded (#450): the dialog
  /// answers `true` when the merge ended in conflicts, and a user who is told
  /// that and left where they were has been informed of a problem and offered
  /// nowhere to solve it. The command palette already did this for the
  /// single-branch merge; this is the same answer for the multi-branch one.
  Future<void> _performMergeBranches(BuildContext context) async {
    final bool? hasConflicts = await showMergeBranchesDialog(context);
    if (hasConflicts == true && context.mounted) {
      await Navigator.of(context).pushNamed('/conflicts');
    }
  }
}
