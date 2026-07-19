import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart' as crypto;
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

  /// SHA-256 of the published archive, lower-case hex.
  ///
  /// Null when the manifest predates digest publishing. The updater refuses to
  /// install in that case rather than trusting an unverified download.
  final String? sha256;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.releaseDate,
    required this.fileSize,
    required this.platform,
    this.sha256,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['downloadUrl'] as String,
      changelog: json['changelog'] as String? ?? '',
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      fileSize: json['fileSize'] as int? ?? 0,
      platform: json['platform'] as String? ?? 'unknown',
      sha256: json['sha256'] as String?,
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
  /// Published releases of the project, newest first.
  static const String _releasesUrl =
      'https://api.github.com/repos/kartalbas/flutter-gitui/releases';

  /// Get platform-specific manifest file name
  static String get _manifestFileName {
    if (Platform.isWindows) {
      return 'latest-windows.json';
    } else if (Platform.isLinux) {
      return 'latest-linux.json';
    }
    return 'latest.json'; // fallback
  }

  /// Download URL of the release asset called [name], null when absent.
  static String? _assetUrl(List<dynamic> assets, String name) {
    for (final asset in assets) {
      if (asset is Map<String, dynamic> && asset['name'] == name) {
        return asset['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// Check for updates
  /// Returns Result\<UpdateInfo?\> - Success(UpdateInfo) if update available, Success(null) if up-to-date, Failure on error
  static Future<Result<UpdateInfo?>> checkForUpdates() async {
    return runCatchingAsync(() async {
      Logger.info('Checking for updates...');

      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      final fullVersion = '$currentVersion+$currentBuild';
      Logger.info('Current version: $fullVersion');

      // A build whose own version carries a pre-release suffix stays on the
      // pre-release channel, a final build only ever sees final releases.
      // Deriving the channel from the running version is what keeps a stable
      // install from being offered an alpha, with nothing to configure.
      final acceptPreRelease = _preReleaseIdentifiers(
        currentVersion,
      ).isNotEmpty;

      final releasesResponse = await http
          .get(
            Uri.parse(_releasesUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (releasesResponse.statusCode != 200) {
        Logger.warning(
          'Failed to list releases: ${releasesResponse.statusCode}',
        );
        throw Exception(
          'Failed to fetch releases: HTTP ${releasesResponse.statusCode}',
        );
      }

      final releases =
          json.decode(utf8.decode(releasesResponse.bodyBytes)) as List<dynamic>;

      // A draft is neither listed here nor serves its assets, so publishing the
      // draft is the step that makes a release reachable by the updater.
      Map<String, dynamic>? release;
      for (final entry in releases) {
        if (entry is! Map<String, dynamic>) continue;
        if (entry['draft'] == true) continue;
        if (!acceptPreRelease && entry['prerelease'] == true) continue;
        release = entry;
        break;
      }

      if (release == null) {
        Logger.info('✓ No published release for this channel');
        return null;
      }

      // Manifest and archive are both read from this one release, so the
      // digest can never end up describing bytes from a different build.
      final assets = release['assets'] as List<dynamic>? ?? const <dynamic>[];
      final manifestUrl = _assetUrl(assets, _manifestFileName);
      if (manifestUrl == null) {
        Logger.warning('Release ${release['tag_name']} has no manifest asset');
        throw Exception(
          'Failed to fetch update manifest: the latest release publishes no '
          '$_manifestFileName.',
        );
      }

      Logger.info('Manifest URL: $manifestUrl');
      final response = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 10));

      Logger.info('Manifest response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        Logger.warning(
          'Failed to fetch update manifest: ${response.statusCode}',
        );
        Logger.warning('Response body: ${response.body}');
        throw Exception(
          'Failed to fetch update manifest: HTTP ${response.statusCode}',
        );
      }

      Logger.info('Manifest fetched successfully, parsing...');

      // Parse manifest with explicit UTF-8 decoding for proper emoji/special character support
      final jsonString = utf8.decode(response.bodyBytes);
      final manifestData = json.decode(jsonString) as Map<String, dynamic>;
      final latestVersion = manifestData['version'] as String;

      Logger.info('Latest version from manifest: $latestVersion');
      Logger.info('Comparing with current: $fullVersion');

      // Compare versions
      if (isNewerVersion(latestVersion, fullVersion)) {
        Logger.info('✓ New version available: $latestVersion > $fullVersion');

        // Determine platform from manifest
        final String platform;
        final String downloadFileName;
        final Map<String, dynamic>? platformData;

        if (Platform.isWindows) {
          platform = 'windows';
          platformData = manifestData['windows'] as Map<String, dynamic>?;
          downloadFileName =
              platformData?['fileName'] as String? ??
              'flutter-gitui-v$latestVersion-windows.zip';
        } else if (Platform.isLinux) {
          platform = 'linux';
          platformData = manifestData['linux'] as Map<String, dynamic>?;
          downloadFileName =
              platformData?['fileName'] as String? ??
              'flutter-gitui-v$latestVersion-linux.zip';
        } else {
          // Only Windows and Linux publish release archives and can install
          // them; offering an update anywhere else would end in a multi-MB
          // download that can never be applied.
          Logger.warning('Unsupported platform for updates');
          throw Exception('Unsupported platform for updates');
        }

        // The manifest is remote input; anything but a plain basename could
        // escape the temp directory or the generated update script.
        if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(downloadFileName)) {
          Logger.warning('Rejected manifest fileName: $downloadFileName');
          throw Exception(
            'Update rejected: the release manifest fileName is not a valid '
            'archive name.',
          );
        }

        final downloadUrl = _assetUrl(assets, downloadFileName);
        if (downloadUrl == null) {
          Logger.warning('Release asset not found: $downloadFileName');
          throw Exception(
            'Update rejected: the release publishes no $downloadFileName '
            'asset.',
          );
        }
        final fileSize = platformData?['fileSize'] as int? ?? 0;
        final sha256Digest = platformData?['sha256'] as String?;

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
          sha256: sha256Digest,
        );
      } else {
        Logger.info('✓ App is up to date ($fullVersion >= $latestVersion)');
        return null;
      }
    });
  }

  /// Whether [newVersion] takes precedence over [currentVersion].
  ///
  /// Ordering follows semantic versioning precedence, pre-release identifiers
  /// included: 0.5.0-alpha < 0.5.0-alpha.2 < 0.5.0-beta < 0.5.0. Treating a
  /// pre-release as its bare release instead would leave everyone running
  /// 0.5.0-alpha permanently "up to date" and never offer them 0.5.0.
  static bool isNewerVersion(String newVersion, String currentVersion) {
    final newParts = _releaseParts(newVersion);
    final currentParts = _releaseParts(currentVersion);

    // Compare major, minor, patch
    for (var i = 0; i < 3; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    final preRelease = _comparePreRelease(
      _preReleaseIdentifiers(newVersion),
      _preReleaseIdentifiers(currentVersion),
    );
    if (preRelease != 0) return preRelease > 0;

    // Builds between two tags share major.minor.patch and differ only in the
    // build number, so ignoring it would report every one of them as current.
    // It breaks a tie only: precedence above never depends on it.
    return _buildNumber(newVersion) > _buildNumber(currentVersion);
  }

  /// Pre-release identifiers of a version, empty for a final release.
  static List<String> _preReleaseIdentifiers(String version) {
    // Build metadata ('+42') carries no precedence and may itself contain '-'.
    final release = version.split('+')[0];
    final separator = release.indexOf('-');
    if (separator < 0) return const <String>[];
    final preRelease = release.substring(separator + 1);
    if (preRelease.isEmpty) return const <String>[];
    return preRelease.split('.');
  }

  /// Semantic versioning precedence of two pre-release identifier lists.
  ///
  /// Negative when [a] ranks below [b], positive when it ranks above, zero
  /// when the two are equal.
  static int _comparePreRelease(List<String> a, List<String> b) {
    // A pre-release always ranks below the release it leads up to.
    if (a.isEmpty || b.isEmpty) {
      if (a.isEmpty && b.isEmpty) return 0;
      return a.isEmpty ? 1 : -1;
    }

    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) continue;
      final left = _identifierNumber(a[i]);
      final right = _identifierNumber(b[i]);
      if (left != null && right != null) return left.compareTo(right);
      // A numeric identifier always ranks below an alphanumeric one.
      if (left != null) return -1;
      if (right != null) return 1;
      return a[i].compareTo(b[i]);
    }

    // Every shared identifier matched, so the longer list is the later one.
    return a.length.compareTo(b.length);
  }

  /// Numeric value of a pre-release identifier, null when it is alphanumeric.
  ///
  /// Digits only: int.tryParse would also accept a signed identifier such as
  /// '-1' and sort it below every genuine number.
  static int? _identifierNumber(String identifier) {
    if (identifier.isEmpty) return null;
    for (final unit in identifier.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return null;
    }
    return int.tryParse(identifier);
  }

  /// Major, minor and patch of a version, always exactly three components.
  ///
  /// A shorter version ('1.4') pads with zeros and a pre-release suffix
  /// ('1.4.0-hotfix1') is ordered separately by [_comparePreRelease], so a
  /// slightly nonstandard manifest version still compares instead of aborting.
  /// Anything genuinely unparseable throws: reporting it as "not newer" would
  /// leave every client permanently on "up to date" with nothing but a log line
  /// to show for it.
  static List<int> _releaseParts(String version) {
    // Build metadata ('+42') is ordered separately by _buildNumber.
    final release = version.split('+')[0].split('-')[0];
    final components = release.split('.');
    if (components.length > 3) {
      throw FormatException('Unsupported version format: $version');
    }
    final parts = <int>[0, 0, 0];
    for (var i = 0; i < components.length; i++) {
      final value = int.tryParse(components[i]);
      if (value == null) {
        throw FormatException('Unsupported version format: $version');
      }
      parts[i] = value;
    }
    return parts;
  }

  /// Numeric build component of a version, 0 when absent or non-numeric.
  static int _buildNumber(String version) {
    final parts = version.split('+');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
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
      // Refuse to download at all when the manifest publishes no digest: the
      // archive would be installed unverified, so whoever can write to the
      // release storage would get code execution on every client.
      final expected = updateInfo.sha256?.trim().toLowerCase();
      if (expected == null || expected.length != 64) {
        throw Exception(
          'Update rejected: the release manifest publishes no SHA-256 digest, '
          'so the download cannot be verified.',
        );
      }

      final tempDir = await getTemporaryDirectory();
      // basename() so a crafted manifest cannot walk out of the temp directory.
      final fileName = path.basename(Uri.parse(updateInfo.downloadUrl).path);
      final filePath = path.join(tempDir.path, fileName);

      // Download file with progress tracking
      final request = http.Request('GET', Uri.parse(updateInfo.downloadUrl));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        Logger.error(
          'Failed to download update: ${streamedResponse.statusCode}',
        );
        throw Exception(
          'Failed to download update: HTTP ${streamedResponse.statusCode}',
        );
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int downloaded = 0;
      final contentLength = streamedResponse.contentLength ?? 0;

      try {
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloaded += chunk.length;

          if (contentLength > 0 && onProgress != null) {
            final progress = downloaded / contentLength;
            onProgress(progress);
          }
        }

        await sink.close();
      } catch (_) {
        // Close before deleting: an open sink keeps the temp file locked on
        // Windows, so the delete and any retry would fail with a sharing
        // violation.
        try {
          await sink.close();
        } catch (_) {
          // The original transfer error is what matters.
        }
        try {
          await file.delete();
        } catch (_) {
          // Best effort; the transfer failure is what matters.
        }
        rethrow;
      }

      // A truncated body can end the stream without throwing; reject it here
      // so the digest check reports tampering, not mere network trouble.
      if ((contentLength > 0 && downloaded != contentLength) ||
          (updateInfo.fileSize > 0 && downloaded != updateInfo.fileSize)) {
        try {
          await file.delete();
        } catch (_) {
          // Best effort; the incomplete transfer is what matters.
        }
        throw Exception(
          'Update rejected: incomplete download ($downloaded bytes received).',
        );
      }

      // Verify before the archive is ever handed to the installer.
      final actual = (await crypto.sha256.bind(file.openRead()).first)
          .toString()
          .toLowerCase();
      if (actual != expected) {
        Logger.error('Update digest mismatch: expected $expected, got $actual');
        try {
          await file.delete();
        } catch (_) {
          // Best effort; the mismatch is what matters.
        }
        throw Exception(
          'Update rejected: the downloaded archive does not match the '
          'published SHA-256 digest.',
        );
      }

      Logger.info('Update downloaded and verified: $filePath');
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
      } else {
        Logger.warning('Update installation not supported on this platform');
        throw Exception('Update installation not supported on this platform');
      }
    });
  }

  /// Launch a process in detached mode
  /// This prevents the process from being tied to the parent's lifecycle
  static Future<bool> _launchDetached(
    String exePath,
    List<String> args,
    String workingDir,
  ) async {
    try {
      Logger.info(
        'Launching: $exePath with args: ${args.join(" ")}',
        forceConsole: true,
      );

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
      Logger.info(
        'Zip file exists: ${File(zipFilePath).existsSync()}',
        forceConsole: true,
      );

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
      Logger.info(
        'Updater exists: ${File(updaterPath).existsSync()}',
        forceConsole: true,
      );

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
        final success = await _launchDetached(updaterPath, [
          zipFilePath,
          exePath,
          currentPid.toString(),
        ], rootDir);

        if (!success) {
          Logger.error('Failed to launch updater', null, null, true);
          return false;
        }

        Logger.info(
          'Main app will now exit to allow update',
          forceConsole: true,
        );
        return true;
      } else {
        // Fallback to batch script method
        Logger.warning('⚠ Updater.exe not found at: $updaterPath');
        Logger.info('Using fallback batch script method', forceConsole: true);

        final updateScriptPath = path.join(appDir, '_update.bat');
        // cmd expands %VAR% even inside double quotes and drops stray percent
        // signs, so every path reaching the batch file has to double them --
        // including the PowerShell arguments, which cmd parses first.
        String cmdEscape(String value) => value.replaceAll('%', '%%');
        // Apostrophes are legal in Windows paths and would terminate the
        // single-quoted PowerShell strings early; doubling them keeps each
        // path one literal.
        final psZipFilePath = cmdEscape(zipFilePath.replaceAll("'", "''"));
        // The archive is laid out relative to the root, so a universal build
        // must extract into rootDir; extracting into windows/ would nest a
        // second windows/ inside it and leave the real files untouched.
        final psRootDir = cmdEscape(rootDir.replaceAll("'", "''"));
        final cmdZipFilePath = cmdEscape(zipFilePath);
        final cmdExePath = cmdEscape(exePath);
        final updateScript =
            '''
@echo off
echo =========================================
echo Flutter GitUI Update
echo =========================================
echo.
echo Waiting for application to close...
rem timeout.exe needs a console stdin, which this detached script does not have,
rem so it would abort instantly and let extraction race the still-running app.
rem Poll the app PID like updater.exe does and sleep with ping instead.
set _tries=0
:waitloop
tasklist /FI "PID eq $pid" /NH 2>nul | find "$pid" >nul
if errorlevel 1 goto closed
set /a _tries+=1
if %_tries% geq 30 goto closed
ping -n 2 127.0.0.1 >nul
goto waitloop
:closed

echo Extracting update...
powershell -Command "Expand-Archive -Path '$psZipFilePath' -DestinationPath '$psRootDir' -Force"
if errorlevel 1 (
  rem No console is attached, so pause would linger forever in a hidden window.
  echo ERROR: Failed to extract update!>>"%~dp0_update_error.log"
  exit /b 1
)

echo Cleaning up...
del "$cmdZipFilePath" 2>nul

echo Update complete! Restarting Flutter GitUI...
start "" "$cmdExePath"

echo.
echo Deleting update script...
ping -n 3 127.0.0.1 >nul
del "%~f0"
''';

        await File(updateScriptPath).writeAsString(updateScript);

        // Run update script in detached process
        await Process.start('cmd.exe', [
          '/c',
          updateScriptPath,
        ], mode: ProcessStartMode.detached);

        Logger.info(
          'Update script started, exiting app...',
          forceConsole: true,
        );
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
        final success = await _launchDetached(updaterPath, [
          zipFilePath,
          exePath,
          currentPid.toString(),
        ], rootDir);

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
        // The archive is laid out relative to the root, so a universal build
        // must extract into rootDir; extracting into linux/ would nest a
        // second linux/ inside it and leave the real files untouched.
        final updateScript =
            '''
#!/bin/bash
echo "========================================="
echo "Flutter GitUI Update"
echo "========================================="
echo ""
echo "Waiting for application to close..."
sleep 3

echo "Extracting update..."
unzip -o "$zipFilePath" -d "$rootDir"
if [ \$? -ne 0 ]; then
  echo "ERROR: Failed to extract update!"
  read -p "Press Enter to exit..."
  exit 1
fi

echo "Setting permissions..."
# Restore the exec bit on the binary that is relaunched below; archives zipped
# on Windows CI lose file modes, and hardcoded name guesses miss both the
# standard and the universal layout.
chmod +x "$exePath"

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
        await Process.start('/bin/bash', [
          updateScriptPath,
        ], mode: ProcessStartMode.detached);

        Logger.info('Update script started, exiting app...');
        return true;
      }
    } catch (e, stackTrace) {
      Logger.error('Error installing Linux update', e, stackTrace);
      return false;
    }
  }
}
