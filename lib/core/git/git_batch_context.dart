import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Types of providers that can be refreshed
enum RefreshType {
  status,
  branches,
  stashes,
  tags,
  remotes,
  history,
  mergeState,
}

/// Context for tracking batch git operations
///
/// This class accumulates refresh requests during a batch operation
/// and executes them all at once when the batch ends.
class GitBatchContext {
  final Set<RefreshType> _pendingRefreshes = {};
  bool _isActive = false;
  int _operationCount = 0;
  int _completedOperations = 0;
  String? _batchName;

  /// Whether a batch operation is currently active
  bool get isActive => _isActive;

  /// Number of operations in the current batch
  int get operationCount => _operationCount;

  /// Number of completed operations in the current batch
  int get completedOperations => _completedOperations;

  /// Progress percentage (0.0 to 1.0)
  double get progress => _operationCount > 0
      ? _completedOperations / _operationCount
      : 0.0;

  /// Name of the current batch operation
  String? get batchName => _batchName;

  /// Start a new batch operation
  void begin({String? name, int? totalOperations}) {
    _isActive = true;
    _pendingRefreshes.clear();
    _operationCount = totalOperations ?? 0;
    _completedOperations = 0;
    _batchName = name;
  }

  /// Set the total number of operations in the batch
  void setTotalOperations(int count) {
    _operationCount = count;
  }

  /// Mark a refresh type as pending
  void markForRefresh(RefreshType type) {
    if (_isActive) {
      _pendingRefreshes.add(type);
    }
  }

  /// Mark multiple refresh types as pending
  void markMultipleForRefresh(List<RefreshType> types) {
    if (_isActive) {
      _pendingRefreshes.addAll(types);
    }
  }

  /// Increment the completed operation count
  void incrementCompleted() {
    if (_isActive && _completedOperations < _operationCount) {
      _completedOperations++;
    }
  }

  /// Get all pending refresh types and clear them
  Set<RefreshType> getPendingRefreshes() {
    final result = Set<RefreshType>.from(_pendingRefreshes);
    _pendingRefreshes.clear();
    return result;
  }

  /// Check if a specific refresh type is pending
  bool hasPendingRefresh(RefreshType type) {
    return _pendingRefreshes.contains(type);
  }

  /// End the batch operation
  void end() {
    _isActive = false;
    _operationCount = 0;
    _completedOperations = 0;
    _batchName = null;
  }

  /// Clear all pending refreshes without ending the batch
  void clearPending() {
    _pendingRefreshes.clear();
  }
}

/// Provider for the global batch context
final gitBatchContextProvider = Provider<GitBatchContext>((ref) {
  return GitBatchContext();
});
