import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

/// Result of a batch operation for a repository
class RepositoryBatchResult {
  final bool success;
  final String message;

  const RepositoryBatchResult({
    required this.success,
    required this.message,
  });
}

/// Stores results from batch operations for each repository
/// Key: repository path, Value: operation result
class RepositoryBatchResultNotifier extends StateNotifier<Map<String, RepositoryBatchResult>> {
  RepositoryBatchResultNotifier() : super({});

  /// Set a result for a specific repository
  void setResult(String repositoryPath, bool success, String message) {
    state = {
      ...state,
      repositoryPath: RepositoryBatchResult(success: success, message: message),
    };
  }

  /// Set multiple results at once
  void setResults(Map<String, RepositoryBatchResult> results) {
    state = {
      ...state,
      ...results,
    };
  }

  /// Clear result for a specific repository
  void clearResult(String repositoryPath) {
    final newState = Map<String, RepositoryBatchResult>.from(state);
    newState.remove(repositoryPath);
    state = newState;
  }

  /// Clear all results
  void clearAll() {
    state = {};
  }

  /// Get result for a specific repository
  RepositoryBatchResult? getResult(String repositoryPath) {
    return state[repositoryPath];
  }

  /// Check if a repository has a result
  bool hasResult(String repositoryPath) {
    return state.containsKey(repositoryPath);
  }
}

/// Provider for repository batch operation results
final repositoryBatchErrorProvider =
    StateNotifierProvider<RepositoryBatchResultNotifier, Map<String, RepositoryBatchResult>>(
  (ref) => RepositoryBatchResultNotifier(),
);

/// Convenience provider to get result for a specific repository
final repositoryBatchErrorByPathProvider =
    Provider.family<RepositoryBatchResult?, String>((ref, repositoryPath) {
  final results = ref.watch(repositoryBatchErrorProvider);
  return results[repositoryPath];
});
