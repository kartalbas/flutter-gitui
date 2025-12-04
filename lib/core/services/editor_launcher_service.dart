import 'dart:io';

import 'logger_service.dart';
import '../config/config_service.dart';

/// Service for launching external text editors
///
/// Handles platform-specific path resolution and process launching.
/// On Windows, automatically resolves paths without extensions to .cmd/.exe/.bat
class EditorLauncherService {
  /// Launch an editor with a file or folder path
  ///
  /// Resolves platform-specific executable paths before launching.
  /// Throws an exception if the editor fails to launch.
  static Future<void> launch({
    required String editorPath,
    required String targetPath,
  }) async {
    // Resolve to platform-specific executable
    final resolvedPath = _resolveExecutablePath(editorPath);

    // Verify the resolved path exists
    if (!File(resolvedPath).existsSync()) {
      final message = Platform.isWindows
          ? 'Editor executable not found: $editorPath\n'
              'Tried: $editorPath.cmd, $editorPath.exe, $editorPath.bat\n'
              'On Windows, editor paths must end with .exe, .cmd, or .bat\n'
              'Please update your editor path in Settings'
          : 'Editor not found: $editorPath\n'
              'Please update your editor path in Settings';

      Logger.error('Editor executable not found: $resolvedPath', null);
      throw ProcessException(resolvedPath, [], message);
    }

    // Launch the editor
    Logger.info('Launching editor: $resolvedPath with target: $targetPath');
    await Process.start(
      resolvedPath,
      [targetPath],
      mode: ProcessStartMode.detached,
    );
  }

  /// Resolve editor paths to valid executables (platform-specific)
  ///
  /// WINDOWS: If path lacks .exe/.cmd/.bat, tries adding them in order
  /// Example: .../bin/code → .../bin/code.cmd
  ///
  /// LINUX/MACOS: Returns path as-is (shell scripts work directly)
  static String _resolveExecutablePath(String path) {
    // LINUX/MACOS: No changes needed, shell scripts work
    if (!Platform.isWindows) {
      return path;
    }

    // WINDOWS ONLY: Must have executable extension

    // If path already has Windows executable extension, return as-is
    if (path.endsWith('.exe') ||
        path.endsWith('.cmd') ||
        path.endsWith('.bat')) {
      return path;
    }

    // Try common Windows executable extensions in order
    // .cmd first (most common for CLI wrappers like VS Code)
    // .exe second (actual executables)
    // .bat last (batch scripts)
    final extensions = ['.cmd', '.exe', '.bat'];

    for (final ext in extensions) {
      final pathWithExt = '$path$ext';
      if (File(pathWithExt).existsSync()) {
        Logger.info('[Windows] Resolved editor executable: $path → $pathWithExt');
        return pathWithExt;
      }
    }

    // No executable found with common extensions
    Logger.warning('[Windows] Could not find executable for: $path');
    Logger.warning('[Windows] Tried: ${extensions.map((e) => '$path$e').join(', ')}');

    return path; // Return original, will fail with clear error in launch()
  }

  /// Launch editor using the text editor from config
  /// Convenience method that automatically gets editor from settings
  static Future<void> launchWithConfigEditor(String targetPath) async {
    try {
      final config = await ConfigService.load();
      final editorPath = config.tools.textEditor;

      if (editorPath == null || editorPath.isEmpty) {
        throw Exception('No text editor configured in settings');
      }

      await launch(editorPath: editorPath, targetPath: targetPath);
    } catch (e, stack) {
      Logger.error('Failed to launch editor', e, stack);
      rethrow;
    }
  }

  /// Open app log file with configured editor
  static Future<void> openAppLog() async {
    final logPath = Logger.logFilePath;
    if (logPath == null) {
      throw Exception('Log file path not available');
    }
    await launchWithConfigEditor(logPath);
  }

  /// Open git log file with configured editor
  static Future<void> openGitLog() async {
    final gitLogPath = Logger.gitLogFilePath;
    if (gitLogPath == null) {
      throw Exception('Git log file path not available');
    }
    await launchWithConfigEditor(gitLogPath);
  }
}
