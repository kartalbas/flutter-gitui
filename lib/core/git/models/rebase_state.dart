/// State of git rebase operation
class RebaseState {
  final bool isActive;
  final String? ontoBranch;
  final String? currentCommit;
  final int? totalSteps;
  final int? currentStep;
  final bool hasConflicts;

  const RebaseState({
    required this.isActive,
    this.ontoBranch,
    this.currentCommit,
    this.totalSteps,
    this.currentStep,
    this.hasConflicts = false,
  });

  /// Create idle state (no rebase active)
  factory RebaseState.idle() {
    return const RebaseState(isActive: false);
  }

  /// Create active rebase state
  factory RebaseState.active({
    required String ontoBranch,
    String? currentCommit,
    int? totalSteps,
    int? currentStep,
    bool hasConflicts = false,
  }) {
    return RebaseState(
      isActive: true,
      ontoBranch: ontoBranch,
      currentCommit: currentCommit,
      totalSteps: totalSteps,
      currentStep: currentStep,
      hasConflicts: hasConflicts,
    );
  }

  /// Get progress percentage
  double? get progress {
    if (totalSteps == null || currentStep == null || totalSteps == 0) {
      return null;
    }
    return currentStep! / totalSteps!;
  }

  /// Get progress text
  String? get progressText {
    if (totalSteps == null || currentStep == null) return null;
    return '$currentStep / $totalSteps';
  }

  /// Copy with updated fields
  RebaseState copyWith({
    bool? isActive,
    String? ontoBranch,
    String? currentCommit,
    int? totalSteps,
    int? currentStep,
    bool? hasConflicts,
  }) {
    return RebaseState(
      isActive: isActive ?? this.isActive,
      ontoBranch: ontoBranch ?? this.ontoBranch,
      currentCommit: currentCommit ?? this.currentCommit,
      totalSteps: totalSteps ?? this.totalSteps,
      currentStep: currentStep ?? this.currentStep,
      hasConflicts: hasConflicts ?? this.hasConflicts,
    );
  }
}

/// Mode for rebase operation
enum RebaseMode {
  normal,
  interactive;

  String get displayName {
    switch (this) {
      case RebaseMode.normal:
        return 'Normal';
      case RebaseMode.interactive:
        return 'Interactive';
    }
  }
}

/// Action during rebase conflict resolution
enum RebaseAction {
  continue_,
  skip,
  abort;

  String get displayName {
    switch (this) {
      case RebaseAction.continue_:
        return 'Continue';
      case RebaseAction.skip:
        return 'Skip';
      case RebaseAction.abort:
        return 'Abort';
    }
  }

  String get command {
    switch (this) {
      case RebaseAction.continue_:
        return 'continue';
      case RebaseAction.skip:
        return 'skip';
      case RebaseAction.abort:
        return 'abort';
    }
  }
}
