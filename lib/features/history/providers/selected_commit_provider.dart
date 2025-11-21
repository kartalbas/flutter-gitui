import 'package:riverpod/legacy.dart';
import '../../../core/git/models/commit.dart';

/// Provider for the currently selected commit in history view
final selectedCommitProvider = StateProvider<GitCommit?>((ref) => null);

/// Provider for the selected commit index in the list
final selectedCommitIndexProvider = StateProvider<int>((ref) => -1);
