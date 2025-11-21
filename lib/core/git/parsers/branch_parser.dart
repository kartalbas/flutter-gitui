import '../models/branch.dart';

/// Parser for git branch output
class BranchParser {
  /// Parse git branch -vv output (local branches with verbose info)
  /// Format: * main abc1234 [origin/main: ahead 2, behind 1] Commit message
  static List<GitBranch> parseVerbose(String output, {List<String>? protectedBranches}) {
    final branches = <GitBranch>[];
    final lines = output.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      final branch = _parseBranchLine(line, isRemote: false, protectedBranches: protectedBranches);
      if (branch != null) {
        branches.add(branch);
      }
    }

    return branches;
  }

  /// Parse git branch -r output (remote branches)
  /// Format:   origin/main
  ///           origin/HEAD -> origin/main
  static List<GitBranch> parseRemote(String output, {List<String>? protectedBranches}) {
    final branches = <GitBranch>[];
    final lines = output.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      // Skip HEAD pointer lines like "origin/HEAD -> origin/main"
      if (line.contains('->')) continue;

      final branch = _parseBranchLine(line, isRemote: true, protectedBranches: protectedBranches);
      if (branch != null) {
        branches.add(branch);
      }
    }

    return branches;
  }

  /// Parse git branch -a -vv output (all branches)
  static List<GitBranch> parseAll(String output, {List<String>? protectedBranches}) {
    final branches = <GitBranch>[];
    final lines = output.split('\n').where((line) => line.trim().isNotEmpty);

    for (final line in lines) {
      // Skip HEAD pointer lines
      if (line.contains('->')) continue;

      final isRemote = line.trimLeft().startsWith('remotes/');
      final branch = _parseBranchLine(line, isRemote: isRemote, protectedBranches: protectedBranches);
      if (branch != null) {
        branches.add(branch);
      }
    }

    return branches;
  }

  /// Parse a single branch line
  static GitBranch? _parseBranchLine(String line, {required bool isRemote, List<String>? protectedBranches}) {
    try {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return null;

      // Check if current branch (starts with *)
      final isCurrent = trimmed.startsWith('*');

      // Remove the * marker and trim
      var branchLine = isCurrent ? trimmed.substring(1).trim() : trimmed;

      // For remote branches, remove "remotes/" prefix
      if (branchLine.startsWith('remotes/')) {
        branchLine = branchLine.substring('remotes/'.length);
      }

      // Parse branch name (first token)
      final parts = branchLine.split(RegExp(r'\s+'));
      if (parts.isEmpty) return null;

      final branchName = parts[0];
      String? commitHash;
      String? upstream;
      int? aheadBy;
      int? behindBy;
      String? commitMessage;

      // If verbose format (has commit hash)
      if (parts.length > 1 && _isCommitHash(parts[1])) {
        commitHash = parts[1];

        // Parse tracking info [origin/main: ahead 2, behind 1]
        final trackingMatch = RegExp(r'\[([^\]]+)\]').firstMatch(branchLine);
        if (trackingMatch != null) {
          final tracking = trackingMatch.group(1)!;

          // Extract upstream branch name
          final upstreamParts = tracking.split(':');
          upstream = upstreamParts[0].trim();

          // Extract ahead/behind counts
          if (upstreamParts.length > 1) {
            final status = upstreamParts[1];
            final aheadMatch = RegExp(r'ahead (\d+)').firstMatch(status);
            final behindMatch = RegExp(r'behind (\d+)').firstMatch(status);

            if (aheadMatch != null) {
              aheadBy = int.tryParse(aheadMatch.group(1)!);
            }
            if (behindMatch != null) {
              behindBy = int.tryParse(behindMatch.group(1)!);
            }
          }

          // Extract commit message (after tracking info)
          final messageStart = branchLine.indexOf(']') + 1;
          if (messageStart < branchLine.length) {
            commitMessage = branchLine.substring(messageStart).trim();
          }
        } else {
          // No tracking info, just commit message after hash
          final messageStart = branchLine.indexOf(parts[1]) + parts[1].length;
          if (messageStart < branchLine.length) {
            commitMessage = branchLine.substring(messageStart).trim();
          }
        }
      }

      // Construct full name
      String fullName;
      if (isRemote) {
        fullName = 'refs/remotes/$branchName';
      } else {
        fullName = 'refs/heads/$branchName';
      }

      // Check if branch is protected
      final isProtected = protectedBranches != null && protectedBranches.isNotEmpty
          ? GitBranch.isProtectedBranch(branchName, protectedBranches)
          : false;

      return GitBranch(
        name: branchName,
        fullName: fullName,
        isLocal: !isRemote,
        isRemote: isRemote,
        isCurrent: isCurrent,
        isProtected: isProtected,
        upstreamBranch: upstream,
        aheadBy: aheadBy,
        behindBy: behindBy,
        lastCommitHash: commitHash,
        lastCommitMessage: commitMessage,
      );
    } catch (e) {
      // If parsing fails, return null
      return null;
    }
  }

  /// Check if a string looks like a commit hash (7-40 hex characters)
  static bool _isCommitHash(String str) {
    return RegExp(r'^[0-9a-f]{7,40}$').hasMatch(str);
  }

  /// Get current branch name from git branch output
  static String? getCurrentBranch(String output) {
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.trim().startsWith('*')) {
        final parts = line.trim().substring(1).trim().split(RegExp(r'\s+'));
        return parts.isNotEmpty ? parts[0] : null;
      }
    }
    return null;
  }
}
