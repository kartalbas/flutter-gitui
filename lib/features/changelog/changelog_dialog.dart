import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_label.dart';
import '../../shared/components/base_viewer_dialog.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/keyboard_guards.dart';
import '../../core/models/changelog_release.dart';
import '../../core/services/changelog_service.dart';
import '../../core/services/version_service.dart';
import '../../core/services/logger_service.dart';
import '../../shared/components/base_layout.dart';

class ChangelogDialog extends HookConsumerWidget {
  final int initialIndex;

  const ChangelogDialog({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changelogAsync = ref.watch(changelogDataProvider);
    final currentIndex = useState(initialIndex);
    final dontShowAgain = useState(false);
    final touched = useState(false); // User toggled the checkbox themselves
    final versionService = ref.watch(versionServiceProvider);

    // Initialize the checkbox from the persisted setting. The load is async,
    // so adopt the stored value only while the user has not touched the
    // checkbox yet, and never after the dialog was dismissed.
    useEffect(() {
      versionService.isWhatsNewDialogDisabled().then((isDisabled) {
        if (!context.mounted) return;
        if (!touched.value) dontShowAgain.value = isDisabled;
      });
      return null;
    }, []);

    // Persisting on toggle (instead of on close) makes every close path -
    // Esc, Enter, the X, the barrier and the Close button - equally safe:
    // there is no pending state a dismissal could lose.
    Future<void> setDontShowAgain(bool value) async {
      touched.value = true;
      dontShowAgain.value = value;
      if (value) {
        await versionService.disableWhatsNewDialog();
      } else {
        await versionService.enableWhatsNewDialog();
      }
    }

    final releases =
        changelogAsync.value?.releases ?? const <ChangelogRelease>[];
    final index = releases.isEmpty
        ? 0
        : currentIndex.value.clamp(0, releases.length - 1);
    final hasOlder = index < releases.length - 1;
    final hasNewer = index > 0;

    // The version pager is this dialog's list; the arrow keys drive it. A
    // raw CallbackShortcuts used to sit here and fired unconditionally, so
    // paging shadowed the selection caret of the selectable release body -
    // exactly the drift avoid_raw_shortcuts now bans (#382). The handler
    // follows the shared keyboard contract instead: it yields every key a
    // focused editable interprets (focusedEditableOwnsKey - the selectable
    // markdown is an editable in the guard's sense), leaves modified chords
    // to the shell, and only then pages.
    KeyEventResult handlePagerKey(FocusNode node, KeyEvent event) {
      if (event is KeyUpEvent) return KeyEventResult.ignored;
      if (focusedEditableOwnsKey(event)) return KeyEventResult.ignored;
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed ||
          keyboard.isAltPressed ||
          keyboard.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (hasOlder) currentIndex.value = index + 1;
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (hasNewer) currentIndex.value = index - 1;
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Mirrors what CallbackShortcuts builds internally: a non-focusable,
    // traversal-invisible node that only observes keys bubbling up from the
    // dialog - never a Tab stop, never a focus claim.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: handlePagerKey,
      child: BaseViewerDialog(
        icon: IconRole.clockCounterClockwise,
        title: 'Release History',
        widthFactor: 0.75,
        heightFactor: 0.85,
        // Reading is this dialog's only job, so closing is its primary
        // action: Enter, Esc and the X all do the same thing.
        onSubmit: () => Navigator.of(context).pop(),
        content: changelogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _StatusPane(
            icon: Icons.error_outline,
            iconColor: Theme.of(context).colorScheme.error,
            title: 'Failed to load changelog',
            detail: error.toString(),
          ),
          data: (changelogData) {
            if (changelogData.releases.isEmpty) {
              return _StatusPane(
                icon: Icons.history,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                title: 'No release history available',
              );
            }

            final release = changelogData.releases[index];

            return Column(
              children: [
                // Version header
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: BaseInset(
                    all: Inset.normal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const BaseGap(Proximity.related),
                            BaseLabel(
                              'Version ${release.version}',
                              role: TextRole.pageTitle,
                            ),
                            if (index == 0) ...[
                              const BaseGap(Proximity.related),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.paddingS,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusL,
                                  ),
                                ),
                                // Tone.onAccent, not a dropped override: the
                                // pill behind this text is painted with the
                                // accent by the application itself, which is
                                // the exact case the tone's doc names. It
                                // leaves with the pill when the badge surface
                                // migrates.
                                child: BaseLabel(
                                  'LATEST',
                                  role: TextRole.micro,
                                  tone: Tone.onAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const BaseGap(Proximity.related),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const BaseGap(Proximity.hairline),
                            BaseLabel(
                              _formatDate(release.date),
                              role: TextRole.detail,
                              tone: Tone.muted,
                            ),
                            const BaseGap(Proximity.grouped),
                            Icon(
                              Icons.commit,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const BaseGap(Proximity.hairline),
                            BaseLabel(
                              release.commit,
                              role: TextRole.detail,
                              tone: Tone.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Changelog content
                Expanded(
                  // A scroll view's padding is the inset its content owes
                  // the viewport's edge and scrolls with it, so it is stated
                  // as an inset around the content.
                  child: SingleChildScrollView(
                    child: BaseInset(
                      all: Inset.roomy,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: MarkdownBody(
                          data: release.changelog,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            h3: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  height: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            listBullet: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  height: 1.8,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        footer: releases.isEmpty
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: BaseInset(
                  all: Inset.normal,
                  child: Row(
                    children: [
                      // "Don't show again" checkbox (left side)
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: dontShowAgain.value,
                              onChanged: (value) =>
                                  setDontShowAgain(value ?? false),
                            ),
                            const BaseGap(Proximity.related),
                            Flexible(
                              child: BaseLabel(
                                "Don't show on startup",
                                role: TextRole.detail,
                                tone: Tone.muted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Navigation controls (center)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BaseIconButton(
                            onPressed: hasOlder
                                ? () => currentIndex.value = releases.length - 1
                                : null,
                            icon: IconRole.caretLineLeft,
                            tooltip: 'Oldest version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.related),
                          BaseIconButton(
                            onPressed: hasOlder
                                ? () => currentIndex.value = index + 1
                                : null,
                            icon: IconRole.caretLeft,
                            tooltip: 'Older version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.grouped),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingM,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXL,
                              ),
                            ),
                            // The pill paints its own fill and states the
                            // foreground that pairs with it.
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              child: BaseLabel(
                                '${index + 1} of ${releases.length}',
                                role: TextRole.body,
                              ),
                            ),
                          ),
                          const BaseGap(Proximity.grouped),
                          BaseIconButton(
                            onPressed: hasNewer
                                ? () => currentIndex.value = index - 1
                                : null,
                            icon: IconRole.caretRight,
                            tooltip: 'Newer version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.related),
                          BaseIconButton(
                            onPressed: hasNewer
                                ? () => currentIndex.value = 0
                                : null,
                            icon: IconRole.caretLineRight,
                            tooltip: 'Latest version',
                            variant: ButtonVariant.primary,
                          ),
                          const BaseGap(Proximity.separate),
                          BaseButton(
                            label: 'Close',
                            variant: ButtonVariant.primary,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('MMMM d, yyyy').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  /// Show the changelog dialog
  static Future<void> show(BuildContext context, {int initialIndex = 0}) async {
    // Dismissable from every path: the checkbox persists on toggle, so a
    // barrier click or Esc cannot lose anything.
    await showDialog(
      context: context,
      builder: (_) => ChangelogDialog(initialIndex: initialIndex),
    );
  }

  /// Show the "What's New" dialog if needed (version upgrade)
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final versionService = ref.read(versionServiceProvider);

    // Get current state for logging
    final currentVersion = await versionService.getCurrentVersion();
    final lastSeenVersion = await versionService.getLastSeenVersion();
    final isDisabled = await versionService.isWhatsNewDialogDisabled();

    Logger.info('[ChangelogDialog] showIfNeeded called');
    Logger.info('[ChangelogDialog] Current version: $currentVersion');
    Logger.info('[ChangelogDialog] Last seen version: $lastSeenVersion');
    Logger.info('[ChangelogDialog] Dialog disabled: $isDisabled');

    final shouldShow = await versionService.shouldShowWhatsNew();
    Logger.info('[ChangelogDialog] shouldShowWhatsNew result: $shouldShow');

    if (!shouldShow || !context.mounted) {
      Logger.info(
        '[ChangelogDialog] Not showing - shouldShow: $shouldShow, mounted: ${context.mounted}',
      );
      return;
    }

    final changelogData = await ref.read(changelogDataProvider.future);
    final latestRelease = changelogData.releases.firstOrNull;

    Logger.info('[ChangelogDialog] Latest release: ${latestRelease?.version}');

    if (latestRelease == null || !context.mounted) {
      Logger.info('[ChangelogDialog] Not showing - no release or not mounted');
      return;
    }

    // Release builds regenerate assets/changelog.json in CI before packing
    // (tools/changelog/generate_changelog.dart), so on an installed release
    // both versions match and the dialog shows. A source build still runs
    // against the checked-in seed asset, and announcing its entry as LATEST
    // would describe a release this build is not - the guard stays for that.
    if (latestRelease.version != currentVersion.split('+').first) {
      Logger.info(
        '[ChangelogDialog] Not showing - changelog latest ${latestRelease.version} does not match app $currentVersion',
      );
      return;
    }

    // Compare without the build number so this matches shouldShowWhatsNew, which
    // treats "0.1.0+1" and "0.1.0+2" as the same version.
    final isVersionUpgrade =
        lastSeenVersion == null ||
        lastSeenVersion.split('+').first != currentVersion.split('+').first;
    Logger.info('[ChangelogDialog] Is version upgrade: $isVersionUpgrade');

    // Show dialog with latest release
    Logger.info('[ChangelogDialog] Showing dialog now');
    await showDialog(
      context: context,
      builder: (_) => const ChangelogDialog(initialIndex: 0),
    );

    // Only mark version as seen after version upgrades (first run or update)
    // For normal runs, we DON'T mark it as seen so it shows every time
    // (unless user disables it via "Don't show again")
    if (isVersionUpgrade) {
      Logger.info(
        '[ChangelogDialog] Version upgrade detected - marking version as seen',
      );
      // Record the app's own version, not the changelog entry's: the bundled
      // changelog can lag behind the app, and disableWhatsNewDialog() stores
      // currentVersion - writing anything else here would revert that preference.
      await versionService.markVersionAsSeen(currentVersion);
      Logger.info('[ChangelogDialog] Version marked as seen: $currentVersion');
    } else {
      Logger.info('[ChangelogDialog] Normal run - NOT marking version as seen');
    }

    Logger.info('[ChangelogDialog] showIfNeeded completed');
  }
}

/// Loading-adjacent panes (error, empty history). Closing goes through the
/// header X, Esc or Enter - a pane-level Close button would be a second
/// affordance for the same job.
class _StatusPane extends StatelessWidget {
  const _StatusPane({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return BaseInset(
      all: Inset.roomy,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: iconColor),
          const BaseGap(Proximity.grouped),
          BaseLabel(title, role: TextRole.pageTitle),
          if (detail != null) ...[
            const BaseGap(Proximity.related),
            BaseLabel(detail!, role: TextRole.body, align: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
