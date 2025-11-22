import 'package:riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'update_service.dart';
import 'logger_service.dart';

/// Provider for available update information
/// Null if no update is available or check hasn't been performed
final updateAvailableProvider = StateProvider<UpdateInfo?>((ref) => null);

/// Provider for update check in progress state
final checkingForUpdatesProvider = StateProvider<bool>((ref) => false);

/// Provider for last update check timestamp
final lastUpdateCheckProvider = StateProvider<DateTime?>((ref) => null);

/// Provider tracking if update dialog has been shown this session
final updateDialogShownProvider = StateProvider<String?>((ref) => null);

/// Provider for dismissed update version
final dismissedUpdateVersionProvider = StateProvider<String?>((ref) => null);

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

/// Check for updates and update state
/// This function can be called with any Ref type (ProviderRef or WidgetRef)
Future<void> checkForUpdates(dynamic ref) async {
  try {
    ref.read(checkingForUpdatesProvider.notifier).state = true;

    final updateInfo = await UpdateService.checkForUpdates();

    // Check if this version was dismissed
    final dismissedVersion = ref.read(dismissedUpdateVersionProvider);

    if (updateInfo != null) {
      // If user dismissed this version, don't show it again
      if (dismissedVersion == updateInfo.version) {
        Logger.info('Update ${updateInfo.version} was dismissed, not showing');
        ref.read(updateAvailableProvider.notifier).state = null;
      } else {
        // New version (not dismissed), show it
        Logger.info('Update available: ${updateInfo.version}');
        ref.read(updateAvailableProvider.notifier).state = updateInfo;

        // Clear dismissed version if new update is available
        if (dismissedVersion != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('dismissed_update_version');
          ref.read(dismissedUpdateVersionProvider.notifier).state = null;
        }
      }
    } else {
      Logger.info('No updates available');
      ref.read(updateAvailableProvider.notifier).state = null;
    }

    ref.read(lastUpdateCheckProvider.notifier).state = DateTime.now();
  } catch (e) {
    Logger.error('Error checking for updates', e);
  } finally {
    ref.read(checkingForUpdatesProvider.notifier).state = false;
  }
}
