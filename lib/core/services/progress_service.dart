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

  /// Start a new operation with progress tracking
  void startOperation(
    String operationName,
    int totalSteps, {
    bool isIndeterminate = false,
  }) {
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
  void completeOperation() {
    state = null;
  }

  /// Cancel/abort the operation
  void cancelOperation() {
    state = null;
  }
}

/// Global progress provider
final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressInfo?>(
  (ref) {
    return ProgressNotifier();
  },
);
