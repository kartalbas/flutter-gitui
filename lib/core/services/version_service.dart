import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/config_service.dart';
import 'logger_service.dart';

final versionServiceProvider = Provider<VersionService>((ref) {
  return VersionService();
});

class VersionService {
  Future<void> initialize() async {
    // Ensure config directory exists
    await ConfigService.ensureConfigDirExists();
  }

  /// Get the current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  /// Get the last version the user saw the changelog for
  Future<String?> getLastSeenVersion() async {
    try {
      final config = await ConfigService.load().then((result) => result.unwrap());
      return config.lastSeenVersion;
    } catch (e) {
      Logger.warning('Failed to load last seen version from config', e);
      return null;
    }
  }

  /// Mark the current version as seen
  Future<void> markVersionAsSeen(String version) async {
    try {
      final config = await ConfigService.load().then((result) => result.unwrap());
      final updatedConfig = config.copyWith(lastSeenVersion: version);
      await ConfigService.save(updatedConfig).then((result) => result.unwrap());
      Logger.info('[VersionService] Marked version as seen: $version');
    } catch (e, stack) {
      Logger.error('[VersionService] Failed to mark version as seen', e, stack);
    }
  }

  /// Check if dialog is disabled
  Future<bool> isWhatsNewDialogDisabled() async {
    try {
      final config = await ConfigService.load().then((result) => result.unwrap());
      return config.disableWhatsNewDialog ?? false;
    } catch (e) {
      Logger.warning('Failed to check dialog disabled state', e);
      return false;
    }
  }

  /// Check if the user should see the "What's New" dialog
  ///
  /// Use cases:
  /// 1. First run (lastSeenVersion == null) -> Always show
  /// 2. After any update/upgrade (version changed) -> Always show
  /// 3. Normal runs (version unchanged):
  ///    - User disabled dialog -> Don't show
  ///    - User didn't disable -> Show every time
  Future<bool> shouldShowWhatsNew() async {
    final currentVersion = await getCurrentVersion();
    final lastSeenVersion = await getLastSeenVersion();

    Logger.info('[VersionService] Version check - Current: $currentVersion, Last seen: $lastSeenVersion');

    // Case 1: First run - always show
    if (lastSeenVersion == null) {
      Logger.info('[VersionService] First run - showing What\'s New dialog');
      return true;
    }

    // Case 2: Version changed (update/upgrade) - always show
    // Compare only the version part, ignore build number (e.g., "0.1.0+1" vs "0.1.0+2" are same version)
    final currentVersionOnly = _extractVersion(currentVersion);
    final lastSeenVersionOnly = _extractVersion(lastSeenVersion);

    if (lastSeenVersionOnly != currentVersionOnly) {
      Logger.info('[VersionService] Version changed - showing What\'s New dialog ($lastSeenVersionOnly -> $currentVersionOnly)');
      return true;
    }

    // Case 3: Normal run (same version) - check user preference
    final isDisabled = await isWhatsNewDialogDisabled();
    if (isDisabled) {
      Logger.info('[VersionService] Normal run - dialog disabled by user');
      return false;
    }

    Logger.info('[VersionService] Normal run - dialog enabled, showing What\'s New');
    return true;
  }

  /// Extract version without build number (e.g., "0.1.0+5" -> "0.1.0")
  String _extractVersion(String fullVersion) {
    final parts = fullVersion.split('+');
    return parts.isNotEmpty ? parts[0] : fullVersion;
  }

  /// Disable the "What's New" dialog permanently
  Future<void> disableWhatsNewDialog() async {
    try {
      final currentConfig = await ConfigService.load().then((result) => result.unwrap());
      final currentVersion = await getCurrentVersion();

      Logger.info('[VersionService] Disabling What\'s New dialog');
      Logger.info('[VersionService] Current version: $currentVersion');
      Logger.info('[VersionService] Current config.disableWhatsNewDialog: ${currentConfig.disableWhatsNewDialog}');
      Logger.info('[VersionService] Current config.lastSeenVersion: ${currentConfig.lastSeenVersion}');

      final updatedConfig = currentConfig.copyWith(
        disableWhatsNewDialog: true,
        lastSeenVersion: currentVersion, // Mark current version as seen
      );

      await ConfigService.save(updatedConfig).then((result) => result.unwrap());

      // Verify it was saved
      final verifyConfig = await ConfigService.load().then((result) => result.unwrap());
      Logger.info('[VersionService] Verified saved config.disableWhatsNewDialog: ${verifyConfig.disableWhatsNewDialog}');
      Logger.info('[VersionService] Verified saved config.lastSeenVersion: ${verifyConfig.lastSeenVersion}');
      Logger.info('[VersionService] Disabled What\'s New dialog successfully');
    } catch (e, stack) {
      Logger.error('[VersionService] Failed to disable What\'s New dialog', e, stack);
      rethrow;
    }
  }

  /// Re-enable the "What's New" dialog
  Future<void> enableWhatsNewDialog() async {
    try {
      final config = await ConfigService.load().then((result) => result.unwrap());
      final updatedConfig = config.copyWith(disableWhatsNewDialog: false);
      await ConfigService.save(updatedConfig).then((result) => result.unwrap());
      Logger.debug('Enabled What\'s New dialog');
    } catch (e, stack) {
      Logger.error('Failed to enable What\'s New dialog', e, stack);
    }
  }

  /// Reset the last seen version to force the changelog dialog to show on next start
  Future<void> resetLastSeenVersion() async {
    try {
      final config = await ConfigService.load().then((result) => result.unwrap());
      final updatedConfig = config.copyWith(lastSeenVersion: null);
      await ConfigService.save(updatedConfig).then((result) => result.unwrap());
      Logger.debug('Reset last seen version - changelog will show on next start');
    } catch (e, stack) {
      Logger.error('Failed to reset last seen version', e, stack);
    }
  }
}
