import '../../../core/git/models/branch.dart';

/// Service class for branch-related business logic
/// Handles filtering and searching branches
class BranchesService {
  const BranchesService();

  /// Filter branches based on search query
  /// Searches in branch short name
  List<GitBranch> filterBranches({
    required List<GitBranch> branches,
    required String searchQuery,
  }) {
    if (searchQuery.isEmpty) {
      return branches;
    }

    final query = searchQuery.toLowerCase();
    return branches.where((branch) {
      return branch.shortName.toLowerCase().contains(query);
    }).toList();
  }
}
