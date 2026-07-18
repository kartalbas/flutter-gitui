import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diff_tool_service.dart';
import 'models/diff_tool.dart';
import '../git/git_providers.dart';
import '../config/config_providers.dart';

/// Available diff tools provider (auto-detected)
final availableDiffToolsProvider = FutureProvider<List<DiffTool>>((ref) async {
  return await DiffToolService.detectAvailableTools();
});

/// Selected diff tool provider (user's preferred tool from YAML config)
final selectedDiffToolProvider = Provider<DiffTool?>((ref) {
  final availableToolsAsync = ref.watch(availableDiffToolsProvider);
  final preferredDiffToolType = ref.watch(preferredDiffToolProvider);

  return availableToolsAsync.when(
    data: (availableTools) {
      if (availableTools.isEmpty) return null;

      // Try to find the preferred tool from config
      if (preferredDiffToolType != null) {
        try {
          return availableTools.firstWhere(
            (t) => t.type == preferredDiffToolType,
          );
        } catch (e) {
          // Tool not found, fall through to default
        }
      }

      // Default to first available tool
      return availableTools.first;
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provider for diff tool actions
class DiffToolActions {
  final Ref ref;

  DiffToolActions(this.ref);

  /// Set the preferred diff tool (saves to YAML config)
  Future<void> setPreferred(DiffTool tool) async {
    await ref.read(configProvider.notifier).setDiffTool(tool.type);
  }
}

/// Diff actions provider
class DiffActions {
  final Ref ref;

  DiffActions(this.ref);

  /// Launch diff for unstaged file
  Future<void> diffUnstagedFile(String filePath) async {
    final tool = ref.read(selectedDiffToolProvider);
    if (tool == null) {
      throw Exception('No diff tool selected');
    }

    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) {
      throw Exception('No repository open');
    }

    // Create temp file with HEAD version
    final repoPath = ref.read(currentRepositoryPathProvider);
    if (repoPath == null) return;

    final tempDir = Directory.systemTemp.createTempSync('gitdiff_');
    final headFile = '${tempDir.path}/HEAD_$filePath'.replaceAll('/', '_');

    try {
      // Get HEAD version of file
      final result = await Process.run(
        'git',
        ['show', 'HEAD:$filePath'],
        workingDirectory: repoPath,
      );

      if (result.exitCode == 0) {
        await File(headFile).writeAsString(result.stdout.toString());

        // Launch diff
        final workingFile = '$repoPath/$filePath';
        await DiffToolService.launchDiff(
          tool,
          headFile,
          workingFile,
          label: filePath,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Launch diff for staged file
  Future<void> diffStagedFile(String filePath) async {
    final tool = ref.read(selectedDiffToolProvider);
    if (tool == null) {
      throw Exception('No diff tool selected');
    }

    final repoPath = ref.read(currentRepositoryPathProvider);
    if (repoPath == null) return;

    final tempDir = Directory.systemTemp.createTempSync('gitdiff_');
    final headFile = '${tempDir.path}/HEAD_$filePath'.replaceAll('/', '_');
    final stagedFile = '${tempDir.path}/STAGED_$filePath'.replaceAll('/', '_');

    try {
      // Get HEAD version
      final headResult = await Process.run(
        'git',
        ['show', 'HEAD:$filePath'],
        workingDirectory: repoPath,
      );

      // Get staged version
      final stagedResult = await Process.run(
        'git',
        ['show', ':$filePath'],
        workingDirectory: repoPath,
      );

      if (headResult.exitCode == 0 && stagedResult.exitCode == 0) {
        await File(headFile).writeAsString(headResult.stdout.toString());
        await File(stagedFile).writeAsString(stagedResult.stdout.toString());

        // Launch diff
        await DiffToolService.launchDiff(
          tool,
          headFile,
          stagedFile,
          label: filePath,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Launch diff between two commits
  Future<void> diffCommits(
    String fromCommit,
    String toCommit,
    String filePath,
  ) async {
    final tool = ref.read(selectedDiffToolProvider);
    if (tool == null) {
      throw Exception('No diff tool selected');
    }

    final repoPath = ref.read(currentRepositoryPathProvider);
    if (repoPath == null) return;

    final tempDir = Directory.systemTemp.createTempSync('gitdiff_');
    final fromFile = '${tempDir.path}/${fromCommit.substring(0, 7)}_$filePath'.replaceAll('/', '_');
    final toFile = '${tempDir.path}/${toCommit.substring(0, 7)}_$filePath'.replaceAll('/', '_');

    try {
      // Get from version
      final fromResult = await Process.run(
        'git',
        ['show', '$fromCommit:$filePath'],
        workingDirectory: repoPath,
      );

      // Get to version
      final toResult = await Process.run(
        'git',
        ['show', '$toCommit:$filePath'],
        workingDirectory: repoPath,
      );

      if (fromResult.exitCode == 0 && toResult.exitCode == 0) {
        await File(fromFile).writeAsString(fromResult.stdout.toString());
        await File(toFile).writeAsString(toResult.stdout.toString());

        // Launch diff
        await DiffToolService.launchDiff(
          tool,
          fromFile,
          toFile,
          label: filePath,
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

/// Diff tool actions provider (for setting preferred tool)
final diffToolActionsProvider = Provider<DiffToolActions>((ref) => DiffToolActions(ref));

/// Diff actions provider
final diffActionsProvider = Provider<DiffActions>((ref) => DiffActions(ref));
