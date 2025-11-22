/// State of git bisect operation
class BisectState {
  final bool isActive;
  final String? currentCommit;
  final int? stepsRemaining;
  final List<String> goodCommits;
  final List<String> badCommits;
  final String? foundCommit;

  const BisectState({
    required this.isActive,
    this.currentCommit,
    this.stepsRemaining,
    this.goodCommits = const [],
    this.badCommits = const [],
    this.foundCommit,
  });

  /// Create idle state (no bisect active)
  factory BisectState.idle() {
    return const BisectState(isActive: false);
  }

  /// Create active bisect state
  factory BisectState.active({
    required String currentCommit,
    int? stepsRemaining,
    List<String> goodCommits = const [],
    List<String> badCommits = const [],
  }) {
    return BisectState(
      isActive: true,
      currentCommit: currentCommit,
      stepsRemaining: stepsRemaining,
      goodCommits: goodCommits,
      badCommits: badCommits,
    );
  }

  /// Create completed bisect state (found the commit)
  factory BisectState.completed({
    required String foundCommit,
    List<String> goodCommits = const [],
    List<String> badCommits = const [],
  }) {
    return BisectState(
      isActive: true,
      foundCommit: foundCommit,
      goodCommits: goodCommits,
      badCommits: badCommits,
    );
  }

  /// Check if bisect has found the commit
  bool get isCompleted => foundCommit != null;

  /// Copy with updated fields
  BisectState copyWith({
    bool? isActive,
    String? currentCommit,
    int? stepsRemaining,
    List<String>? goodCommits,
    List<String>? badCommits,
    String? foundCommit,
  }) {
    return BisectState(
      isActive: isActive ?? this.isActive,
      currentCommit: currentCommit ?? this.currentCommit,
      stepsRemaining: stepsRemaining ?? this.stepsRemaining,
      goodCommits: goodCommits ?? this.goodCommits,
      badCommits: badCommits ?? this.badCommits,
      foundCommit: foundCommit ?? this.foundCommit,
    );
  }
}

/// Step in the bisect process
enum BisectStep {
  good,
  bad,
  skip;

  String get displayName {
    switch (this) {
      case BisectStep.good:
        return 'Good';
      case BisectStep.bad:
        return 'Bad';
      case BisectStep.skip:
        return 'Skip';
    }
  }

  String get command {
    switch (this) {
      case BisectStep.good:
        return 'good';
      case BisectStep.bad:
        return 'bad';
      case BisectStep.skip:
        return 'skip';
    }
  }
}
