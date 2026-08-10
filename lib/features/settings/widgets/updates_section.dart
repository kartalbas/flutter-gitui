import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ControlScale,
        DialogRouteSpec,
        IconRole,
        Inset,
        NoticeLifetime,
        NoticeSpec,
        Overlays,
        Proximity,
        TextRole,
        ToggleKind,
        Tone;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_toggle_row.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/managed_install.dart';
import '../../../core/services/update_check_policy.dart';
import '../../../core/services/update_providers.dart';
import '../../../core/services/update_reasons.dart';
import '../../../shared/dialogs/update_available_dialog.dart';
import '../../../features/changelog/changelog_dialog.dart';
import 'settings_section.dart';
import '../../../shared/components/base_layout.dart';

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
  /// Null until package_info_plus has answered; the placeholder shown until
  /// then is a translation, so it is resolved at build time rather than here.
  String? _currentVersion;

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
          updates.lastCheckVersion ?? '?',
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

    // The button that starts this is not built for a managed installation, so
    // reaching here means something else called it. Saying "up to date" would
    // be a claim no check was ever made to support (#364).
    final suppressedBy = report.suppressedBy;
    if (suppressedBy != null) {
      Logger.info('Manual update check suppressed: ${suppressedBy.name}');
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    final failureReason = report.failureReason;
    if (failureReason != null) {
      // The check classifies each failure mode as something the user can act
      // on; the raw exception named an internal host and an OS errno. The
      // sentence is produced here, in the active locale, from the reason the
      // check returned (#393).
      //
      // The fill left with the surface. `NoticeLifetime` has two rungs and
      // this notice is neither: it went away on its own (so not `persistent`),
      // but its eight seconds were chosen because four is not enough to read
      // a URL - the auto-dismissing-but-readable rung does not exist, and
      // that gap stays reported as a contract finding. Between the two rungs
      // that DO exist, the vocabulary's own definitions decide: `brief` is
      // "something the user may miss without harm", and an explanation of why
      // the check the user just asked for failed is not that - under
      // Material's two-second brief it vanishes unread. So it states
      // `persistent`, which keeps the message until the user dismisses it;
      // what it trades away is the self-dismissal, which is the smaller loss.
      Overlays.notify(
        context,
        NoticeSpec(
          tone: Tone.danger,
          title: failureReason.message(l10n),
          lifetime: NoticeLifetime.persistent,
        ),
      );
      return;
    }

    // A release exists that this build may not install itself -- an unsigned
    // macOS archive today. Naming the version and where to get it is the whole
    // answer, so it is a message rather than the install dialog (#387).
    final manualUpdate = report.manualUpdate;
    if (manualUpdate != null) {
      Logger.info('Manual update available: ${manualUpdate.info.version}');
      // Worth knowing, with nothing wrong: a release exists and this is
      // where to get it - `info`. Same lifetime adjudication as the failure
      // notice above: the twelve seconds existed so the user could read a
      // version and where to get it, which is a message that must be read,
      // not one that may be missed without harm - so it takes `persistent`
      // rather than vanishing at the brief rung's two seconds. The missing
      // middle rung stays a reported contract finding.
      Overlays.notify(
        context,
        NoticeSpec(
          tone: Tone.info,
          title: manualUpdate.reason.message(l10n, manualUpdate.info.version),
          lifetime: NoticeLifetime.persistent,
        ),
      );
      return;
    }

    final update = report.update;
    if (update != null) {
      Logger.info('Update found: ${update.version}');
      await Overlays.dialogFrom<void>(
        context,
        route: DialogRouteSpec(
          title: AppLocalizations.of(context)!.updateAvailableTitle,
          // A download can run inside this dialog; dismissing it by tapping
          // outside would abandon the transfer.
          barrierDismissible: false,
        ),
        builder: (context) => UpdateAvailableDialog(updateInfo: update),
      );
    } else {
      Logger.info('No updates found');
      // The version is read in initState and this runs on a button the user
      // has to reach first, so the placeholder is a formality; an empty
      // version still reads better here than the word "Loading".
      //
      // The fill left with the surface. The check ran and found nothing to
      // do, which is `info`: worth knowing, and nothing is wrong.
      Overlays.notify(
        context,
        NoticeSpec(
          tone: Tone.info,
          title: l10n.upToDateMessage(_currentVersion ?? ''),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final updates = ref.watch(updatesConfigProvider);
    final isChecking = ref.watch(checkingForUpdatesProvider);
    // A package manager owning this installation removes the whole update
    // section's subject: there is no check to schedule, nothing to download in
    // the background and no result to report, so those controls give way to the
    // one thing that is true here -- who does deliver new versions (#364).
    final managedInstall = ref.watch(managedInstallProvider);
    // Null unless the last check found a release this build may not install
    // itself -- an unsigned macOS archive today (#387).
    final manualUpdate = ref.watch(manualUpdateProvider);

    return SettingsSection(
      title: l10n.updates,
      icon: IconRole.downloadSimple,
      children: [
        // Current version
        BaseInset(
          all: Inset.normal,
          child: Row(
            children: [
              // The mark repeats what the words beside it already say, so it
              // is secondary to them and takes the dense scale this row reads
              // at.
              const BaseIcon(
                IconRole.package,
                scale: ControlScale.compact,
                tone: Tone.muted,
              ),
              const BaseGap(Proximity.related),
              BaseLabel(
                l10n.currentVersion,
                role: TextRole.body,
                tone: Tone.muted,
              ),
              const Spacer(),
              BaseLabel(_currentVersion ?? l10n.loading, role: TextRole.body),
            ],
          ),
        ),

        const BaseSeparator(),

        if (managedInstall != null)
          // Naming the manager and the reason is the whole point of keeping
          // "suppressed" apart from "up to date": without it the section would
          // simply be missing its controls, which reads as a defect.
          BaseListItem(
            // The row's own mark. The prominent scale is what a bare `Icon`
            // rendered at under the row's ambient icon theme, and the neutral
            // tone leaves the colour to the row, as before.
            leading: const BaseIcon(
              IconRole.storefront,
              scale: ControlScale.prominent,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(
                  managedInstall.managedByLine(l10n),
                  role: TextRole.body,
                ),
                BaseLabel(
                  managedInstall.explanation(l10n),
                  role: TextRole.detail,
                ),
              ],
            ),
          )
        else ...[
          // How often the app may look for updates on its own
          BaseListItem(
            leading: const BaseIcon(
              IconRole.arrowsClockwise,
              scale: ControlScale.prominent,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(l10n.updateCheckFrequency, role: TextRole.body),
                BaseLabel(
                  _frequencyLabel(l10n, updates.checkFrequency),
                  role: TextRole.detail,
                ),
              ],
            ),
            // No `style:` here, and the absence is the statement. Each entry is
            // a `BaseLabel` at `TextRole.body` that pins its own ramp step and
            // takes only its COLOUR from the enclosing `DefaultTextStyle`,
            // which is precisely `Tone.neutral` - "whatever this surface's
            // ordinary foreground is" - and is what every one of them already
            // says by default. Spelling `onSurface` out again here said the
            // same thing in Material's words. Nothing moves: the fallback ramp
            // step carries the scheme's `onSurface` too
            // (`AppTheme._brightnessCorrectedTextTheme`), and the labels own
            // the size.
            trailing: DropdownButton<UpdateCheckFrequency>(
              value: updates.checkFrequency,
              items: UpdateCheckFrequency.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: BaseLabel(
                    _frequencyLabel(l10n, frequency),
                    role: TextRole.body,
                  ),
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
          BaseToggleRow(
            leading: IconRole.cloudArrowDown,
            label: l10n.autoDownloadUpdates,
            description: l10n.autoDownloadUpdatesDescription,
            value: updates.autoDownload,
            // Takes effect the moment it changes; nothing to confirm.
            kind: ToggleKind.switching,
            onChanged: (value) {
              ref
                  .read(configProvider.notifier)
                  .setUpdateAutoDownload(value ?? false);
            },
          ),

          // When the last check ran and what it concluded; a failed background
          // check surfaces here and in the log instead of in a popup.
          BaseListItem(
            leading: const BaseIcon(
              IconRole.clock,
              scale: ControlScale.prominent,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(l10n.lastUpdateCheck, role: TextRole.body),
                BaseLabel(
                  _lastCheckSummary(l10n, updates),
                  role: TextRole.detail,
                ),
                // Rendered here rather than stored: the reason was persisted as
                // a code, so this line follows whatever language is in force
                // now, not the one that happened to be active when the check
                // failed (#393).
                if (updates.lastCheckOutcome == UpdateCheckOutcome.failed &&
                    updates.lastCheckFailure != null)
                  BaseLabel(
                    updates.lastCheckFailure!.message(l10n),
                    role: TextRole.detail,
                    tone: Tone.danger,
                  ),
                // A release this build may not install itself is explained
                // here rather than only in the message that follows the
                // button, so a user who never presses it still finds out why
                // no restart is being offered (#387).
                if (manualUpdate != null)
                  BaseLabel(
                    manualUpdate.reason.message(
                      l10n,
                      manualUpdate.info.version,
                    ),
                    role: TextRole.detail,
                  ),
              ],
            ),
          ),

          const BaseSeparator(),

          // Check for Updates button
          BaseInset(
            all: Inset.normal,
            child: BaseButton(
              label: isChecking
                  ? l10n.checkingForUpdates
                  : l10n.checkForUpdates,
              variant: ButtonVariant.primary,
              leadingIcon: isChecking ? null : IconRole.arrowsClockwise,
              isLoading: isChecking,
              onPressed: isChecking ? null : _checkForUpdates,
              fullWidth: true,
            ),
          ),
        ],

        // View Changelog button. Its three-sided padding was an inset with
        // one side missing, which is composition written as a number: the
        // section above owns the space over the button, so the button takes
        // an ordinary inset across and below and the run states the rest.
        BaseInset(
          x: Inset.normal,
          y: Inset.none,
          child: BaseButton(
            label: l10n.viewReleaseHistory,
            variant: ButtonVariant.secondary,
            leadingIcon: IconRole.clockCounterClockwise,
            onPressed: () {
              ChangelogDialog.show(context);
            },
            fullWidth: true,
          ),
        ),
        const BaseGap(Proximity.grouped),
      ],
    );
  }
}
