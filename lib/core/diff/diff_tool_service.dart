import 'dart:io';
import 'package:path/path.dart' as p;
import '../services/shell_service.dart';

import 'models/diff_tool.dart';
import '../services/logger_service.dart';
import '../tools/version_detector.dart';

/// Service for detecting and launching external diff/merge tools
class DiffToolService {
  /// Detect all available diff tools on the system
  static Future<List<DiffTool>> detectAvailableTools() async {
    Logger.info('Detecting available diff/merge tools...');
    final tools = <DiffTool>[];

    // On Linux, check git's configured tools first (respects user's preferences)
    // This helps users who already configured their preferred diff tool in git
    if (Platform.isLinux) {
      Logger.info('Checking git config for user-configured diff/merge tools (Linux)');
      await _addGitConfiguredTools(tools);
    }

    // Check each known tool
    for (final toolDef in _knownTools) {
      // Skip if already added from git config
      if (tools.any((t) => t.type == toolDef.type)) {
        continue;
      }

      final tool = await _checkToolAvailability(toolDef);
      if (tool.isAvailable) {
        // Detect version
        final version = await _detectToolVersion(tool);
        final toolWithVersion = tool.copyWith(version: version);
        Logger.info('Found available tool: ${tool.type.name} ${version ?? '(unknown version)'} at ${tool.executablePath}');
        tools.add(toolWithVersion);
      }
    }

    Logger.info('Detection complete: ${tools.length} diff/merge tools available');
    return tools;
  }

  /// Add tools configured in git config (Linux preference detection)
  static Future<void> _addGitConfiguredTools(List<DiffTool> tools) async {
    try {
      // Check git's configured diff tool
      final diffToolResult = await ShellService.run('git config --get diff.tool');
      if (diffToolResult.first.exitCode == 0) {
        final diffToolName = diffToolResult.first.stdout.toString().trim();
        Logger.info('Git diff.tool configured as: $diffToolName');
        final tool = _findToolByGitName(diffToolName);
        if (tool != null) {
          final availableTool = await _checkToolAvailability(tool);
          if (availableTool.isAvailable) {
            final version = await _detectToolVersion(availableTool);
            final toolWithVersion = availableTool.copyWith(version: version);
            Logger.info('Found git-configured diff tool: ${tool.type.name} ${version ?? '(unknown version)'} at ${availableTool.executablePath}');
            tools.add(toolWithVersion);
          } else {
            Logger.warning('Git diff.tool "$diffToolName" configured but not found on system');
          }
        } else {
          Logger.warning('Git diff.tool "$diffToolName" not recognized');
        }
      }

      // Check git's configured merge tool
      final mergeToolResult = await ShellService.run('git config --get merge.tool');
      if (mergeToolResult.first.exitCode == 0) {
        final mergeToolName = mergeToolResult.first.stdout.toString().trim();
        Logger.info('Git merge.tool configured as: $mergeToolName');
        final tool = _findToolByGitName(mergeToolName);
        if (tool != null && !tools.any((t) => t.type == tool.type)) {
          final availableTool = await _checkToolAvailability(tool);
          if (availableTool.isAvailable) {
            final version = await _detectToolVersion(availableTool);
            final toolWithVersion = availableTool.copyWith(version: version);
            Logger.info('Found git-configured merge tool: ${tool.type.name} ${version ?? '(unknown version)'} at ${availableTool.executablePath}');
            tools.add(toolWithVersion);
          } else {
            Logger.warning('Git merge.tool "$mergeToolName" configured but not found on system');
          }
        }
      }
    } catch (e) {
      // Git not available or not configured, continue with normal detection
      Logger.debug('Git config check failed (git may not be installed): $e');
    }
  }

  /// Find tool definition by git tool name
  static DiffTool? _findToolByGitName(String gitName) {
    final normalized = gitName.toLowerCase();
    if (normalized.contains('code') || normalized.contains('vscode')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.vscode);
    }
    if (normalized.contains('bcomp') || normalized.contains('beyond')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.beyondCompare);
    }
    if (normalized.contains('kdiff')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.kdiff3);
    }
    if (normalized.contains('meld')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.meld);
    }
    if (normalized.contains('vimdiff')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.vimdiff);
    }
    if (normalized.contains('p4merge')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.p4merge);
    }
    if (normalized.contains('idea') || normalized.contains('intellij')) {
      return _knownTools.firstWhere((t) => t.type == DiffToolType.intellijIdea);
    }
    return null;
  }

  /// Check if a specific tool is available
  static Future<DiffTool> _checkToolAvailability(DiffTool tool) async {
    // Try common paths for the tool
    final paths = _getSearchPaths(tool.type);

    for (final path in paths) {
      if (await File(path).exists()) {
        return tool.copyWith(
          executablePath: path,
          isAvailable: true,
        );
      }
    }

    // Try PATH using platform-specific command
    try {
      final executables = _getExecutableNames(tool.type);
      final command = Platform.isWindows ? 'where' : 'which';

      for (final executable in executables) {
        try {
          final result = await ShellService.run('$command $executable');
          if (result.first.exitCode == 0) {
            var path = result.first.stdout.toString().trim().split('\n').first;

            // On Windows, if we found a .cmd wrapper (like Scoop's code.cmd),
            // try to resolve it to the actual .exe
            if (Platform.isWindows && path.toLowerCase().endsWith('.cmd')) {
              final resolvedPath = await _resolveWindowsWrapper(path, executable);
              if (resolvedPath != null) {
                path = resolvedPath;
              }
            }

            return tool.copyWith(
              executablePath: path,
              isAvailable: true,
            );
          }
        } catch (e) {
          // Try next executable variant
          Logger.debug('Failed to find executable $executable in PATH: $e');
          continue;
        }
      }
    } catch (e) {
      // Tool not in PATH
      Logger.debug('Tool ${tool.type.name} not found in PATH: $e');
    }

    return tool;
  }

  /// Detect the version of a tool using file properties (doesn't launch GUI)
  static Future<String?> _detectToolVersion(DiffTool tool) async {
    try {
      // Use VersionDetector which reads file properties first (doesn't launch GUI)
      // Falls back to --version only if file properties fail
      final version = await VersionDetector.detectVersion(tool.executablePath);
      if (version != null) {
        Logger.debug('Detected version for ${tool.type.name}: $version');
        return version;
      }
    } catch (e) {
      Logger.debug('Failed to detect version for ${tool.type.name}: $e');
    }
    return null;
  }

  /// Get search paths for a tool type
  static List<String> _getSearchPaths(DiffToolType type) {
    if (Platform.isWindows) {
      return _getWindowsSearchPaths(type);
    } else if (Platform.isMacOS) {
      return _getMacOSSearchPaths(type);
    } else {
      return _getLinuxSearchPaths(type);
    }
  }

  /// Windows search paths
  /// Returns empty list - relies on PATH environment variable via 'where' command
  /// This respects user's installation method (standard installer, Scoop, Chocolatey, portable, etc.)
  static List<String> _getWindowsSearchPaths(DiffToolType type) {
    return [];
  }

  /// macOS search paths
  /// Returns empty list - relies on PATH environment variable via 'which' command
  /// This respects user's installation method (Homebrew, MacPorts, App Store, direct download, etc.)
  static List<String> _getMacOSSearchPaths(DiffToolType type) {
    return [];
  }

  /// Linux search paths
  /// Returns empty list - relies on PATH environment variable via 'which' command
  /// This respects user's installation method (apt, dnf, pacman, Snap, Flatpak, AppImage, etc.)
  static List<String> _getLinuxSearchPaths(DiffToolType type) {
    return [];
  }

  /// Get executable names for PATH search (tries multiple variants)
  static List<String> _getExecutableNames(DiffToolType type) {
    switch (type) {
      case DiffToolType.vscode:
        if (Platform.isWindows) {
          return ['code.cmd', 'code.exe', 'Code.exe'];  // Scoop uses code.cmd, installers use code.exe
        }
        return ['code'];

      case DiffToolType.intellijIdea:
        return ['idea'];  // Linux only

      case DiffToolType.beyondCompare:
        return Platform.isWindows ? ['BComp.exe', 'bcomp.exe'] : ['bcomp'];

      case DiffToolType.kdiff3:
        return Platform.isWindows ? ['kdiff3.exe'] : ['kdiff3'];

      case DiffToolType.p4merge:
        return Platform.isWindows ? ['p4merge.exe'] : ['p4merge'];

      case DiffToolType.meld:
        return ['meld', 'meld.exe'];

      case DiffToolType.winMerge:
        return ['WinMergeU.exe'];

      case DiffToolType.tortoiseGitMerge:
        return ['TortoiseGitMerge.exe'];

      default:
        return [''];
    }
  }

  /// Resolve Windows .cmd wrapper to actual .exe location
  /// For package managers like Scoop that use .cmd wrappers
  static Future<String?> _resolveWindowsWrapper(String cmdPath, String executableName) async {
    try {
      // For Scoop's code.cmd, the actual Code.exe is usually in the same directory's parent
      final cmdFile = File(cmdPath);
      final cmdDir = cmdFile.parent;

      // Check if Code.exe exists in the same directory
      final exeName = executableName.replaceAll('.cmd', '.exe');
      final exePath = p.join(cmdDir.path, exeName);
      if (await File(exePath).exists()) {
        return exePath;
      }

      // Check parent directory (Scoop structure: bin/code.cmd -> ../Code.exe)
      final parentExePath = p.join(cmdDir.parent.path, exeName);
      if (await File(parentExePath).exists()) {
        return parentExePath;
      }

      // Check with capital first letter
      final capitalExeName = exeName[0].toUpperCase() + exeName.substring(1);
      final capitalExePath = p.join(cmdDir.parent.path, capitalExeName);
      if (await File(capitalExePath).exists()) {
        return capitalExePath;
      }
    } catch (e) {
      Logger.debug('Failed to resolve Windows wrapper: $e');
    }

    return null;
  }

  /// Launch diff tool to compare two files
  static Future<void> launchDiff(
    DiffTool tool,
    String leftFile,
    String rightFile, {
    String? label,
  }) async {
    final command = tool.diffCommand(leftFile, rightFile, label: label);
    await Process.start(command.first, command.sublist(1), mode: ProcessStartMode.detached);
  }

  /// Launch merge tool for 3-way merge
  static Future<void> launchMerge(
    DiffTool tool,
    String base,
    String local,
    String remote,
    String merged,
  ) async {
    final command = tool.mergeCommand(base, local, remote, merged);
    await Process.start(command.first, command.sublist(1), mode: ProcessStartMode.detached);
  }

  /// Known diff tools with their default configurations
  static final List<DiffTool> _knownTools = [
    const DiffTool(
      type: DiffToolType.vscode,
      executablePath: '',
      diffArgs: '--wait --diff \$LOCAL \$REMOTE',
      mergeArgs: '--wait --merge \$LOCAL \$REMOTE \$BASE \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.intellijIdea,
      executablePath: '',
      diffArgs: 'diff \$LOCAL \$REMOTE',
      mergeArgs: 'merge \$LOCAL \$REMOTE \$BASE \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.beyondCompare,
      executablePath: '',
      diffArgs: '\$LOCAL \$REMOTE',
      mergeArgs: '\$LOCAL \$REMOTE \$BASE \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.kdiff3,
      executablePath: '',
      diffArgs: '\$LOCAL \$REMOTE',
      mergeArgs: '\$BASE \$LOCAL \$REMOTE -o \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.p4merge,
      executablePath: '',
      diffArgs: '\$LOCAL \$REMOTE',
      mergeArgs: '\$BASE \$LOCAL \$REMOTE \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.meld,
      executablePath: '',
      diffArgs: '\$LOCAL \$REMOTE',
      mergeArgs: '\$LOCAL \$BASE \$REMOTE --output=\$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.winMerge,
      executablePath: '',
      diffArgs: '-e -u \$LOCAL \$REMOTE',
      mergeArgs: '-e -u \$LOCAL \$REMOTE \$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.tortoiseGitMerge,
      executablePath: '',
      diffArgs: '/base:\$LOCAL /mine:\$REMOTE',
      mergeArgs: '/base:\$BASE /mine:\$LOCAL /theirs:\$REMOTE /merged:\$MERGED',
    ),
    const DiffTool(
      type: DiffToolType.vimdiff,
      executablePath: '',
      diffArgs: '-d \$LOCAL \$REMOTE',
      mergeArgs: '-d \$BASE \$LOCAL \$REMOTE \$MERGED',
    ),
  ];
}
