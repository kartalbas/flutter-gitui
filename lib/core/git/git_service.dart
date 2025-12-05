import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart';

import '../services/shell_service.dart';
import '../utils/result.dart';
import 'git_exception.dart';
import 'models/file_status.dart';
import 'models/commit.dart';
import 'models/branch.dart';
import 'models/remote.dart';
import 'models/stash.dart';
import 'models/tag.dart';
import 'models/merge_conflict.dart';
import 'models/reflog_entry.dart';
import 'models/bisect_state.dart';
import 'models/rebase_state.dart';
import 'models/git_command_log.dart';
import 'models/file_change.dart';
import 'models/blame.dart';
import 'parsers/status_parser.dart';
import 'parsers/log_parser.dart';
import 'parsers/branch_parser.dart';
import 'parsers/remote_parser.dart';
import 'parsers/stash_parser.dart';
import 'parsers/tag_parser.dart';
import 'parsers/merge_parser.dart';
import 'parsers/reflog_parser.dart';
import 'parsers/blame_parser.dart';

/// Reset mode for reset operations
enum ResetMode {
  soft, // Keep changes staged
  mixed, // Keep changes unstaged (default)
  hard, // Discard all changes
}

/// Service for Git operations using Git CLI
class GitService {
  final String repoPath;
  final String? gitExecutablePath;
  final void Function(GitCommandLog)? onCommandExecuted;
  final List<String>? protectedBranches;
  final void Function(String operationName, bool isComplete)? onProgressUpdate;
  late final Shell _shell;

  GitService(
    this.repoPath, {
    this.gitExecutablePath,
    this.onCommandExecuted,
    this.protectedBranches,
    this.onProgressUpdate,
  }) {
    _shell = Shell(
      workingDirectory: repoPath,
      throwOnError: false, // We'll handle errors ourselves
      verbose: false, // Disable console output to prevent FileSystemException on Windows GUI apps
      stdout: null, // Don't pipe to stdout (invalid handle on Windows GUI apps)
      stderr: null, // Don't pipe to stderr (invalid handle on Windows GUI apps)
      // Set environment to force UTF-8 encoding for git output
      environment: {
        ...Platform.environment,
        'LC_ALL': 'C.UTF-8',
        'LANG': 'C.UTF-8',
      },
    );
  }

  /// Check if Git is installed
  static Future<bool> isGitInstalled() async {
    try {
      final result = await ShellService.run('git --version');
      return result.first.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if directory is a Git repository
  static Future<bool> isGitRepository(String path) async {
    try {
      final gitDir = Directory(p.join(path, '.git'));
      return await gitDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// Execute a Git command
  Future<ProcessResult> _execute(
    String command, {
    bool throwOnError = true,
  }) async {
    // Ensure git executable is configured
    if (gitExecutablePath == null || gitExecutablePath!.isEmpty) {
      throw GitException(
        'Git executable path not configured. Please configure it in Settings.',
        stderr: 'Git executable path is required but not set in configuration.',
      );
    }

    final startTime = DateTime.now();
    // Use configured git executable path instead of just 'git'
    final fullCommand = '"$gitExecutablePath" $command';

    // Extract operation name from command for progress display
    final operationName = _getOperationName(command);

    try {
      // Start progress tracking
      if (onProgressUpdate != null) {
        onProgressUpdate!(operationName, false);
      }

      final results = await _shell.run(fullCommand);
      final result = results.first;
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Log the command execution
      if (onCommandExecuted != null) {
        final log = GitCommandLog(
          command: fullCommand,
          timestamp: startTime,
          output: result.stdout.toString(),
          error: result.stderr.toString(),
          exitCode: result.exitCode,
          duration: duration,
        );
        onCommandExecuted!(log);
      }

      if (throwOnError && result.exitCode != 0) {
        throw GitException(
          'Git command failed: $fullCommand',
          exitCode: result.exitCode,
          stderr: result.stderr.toString(),
          stdout: result.stdout.toString(),
        );
      }

      return result;
    } on ShellException catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Log the failed command
      if (onCommandExecuted != null) {
        final log = GitCommandLog(
          command: fullCommand,
          timestamp: startTime,
          error: e.message,
          exitCode: -1,
          duration: duration,
        );
        onCommandExecuted!(log);
      }

      throw GitException(
        'Failed to execute git command: $command',
        stderr: e.message,
      );
    } finally {
      // Complete progress tracking
      if (onProgressUpdate != null) {
        onProgressUpdate!(operationName, true);
      }
    }
  }

  /// Extract a user-friendly operation name from a git command
  String _getOperationName(String command) {
    // Get the first word (the git subcommand)
    final parts = command.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Git operation';

    final subcommand = parts[0];

    // Map common git commands to friendly names
    switch (subcommand) {
      case 'add':
        return 'Staging changes';
      case 'commit':
        return 'Committing changes';
      case 'push':
        return 'Pushing to remote';
      case 'pull':
        return 'Pulling from remote';
      case 'fetch':
        return 'Fetching from remote';
      case 'checkout':
        return 'Checking out';
      case 'branch':
        return 'Managing branches';
      case 'merge':
        return 'Merging branches';
      case 'rebase':
        return 'Rebasing';
      case 'reset':
        return 'Resetting';
      case 'stash':
        return 'Stashing changes';
      case 'tag':
        return 'Managing tags';
      case 'log':
        return 'Loading history';
      case 'status':
        return 'Getting status';
      case 'diff':
        return 'Getting diff';
      case 'remote':
        return 'Managing remotes';
      case 'clone':
        return 'Cloning repository';
      case 'init':
        return 'Initializing repository';
      case 'cherry-pick':
        return 'Cherry-picking commit';
      case 'revert':
        return 'Reverting commit';
      case 'clean':
        return 'Cleaning working directory';
      case 'reflog':
        return 'Loading reflog';
      case 'bisect':
        return 'Bisecting';
      case 'show':
        return 'Loading details';
      case 'blame':
        return 'Loading blame';
      case 'for-each-ref':
        return 'Loading references';
      case 'ls-remote':
        return 'Listing remote references';
      case 'rev-parse':
        return 'Resolving revision';
      case 'rev-list':
        return 'Listing revisions';
      default:
        return 'Git operation';
    }
  }

  // ============================================
  // Repository Info
  // ============================================

  /// Get current branch name
  ///
  /// Returns 'HEAD' if in detached HEAD state.
  ///
  /// Returns [Result.Success] with branch name on success.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<String>> getCurrentBranch() async {
    return runCatchingAsync(() async {
      final result = await _execute('branch --show-current');
      final branch = result.stdout.toString().trim();

      // Detached HEAD state: git branch --show-current returns empty string
      // This is a valid state, not an error
      if (branch.isEmpty) {
        return 'HEAD';
      }

      return branch;
    });
  }

  /// Get repository root path
  Future<String?> getRepositoryRoot() async {
    try {
      final result = await _execute('rev-parse --show-toplevel');
      return result.stdout.toString().trim();
    } catch (e) {
      return null;
    }
  }

  /// Check if working directory is clean
  ///
  /// Returns [Result.Success] with true if clean, false if dirty.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<bool>> isClean() async {
    return runCatchingAsync(() async {
      final result = await _execute('status --porcelain');
      return result.stdout.toString().trim().isEmpty;
    });
  }

  // ============================================
  // Status Operations
  // ============================================

  /// Get repository status
  ///
  /// Returns empty list if no changes exist.
  ///
  /// Returns [Result.Success] with list of file statuses on success.
  /// Returns [Result.Failure] if git command fails or parsing fails.
  Future<Result<List<FileStatus>>> getStatus() async {
    return runCatchingAsync(() async {
      final result = await _execute('status --porcelain');
      final output = result.stdout.toString();
      return StatusParser.parse(output);
    });
  }

  /// Get detailed status information
  ///
  /// Returns [Result.Success] with status info map on success.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<Map<String, dynamic>>> getStatusInfo() async {
    return runCatchingAsync(() async {
      // Internal call - unwrap the Result since we're in the same service
      final statuses = await getStatus().then((result) => result.unwrap());

      return {
        'total': statuses.length,
        'staged': statuses.where((s) => s.isStaged).length,
        'unstaged': statuses.where((s) => s.hasUnstagedChanges).length,
        'untracked': statuses.where((s) => s.isUntracked).length,
      };
    });
  }

  // ============================================
  // Staging Operations
  // ============================================

  /// Stage a file
  Future<Result<void>> stageFile(String filePath) async {
    return runCatchingAsync(() async {
      await _execute('add "$filePath"');
    });
  }

  /// Stage all files
  Future<Result<void>> stageAll() async {
    return runCatchingAsync(() async {
      await _execute('add --all');
    });
  }

  /// Unstage a file
  Future<Result<void>> unstageFile(String filePath) async {
    return runCatchingAsync(() async {
      await _execute('reset HEAD "$filePath"', throwOnError: false);
    });
  }

  /// Unstage all files
  Future<Result<void>> unstageAll() async {
    return runCatchingAsync(() async {
      await _execute('reset HEAD', throwOnError: false);
    });
  }

  // ============================================
  // Commit Operations
  // ============================================

  /// Commit staged changes
  ///
  /// Returns [Result.Success] with commit output on success.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<String>> commit(String message, {bool amend = false}) async {
    return runCatchingAsync(() async {
      final amendFlag = amend ? '--amend' : '';
      final escapedMessage = message.replaceAll('"', '\\"').replaceAll('\n', '\\n');

      final result = await _execute('commit $amendFlag -m "$escapedMessage"');
      return result.stdout.toString();
    });
  }

  /// Get last commit message
  ///
  /// Returns empty string if no commits exist (new repository).
  ///
  /// Returns [Result.Success] with commit message on success.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<String>> getLastCommitMessage() async {
    return runCatchingAsync(() async {
      final result = await _execute('log -1 --pretty=%B');
      return result.stdout.toString().trim();
    });
  }

  // ============================================
  // Diff Operations
  // ============================================

  /// Get diff for a file
  Future<Result<String>> getDiff(String filePath, {bool staged = false}) async {
    return runCatchingAsync(() async {
      final stagedFlag = staged ? '--cached' : '';
      final result = await _execute('diff $stagedFlag "$filePath"', throwOnError: false);
      return result.stdout.toString();
    });
  }

  /// Get diff for all changes
  Future<Result<String>> getDiffAll({bool staged = false}) async {
    return runCatchingAsync(() async {
      final stagedFlag = staged ? '--cached' : '';
      final result = await _execute('diff $stagedFlag', throwOnError: false);
      return result.stdout.toString();
    });
  }

  /// Get diff for a file in a specific commit
  Future<Result<String>> getDiffForCommit(String commitHash, String filePath) async {
    return runCatchingAsync(() async {
      final result = await _execute(
        'show "$commitHash" -- "$filePath"',
        throwOnError: false,
      );
      return result.stdout.toString();
    });
  }

  /// Get file content from working directory
  /// Returns the raw file content as a string, or null if file doesn't exist
  Future<String?> getFileContent(String filePath) async {
    try {
      final file = File(p.join(repoPath, filePath));
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // Discard Operations
  // ============================================

  /// Discard changes in a file
  Future<void> discardFile(String filePath) async {
    await _execute('checkout -- "$filePath"');
  }

  /// Discard all changes
  Future<void> discardAll() async {
    await _execute('checkout -- .');
  }

  /// Delete untracked file
  Future<void> deleteUntrackedFile(String filePath) async {
    final file = File(p.join(repoPath, filePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ============================================
  // Log Operations
  // ============================================

  /// Get commit history
  ///
  /// Returns empty list if no commits exist (new repository).
  ///
  /// Returns [Result.Success] with list of commits on success.
  /// Returns [Result.Failure] if git command fails or parsing fails.
  Future<Result<List<GitCommit>>> getLog({
    int? limit,
    String? branch,
    String? filePath,
    String? grepMessage,
    String? author,
    String? since,
    String? until,
    bool allMatch = false,
  }) async {
    return runCatchingAsync(() async {
      final args = StringBuffer('log');

      // Add format
      args.write(' --format="${LogParser.gitLogFormat}${LogParser.commitSeparator}"');

      // Add limit
      if (limit != null) {
        args.write(' -n $limit');
      }

      // Add search filters
      if (grepMessage != null && grepMessage.isNotEmpty) {
        args.write(' --grep="$grepMessage"');
      }

      if (author != null && author.isNotEmpty) {
        args.write(' --author="$author"');
      }

      if (since != null && since.isNotEmpty) {
        args.write(' --since="$since"');
      }

      if (until != null && until.isNotEmpty) {
        args.write(' --until="$until"');
      }

      if (allMatch) {
        args.write(' --all-match');
      }

      // Add branch
      if (branch != null) {
        args.write(' "$branch"');
      }

      // Add file path
      if (filePath != null) {
        args.write(' -- "$filePath"');
      }

      final result = await _execute(args.toString(), throwOnError: false);
      final output = result.stdout.toString();

      return LogParser.parse(output);
    });
  }

  /// Get a single commit by hash
  ///
  /// Returns null if commit doesn't exist.
  ///
  /// Returns [Result.Success] with commit or null on success.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<GitCommit?>> getCommit(String hash) async {
    return runCatchingAsync(() async {
      // Internal call - unwrap the Result since we're in the same service
      final commits = await getLog(limit: 1).then((result) => result.unwrap());
      return commits.isNotEmpty ? commits.first : null;
    });
  }

  /// Get commits for a specific file
  Future<Result<List<GitCommit>>> getFileHistory(String filePath) async {
    return await getLog(filePath: filePath);
  }

  /// Get commits between two refs
  Future<List<GitCommit>> getCommitsBetween(String from, String to) async {
    final result = await _execute(
      'log --format="${LogParser.gitLogFormat}${LogParser.commitSeparator}" $from..$to',
      throwOnError: false,
    );
    final output = result.stdout.toString();
    return LogParser.parse(output);
  }

  /// Get changed files for a specific commit with statistics
  Future<List<FileChange>> getCommitChangedFiles(String commitHash) async {
    try {
      // Get file stats (additions/deletions)
      final statsResult = await _execute(
        'show --numstat --format="" "$commitHash"',
        throwOnError: false,
      );

      // Get file status (added/modified/deleted/renamed)
      final statusResult = await _execute(
        'show --name-status --format="" "$commitHash"',
        throwOnError: false,
      );

      final statsLines = statsResult.stdout.toString().trim().split('\n');
      final statusLines = statusResult.stdout.toString().trim().split('\n');

      final fileChanges = <FileChange>[];

      // Parse status lines first to get the file paths and change types
      for (final statusLine in statusLines) {
        if (statusLine.isEmpty) continue;

        final parts = statusLine.split('\t');
        if (parts.length < 2) continue;

        final statusChar = parts[0];
        final path = parts.length > 2 ? parts[2] : parts[1]; // Renamed files have 3 parts
        final oldPath = parts.length > 2 ? parts[1] : null;

        // Find matching stats line
        int additions = 0;
        int deletions = 0;

        for (final statsLine in statsLines) {
          if (statsLine.isEmpty) continue;

          final statsParts = statsLine.split('\t');
          if (statsParts.length < 3) continue;

          final statsPath = statsParts[2];
          if (statsPath == path || (oldPath != null && statsPath == oldPath)) {
            additions = int.tryParse(statsParts[0]) ?? 0;
            deletions = int.tryParse(statsParts[1]) ?? 0;
            break;
          }
        }

        fileChanges.add(FileChange(
          path: path,
          type: FileChange.parseType(statusChar),
          oldPath: oldPath,
          additions: additions,
          deletions: deletions,
        ));
      }

      return fileChanges;
    } catch (e) {
      return [];
    }
  }

  /// Get file content at a specific commit
  /// Returns the raw file content as bytes
  Future<List<int>> getFileContentAtCommit(String commitHash, String filePath) async {
    try {
      final result = await _execute(
        'show "$commitHash:$filePath"',
        throwOnError: false,
      );

      if (result.exitCode != 0) {
        throw GitException(
          'Failed to get file content',
          stderr: result.stderr.toString(),
        );
      }

      // Return raw bytes - git show outputs the file content as-is
      return result.stdout as List<int>;
    } catch (e) {
      throw GitException(
        'Failed to get file content at commit $commitHash: $e',
      );
    }
  }

  /// Get blame information for a file (who changed what when)
  ///
  /// Shows line-by-line authorship information including:
  /// - Commit hash
  /// - Author name and email
  /// - Author timestamp
  /// - Commit summary
  /// - Line content
  ///
  /// Parameters:
  /// - [filePath]: Path to the file relative to repository root
  /// - [commitHash]: Optional commit to blame from (defaults to HEAD)
  ///
  /// Returns [FileBlame] with all line information
  ///
  /// Returns [Result.Success] with FileBlame on success.
  /// Returns [Result.Failure] if the file doesn't exist or git blame fails.
  Future<Result<FileBlame>> getBlame(String filePath, {String? commitHash}) async {
    return runCatchingAsync(() async {
      final commit = commitHash ?? 'HEAD';
      final result = await _execute(
        'blame --line-porcelain "$commit" -- "$filePath"',
        throwOnError: false,
      );

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        if (stderr.contains('no such path')) {
          throw GitException(
            'File not found: $filePath',
            stderr: stderr,
          );
        }
        throw GitException(
          'Failed to get blame information',
          stderr: stderr,
        );
      }

      final output = result.stdout.toString();
      return BlameParser.parse(output, filePath);
    });
  }

  /// Get repository status including ahead/behind and uncommitted changes
  /// Returns null if the repository is not valid or cannot be accessed
  Future<Map<String, dynamic>?> getRepositoryStatus(String repoPath) async {
    try {
      // Check if directory exists
      final dir = Directory(repoPath);
      if (!await dir.exists()) {
        return {
          'exists': false,
          'isValidGit': false,
        };
      }

      // Check if it's a valid git repository
      final gitDir = Directory('$repoPath/.git');
      if (!await gitDir.exists()) {
        return {
          'exists': true,
          'isValidGit': false,
        };
      }

      // Get current branch (logged)
      final branchResult = await _execute('branch --show-current', throwOnError: false);
      final currentBranch = branchResult.exitCode == 0
          ? branchResult.stdout.toString().trim()
          : null;

      // Check for remote (logged)
      final remoteResult = await _execute('remote', throwOnError: false);
      final hasRemote = remoteResult.exitCode == 0 &&
          remoteResult.stdout.toString().trim().isNotEmpty;

      int commitsAhead = 0;
      int commitsBehind = 0;

      // Only check ahead/behind if there's a remote and current branch
      if (hasRemote && currentBranch != null && currentBranch.isNotEmpty) {
        // Get the remote name (usually 'origin') (logged)
        final remoteNameResult = await _execute('remote', throwOnError: false);
        final remoteName = remoteNameResult.exitCode == 0
            ? remoteNameResult.stdout.toString().trim().split('\n').first
            : 'origin';

        // Check if upstream is set, if not try origin/<branch> (logged)
        final upstreamCheckResult = await _execute(
          'rev-parse --abbrev-ref @{upstream}',
          throwOnError: false,
        );

        final remoteBranch = upstreamCheckResult.exitCode == 0
            ? upstreamCheckResult.stdout.toString().trim()
            : '$remoteName/$currentBranch';

        // Note: We check against the last known remote state without fetching
        // to avoid slowing down the dashboard. User can manually fetch/refresh.

        // Check commits ahead (logged)
        final aheadResult = await _execute(
          'rev-list --count "$remoteBranch..HEAD"',
          throwOnError: false,
        );
        if (aheadResult.exitCode == 0) {
          commitsAhead = int.tryParse(aheadResult.stdout.toString().trim()) ?? 0;
        }

        // Check commits behind (logged)
        final behindResult = await _execute(
          'rev-list --count "HEAD..$remoteBranch"',
          throwOnError: false,
        );
        if (behindResult.exitCode == 0) {
          commitsBehind = int.tryParse(behindResult.stdout.toString().trim()) ?? 0;
        }
      }

      // Check for uncommitted changes (logged)
      final statusResult = await _execute('status --porcelain', throwOnError: false);
      final hasUncommittedChanges = statusResult.exitCode == 0 &&
          statusResult.stdout.toString().trim().isNotEmpty;

      return {
        'exists': true,
        'isValidGit': true,
        'currentBranch': currentBranch,
        'hasRemote': hasRemote,
        'commitsAhead': commitsAhead,
        'commitsBehind': commitsBehind,
        'hasUncommittedChanges': hasUncommittedChanges,
      };
    } catch (e) {
      return {
        'exists': true,
        'isValidGit': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================
  // Branch Operations
  // ============================================

  /// Get all branches (local and remote) with detailed information
  ///
  /// Returns empty list if there are no branches (e.g., new repository).
  ///
  /// Returns [Result.Success] with list of branches on success.
  /// Returns [Result.Failure] if git command fails or parsing fails.
  Future<Result<List<GitBranch>>> getAllBranches() async {
    return runCatchingAsync(() async {
      final result = await _execute('branch -a -vv');
      return BranchParser.parseAll(result.stdout.toString(), protectedBranches: protectedBranches);
    });
  }

  /// Get local branches only with detailed information
  ///
  /// Returns empty list if there are no branches (e.g., new repository).
  ///
  /// Returns [Result.Success] with list of branches on success.
  /// Returns [Result.Failure] if git command fails or parsing fails.
  Future<Result<List<GitBranch>>> getLocalBranches() async {
    return runCatchingAsync(() async {
      final result = await _execute('branch -vv');
      return BranchParser.parseVerbose(result.stdout.toString(), protectedBranches: protectedBranches);
    });
  }

  /// Get remote branches only
  ///
  /// Returns empty list if there are no remote branches.
  ///
  /// Returns [Result.Success] with list of branches on success.
  /// Returns [Result.Failure] if git command fails or parsing fails.
  Future<Result<List<GitBranch>>> getRemoteBranches() async {
    return runCatchingAsync(() async {
      final result = await _execute('branch -r');
      return BranchParser.parseRemote(result.stdout.toString(), protectedBranches: protectedBranches);
    });
  }

  /// Get list of local branch names (simple version for backward compatibility)
  Future<List<String>> getBranches() async {
    final result = await _execute('branch --format="%(refname:short)"');
    final output = result.stdout.toString();
    return output.split('\n').where((s) => s.isNotEmpty).toList();
  }

  /// Create a new branch
  /// [branchName] - Name of the new branch
  /// [startPoint] - Optional commit/branch to start from (defaults to HEAD)
  /// [checkout] - Whether to checkout the new branch immediately
  ///
  /// Returns [Result.Success] on successful branch creation.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<void>> createBranch(
    String branchName, {
    String? startPoint,
    bool checkout = false,
  }) async {
    return runCatchingAsync(() async {
      final args = StringBuffer('branch');
      args.write(' "$branchName"');
      if (startPoint != null) {
        args.write(' "$startPoint"');
      }

      await _execute(args.toString());

      if (checkout) {
        // Internal call - unwrap the Result since we're in the same service
        await checkoutBranch(branchName).then((result) => result.unwrap());
      }
    });
  }

  /// Delete a branch
  /// [branchName] - Name of the branch to delete
  /// [force] - Force delete even if not fully merged
  ///
  /// Returns [Result.Success] on successful branch deletion.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<void>> deleteBranch(String branchName, {bool force = false}) async {
    return runCatchingAsync(() async {
      final flag = force ? '-D' : '-d';
      await _execute('branch $flag "$branchName"');
    });
  }

  /// Delete a remote branch
  Future<Result<void>> deleteRemoteBranch(String remoteName, String branchName) async {
    return runCatchingAsync(() async {
      await _execute('push "$remoteName" --delete "$branchName"');
    });
  }

  /// Checkout (switch to) a branch
  /// [branchName] - Name of the branch to checkout
  /// [createIfMissing] - Create the branch if it doesn't exist
  ///
  /// Returns [Result.Success] on successful checkout.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<void>> checkoutBranch(
    String branchName, {
    bool createIfMissing = false,
  }) async {
    return runCatchingAsync(() async {
      if (createIfMissing) {
        await _execute('checkout -b "$branchName"');
      } else {
        await _execute('checkout "$branchName"');
      }
    });
  }

  /// Rename a branch
  /// [oldName] - Current branch name (null for current branch)
  /// [newName] - New branch name
  /// [force] - Force rename even if new name already exists
  ///
  /// Returns [Result.Success] on successful rename.
  /// Returns [Result.Failure] if git command fails.
  Future<Result<void>> renameBranch(String newName, {String? oldName, bool force = false}) async {
    return runCatchingAsync(() async {
      final flag = force ? '-M' : '-m';
      if (oldName != null) {
        await _execute('branch $flag "$oldName" "$newName"');
      } else {
        await _execute('branch $flag "$newName"');
      }
    });
  }

  /// Merge a branch into the current branch
  /// [branchName] - Name of the branch to merge
  /// [noFastForward] - Disable fast-forward merging
  /// [squash] - Squash commits when merging
  ///
  /// Returns [Result.Success] on successful merge.
  /// Returns [Result.Failure] if git command fails or merge conflicts occur.
  Future<Result<void>> mergeBranch(
    String branchName, {
    bool fastForwardOnly = false,
    bool noFastForward = false,
    bool squash = false,
    String? message,
  }) async {
    return runCatchingAsync(() async {
      final args = StringBuffer('merge');

      if (fastForwardOnly) {
        args.write(' --ff-only');
      } else if (noFastForward) {
        args.write(' --no-ff');
      }

      if (squash) {
        args.write(' --squash');
      }

      if (message != null && message.isNotEmpty) {
        args.write(' -m "${message.replaceAll('"', '\\"')}"');
      }

      args.write(' "$branchName"');

      await _execute(args.toString());
    });
  }

  /// Set upstream tracking branch
  /// [branchName] - Local branch name (null for current branch)
  /// [upstreamBranch] - Upstream branch in format "remote/branch" (e.g., "origin/main")
  Future<void> setUpstream(String upstreamBranch, {String? branchName}) async {
    if (branchName != null) {
      await _execute('branch --set-upstream-to="$upstreamBranch" "$branchName"');
    } else {
      await _execute('branch --set-upstream-to="$upstreamBranch"');
    }
  }

  /// Unset upstream tracking branch
  Future<void> unsetUpstream({String? branchName}) async {
    if (branchName != null) {
      await _execute('branch --unset-upstream "$branchName"');
    } else {
      await _execute('branch --unset-upstream');
    }
  }

  /// Get upstream branch for a local branch
  Future<String?> getUpstreamBranch({String? branchName}) async {
    try {
      final args = branchName != null
          ? 'rev-parse --abbrev-ref "$branchName@{upstream}"'
          : 'rev-parse --abbrev-ref @{upstream}';
      final result = await _execute(args, throwOnError: false);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================
  // Remote Operations
  // ============================================

  /// Get all remotes with their URLs
  Future<Result<List<GitRemote>>> getRemotes() async {
    return runCatchingAsync(() async {
      final result = await _execute('remote -v');
      final output = result.stdout.toString();
      return RemoteParser.parseRemotes(output);
    });
  }

  /// Get list of remote names only
  Future<Result<List<String>>> getRemoteNames() async {
    return runCatchingAsync(() async {
      final result = await _execute('remote');
      final output = result.stdout.toString();
      return RemoteParser.parseRemoteNames(output);
    });
  }

  /// Add a new remote
  Future<Result<void>> addRemote(String name, String url) async {
    return runCatchingAsync(() async {
      await _execute('remote add "$name" "$url"');
    });
  }

  /// Remove a remote
  Future<Result<void>> removeRemote(String name) async {
    return runCatchingAsync(() async {
      await _execute('remote remove "$name"');
    });
  }

  /// Rename a remote
  Future<Result<void>> renameRemote(String oldName, String newName) async {
    return runCatchingAsync(() async {
      await _execute('remote rename "$oldName" "$newName"');
    });
  }

  /// Set remote URL
  Future<Result<void>> setRemoteUrl(
    String name,
    String url, {
    bool push = false,
  }) async {
    return runCatchingAsync(() async {
      final pushArg = push ? '--push ' : '';
      await _execute('remote set-url $pushArg"$name" "$url"');
    });
  }

  /// Get URL for a specific remote
  Future<Result<String?>> getRemoteUrl(String name, {bool push = false}) async {
    return runCatchingAsync(() async {
      final type = push ? '--push' : '';
      final result = await _execute(
        'remote get-url $type "$name"',
        throwOnError: false,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    });
  }

  /// Fetch from remote
  Future<Result<String>> fetch({
    String? remote,
    String? branch,
    bool prune = false,
    bool all = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['fetch'];

      if (prune) parts.add('--prune');
      if (all) parts.add('--all');

      if (remote != null) {
        parts.add('"$remote"');
        if (branch != null) parts.add('"$branch"');
      }

      final result = await _execute(parts.join(' '));
      // Git fetch outputs to stderr, not stdout
      final output = result.stderr.toString().trim();
      return output.isNotEmpty ? output : 'Fetch completed';
    });
  }

  /// Pull from remote
  Future<Result<String>> pull({
    String? remote,
    String? branch,
    bool rebase = false,
    bool ffOnly = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['pull'];

      if (rebase) parts.add('--rebase');
      if (ffOnly) parts.add('--ff-only');

      if (remote != null) {
        parts.add('"$remote"');
        if (branch != null) parts.add('"$branch"');
      }

      final result = await _execute(parts.join(' '));
      // Git pull outputs to stderr, not stdout
      final output = result.stderr.toString().trim();
      return output.isNotEmpty ? output : 'Pull completed';
    });
  }

  /// Push to remote
  Future<Result<String>> push({
    String? remote,
    String? branch,
    bool force = false,
    bool setUpstream = false,
    bool all = false,
    bool tags = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['push'];

      // Use --force-with-lease instead of --force for safer force pushing
      // This prevents overwriting work if someone else has pushed changes you don't have
      if (force) parts.add('--force-with-lease');
      if (setUpstream) parts.add('--set-upstream');
      if (all) parts.add('--all');
      if (tags) parts.add('--tags');

      if (remote != null) {
        parts.add('"$remote"');
        if (branch != null) parts.add('"$branch"');
      }

      final result = await _execute(parts.join(' '));
      // Git push outputs to stderr, not stdout
      final output = result.stderr.toString().trim();
      return output.isNotEmpty ? output : 'Push completed';
    });
  }

  /// Prune remote tracking branches
  Future<Result<void>> pruneRemote(String remote) async {
    return runCatchingAsync(() async {
      await _execute('remote prune "$remote"');
    });
  }

  /// Show information about a remote
  Future<Result<String>> showRemote(String name) async {
    return runCatchingAsync(() async {
      final result = await _execute('remote show "$name"');
      return result.stdout.toString();
    });
  }

  // ============================================
  // Stash Operations
  // ============================================

  /// List all stashes
  Future<Result<List<GitStash>>> getStashes() async {
    return runCatchingAsync(() async {
      // Use custom format: ref|hash|timestamp|message
      final result = await _execute(
        'stash list --format=%gD|%H|%at|%gs',
        throwOnError: false,
      );
      return StashParser.parseStashList(result.stdout.toString());
    });
  }

  /// Create a new stash
  ///
  /// [message] - Optional message for the stash
  /// [includeUntracked] - Include untracked files
  /// [keepIndex] - Keep staged changes in the index
  /// [files] - Optional list of specific files to stash (if null, stashes all files)
  Future<Result<void>> createStash({
    String? message,
    bool includeUntracked = false,
    bool keepIndex = false,
    List<String>? files,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['stash', 'push'];

      if (includeUntracked) {
        parts.add('--include-untracked');
      }

      if (keepIndex) {
        parts.add('--keep-index');
      }

      if (message != null && message.isNotEmpty) {
        parts.add('-m');
        parts.add('"${message.replaceAll('"', '\\"')}"');
      }

      // Add specific files if provided
      if (files != null && files.isNotEmpty) {
        parts.add('--');
        for (final file in files) {
          // Quote file paths that contain spaces
          if (file.contains(' ')) {
            parts.add('"$file"');
          } else {
            parts.add(file);
          }
        }
      }

      await _execute(parts.join(' '));
    });
  }

  /// Apply a stash
  ///
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  /// [index] - Also restore staged changes
  Future<Result<void>> applyStash(String stashRef, {bool index = false}) async {
    return runCatchingAsync(() async {
      final parts = ['stash', 'apply', '"$stashRef"'];

      if (index) {
        parts.add('--index');
      }

      await _execute(parts.join(' '));
    });
  }

  /// Pop a stash (apply and remove)
  ///
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  /// [index] - Also restore staged changes
  Future<Result<void>> popStash(String stashRef, {bool index = false}) async {
    return runCatchingAsync(() async {
      final parts = ['stash', 'pop', '"$stashRef"'];

      if (index) {
        parts.add('--index');
      }

      await _execute(parts.join(' '));
    });
  }

  /// Drop a stash (remove without applying)
  ///
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  Future<Result<void>> dropStash(String stashRef) async {
    return runCatchingAsync(() async {
      await _execute('stash drop "$stashRef"');
    });
  }

  /// Clear all stashes
  Future<Result<void>> clearStashes() async {
    return runCatchingAsync(() async {
      await _execute('stash clear');
    });
  }

  /// Show stash changes (file list)
  ///
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  Future<Result<Map<String, dynamic>>> showStash(String stashRef) async {
    return runCatchingAsync(() async {
      final result = await _execute(
        'stash show --stat "$stashRef"',
        throwOnError: false,
      );
      return StashParser.parseStashShow(result.stdout.toString());
    });
  }

  /// Get diff for a stash
  ///
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  Future<Result<String>> getStashDiff(String stashRef) async {
    return runCatchingAsync(() async {
      final result = await _execute('stash show -p "$stashRef"');
      return result.stdout.toString();
    });
  }

  /// Create a branch from a stash
  ///
  /// [branchName] - Name for the new branch
  /// [stashRef] - Stash reference (e.g., "stash@{0}")
  Future<Result<void>> branchFromStash(String branchName, String stashRef) async {
    return runCatchingAsync(() async {
      await _execute('stash branch "$branchName" "$stashRef"');
    });
  }

  // ============================================
  // Tag Operations
  // ============================================

  /// List all tags
  Future<Result<List<GitTag>>> getTags() async {
    return runCatchingAsync(() async {
      // Use for-each-ref with custom format for detailed info
      // Format: name|@|commitHash|@|objectType|@|taggerName|@|taggerEmail|@|taggerDate|@|subject|@|commitMessage
      // Using |@| as separator to avoid conflicts with message content
      final result = await _execute(
        'for-each-ref refs/tags --format='
        '"%(refname:short)|@|%(objectname)|@|%(objecttype)|@|'
        '%(taggername)|@|%(taggeremail)|@|%(taggerdate:unix)|@|'
        '%(subject)|@|%(*subject)"',
        throwOnError: false,
      );
      return TagParser.parseTagList(result.stdout.toString());
    });
  }

  /// Get remote tags for a specific remote
  ///
  /// Returns a set of tag names that exist on the remote
  Future<Result<Set<String>>> getRemoteTags(String remoteName) async {
    return runCatchingAsync(() async {
      final result = await _execute(
        'ls-remote --tags "$remoteName"',
        throwOnError: false,
      );

      final tags = <String>{};
      final lines = result.stdout.toString().split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Format: <hash> refs/tags/<tag-name>
        final parts = trimmed.split('\t');
        if (parts.length >= 2) {
          final ref = parts[1];
          if (ref.startsWith('refs/tags/')) {
            var tagName = ref.substring('refs/tags/'.length);
            // Remove ^{} suffix for annotated tags
            if (tagName.endsWith('^{}')) {
              tagName = tagName.substring(0, tagName.length - 3);
            }
            tags.add(tagName);
          }
        }
      }

      return tags;
    });
  }

  /// Get local-only tags (tags that exist locally but not on remote)
  ///
  /// Returns a set of tag names that are only local
  Future<Result<Set<String>>> getLocalOnlyTags(String remoteName) async {
    return runCatchingAsync(() async {
      final localTags = (await getTags()).unwrap();
      final remoteTags = (await getRemoteTags(remoteName)).unwrap();

      final localOnlyTags = <String>{};
      for (final tag in localTags) {
        if (!remoteTags.contains(tag.name)) {
          localOnlyTags.add(tag.name);
        }
      }

      return localOnlyTags;
    });
  }

  /// Get remote-only tags (tags that exist on remote but not locally)
  ///
  /// Returns a set of tag names that are only on remote
  Future<Result<Set<String>>> getRemoteOnlyTags(String remoteName) async {
    return runCatchingAsync(() async {
      final localTags = (await getTags()).unwrap();
      final remoteTags = (await getRemoteTags(remoteName)).unwrap();

      final localTagNames = localTags.map((tag) => tag.name).toSet();
      final remoteOnlyTags = <String>{};

      for (final tagName in remoteTags) {
        if (!localTagNames.contains(tagName)) {
          remoteOnlyTags.add(tagName);
        }
      }

      return remoteOnlyTags;
    });
  }

  /// Create a lightweight tag
  ///
  /// [tagName] - Name of the tag
  /// [commitHash] - Optional commit hash (defaults to HEAD)
  Future<Result<void>> createLightweightTag(String tagName, {String? commitHash}) async {
    return runCatchingAsync(() async {
      final parts = ['tag', '"$tagName"'];
      if (commitHash != null) {
        parts.add('"$commitHash"');
      }
      await _execute(parts.join(' '));
    });
  }

  /// Create an annotated tag
  ///
  /// [tagName] - Name of the tag
  /// [message] - Tag message
  /// [commitHash] - Optional commit hash (defaults to HEAD)
  Future<Result<void>> createAnnotatedTag(
    String tagName, {
    required String message,
    String? commitHash,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['tag', '-a', '"$tagName"'];
      parts.add('-m');
      parts.add('"${message.replaceAll('"', '\\"')}"');
      if (commitHash != null) {
        parts.add('"$commitHash"');
      }
      await _execute(parts.join(' '));
    });
  }

  /// Delete a tag (local)
  ///
  /// [tagName] - Name of the tag to delete
  Future<Result<void>> deleteTag(String tagName) async {
    return runCatchingAsync(() async {
      await _execute('tag -d "$tagName"');
    });
  }

  /// Delete a remote tag
  ///
  /// [remoteName] - Name of the remote (e.g., "origin")
  /// [tagName] - Name of the tag to delete
  Future<Result<void>> deleteRemoteTag(String remoteName, String tagName) async {
    return runCatchingAsync(() async {
      await _execute('push "$remoteName" --delete "refs/tags/$tagName"');
    });
  }

  /// Push a tag to remote
  ///
  /// [remoteName] - Name of the remote (e.g., "origin")
  /// [tagName] - Name of the tag to push
  Future<Result<void>> pushTag(String remoteName, String tagName) async {
    return runCatchingAsync(() async {
      await _execute('push "$remoteName" "$tagName"');
    });
  }

  /// Push all tags to remote
  ///
  /// [remoteName] - Name of the remote (e.g., "origin")
  Future<Result<void>> pushAllTags(String remoteName) async {
    return runCatchingAsync(() async {
      await _execute('push "$remoteName" --tags');
    });
  }

  /// Fetch tags from remote
  ///
  /// [remoteName] - Optional remote name (defaults to all remotes)
  Future<Result<void>> fetchTags({String? remoteName}) async {
    return runCatchingAsync(() async {
      if (remoteName != null) {
        await _execute('fetch "$remoteName" --tags');
      } else {
        await _execute('fetch --tags');
      }
    });
  }

  /// Checkout a tag (creates detached HEAD)
  ///
  /// [tagName] - Name of the tag to checkout
  Future<Result<void>> checkoutTag(String tagName) async {
    return runCatchingAsync(() async {
      await _execute('checkout "$tagName"');
    });
  }

  /// Get detailed information about a tag
  ///
  /// [tagName] - Name of the tag
  Future<Result<Map<String, dynamic>>> getTagDetails(String tagName) async {
    return runCatchingAsync(() async {
      final result = await _execute('show "$tagName" --no-patch');
      return TagParser.parseTagDetails(result.stdout.toString());
    });
  }

  /// Check if a tag exists
  ///
  /// [tagName] - Name of the tag
  Future<Result<bool>> tagExists(String tagName) async {
    return runCatchingAsync(() async {
      final result = await _execute('tag -l "$tagName"', throwOnError: false);
      return result.stdout.toString().trim() == tagName;
    });
  }

  /// Get commit hash for a tag
  ///
  /// [tagName] - Name of the tag
  Future<Result<String?>> getTagCommitHash(String tagName) async {
    return runCatchingAsync(() async {
      final result = await _execute('rev-list -n 1 "$tagName"');
      return result.stdout.toString().trim();
    });
  }

  // ============================================
  // Repository Initialization
  // ============================================

  /// Clone a repository
  ///
  /// [url] - Repository URL to clone from
  /// [destinationPath] - Local path where to clone
  /// [branchName] - Optional specific branch to clone
  /// [depth] - Optional shallow clone depth
  static Future<String> cloneRepository({
    required String url,
    required String destinationPath,
    String? branchName,
    int? depth,
  }) async {
    final shell = Shell(throwOnError: false, verbose: false, stdout: null, stderr: null);

    final parts = ['git', 'clone'];

    if (branchName != null) {
      parts.addAll(['--branch', '"$branchName"']);
    }

    if (depth != null) {
      parts.addAll(['--depth', depth.toString()]);
    }

    parts.add('"$url"');
    parts.add('"$destinationPath"');

    final results = await shell.run(parts.join(' '));
    final result = results.first;

    if (result.exitCode != 0) {
      throw GitException(
        'Failed to clone repository',
        exitCode: result.exitCode,
        stderr: result.stderr.toString(),
        stdout: result.stdout.toString(),
      );
    }

    return destinationPath;
  }

  /// Initialize a new Git repository
  ///
  /// [path] - Directory path to initialize
  /// [bare] - Create a bare repository
  /// [initialBranch] - Name of the initial branch (default: main)
  static Future<void> initializeRepository({
    required String path,
    bool bare = false,
    String? initialBranch,
  }) async {
    // Ensure directory exists
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final shell = Shell(
      workingDirectory: path,
      throwOnError: false,
      verbose: false,
      stdout: null,
      stderr: null,
    );

    final parts = ['git', 'init'];

    if (bare) {
      parts.add('--bare');
    }

    if (initialBranch != null) {
      parts.addAll(['--initial-branch', '"$initialBranch"']);
    }

    final results = await shell.run(parts.join(' '));
    final result = results.first;

    if (result.exitCode != 0) {
      throw GitException(
        'Failed to initialize repository',
        exitCode: result.exitCode,
        stderr: result.stderr.toString(),
        stdout: result.stdout.toString(),
      );
    }
  }

  // ============================================
  // Merge Operations
  // ============================================

  /// Check if merge is in progress
  Future<bool> isMergeInProgress() async {
    try {
      final mergeHeadFile = File(p.join(repoPath, '.git', 'MERGE_HEAD'));
      return await mergeHeadFile.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get current merge state
  Future<MergeState> getMergeState() async {
    final isInProgress = await isMergeInProgress();

    if (!isInProgress) {
      return const MergeState.empty();
    }

    // Read MERGE_HEAD and MERGE_MSG
    String? mergingBranch;
    String? message;

    try {
      final mergeMsgFile = File(p.join(repoPath, '.git', 'MERGE_MSG'));
      if (await mergeMsgFile.exists()) {
        final content = await mergeMsgFile.readAsString();
        final parsed = MergeParser.parseMergeMsg(content);
        mergingBranch = parsed['branch'];
        message = parsed['message'];
      }
    } catch (e) {
      // Ignore
    }

    // Get conflicts from status
    final statusResult = await getStatus();
    final status = statusResult.unwrapOr([]);
    final conflicts = <MergeConflict>[];

    for (final file in status) {
      final statusCode = file.displayStatus;
      ConflictType? type;

      // Determine conflict type from status code
      // Conflict status codes: UU, AA, DD, AU, UA, DU, UD
      if (statusCode == 'DD') {
        continue; // Both deleted - skip
      } else if (statusCode == 'AA') {
        type = ConflictType.bothAdded;
      } else if (statusCode == 'UU') {
        type = ConflictType.bothModified;
      } else if (statusCode == 'AU') {
        type = ConflictType.addedByUs;
      } else if (statusCode == 'UA') {
        type = ConflictType.addedByThem;
      } else if (statusCode == 'DU') {
        type = ConflictType.deletedByUs;
      } else if (statusCode == 'UD') {
        type = ConflictType.deletedByThem;
      }

      // Only add if it's a conflict
      if (type != null) {
        conflicts.add(MergeConflict(
          filePath: file.path,
          type: type,
        ));
      }
    }

    final currentBranchResult = await getCurrentBranch();
    final String? currentBranch = currentBranchResult.when(
      success: (branch) => branch,
      failure: (msg, error, stackTrace) => null,
    );

    return MergeState(
      isInProgress: true,
      mergingBranch: mergingBranch,
      currentBranch: currentBranch,
      conflicts: conflicts,
      message: message,
    );
  }

  /// Get file content during merge (for conflict resolution)
  Future<Map<String, String?>> getMergeFileVersions(String filePath) async {
    final result = <String, String?>{
      'ours': null,
      'theirs': null,
      'base': null,
      'working': null,
    };

    try {
      // Get working tree version (with conflict markers)
      final workingFile = File(p.join(repoPath, filePath));
      if (await workingFile.exists()) {
        result['working'] = await workingFile.readAsString();
      }

      // Get ours version (stage 2)
      try {
        final oursResult = await _execute(
          'show :2:"$filePath"',
          throwOnError: false,
        );
        if (oursResult.exitCode == 0) {
          result['ours'] = oursResult.stdout.toString();
        }
      } catch (e) {
        // File might not exist in ours
      }

      // Get theirs version (stage 3)
      try {
        final theirsResult = await _execute(
          'show :3:"$filePath"',
          throwOnError: false,
        );
        if (theirsResult.exitCode == 0) {
          result['theirs'] = theirsResult.stdout.toString();
        }
      } catch (e) {
        // File might not exist in theirs
      }

      // Get base version (stage 1)
      try {
        final baseResult = await _execute(
          'show :1:"$filePath"',
          throwOnError: false,
        );
        if (baseResult.exitCode == 0) {
          result['base'] = baseResult.stdout.toString();
        }
      } catch (e) {
        // File might not exist in base
      }
    } catch (e) {
      // Error getting file versions
    }

    return result;
  }

  /// Resolve conflict by choosing a version
  Future<void> resolveConflict(
    String filePath, {
    required ResolutionChoice choice,
    String? manualContent,
  }) async {
    final file = File(p.join(repoPath, filePath));

    switch (choice) {
      case ResolutionChoice.ours:
        // Checkout ours version
        await _execute('checkout --ours "$filePath"');
        break;

      case ResolutionChoice.theirs:
        // Checkout theirs version
        await _execute('checkout --theirs "$filePath"');
        break;

      case ResolutionChoice.base:
        // Checkout base version (requires getting from stage 1)
        try {
          final baseResult = await _execute('show :1:"$filePath"');
          await file.writeAsString(baseResult.stdout.toString());
        } catch (e) {
          throw GitException('Failed to get base version of file', stderr: e.toString());
        }
        break;

      case ResolutionChoice.manual:
        // Write manual content
        if (manualContent == null) {
          throw GitException('Manual content required for manual resolution');
        }
        await file.writeAsString(manualContent);
        break;

      case ResolutionChoice.both:
        // Keep both changes (concatenate ours + theirs)
        final versions = await getMergeFileVersions(filePath);
        final oursContent = versions['ours'] ?? '';
        final theirsContent = versions['theirs'] ?? '';
        await file.writeAsString('$oursContent\n$theirsContent');
        break;
    }

    // Stage the resolved file
    await stageFile(filePath);
  }

  /// Abort merge
  Future<Result<void>> abortMerge() async {
    return runCatchingAsync(() async {
      await _execute('merge --abort');
    });
  }

  /// Continue merge after resolving conflicts
  Future<Result<void>> continueMerge({String? message}) async {
    return runCatchingAsync(() async {
      // Check if all conflicts are resolved
      final mergeState = await getMergeState();
      if (mergeState.unresolvedCount > 0) {
        throw GitException(
          'Cannot continue merge: ${mergeState.unresolvedCount} conflicts remain unresolved',
        );
      }

      // Commit the merge
      if (message != null && message.isNotEmpty) {
        final result = await commit(message);
        result.unwrap(); // Propagate error if commit fails
      } else {
        // Use default merge message from MERGE_MSG
        await _execute('commit --no-edit');
      }
    });
  }

  // ============================================
  // Advanced Commit Operations
  // ============================================

  /// Amend the last commit with currently staged changes
  Future<void> amendCommit({
    String? newMessage,
    bool noEdit = false,
  }) async {
    final parts = ['commit', '--amend'];

    if (noEdit) {
      parts.add('--no-edit');
    } else if (newMessage != null && newMessage.isNotEmpty) {
      parts.add('-m');
      parts.add('"${newMessage.replaceAll('"', '\\"')}"');
    }

    await _execute(parts.join(' '));
  }

  /// Cherry-pick a commit
  Future<Result<void>> cherryPickCommit(
    String commitHash, {
    bool noCommit = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['cherry-pick'];

      if (noCommit) {
        parts.add('--no-commit');
      }

      parts.add(commitHash);

      await _execute(parts.join(' '));
    });
  }

  /// Abort an ongoing cherry-pick
  Future<Result<void>> abortCherryPick() async {
    return runCatchingAsync(() async {
      await _execute('cherry-pick --abort');
    });
  }

  /// Continue cherry-pick after resolving conflicts
  Future<Result<void>> continueCherryPick() async {
    return runCatchingAsync(() async {
      await _execute('cherry-pick --continue');
    });
  }

  /// Revert a commit (creates a new commit that undoes the changes)
  Future<Result<void>> revertCommit(
    String commitHash, {
    bool noCommit = false,
    String? message,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['revert'];

      if (noCommit) {
        parts.add('--no-commit');
      }

      if (message != null && message.isNotEmpty) {
        parts.add('-m');
        parts.add('"${message.replaceAll('"', '\\"')}"');
      }

      parts.add(commitHash);

      await _execute(parts.join(' '));
    });
  }

  /// Reset branch to a specific commit
  Future<Result<void>> resetToCommit(
    String commitHash, {
    ResetMode mode = ResetMode.mixed,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['reset'];

      switch (mode) {
        case ResetMode.soft:
          parts.add('--soft');
          break;
        case ResetMode.mixed:
          parts.add('--mixed');
          break;
        case ResetMode.hard:
          parts.add('--hard');
          break;
      }

      parts.add(commitHash);

      await _execute(parts.join(' '));
    });
  }

  /// Clean working directory (remove untracked files)
  Future<Result<void>> cleanWorkingDirectory({
    bool directories = false,
    bool force = false,
    bool dryRun = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['clean'];

      if (dryRun) {
        parts.add('-n'); // Dry run
      } else if (force) {
        parts.add('-f'); // Force
      }

      if (directories) {
        parts.add('-d'); // Include directories
      }

      await _execute(parts.join(' '));
    });
  }

  // ============================================
  // Reflog
  // ============================================

  /// Get reflog entries
  ///
  /// [maxCount] - Maximum number of entries to return (default 50)
  /// [ref] - Specific ref to show reflog for (default HEAD)
  Future<Result<List<ReflogEntry>>> getReflog({int maxCount = 50, String ref = 'HEAD'}) async {
    return runCatchingAsync(() async {
      final parts = ['reflog', 'show', ref, '-n', maxCount.toString()];
      final result = await _execute(parts.join(' '));

      if (result.stdout == null) return [];

      return ReflogParser.parse(result.stdout.toString());
    });
  }

  /// Get all reflog entries (no limit)
  Future<Result<List<ReflogEntry>>> getAllReflog({String ref = 'HEAD'}) async {
    return runCatchingAsync(() async {
      final result = await _execute('reflog show $ref');

      if (result.stdout == null) return [];

      return ReflogParser.parse(result.stdout.toString());
    });
  }

  /// Reset HEAD to a specific reflog entry
  ///
  /// [selector] - The reflog selector (e.g., HEAD@{2})
  /// [mode] - Reset mode (soft, mixed, or hard)
  Future<Result<void>> resetToReflog(String selector, {ResetMode mode = ResetMode.mixed}) async {
    return runCatchingAsync(() async {
      final parts = ['reset'];

      switch (mode) {
        case ResetMode.soft:
          parts.add('--soft');
          break;
        case ResetMode.mixed:
          parts.add('--mixed');
          break;
        case ResetMode.hard:
          parts.add('--hard');
          break;
      }

      parts.add(selector);

      await _execute(parts.join(' '));
    });
  }

  // ============================================
  // Bisect
  // ============================================

  /// Start bisecting between a good and bad commit
  ///
  /// [badCommit] - The commit where the bug is present (defaults to HEAD)
  /// [goodCommit] - The commit where the bug was not present
  Future<void> startBisect({
    String badCommit = 'HEAD',
    required String goodCommit,
  }) async {
    // Start bisect
    await _execute('bisect start');

    // Mark bad commit
    await _execute('bisect bad $badCommit');

    // Mark good commit
    await _execute('bisect good $goodCommit');
  }

  /// Mark current commit as good
  Future<void> markBisectGood() async {
    await _execute('bisect good');
  }

  /// Mark current commit as bad
  Future<void> markBisectBad() async {
    await _execute('bisect bad');
  }

  /// Skip current commit (cannot be tested)
  Future<void> skipBisect() async {
    await _execute('bisect skip');
  }

  /// Reset/stop bisect and return to original HEAD
  Future<Result<void>> resetBisect() async {
    return runCatchingAsync(() async {
      await _execute('bisect reset');
    });
  }

  /// Get current bisect state
  Future<BisectState> getBisectState() async {
    // Check if bisect is active by looking for .git/BISECT_LOG
    final bisectLogFile = File(p.join(repoPath, '.git', 'BISECT_LOG'));
    final bisectStartFile = File(p.join(repoPath, '.git', 'BISECT_START'));

    if (!await bisectLogFile.exists() || !await bisectStartFile.exists()) {
      return BisectState.idle();
    }

    // Bisect is active, get current commit
    final currentCommit = await getHeadCommit();

    // Check if bisect found the commit
    final bisectResult = await _tryGetBisectResult();
    if (bisectResult != null) {
      return BisectState.completed(
        foundCommit: bisectResult,
      );
    }

    // Parse bisect log to get good/bad commits
    final bisectLog = await bisectLogFile.readAsString();
    final goodCommits = <String>[];
    final badCommits = <String>[];

    for (final line in bisectLog.split('\n')) {
      if (line.startsWith('git bisect good')) {
        final match = RegExp(r'git bisect good ([0-9a-f]+)').firstMatch(line);
        if (match != null) {
          goodCommits.add(match.group(1)!);
        }
      } else if (line.startsWith('git bisect bad')) {
        final match = RegExp(r'git bisect bad ([0-9a-f]+)').firstMatch(line);
        if (match != null) {
          badCommits.add(match.group(1)!);
        }
      }
    }

    // Try to get steps remaining from bisect visualize
    int? stepsRemaining;
    try {
      final result = await _execute('bisect visualize --oneline');
      if (result.stdout != null) {
        final lines = result.stdout.toString().split('\n').where((l) => l.trim().isNotEmpty).length;
        // Estimate steps remaining (log2 of remaining commits)
        if (lines > 0) {
          stepsRemaining = (lines / 2).ceil();
        }
      }
    } catch (e) {
      // Ignore errors, steps remaining is optional
    }

    return BisectState.active(
      currentCommit: currentCommit?.hash ?? 'Unknown',
      stepsRemaining: stepsRemaining,
      goodCommits: goodCommits,
      badCommits: badCommits,
    );
  }

  /// Try to get the bisect result if found
  Future<String?> _tryGetBisectResult() async {
    try {
      final result = await _execute('bisect log');
      if (result.stdout != null) {
        final log = result.stdout.toString();
        // Check for the "first bad commit" message
        final match = RegExp(r'([0-9a-f]+) is the first bad commit').firstMatch(log);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Get HEAD commit
  Future<GitCommit?> getHeadCommit() async {
    final result = await getLog(limit: 1);
    final commits = result.unwrapOr([]);
    return commits.isNotEmpty ? commits.first : null;
  }

  // ============================================
  // Rebase
  // ============================================

  /// Rebase current branch onto another branch
  ///
  /// [ontoBranch] - The branch to rebase onto
  /// [interactive] - Whether to do an interactive rebase
  /// [preserveMerges] - Whether to preserve merge commits during rebase
  Future<Result<void>> rebaseBranch({
    required String ontoBranch,
    bool interactive = false,
    bool preserveMerges = false,
  }) async {
    return runCatchingAsync(() async {
      final parts = ['rebase'];

      if (interactive) {
        parts.add('-i');
      }

      if (preserveMerges) {
        parts.add('--rebase-merges');
      }

      parts.add(ontoBranch);

      await _execute(parts.join(' '));
    });
  }

  /// Continue rebase after resolving conflicts
  Future<Result<void>> continueRebase() async {
    return runCatchingAsync(() async {
      await _execute('rebase --continue');
    });
  }

  /// Skip current commit during rebase
  Future<Result<void>> skipRebase() async {
    return runCatchingAsync(() async {
      await _execute('rebase --skip');
    });
  }

  /// Abort rebase and return to original state
  Future<Result<void>> abortRebase() async {
    return runCatchingAsync(() async {
      await _execute('rebase --abort');
    });
  }

  /// Get current rebase state
  Future<RebaseState> getRebaseState() async {
    // Check if rebase is active by looking for .git/rebase-merge or .git/rebase-apply
    final rebaseMergeDir = Directory(p.join(repoPath, '.git', 'rebase-merge'));
    final rebaseApplyDir = Directory(p.join(repoPath, '.git', 'rebase-apply'));

    if (!await rebaseMergeDir.exists() && !await rebaseApplyDir.exists()) {
      return RebaseState.idle();
    }

    // Rebase is active
    String? ontoBranch;
    int? totalSteps;
    int? currentStep;
    bool hasConflicts = false;

    // Try to read rebase info from rebase-merge (interactive rebase)
    if (await rebaseMergeDir.exists()) {
      final headNameFile = File(p.join(rebaseMergeDir.path, 'head-name'));
      if (await headNameFile.exists()) {
        final headName = await headNameFile.readAsString();
        ontoBranch = headName.trim().replaceAll('refs/heads/', '');
      }

      final msgNumFile = File(p.join(rebaseMergeDir.path, 'msgnum'));
      final endFile = File(p.join(rebaseMergeDir.path, 'end'));

      if (await msgNumFile.exists() && await endFile.exists()) {
        currentStep = int.tryParse(await msgNumFile.readAsString());
        totalSteps = int.tryParse(await endFile.readAsString());
      }
    }
    // Try to read from rebase-apply (non-interactive rebase)
    else if (await rebaseApplyDir.exists()) {
      final headNameFile = File(p.join(rebaseApplyDir.path, 'head-name'));
      if (await headNameFile.exists()) {
        final headName = await headNameFile.readAsString();
        ontoBranch = headName.trim().replaceAll('refs/heads/', '');
      }

      final nextFile = File(p.join(rebaseApplyDir.path, 'next'));
      final lastFile = File(p.join(rebaseApplyDir.path, 'last'));

      if (await nextFile.exists() && await lastFile.exists()) {
        currentStep = int.tryParse(await nextFile.readAsString());
        totalSteps = int.tryParse(await lastFile.readAsString());
      }
    }

    // Check for conflicts - if rebase is paused, there are likely conflicts
    // We can detect this by checking if there are unstaged changes
    try {
      final statusResult = await getStatus();
      final status = statusResult.unwrapOr([]);
      hasConflicts = status.isNotEmpty;
    } catch (e) {
      // If we can't get status, assume no conflicts
      hasConflicts = false;
    }

    // Get current commit being rebased
    String? currentCommit;
    try {
      final headCommit = await getHeadCommit();
      currentCommit = headCommit?.shortHash;
    } catch (e) {
      // Ignore errors
    }

    return RebaseState.active(
      ontoBranch: ontoBranch ?? 'unknown',
      currentCommit: currentCommit,
      totalSteps: totalSteps,
      currentStep: currentStep,
      hasConflicts: hasConflicts,
    );
  }

  /// Squash commits using interactive rebase
  ///
  /// [fromCommit] - The oldest commit hash to include in the squash (commit just before the range)
  /// [toCommit] - The newest commit hash to include in the squash
  /// [newMessage] - The new commit message for the squashed commit
  Future<void> squashCommits({
    required String fromCommit,
    required String toCommit,
    required String newMessage,
  }) async {
    // Use reset and commit to squash
    // This is simpler than interactive rebase and works well for consecutive commits

    // Step 1: Soft reset to the commit before the range (parent of oldest commit)
    final result = await _execute('rev-parse $fromCommit^', throwOnError: false);

    // Check if the command failed (non-zero exit code or stderr has content)
    if (result.exitCode != 0) {
      final errorMessage = result.stderr.toString().trim();
      if (errorMessage.contains('unknown revision')) {
        throw Exception('Cannot squash: The oldest selected commit appears to be the root commit (no parent commit exists).');
      }
      throw Exception('Could not find parent commit: $errorMessage');
    }

    final parentCommit = result.stdout.toString().trim();
    if (parentCommit.isEmpty) {
      throw Exception('Could not find parent commit: rev-parse returned empty result');
    }

    // Step 2: Soft reset to parent (keeps all changes in staging area)
    await _execute('reset --soft $parentCommit');

    // Step 3: Create new commit with all the changes
    final escapedMessage = newMessage.replaceAll('"', '\\"');
    await _execute('commit -m "$escapedMessage"');
  }

  // ============================================
  // Utility
  // ============================================

  /// Execute any Git command (for advanced operations)
  Future<String> executeCommand(String command) async {
    final result = await _execute(command);
    return result.stdout.toString();
  }
}
