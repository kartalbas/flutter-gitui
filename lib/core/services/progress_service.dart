import 'package:riverpod/legacy.dart';

/// Progress information for an ongoing operation
class ProgressInfo {
  final String operationName;
  final int currentStep;
  final int totalSteps;
  final String? statusMessage;
  final bool isIndeterminate;

  const ProgressInfo({
    required this.operationName,
    required this.currentStep,
    required this.totalSteps,
    this.statusMessage,
    this.isIndeterminate = false,
  });

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0.0;
  int get remainingSteps => totalSteps - currentStep;
  bool get isComplete => currentStep >= totalSteps;

  ProgressInfo copyWith({
    String? operationName,
    int? currentStep,
    int? totalSteps,
    String? statusMessage,
    bool? isIndeterminate,
  }) {
    return ProgressInfo(
      operationName: operationName ?? this.operationName,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      statusMessage: statusMessage ?? this.statusMessage,
      isIndeterminate: isIndeterminate ?? this.isIndeterminate,
    );
  }
}

/// Progress service state notifier
class ProgressNotifier extends StateNotifier<ProgressInfo?> {
  ProgressNotifier() : super(null);

  // Git commands routinely overlap (file watcher refreshes, fan-out provider
  // invalidations), so per-command progress is refcounted: without it the
  // first command to finish hid the overlay while others were still running.
  int _automaticOperationCount = 0;

  // A multi-step operation started by the UI owns the overlay; per-command
  // progress must neither overwrite its label nor clear it mid-flow.
  bool _hasExplicitOperation = false;

  /// Start a new operation with progress tracking
  ///
  /// [isAutomatic] marks implicit per-git-command progress, which is
  /// refcounted and yields to an explicitly started operation.
  void startOperation(
    String operationName,
    int totalSteps, {
    bool isIndeterminate = false,
    bool isAutomatic = false,
  }) {
    if (isAutomatic) {
      _automaticOperationCount++;
      if (_hasExplicitOperation || state != null) return;
    } else {
      _hasExplicitOperation = true;
    }
    state = ProgressInfo(
      operationName: operationName,
      currentStep: 0,
      totalSteps: totalSteps,
      isIndeterminate: isIndeterminate,
    );
  }

  /// Update progress
  void updateProgress(int currentStep, {String? statusMessage}) {
    if (state == null) return;
    state = state!.copyWith(
      currentStep: currentStep,
      statusMessage: statusMessage,
    );
  }

  /// Increment progress by 1
  void incrementProgress({String? statusMessage}) {
    if (state == null) return;
    state = state!.copyWith(
      currentStep: state!.currentStep + 1,
      statusMessage: statusMessage,
    );
  }

  /// Complete the operation
  ///
  /// [isAutomatic] must match the value passed to [startOperation].
  void completeOperation({bool isAutomatic = false}) {
    if (isAutomatic) {
      if (_automaticOperationCount > 0) _automaticOperationCount--;
      // Keep the overlay up while another command is still in flight or an
      // explicitly started operation owns it.
      if (_hasExplicitOperation || _automaticOperationCount > 0) return;
    } else {
      _hasExplicitOperation = false;
    }
    state = null;
  }

  /// Cancel/abort the operation
  void cancelOperation() {
    _hasExplicitOperation = false;
    state = null;
  }
}

/// Global progress provider
final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressInfo?>(
  (ref) {
    return ProgressNotifier();
  },
);
