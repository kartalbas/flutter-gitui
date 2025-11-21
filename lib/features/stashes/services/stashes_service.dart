import '../../../core/git/models/stash.dart';

/// Service class for stash-related business logic
/// Handles filtering and searching stashes
class StashesService {
  const StashesService();

  /// Filter stashes based on search query
  /// Searches in stash message, branch name, and reference
  List<GitStash> filterStashes({
    required List<GitStash> stashes,
    required String searchQuery,
  }) {
    if (searchQuery.isEmpty) {
      return stashes;
    }

    final query = searchQuery.toLowerCase();
    return stashes.where((stash) {
      return stash.message.toLowerCase().contains(query) ||
             stash.branch.toLowerCase().contains(query) ||
             stash.ref.toLowerCase().contains(query);
    }).toList();
  }
}
