import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/update_check_policy.dart';
import '../../../core/services/update_providers.dart';
import '../../../shared/dialogs/update_available_dialog.dart';
import '../../../features/changelog/changelog_dialog.dart';
import 'settings_section.dart';

/// Updates section for settings
///
/// Checking and downloading are the only automatic parts of the update flow,
/// and both are governed here; installing always stays a restart the user
/// chooses in the update dialog.
class UpdatesSection extends ConsumerStatefulWidget {
  const UpdatesSection({super.key});

  @override
  ConsumerState<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<UpdatesSection> {
  String _currentVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    // Fired from initState: leaving Settings before the platform channel
    // returns disposes this State, and setState on it would assert.
    if (!mounted) return;
    // Releases are stamped without build metadata, so package_info_plus reports
    // an empty build number; appending it would render "0.5.0-alpha+".
    final buildNumber = packageInfo.buildNumber;
    setState(() {
      _currentVersion = buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+$buildNumber';
    });
  }

  String _frequencyLabel(
    AppLocalizations l10n,
    UpdateCheckFrequency frequency,
  ) {
    switch (frequency) {
      case UpdateCheckFrequency.onStart:
        return l10n.updateFrequencyOnStart;
      case UpdateCheckFrequency.daily:
        return l10n.updateFrequencyDaily;
      case UpdateCheckFrequency.weekly:
        return l10n.updateFrequencyWeekly;
      case UpdateCheckFrequency.never:
        return l10n.updateFrequencyNever;
    }
  }

  String _lastCheckResultLabel(AppLocalizations l10n, UpdatesConfig updates) {
    switch (updates.lastCheckOutcome) {
      case UpdateCheckOutcome.upToDate:
        return l10n.updateCheckResultUpToDate;
      case UpdateCheckOutcome.updateAvailable:
        return l10n.updateCheckResultUpdateAvailable(
          updates.lastCheckDetail ?? '?',
        );
      case UpdateCheckOutcome.failed:
        return l10n.updateCheckResultFailed;
      case null:
        return '';
    }
  }

  /// One line summarising the last check: when it ran and what it concluded.
  String _lastCheckSummary(AppLocalizations l10n, UpdatesConfig updates) {
    final time = updates.lastCheckTime;
    if (time == null) return l10n.lastUpdateCheckNever;
    final result = _lastCheckResultLabel(l10n, updates);
    final stamp = _formatTime(time);
    return result.isEmpty ? stamp : '$stamp - $result';
  }

  /// Local wall-clock time at minute precision; a timestamp is technical
  /// enough that one fixed layout serves every locale.
  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _checkForUpdates() async {
    Logger.info('Manual update check initiated');
    // The shared check also persists the outcome shown above and stages the
    // background download when that setting is on, so a manual check behaves
    // exactly like a scheduled one plus a surface for the result.
    final report = await checkForUpdates(ref);
    if (!mounted) return;

    final failureMessage = report.failureMessage;
    if (failureMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // The check phrases each failure mode as something the user can act
          // on; the raw exception named an internal host and an OS errno.
          content: Text(failureMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          // The message says what to do next and carries a URL, which four
          // seconds is not enough to read.
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    final update = report.update;
    if (update != null) {
      Logger.info('Update found: ${update.version}');
      await showDialog(
        context: context,
        // A download can run inside this dialog; dismissing it by tapping
        // outside would abandon the transfer.
        barrierDismissible: false,
        builder: (context) => UpdateAvailableDialog(updateInfo: update),
      );
    } else {
      Logger.info('No updates found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.upToDateMessage(_currentVersion),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final updates = ref.watch(updatesConfigProvider);
    final isChecking = ref.watch(checkingForUpdatesProvider);

    return SettingsSection(
      title: l10n.updates,
      icon: PhosphorIconsRegular.downloadSimple,
      children: [
        // Current version
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.package,
                size: AppTheme.iconS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingS),
              BodyMediumLabel(
                l10n.currentVersion,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const Spacer(),
              LabelLargeLabel(_currentVersion),
            ],
          ),
        ),

        const Divider(),

        // How often the app may look for updates on its own
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.arrowsClockwise),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.updateCheckFrequency),
              BodySmallLabel(_frequencyLabel(l10n, updates.checkFrequency)),
            ],
          ),
          trailing: DropdownButton<UpdateCheckFrequency>(
            value: updates.checkFrequency,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: UpdateCheckFrequency.values.map((frequency) {
              return DropdownMenuItem(
                value: frequency,
                child: BodyMediumLabel(_frequencyLabel(l10n, frequency)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(configProvider.notifier)
                    .setUpdateCheckFrequency(value);
              }
            },
          ),
        ),

        // Background download of a found update; installing stays manual
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.cloudArrowDown),
          title: Text(l10n.autoDownloadUpdates),
          subtitle: Text(l10n.autoDownloadUpdatesDescription),
          value: updates.autoDownload,
          onChanged: (value) {
            ref.read(configProvider.notifier).setUpdateAutoDownload(value);
          },
        ),

        // When the last check ran and what it concluded; a failed background
        // check surfaces here and in the log instead of in a popup.
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.clock),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.lastUpdateCheck),
              BodySmallLabel(_lastCheckSummary(l10n, updates)),
              if (updates.lastCheckOutcome == UpdateCheckOutcome.failed &&
                  updates.lastCheckDetail != null)
                BodySmallLabel(
                  updates.lastCheckDetail!,
                  color: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
        ),

        const Divider(),

        // Check for Updates button
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: BaseButton(
            label: isChecking ? l10n.checkingForUpdates : l10n.checkForUpdates,
            variant: ButtonVariant.primary,
            leadingIcon: isChecking
                ? null
                : PhosphorIconsRegular.arrowsClockwise,
            isLoading: isChecking,
            onPressed: isChecking ? null : _checkForUpdates,
            fullWidth: true,
          ),
        ),

        // View Changelog button
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.paddingM,
            right: AppTheme.paddingM,
            bottom: AppTheme.paddingM,
          ),
          child: BaseButton(
            label: l10n.viewReleaseHistory,
            variant: ButtonVariant.secondary,
            leadingIcon: PhosphorIconsRegular.clockCounterClockwise,
            onPressed: () {
              ChangelogDialog.show(context);
            },
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}
