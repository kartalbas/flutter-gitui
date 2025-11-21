import 'dart:io';

/// Service for detecting version information from executables
class VersionDetector {
  /// Detect version of an executable
  /// Tries multiple strategies based on platform and tool type
  static Future<String?> detectVersion(String executablePath) async {
    if (!await File(executablePath).exists()) {
      return null;
    }

    // Strategy 1: Platform-specific methods (doesn't launch GUI)
    if (Platform.isWindows) {
      // Windows: Use PowerShell to read .exe version info (doesn't launch GUI)
      final version = await _getWindowsExeVersion(executablePath);
      if (version != null) return version;
    } else if (Platform.isMacOS) {
      // macOS: Check if it's a .app bundle and read Info.plist
      final version = await _getMacOsAppVersion(executablePath);
      if (version != null) return version;
    }

    // Strategy 2: Try --version flag (may launch GUI for some apps)
    String? version = await _tryVersionFlag(executablePath);
    if (version != null) return version;

    // Strategy 3: Try -v flag
    version = await _tryFlag(executablePath, '-v');
    if (version != null) return version;

    // Strategy 4: Try --help and parse for version
    version = await _tryVersionFromHelp(executablePath);
    if (version != null) return version;

    return null;
  }

  /// Try running executable with --version flag
  static Future<String?> _tryVersionFlag(String executablePath) async {
    return _tryFlag(executablePath, '--version');
  }

  /// Try running executable with a specific flag
  static Future<String?> _tryFlag(String executablePath, String flag) async {
    try {
      // Special handling for VS Code - use shell command to avoid launching GUI
      final fileName = executablePath.split(Platform.pathSeparator).last.toLowerCase();
      final isVSCode = fileName.contains('code.exe') || fileName == 'code.exe';

      ProcessResult result;
      if (isVSCode && Platform.isWindows) {
        // Use "code" command via shell to get version without launching GUI
        result = await Process.run(
          'cmd',
          ['/c', 'code', flag],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
      } else {
        result = await Process.run(
          executablePath,
          [flag],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
      }

      if (result.exitCode == 0 || result.exitCode == 1) {
        // Some tools return version on stdout, some on stderr
        final output = result.stdout.toString().trim();
        final errOutput = result.stderr.toString().trim();

        final combined = output.isNotEmpty ? output : errOutput;
        if (combined.isNotEmpty) {
          // Extract version number from output
          return _extractVersion(combined);
        }
      }
    } catch (e) {
      // Ignore errors (timeout, process doesn't support flag, etc.)
    }
    return null;
  }

  /// Get version from Windows .exe file metadata using PowerShell
  static Future<String?> _getWindowsExeVersion(String executablePath) async {
    if (!Platform.isWindows) return null;

    try {
      // Escape path for PowerShell
      final escapedPath = executablePath.replaceAll("'", "''");

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "(Get-Item '$escapedPath').VersionInfo.ProductVersion"
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        if (version.isNotEmpty && version != '0.0.0.0') {
          return version;
        }
      }

      // Also try FileVersion if ProductVersion fails
      final result2 = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "(Get-Item '$escapedPath').VersionInfo.FileVersion"
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));

      if (result2.exitCode == 0) {
        final version = result2.stdout.toString().trim();
        if (version.isNotEmpty && version != '0.0.0.0') {
          return version;
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Get version from macOS .app bundle Info.plist
  static Future<String?> _getMacOsAppVersion(String executablePath) async {
    if (!Platform.isMacOS) return null;

    try {
      // Check if path is inside a .app bundle
      if (executablePath.contains('.app/')) {
        // Extract .app path
        final appPath = executablePath.substring(
          0,
          executablePath.indexOf('.app/') + 4,
        );
        final plistPath = '$appPath/Contents/Info.plist';

        if (await File(plistPath).exists()) {
          // Use PlistBuddy to read version
          final result = await Process.run(
            '/usr/libexec/PlistBuddy',
            ['-c', 'Print :CFBundleShortVersionString', plistPath],
            runInShell: false,
          ).timeout(const Duration(seconds: 2));

          if (result.exitCode == 0) {
            final version = result.stdout.toString().trim();
            if (version.isNotEmpty) {
              return version;
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Try to extract version from --help output
  static Future<String?> _tryVersionFromHelp(String executablePath) async {
    try {
      final result = await Process.run(
        executablePath,
        ['--help'],
        runInShell: false,
      ).timeout(const Duration(seconds: 2));

      final output = result.stdout.toString() + result.stderr.toString();
      return _extractVersion(output);
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Extract version number from text using regex
  static String? _extractVersion(String text) {
    if (text.isEmpty) return null;

    // Common version patterns:
    // - "version 1.2.3"
    // - "v1.2.3"
    // - "1.2.3"
    // - "git version 2.39.0"

    // Pattern 1: "version X.Y.Z" or "Version X.Y.Z"
    final versionPattern1 = RegExp(
      r'[Vv]ersion\s+(\d+\.\d+(?:\.\d+)?(?:\.\d+)?(?:-[\w.]+)?)',
      caseSensitive: false,
    );
    final match1 = versionPattern1.firstMatch(text);
    if (match1 != null) {
      return match1.group(1);
    }

    // Pattern 2: "vX.Y.Z" at start of line
    final versionPattern2 = RegExp(
      r'^v?(\d+\.\d+(?:\.\d+)?(?:\.\d+)?(?:-[\w.]+)?)',
      multiLine: true,
    );
    final match2 = versionPattern2.firstMatch(text);
    if (match2 != null) {
      return match2.group(1);
    }

    // Pattern 3: First occurrence of X.Y.Z pattern
    final versionPattern3 = RegExp(
      r'\b(\d+\.\d+(?:\.\d+)?(?:\.\d+)?(?:-[\w.]+)?)\b',
    );
    final match3 = versionPattern3.firstMatch(text);
    if (match3 != null) {
      final version = match3.group(1)!;
      // Only return if it looks like a reasonable version number
      if (version.split('.').first.length <= 3) {
        return version;
      }
    }

    return null;
  }

  /// Detect version and tool name (for additional validation)
  static Future<ToolVersionInfo?> detectToolInfo(String executablePath) async {
    final version = await detectVersion(executablePath);
    if (version == null) return null;

    final fileName = executablePath.split(Platform.pathSeparator).last.toLowerCase();

    // Try to identify the tool from filename and version output
    String? toolName;

    if (fileName.contains('code')) {
      toolName = 'Visual Studio Code';
    } else if (fileName.contains('bcompare') || fileName.contains('bcomp')) {
      toolName = 'Beyond Compare';
    } else if (fileName.contains('kdiff3')) {
      toolName = 'KDiff3';
    } else if (fileName.contains('p4merge')) {
      toolName = 'P4Merge';
    } else if (fileName.contains('meld')) {
      toolName = 'Meld';
    } else if (fileName.contains('winmerge')) {
      toolName = 'WinMerge';
    } else if (fileName.contains('tortoisemerge') || fileName.contains('tortoisegitmerge')) {
      toolName = 'TortoiseMerge';
    } else if (fileName.contains('notepad++')) {
      toolName = 'Notepad++';
    } else if (fileName.contains('sublime')) {
      toolName = 'Sublime Text';
    } else if (fileName.contains('vim')) {
      toolName = 'Vim';
    } else if (fileName.contains('emacs')) {
      toolName = 'Emacs';
    } else if (fileName.contains('atom')) {
      toolName = 'Atom';
    } else if (fileName.contains('git')) {
      toolName = 'Git';
    }

    return ToolVersionInfo(
      version: version,
      toolName: toolName,
      executablePath: executablePath,
    );
  }
}

/// Information about a detected tool
class ToolVersionInfo {
  final String version;
  final String? toolName;
  final String executablePath;

  const ToolVersionInfo({
    required this.version,
    this.toolName,
    required this.executablePath,
  });

  @override
  String toString() {
    if (toolName != null) {
      return '$toolName $version';
    }
    return version;
  }
}
