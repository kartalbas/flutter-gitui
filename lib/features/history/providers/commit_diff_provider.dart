import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/git/git_providers.dart';

/// The file the user highlighted in one commit's changed-file list.
///
/// The commit hash is part of the value so a choice can never leak across
/// commits: selecting another commit that happens to touch a same-named file
/// starts from that commit's own first file instead of silently keeping an
/// unrelated highlight alive.
@immutable
class HighlightedCommitFile {
  const HighlightedCommitFile({required this.commitHash, required this.path});

  final String commitHash;
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightedCommitFile &&
          runtimeType == other.runtimeType &&
          commitHash == other.commitHash &&
          path == other.path;

  @override
  int get hashCode => Object.hash(commitHash, path);
}

/// The user's explicit file choice, if any.
///
/// Raw state - the view never reads this directly. Like the commit selection,
/// the stored choice only counts while it names something the screen shows,
/// and [displayedCommitFileProvider] is the resolution that enforces it.
final highlightedCommitFileProvider = StateProvider<HighlightedCommitFile?>(
  (ref) => null,
);

/// The file whose diff the history view shows for [commitHash]: the explicit
/// choice while this commit still has that file, otherwise the first changed
/// file.
///
/// Falling back to the first file is what makes selecting a commit show a
/// diff immediately - an empty panel waiting for a second click would defeat
/// the point of showing changes in place.
final displayedCommitFileProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, commitHash) async {
      final files = await ref.watch(
        commitChangedFilesProvider(commitHash).future,
      );
      if (files.isEmpty) return null;

      final chosen = ref.watch(highlightedCommitFileProvider);
      if (chosen != null &&
          chosen.commitHash == commitHash &&
          files.any((file) => file.path == chosen.path)) {
        return chosen.path;
      }
      return files.first.path;
    });

/// The diff text of one file in one commit.
///
/// Keyed by the pair so switching between files of the same commit swaps
/// cached values instead of re-running git; auto-disposed so browsing a long
/// history does not accumulate one diff per visited file for the session.
final commitFileDiffProvider = FutureProvider.autoDispose
    .family<String, ({String commitHash, String filePath})>((ref, key) async {
      final gitService = ref.watch(gitServiceProvider);
      if (gitService == null) return '';

      final result = await gitService.getDiffForCommit(
        key.commitHash,
        key.filePath,
      );
      return result.unwrap();
    });
