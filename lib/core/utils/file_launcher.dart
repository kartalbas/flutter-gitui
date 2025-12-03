import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../services/logger_service.dart';

/// Utility for opening files in external applications
class FileLauncher {
  /// Open a file with the system's default application
  ///
  /// Uses url_launcher with file:// URI to open files in their default app.
  /// Falls back to platform-specific commands if url_launcher fails.
  ///
  /// Returns true if the file was successfully opened, false otherwise.
  static Future<bool> openFileExternally(String filePath) async {
    try {
      Logger.info('Opening file externally: $filePath');

      // Try url_launcher first (cross-platform)
      final uri = Uri.file(filePath);

      if (await canLaunchUrl(uri)) {
        final result = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (result) {
          Logger.info('Successfully opened file with url_launcher: $filePath');
          return true;
        }
      }

      // Fallback: Platform-specific commands
      Logger.info('url_launcher failed, trying platform-specific command');

      if (Platform.isWindows) {
        // Windows: Use start command via cmd
        await Process.start(
          'cmd',
          ['/c', 'start', '', filePath],
          mode: ProcessStartMode.detached,
        );
        Logger.info('Opened file with Windows start command: $filePath');
        return true;
      } else if (Platform.isMacOS) {
        // macOS: Use open command
        await Process.start(
          'open',
          [filePath],
          mode: ProcessStartMode.detached,
        );
        Logger.info('Opened file with macOS open command: $filePath');
        return true;
      } else if (Platform.isLinux) {
        // Linux: Try xdg-open
        await Process.start(
          'xdg-open',
          [filePath],
          mode: ProcessStartMode.detached,
        );
        Logger.info('Opened file with xdg-open: $filePath');
        return true;
      }

      Logger.warning('No method available to open file: $filePath');
      return false;

    } catch (e, stackTrace) {
      Logger.error('Error opening file externally: $filePath', e, stackTrace);
      return false;
    }
  }
}
