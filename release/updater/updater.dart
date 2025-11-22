// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

// Log file - uses the same app.log as the main application
File? _logFile;

/// Write message to app.log (same as main application)
void _log(String message) {
  if (_logFile != null) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [FlutterGitUI] [UPDATER] $message\n';
    try {
      _logFile!.writeAsStringSync(logEntry, mode: FileMode.append, flush: true);
    } catch (e) {
      // Silently ignore file write errors
    }
  }
}

/// Initialize logging to app.log (same file as main application)
void _initLog() {
  try {
    // Get user's home directory
    String home;
    if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '';
    } else {
      home = Platform.environment['HOME'] ?? '';
    }

    if (home.isEmpty) {
      // Can't determine home directory, continue without logging
      return;
    }

    // Use the same config directory as the main app
    final configDir = path.join(home, '.flutter-gitui');
    final logPath = path.join(configDir, 'app.log');

    _logFile = File(logPath);

    // Log initialization message
    final timestamp = DateTime.now().toIso8601String();
    _logFile!.writeAsStringSync(
      '[$timestamp] [FlutterGitUI] [UPDATER] Log initialized\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (e) {
    // If we can't initialize logging, continue without it
  }
}

/// Dedicated updater executable for Flutter GitUI
///
/// This runs as a separate process after the main app exits.
/// It extracts the update zip and restarts the application.
///
/// Usage:
///   updater.exe `<zip_path>` `<app_exe_path>` `<pid>`
///
/// Arguments:
///   zip_path    - Path to the downloaded update zip file
///   app_exe_path - Path to the application executable to restart
///   pid         - Process ID of the main app (to wait for it to exit)
void main(List<String> args) async {
  if (args.length != 3) {
    exit(1);
  }

  final zipPath = args[0];
  final appExePath = args[1];
  final pid = int.tryParse(args[2]);

  // Determine root directory
  // The appExePath could be either:
  // - windows/flutter_gitui.exe (platform build with subdirectory)
  // - flutter_gitui.exe (flat build)
  var appDir = path.dirname(appExePath);
  final parentDirName = path.basename(appDir);

  String rootDir;
  if (parentDirName == 'windows' || parentDirName == 'linux') {
    // Platform build - root is parent directory
    rootDir = path.dirname(appDir);
  } else {
    // Flat build - root is same directory
    rootDir = appDir;
  }

  // Initialize logging to app.log (same as main application)
  _initLog();

  _log('');
  _log('=========================================');
  _log('Flutter GitUI Updater');
  _log('=========================================');
  _log('');
  _log('Zip file: $zipPath');
  _log('App path: $appExePath');
  _log('App PID:  $pid');
  _log('Root directory: $rootDir');
  _log('');

  try {
    // Step 1: Verify files exist
    _log('[1/5] Verifying files...');
    if (!File(zipPath).existsSync()) {
      throw Exception('Update zip file not found: $zipPath');
    }
    if (!File(appExePath).existsSync()) {
      throw Exception('Application executable not found: $appExePath');
    }
    _log('      ✓ Files verified');
    _log('');

    // Step 2: Wait for main app to exit
    _log('[2/5] Waiting for application to close...');
    if (pid != null) {
      await _waitForProcessToExit(pid, timeout: Duration(seconds: 30));
      _log('      ✓ Application closed');
    } else {
      _log('      ! No PID provided, waiting 3 seconds...');
      await Future.delayed(Duration(seconds: 3));
    }
    _log('');

    // Step 3: Extract update
    _log('[3/5] Extracting update...');

    // Determine correct extraction directory
    // For platform builds, the executable is in windows/ or linux/ subdirectory
    // We need to extract to the root directory
    var extractDir = path.dirname(appExePath);
    final dirName = path.basename(extractDir);

    if (dirName == 'windows' || dirName == 'linux') {
      // Platform build structure detected - go up one level
      extractDir = path.dirname(extractDir);
      _log('      Detected platform build structure');
      _log('      Extracting to root: $extractDir');
    } else {
      _log('      Extracting to: $extractDir');
    }

    final skippedUpdater = await _extractZip(zipPath, extractDir);
    _log('      ✓ Update extracted to: $extractDir');
    if (skippedUpdater) {
      _log('      ℹ Note: Updater itself was skipped (will be updated on next cycle)');
    }
    _log('');

    // Step 4: Clean up
    _log('[4/5] Cleaning up...');
    try {
      File(zipPath).deleteSync();
      _log('      ✓ Removed temporary files');
    } catch (e) {
      _log('      ! Could not delete zip file: $e');
    }
    _log('');

    // Step 5: Restart application
    _log('[5/5] Restarting application...');

    // Restart the application executable directly
    String restartPath = appExePath;
    _log('      Restarting: $restartPath');

    await Process.start(
      restartPath,
      [],
      mode: ProcessStartMode.detached,
      workingDirectory: extractDir,
    );
    _log('      ✓ Application restarted');
    _log('');
    _log('=========================================');
    _log('Update completed successfully!');
    _log('=========================================');
    _log('');

    // Give it a moment to start
    await Future.delayed(Duration(seconds: 1));

  } catch (e, stackTrace) {
    _log('');
    _log('ERROR: Update failed!');
    _log('');
    _log('Error details:');
    _log(e.toString());
    _log('');
    _log('Stack trace:');
    _log(stackTrace.toString());
    _log('');
    // Don't wait for input when running without console window
    exit(1);
  }
}

/// Wait for a process to exit by checking if it's still running
Future<void> _waitForProcessToExit(int pid, {Duration timeout = const Duration(seconds: 30)}) async {
  final startTime = DateTime.now();

  while (DateTime.now().difference(startTime) < timeout) {
    try {
      if (Platform.isWindows) {
        // Check if process is still running
        final result = await Process.run('tasklist', ['/FI', 'PID eq $pid', '/NH']);
        if (!result.stdout.toString().contains('$pid')) {
          // Process has exited
          return;
        }
      } else {
        // Linux/Mac: check if process exists
        final result = await Process.run('ps', ['-p', '$pid']);
        if (result.exitCode != 0) {
          // Process has exited
          return;
        }
      }
    } catch (e) {
      // If we can't check, assume it's exited
      return;
    }

    // Wait a bit before checking again
    await Future.delayed(Duration(milliseconds: 500));
  }

  throw Exception('Timeout waiting for application to exit (PID: $pid)');
}

/// Extract a zip file to a destination directory
/// Returns true if the updater itself was skipped
Future<bool> _extractZip(String zipPath, String destinationDir) async {
  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  // Get current updater executable path to skip it during extraction
  final currentExePath = Platform.resolvedExecutable;
  final currentExeRelativePath = path.relative(currentExePath, from: destinationDir);

  _log('Current updater path: $currentExePath');
  _log('Relative path: $currentExeRelativePath');

  bool skippedUpdater = false;

  for (final file in archive) {
    final filename = file.name;
    final filePath = path.join(destinationDir, filename);

    // Normalize paths for comparison (convert forward slashes to platform-specific)
    final normalizedFilename = filename.replaceAll('/', path.separator);

    // Skip the updater executable if it's currently running
    if (normalizedFilename == currentExeRelativePath ||
        filePath == currentExePath) {
      _log('Skipping locked file (updater itself): $filename');
      skippedUpdater = true;
      continue;
    }

    if (file.isFile) {
      final outFile = File(filePath);

      // Ensure parent directory exists
      outFile.parent.createSync(recursive: true);

      // Write file (will overwrite existing)
      try {
        outFile.writeAsBytesSync(file.content as List<int>);
      } catch (e) {
        // If we can't write a file (locked/in-use), log and skip it
        _log('Warning: Could not write $filename: $e');
        continue;
      }

      // Restore file permissions on Linux/Mac
      if (!Platform.isWindows && file.mode != 0) {
        await Process.run('chmod', [file.mode.toRadixString(8), filePath]);
      }
    } else {
      // Create directory
      Directory(filePath).createSync(recursive: true);
    }
  }

  return skippedUpdater;
}
