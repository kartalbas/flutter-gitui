import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_label.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/changelog_service.dart';
import '../../core/services/version_service.dart';
import '../../core/services/logger_service.dart';

class ChangelogDialog extends HookConsumerWidget {
  final int initialIndex;

  const ChangelogDialog({
    super.key,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changelogAsync = ref.watch(changelogDataProvider);
    final currentIndex = useState(initialIndex);
    final dontShowAgain = useState(false);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: SizedBox(
        width: screenSize.width * 0.75,
        height: screenSize.height * 0.85,
        child: changelogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppTheme.paddingM),
                TitleLargeLabel('Failed to load changelog'),
                const SizedBox(height: AppTheme.paddingS),
                BodyMediumLabel(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.paddingL),
                BaseButton(
                  label: 'Close',
                  variant: ButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          data: (changelogData) {
            if (changelogData.releases.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppTheme.paddingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppTheme.paddingM),
                    TitleMediumLabel(
                      'No release history available',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppTheme.paddingL),
                    BaseButton(
                      label: 'Close',
                      variant: ButtonVariant.primary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            }

            final release = changelogData.releases[currentIndex.value];
            final hasPrevious = currentIndex.value < changelogData.releases.length - 1;
            final hasNext = currentIndex.value > 0;

            return Column(
              children: [
                // Dialog title bar with close button
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      TitleLargeLabel('Release History'),
                      const Spacer(),
                      BaseIconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.close,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Version header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
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
                          const SizedBox(width: AppTheme.paddingS),
                          TitleLargeLabel(
                            'Version ${release.version}',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          if (currentIndex.value == 0) ...[
                            const SizedBox(width: AppTheme.paddingS),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.paddingS,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: LabelSmallLabel(
                                'LATEST',
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.paddingS),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTheme.paddingXS),
                          BodySmallLabel(
                            _formatDate(release.date),
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTheme.paddingM),
                          Icon(
                            Icons.commit,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTheme.paddingXS),
                          BodySmallLabel(
                            release.commit,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Changelog content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.paddingL),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: MarkdownBody(
                        data: release.changelog,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 2,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.8,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom action bar with navigation
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // "Don't show again" checkbox (left side)
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: dontShowAgain.value,
                              onChanged: (value) => dontShowAgain.value = value ?? false,
                            ),
                            const SizedBox(width: AppTheme.paddingS),
                            Flexible(
                              child: BodySmallLabel(
                                "Don't show on startup",
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Navigation controls (center)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Jump to oldest button (leftmost)
                          BaseIconButton(
                            onPressed: hasPrevious ? () => currentIndex.value = changelogData.releases.length - 1 : null,
                            icon: Icons.first_page,
                            tooltip: 'Oldest version',
                            variant: ButtonVariant.primary,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          // Older button (left arrow)
                          BaseIconButton(
                            onPressed: hasPrevious ? () => currentIndex.value++ : null,
                            icon: Icons.chevron_left,
                            tooltip: 'Older version',
                            variant: ButtonVariant.primary,
                          ),
                          const SizedBox(width: AppTheme.paddingM),
                          // Counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingM, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppTheme.paddingM),
                            ),
                            child: BodyMediumLabel(
                              '${currentIndex.value + 1} of ${changelogData.releases.length}',
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppTheme.paddingM),
                          // Newer button (right arrow)
                          BaseIconButton(
                            onPressed: hasNext ? () => currentIndex.value-- : null,
                            icon: Icons.chevron_right,
                            tooltip: 'Newer version',
                            variant: ButtonVariant.primary,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          // Jump to latest button (rightmost)
                          BaseIconButton(
                            onPressed: hasNext ? () => currentIndex.value = 0 : null,
                            icon: Icons.last_page,
                            tooltip: 'Latest version',
                            variant: ButtonVariant.primary,
                          ),
                          const SizedBox(width: AppTheme.paddingL),
                          // Close button
                          BaseButton(
                            label: 'Close',
                            variant: ButtonVariant.primary,
                            onPressed: () async {
                              // Save preference if "Don't show again" is checked
                              if (dontShowAgain.value) {
                                final versionService = ref.read(versionServiceProvider);
                                await versionService.disableWhatsNewDialog();
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
      Logger.info('[ChangelogDialog] Not showing - shouldShow: $shouldShow, mounted: ${context.mounted}');
      return;
    }

    final changelogData = await ref.read(changelogDataProvider.future);
    final latestRelease = changelogData.releases.firstOrNull;

    Logger.info('[ChangelogDialog] Latest release: ${latestRelease?.version}');

    if (latestRelease == null || !context.mounted) {
      Logger.info('[ChangelogDialog] Not showing - no release or not mounted');
      return;
    }

    final isVersionUpgrade = lastSeenVersion == null || lastSeenVersion != currentVersion;
    Logger.info('[ChangelogDialog] Is version upgrade: $isVersionUpgrade');

    // Show dialog with latest release
    Logger.info('[ChangelogDialog] Showing dialog now');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangelogDialog(initialIndex: 0),
    );

    // Only mark version as seen after version upgrades (first run or update)
    // For normal runs, we DON'T mark it as seen so it shows every time
    // (unless user disables it via "Don't show again")
    if (isVersionUpgrade) {
      Logger.info('[ChangelogDialog] Version upgrade detected - marking version as seen');
      await versionService.markVersionAsSeen(latestRelease.version);
      Logger.info('[ChangelogDialog] Version marked as seen: ${latestRelease.version}');
    } else {
      Logger.info('[ChangelogDialog] Normal run - NOT marking version as seen');
    }

    Logger.info('[ChangelogDialog] showIfNeeded completed');
  }
}
