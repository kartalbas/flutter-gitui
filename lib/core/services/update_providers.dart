import 'package:riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/config_providers.dart';
import 'managed_install.dart';
import 'update_check_policy.dart';
import 'update_service.dart';
import 'logger_service.dart';

/// The package manager that owns this installation, null when the application
/// owns it and may update itself.
///
/// Exposed as a provider so every surface asks the one question in the one
/// place, and so a widget test can stage a snap or a winget install by
/// overriding it instead of needing either to be real.
final managedInstallProvider = Provider<ManagedInstall?>(
  (ref) => ManagedInstallDetector.detectCurrentProcess(),
);

/// Provider for available update information
/// Null if no update is available or check hasn't been performed
final updateAvailableProvider = StateProvider<UpdateInfo?>((ref) => null);

/// Provider for update check in progress state
final checkingForUpdatesProvider = StateProvider<bool>((ref) => false);

/// Provider for dismissed update version
final dismissedUpdateVersionProvider = StateProvider<String?>((ref) => null);

/// An update archive downloaded in the background, digest-verified and ready
/// to be installed the moment the user chooses to restart.
class ReadyUpdate {
  final UpdateInfo info;
  final String filePath;

  const ReadyUpdate({required this.info, required this.filePath});
}

/// The staged download, if the auto-download setting produced one.
final readyUpdateProvider = StateProvider<ReadyUpdate?>((ref) => null);

/// The version a background download is currently transferring.
///
/// Startup and a manual check can overlap; without this latch both would
/// stage the same multi-megabyte archive at the same time.
final _downloadingVersionProvider = StateProvider<String?>((ref) => null);

/// Outcome of one update check, for callers that surface it themselves.
///
/// The background path ignores it; Settings uses it to open the update
/// dialog, show an up-to-date notice or show the failure message without
/// issuing a second request.
class UpdateCheckReport {
  final UpdateInfo? update;
  final String? failureMessage;

  /// Set when no check was made because this package manager owns the
  /// installation. Kept apart from "nothing to offer" so a caller can explain
  /// the absence of an update instead of claiming the build is current.
  final ManagedInstall? suppressedBy;

  const UpdateCheckReport({
    this.update,
    this.failureMessage,
    this.suppressedBy,
  });
}

/// Load dismissed update version from shared preferences
Future<void> loadDismissedUpdateVersion(dynamic ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString('dismissed_update_version');
    ref.read(dismissedUpdateVersionProvider.notifier).state = dismissedVersion;
    if (dismissedVersion != null) {
      Logger.info('Dismissed update version: $dismissedVersion');
    }
  } catch (e) {
    Logger.error('Error loading dismissed update version', e);
  }
}

/// Dismiss an update version (don't show again)
Future<void> dismissUpdateVersion(dynamic ref, String version) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dismissed_update_version', version);
    ref.read(dismissedUpdateVersionProvider.notifier).state = version;
    Logger.info('Dismissed update version: $version');
  } catch (e) {
    Logger.error('Error saving dismissed update version', e);
  }
}

/// Check for updates, persist the outcome and update state.
///
/// Never throws: a failed check is background noise by design (#294), so it
/// goes to the log, to Settings via the persisted outcome and into the
/// returned report - this function opens no surface of its own.
/// This function can be called with any Ref type (ProviderRef or WidgetRef).
///
/// An installation a package manager owns makes no check at all and reports
/// that as [UpdateCheckReport.suppressedBy] rather than as "up to date" (#364).
Future<UpdateCheckReport> checkForUpdates(dynamic ref) async {
  try {
    ref.read(checkingForUpdatesProvider.notifier).state = true;

    // unwrapOr(null) collapsed "the check failed" into "no update available":
    // an offline or server error was logged as being up to date. Throwing
    // instead lets the catch record the real error.
    final checkResult = (await UpdateService.checkForUpdates()).unwrap();

    // A package manager owns this installation, so no check was made and none
    // will be. Nothing is recorded either: the last-check line in Settings
    // describes checks, and there was no check to describe (#364).
    if (checkResult case UpdateCheckSuppressed(:final install)) {
      Logger.info('Update check suppressed: managed by ${install.name}');
      ref.read(updateAvailableProvider.notifier).state = null;
      return UpdateCheckReport(suppressedBy: install);
    }

    // Check if this version was dismissed
    final dismissedVersion = ref.read(dismissedUpdateVersionProvider);

    if (checkResult is! UpdateAvailable) {
      Logger.info('No updates available');
      ref.read(updateAvailableProvider.notifier).state = null;
      await _recordCheck(ref, UpdateCheckOutcome.upToDate, null);
      return const UpdateCheckReport();
    }
    final updateInfo = checkResult.info;

    if (dismissedVersion == updateInfo.version) {
      // The user said no to this version; the quiet indicator stays hidden,
      // but a manual check still receives it through the report.
      Logger.info('Update ${updateInfo.version} was dismissed, not showing');
      ref.read(updateAvailableProvider.notifier).state = null;
    } else {
      Logger.info('Update available: ${updateInfo.version}');
      ref.read(updateAvailableProvider.notifier).state = updateInfo;

      // Clear dismissed version if new update is available
      if (dismissedVersion != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('dismissed_update_version');
        ref.read(dismissedUpdateVersionProvider.notifier).state = null;
      }
    }

    await _recordCheck(
      ref,
      UpdateCheckOutcome.updateAvailable,
      updateInfo.version,
    );
    // A dismissed version is not staged either: downloading what the user
    // declined would spend their bandwidth on it anyway.
    if (dismissedVersion != updateInfo.version) {
      await _autoDownloadIfConfigured(ref, updateInfo);
    }
    return UpdateCheckReport(update: updateInfo);
  } catch (e) {
    Logger.error('Error checking for updates', e);
    final message = UpdateService.describeCheckFailure(e);
    await _recordCheck(ref, UpdateCheckOutcome.failed, message);
    return UpdateCheckReport(failureMessage: message);
  } finally {
    ref.read(checkingForUpdatesProvider.notifier).state = false;
  }
}

/// Best-effort persistence: a config write failure must not turn a quiet
/// background check into an error surface.
Future<void> _recordCheck(
  dynamic ref,
  UpdateCheckOutcome outcome,
  String? detail,
) async {
  try {
    await ref
        .read(configProvider.notifier)
        .recordUpdateCheck(
          time: DateTime.now(),
          outcome: outcome,
          detail: detail,
        );
  } catch (e) {
    Logger.error('Could not persist update check result', e);
  }
}

/// Stages the archive in the background when the setting asks for it.
///
/// A completed download changes nothing on its own - it only makes the
/// restart the user will eventually pick quick. Failures stay in the log:
/// the user did not start this transfer, so nothing may pop up over their
/// work to report it.
Future<void> _autoDownloadIfConfigured(
  dynamic ref,
  UpdateInfo updateInfo,
) async {
  final AppConfig config = ref.read(configProvider);
  if (!config.updates.autoDownload) return;

  final ReadyUpdate? staged = ref.read(readyUpdateProvider);
  if (staged != null && staged.info.version == updateInfo.version) return;

  final String? inFlight = ref.read(_downloadingVersionProvider);
  if (inFlight == updateInfo.version) return;
  ref.read(_downloadingVersionProvider.notifier).state = updateInfo.version;
  try {
    final filePath = (await UpdateService.downloadUpdate(updateInfo)).unwrap();
    ref.read(readyUpdateProvider.notifier).state = ReadyUpdate(
      info: updateInfo,
      filePath: filePath,
    );
    Logger.info('Update ${updateInfo.version} downloaded in the background');
  } catch (e) {
    Logger.error('Background update download failed', e);
  } finally {
    ref.read(_downloadingVersionProvider.notifier).state = null;
  }
}
