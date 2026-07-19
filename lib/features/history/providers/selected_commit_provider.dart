import 'package:riverpod/legacy.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/config/config_providers.dart';

/// Provider for the currently selected commit in history view.
///
/// Watches the current repository so the selection resets on a repository
/// switch. A commit belongs to one repository: keeping it selected across a
/// switch made the details panel render a foreign commit and issue
/// `git show <hash>` against a repository that does not contain it.
final selectedCommitProvider = StateProvider<GitCommit?>((ref) {
  ref.watch(currentRepositoryPathProvider);
  return null;
});

/// Provider for the selected commit index in the list.
///
/// Reset together with [selectedCommitProvider]; an index into the previous
/// repository's commit list points at an unrelated row.
final selectedCommitIndexProvider = StateProvider<int>((ref) {
  ref.watch(currentRepositoryPathProvider);
  return -1;
});
