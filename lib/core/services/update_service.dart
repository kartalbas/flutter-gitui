import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import '../utils/result.dart';

/// Update information model
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String changelog;
  final DateTime releaseDate;
  final int fileSize;
  final String platform;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.releaseDate,
    required this.fileSize,
    required this.platform,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['downloadUrl'] as String,
      changelog: json['changelog'] as String? ?? '',
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      fileSize: json['fileSize'] as int? ?? 0,
      platform: json['platform'] as String? ?? 'unknown',
    );
  }

  /// Convert file size to human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service for checking and downloading app updates
class UpdateService {
  static const String _storageAccount = 'fluttergituiartifacts';
  static const String _containerName = 'releases';

  /// Base URL for Azure Blob Storage
  static String get _baseUrl =>
      'https://$_storageAccount.blob.core.windows.net/$_containerName';

  /// Get platform-specific manifest file name
  static String get _manifestFileName {
    if (Platform.isWindows) {
      return 'latest-windows.json';
    } else if (Platform.isLinux) {
      return 'latest-linux.json';
    } else if (Platform.isMacOS) {
      return 'latest-macos.json';
    }
    return 'latest.json'; // fallback
  }

  /// URL for the latest version manifest (platform-specific)
  static String get _manifestUrl => '$_baseUrl/$_manifestFileName';

  /// Check for updates
  /// Returns Result\<UpdateInfo?\> - Success(UpdateInfo) if update available, Success(null) if up-to-date, Failure on error
  static Future<Result<UpdateInfo?>> checkForUpdates() async {
    return runCatchingAsync(() async {
      Logger.info('Checking for updates...');
      Logger.info('Manifest URL: $_manifestUrl');

      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      final fullVersion = '$currentVersion+$currentBuild';
      Logger.info('Current version: $fullVersion');

      // Fetch latest version manifest
      Logger.info('Fetching manifest from Azure...');
      final response = await http.get(Uri.parse(_manifestUrl)).timeout(
        const Duration(seconds: 10),
      );

      Logger.info('Manifest response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        Logger.warning('Failed to fetch update manifest: ${response.statusCode}');
        Logger.warning('Response body: ${response.body}');
        throw Exception('Failed to fetch update manifest: HTTP ${response.statusCode}');
      }

      Logger.info('Manifest fetched successfully, parsing...');

      // Parse manifest with explicit UTF-8 decoding for proper emoji/special character support
      final jsonString = utf8.decode(response.bodyBytes);
      final manifestData = json.decode(jsonString) as Map<String, dynamic>;
      final latestVersion = manifestData['version'] as String;

      Logger.info('Latest version from manifest: $latestVersion');
      Logger.info('Comparing with current: $fullVersion');

      // Compare versions
      if (_isNewerVersion(latestVersion, fullVersion)) {
        Logger.info('✓ New version available: $latestVersion > $fullVersion');

        // Determine platform from manifest
        final String platform;
        final String downloadFileName;
        final Map<String, dynamic>? platformData;

        if (Platform.isWindows) {
          platform = 'windows';
          platformData = manifestData['windows'] as Map<String, dynamic>?;
          downloadFileName = platformData?['fileName'] as String? ?? 'flutter-gitui-v$latestVersion-windows.zip';
        } else if (Platform.isLinux) {
          platform = 'linux';
          platformData = manifestData['linux'] as Map<String, dynamic>?;
          downloadFileName = platformData?['fileName'] as String? ?? 'flutter-gitui-v$latestVersion-linux.zip';
        } else if (Platform.isMacOS) {
          platform = 'macos';
          platformData = manifestData['macos'] as Map<String, dynamic>?;
          downloadFileName = platformData?['fileName'] as String? ?? 'flutter-gitui-v$latestVersion-macos.zip';
        } else {
          Logger.warning('Unsupported platform for updates');
          throw Exception('Unsupported platform for updates');
        }

        final downloadUrl = '$_baseUrl/$downloadFileName';
        final fileSize = platformData?['fileSize'] as int? ?? 0;

        // Get changelog
        final String changelog;
        if (manifestData.containsKey('changelog')) {
          changelog = manifestData['changelog'] as String;
        } else {
          changelog = 'New version available';
        }

        Logger.info('Download URL: $downloadUrl');
        Logger.info('File size: $fileSize bytes');

        return UpdateInfo(
          version: latestVersion,
          downloadUrl: downloadUrl,
          changelog: changelog,
          releaseDate: DateTime.parse(manifestData['releaseDate'] as String),
          fileSize: fileSize,
          platform: platform,
        );
      } else {
        Logger.info('✓ App is up to date ($fullVersion >= $latestVersion)');
        return null;
      }
    });
  }

  /// Compare two semantic version strings
  /// Returns true if newVersion is greater than currentVersion
  static bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      // Remove build number (+xxx) if present
      final newVer = newVersion.split('+')[0];
      final currentVer = currentVersion.split('+')[0];

      final newParts = newVer.split('.').map(int.parse).toList();
      final currentParts = currentVer.split('.').map(int.parse).toList();

      // Compare major, minor, patch
      for (var i = 0; i < 3; i++) {
        if (newParts[i] > currentParts[i]) return true;
        if (newParts[i] < currentParts[i]) return false;
      }

      return false;
    } catch (e) {
      Logger.error('Error comparing versions', e);
      return false;
    }
  }

  /// Download update file
  /// Returns Result\<String\> with path to downloaded file
  static Future<Result<String>> downloadUpdate(
    UpdateInfo updateInfo, {
    void Function(double progress)? onProgress,
  }) async {
    return runCatchingAsync(() async {
      Logger.info('Downloading update from: ${updateInfo.downloadUrl}');

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(Uri.parse(updateInfo.downloadUrl).path);
      final filePath = path.join(tempDir.path, fileName);

      // Download file with progress tracking
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        Logger.error('Failed to download update: ${streamedResponse.statusCode}');
        throw Exception('Failed to download update: HTTP ${streamedResponse.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int downloaded = 0;
      final contentLength = streamedResponse.contentLength ?? 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          final progress = downloaded / contentLength;
          onProgress(progress);
        }
      }

      await sink.close();

      Logger.info('Update downloaded to: $filePath');
      return filePath;
    });
  }

  /// Install downloaded update
  /// This will close the current app and start the installation
  /// Returns Result\<bool\> - true if installation started successfully
  static Future<Result<bool>> installUpdate(String updateFilePath) async {
    return runCatchingAsync(() async {
      if (Platform.isWindows) {
        return await _installWindowsUpdate(updateFilePath);
      } else if (Platform.isLinux) {
        return await _installLinuxUpdate(updateFilePath);
      } else if (Platform.isMacOS) {
        return await _installMacOSUpdate(updateFilePath);
      } else {
        Logger.warning('Update installation not supported on this platform');
        throw Exception('Update installation not supported on this platform');
      }
    });
  }

  /// Launch a process in detached mode
  /// This prevents the process from being tied to the parent's lifecycle
  static Future<bool> _launchDetached(String exePath, List<String> args, String workingDir) async {
    try {
      Logger.info('Launching: $exePath with args: ${args.join(" ")}', forceConsole: true);

      await Process.start(
        exePath,
        args,
        mode: ProcessStartMode.detached,
        workingDirectory: workingDir,
      );

      Logger.info('✓ Process launched successfully', forceConsole: true);
      return true;
    } catch (e, stackTrace) {
      Logger.error('Error launching process', e, stackTrace, true);
      return false;
    }
  }

  /// Install Windows update (.zip file)
  static Future<bool> _installWindowsUpdate(String zipFilePath) async {
    try {
      // Get app installation directory
      final exePath = Platform.resolvedExecutable;
      var appDir = path.dirname(exePath);

      Logger.info('=== Windows Update Installation ===', forceConsole: true);
      Logger.info('Executable path: $exePath', forceConsole: true);
      Logger.info('App directory: $appDir', forceConsole: true);
      Logger.info('Zip file path: $zipFilePath', forceConsole: true);
      Logger.info('Zip file exists: ${File(zipFilePath).existsSync()}', forceConsole: true);

      // Detect universal build structure
      // If running from windows/ or linux/ subdirectory, go up one level to find root
      final parentDirName = path.basename(appDir);
      String rootDir;
      String updaterPath;

      if (parentDirName == 'windows' || parentDirName == 'linux') {
        // Universal build: we're in windows/ or linux/ subdirectory
        rootDir = path.dirname(appDir);
        updaterPath = path.join(appDir, 'updater.exe');
        Logger.info('✓ Universal build detected', forceConsole: true);
        Logger.info('  Root directory: $rootDir', forceConsole: true);
        Logger.info('  Platform directory: $appDir', forceConsole: true);
      } else {
        // Standard build: app is in root directory
        rootDir = appDir;
        updaterPath = path.join(appDir, 'updater.exe');
        Logger.info('✓ Standard build detected', forceConsole: true);
      }

      Logger.info('Looking for updater at: $updaterPath', forceConsole: true);
      Logger.info('Updater exists: ${File(updaterPath).existsSync()}', forceConsole: true);

      if (File(updaterPath).existsSync()) {
        // Use dedicated updater executable (preferred method)
        Logger.info('✓ Using dedicated updater executable', forceConsole: true);

        // Get current process ID
        final currentPid = pid;
        Logger.info('Current process ID: $currentPid', forceConsole: true);

        // Launch updater with arguments: <zip_path> <app_exe_path> <pid>
        Logger.info('Launching updater with arguments:', forceConsole: true);
        Logger.info('  [0] Zip path: $zipFilePath', forceConsole: true);
        Logger.info('  [1] Exe path: $exePath', forceConsole: true);
        Logger.info('  [2] PID: $currentPid', forceConsole: true);

        // Launch updater in detached mode
        final success = await _launchDetached(
          updaterPath,
          [zipFilePath, exePath, currentPid.toString()],
          rootDir,
        );

        if (!success) {
          Logger.error('Failed to launch updater', null, null, true);
          return false;
        }

        Logger.info('Main app will now exit to allow update', forceConsole: true);
        return true;
      } else {
        // Fallback to batch script method
        Logger.warning('⚠ Updater.exe not found at: $updaterPath');
        Logger.info('Using fallback batch script method', forceConsole: true);

        final updateScriptPath = path.join(appDir, '_update.bat');
        final updateScript = '''
@echo off
echo =========================================
echo Flutter GitUI Update
echo =========================================
echo.
echo Waiting for application to close...
timeout /t 3 /nobreak >nul

echo Extracting update...
powershell -Command "Expand-Archive -Path '$zipFilePath' -DestinationPath '$appDir' -Force"
if errorlevel 1 (
  echo ERROR: Failed to extract update!
  pause
  exit /b 1
)

echo Cleaning up...
del "$zipFilePath" 2>nul

echo Update complete! Restarting Flutter GitUI...
start "" "$exePath"

echo.
echo Deleting update script...
timeout /t 2 /nobreak >nul
del "%~f0"
''';

        await File(updateScriptPath).writeAsString(updateScript);

        // Run update script in detached process
        await Process.start(
          'cmd.exe',
          ['/c', updateScriptPath],
          mode: ProcessStartMode.detached,
        );

        Logger.info('Update script started, exiting app...', forceConsole: true);
        return true;
      }
    } catch (e, stackTrace) {
      Logger.error('Error installing Windows update', e, stackTrace, true);
      return false;
    }
  }

  /// Install Linux update (.zip file)
  static Future<bool> _installLinuxUpdate(String zipFilePath) async {
    try {
      // Get app installation directory
      final exePath = Platform.resolvedExecutable;
      var appDir = path.dirname(exePath);

      Logger.info('=== Linux Update Installation ===');
      Logger.info('Executable path: $exePath');
      Logger.info('App directory: $appDir');
      Logger.info('Zip file path: $zipFilePath');
      Logger.info('Zip file exists: ${File(zipFilePath).existsSync()}');

      // Detect universal build structure
      // If running from windows/ or linux/ subdirectory, go up one level to find root
      final parentDirName = path.basename(appDir);
      String rootDir;
      String updaterPath;

      if (parentDirName == 'windows' || parentDirName == 'linux') {
        // Universal build: we're in windows/ or linux/ subdirectory
        rootDir = path.dirname(appDir);
        updaterPath = path.join(appDir, 'updater');
        Logger.info('✓ Universal build detected');
        Logger.info('  Root directory: $rootDir');
        Logger.info('  Platform directory: $appDir');
      } else {
        // Standard build: app is in root directory
        rootDir = appDir;
        updaterPath = path.join(appDir, 'updater');
        Logger.info('✓ Standard build detected');
      }

      Logger.info('Looking for updater at: $updaterPath');
      Logger.info('Updater exists: ${File(updaterPath).existsSync()}');

      if (File(updaterPath).existsSync()) {
        // Use dedicated updater executable (preferred method)
        Logger.info('✓ Using dedicated updater executable');

        // Get current process ID
        final currentPid = pid;
        Logger.info('Current process ID: $currentPid');

        // Launch updater with arguments: <zip_path> <app_exe_path> <pid>
        Logger.info('Launching updater with arguments:');
        Logger.info('  [0] Zip path: $zipFilePath');
        Logger.info('  [1] Exe path: $exePath');
        Logger.info('  [2] PID: $currentPid');

        // Launch updater in detached mode
        final success = await _launchDetached(
          updaterPath,
          [zipFilePath, exePath, currentPid.toString()],
          rootDir,
        );

        if (!success) {
          Logger.error('Failed to launch updater');
          return false;
        }

        Logger.info('Main app will now exit to allow update');
        return true;
      } else {
        // Fallback to shell script method
        Logger.info('Updater not found, using fallback shell script');

        final updateScriptPath = path.join(appDir, '_update.sh');
        final updateScript = '''
#!/bin/bash
echo "========================================="
echo "Flutter GitUI Update"
echo "========================================="
echo ""
echo "Waiting for application to close..."
sleep 3

echo "Extracting update..."
unzip -o "$zipFilePath" -d "$appDir"
if [ \$? -ne 0 ]; then
  echo "ERROR: Failed to extract update!"
  read -p "Press Enter to exit..."
  exit 1
fi

echo "Setting permissions..."
chmod +x "$appDir/flutter-gitui"
chmod +x "$appDir/linux/flutter_gitui"

echo "Cleaning up..."
rm "$zipFilePath" 2>/dev/null

echo "Update complete! Restarting Flutter GitUI..."
"$exePath" &

echo ""
echo "Deleting update script..."
sleep 2
rm "\$0"
''';

        final scriptFile = File(updateScriptPath);
        await scriptFile.writeAsString(updateScript);

        // Make script executable
        await Process.run('chmod', ['+x', updateScriptPath]);

        // Run update script in detached process
        await Process.start(
          '/bin/bash',
          [updateScriptPath],
          mode: ProcessStartMode.detached,
        );

        Logger.info('Update script started, exiting app...');
        return true;
      }
    } catch (e, stackTrace) {
      Logger.error('Error installing Linux update', e, stackTrace);
      return false;
    }
  }

  /// Install macOS update (.dmg or .zip file)
  static Future<bool> _installMacOSUpdate(String updateFilePath) async {
    try {
      // macOS update process typically involves:
      // 1. Mount DMG
      // 2. Copy app to /Applications
      // 3. Restart

      Logger.warning('macOS update installation not yet implemented');
      return false;
    } catch (e, stackTrace) {
      Logger.error('Error installing macOS update', e, stackTrace);
      return false;
    }
  }
}
