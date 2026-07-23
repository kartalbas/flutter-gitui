import 'dart:async';

import 'package:riverpod/legacy.dart';

/// Progress information for an ongoing operation
class ProgressInfo {
  final String operationName;
  final int currentStep;
  final int totalSteps;
  final String? statusMessage;
  final bool isIndeterminate;

  /// Whether input must stay blocked while the operation runs.
  ///
  /// Automatic per-command progress is non-blocking: presenting it modally
  /// flashed a dialog over every fast local read (#288). Only operations a
  /// caller starts explicitly may take the modal treatment.
  final bool isBlocking;

  const ProgressInfo({
    required this.operationName,
    required this.currentStep,
    required this.totalSteps,
    this.statusMessage,
    this.isIndeterminate = false,
    this.isBlocking = true,
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
    bool? isBlocking,
  }) {
    return ProgressInfo(
      operationName: operationName ?? this.operationName,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      statusMessage: statusMessage ?? this.statusMessage,
      isIndeterminate: isIndeterminate ?? this.isIndeterminate,
      isBlocking: isBlocking ?? this.isBlocking,
    );
  }
}

/// Progress service state notifier
///
/// The state is exactly what the UI renders, so it stays null until an
/// operation has been running for [showDelay]: every git command feeds this
/// notifier, and most are local reads that finish in tens of milliseconds.
/// Showing those flashed an indicator on every click (#288).
class ProgressNotifier extends StateNotifier<ProgressInfo?> {
  ProgressNotifier({this.showDelay = defaultShowDelay}) : super(null);

  /// How long an operation must run before any indicator appears.
  ///
  /// Local reads (status, log, show) complete in well under 100ms, so 400ms
  /// clears them with margin even on a cold cache, while a genuinely slow
  /// operation still gets feedback before the ~1s point at which users start
  /// doubting that a click registered.
  static const Duration defaultShowDelay = Duration(milliseconds: 400);

  /// Injectable so tests can exercise the threshold without waiting 400ms.
  final Duration showDelay;

  // Git commands routinely overlap (file watcher refreshes, fan-out provider
  // invalidations), so per-command progress is refcounted: without it the
  // first command to finish hid the indicator while others were still running.
  int _automaticOperationCount = 0;

  // A multi-step operation started by the UI owns the indicator; per-command
  // progress must neither overwrite its label nor clear it mid-flow.
  bool _hasExplicitOperation = false;

  // Held back by the show delay. Kept out of [state] so that an operation
  // finishing before the delay elapses leaves nothing to render.
  ProgressInfo? _pending;
  Timer? _showTimer;

  /// Start a new operation with progress tracking
  ///
  /// [isAutomatic] marks implicit per-git-command progress, which is
  /// refcounted, non-blocking and yields to an explicitly started operation.
  void startOperation(
    String operationName,
    int totalSteps, {
    bool isIndeterminate = false,
    bool isAutomatic = false,
  }) {
    if (isAutomatic) {
      _automaticOperationCount++;
      // A visible or already scheduled indicator is joined, not restarted:
      // overlapping commands must read as one continuous busy period, and an
      // explicitly started operation keeps ownership of the presentation.
      if (_hasExplicitOperation || state != null || _pending != null) return;
    } else {
      _hasExplicitOperation = true;
    }
    _pending = ProgressInfo(
      operationName: operationName,
      currentStep: 0,
      totalSteps: totalSteps,
      isIndeterminate: isIndeterminate,
      isBlocking: !isAutomatic,
    );
    // Nothing renders yet: an operation that completes before the delay
    // elapses cancels this timer, so fast work never flashes an indicator.
    _showTimer?.cancel();
    _showTimer = Timer(showDelay, () {
      state = _pending;
      _pending = null;
    });
  }

  /// Update progress
  void updateProgress(int currentStep, {String? statusMessage}) {
    // Steps taken while the show delay holds the indicator back must not be
    // lost, or it would mount showing stale numbers.
    if (_pending != null) {
      _pending = _pending!.copyWith(
        currentStep: currentStep,
        statusMessage: statusMessage,
      );
      return;
    }
    if (state == null) return;
    state = state!.copyWith(
      currentStep: currentStep,
      statusMessage: statusMessage,
    );
  }

  /// Increment progress by 1
  void incrementProgress({String? statusMessage}) {
    if (_pending != null) {
      _pending = _pending!.copyWith(
        currentStep: _pending!.currentStep + 1,
        statusMessage: statusMessage,
      );
      return;
    }
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
      // Keep the indicator (or its pending show) while another command is
      // still in flight or an explicitly started operation owns it.
      if (_hasExplicitOperation || _automaticOperationCount > 0) return;
    } else {
      _hasExplicitOperation = false;
    }
    _clearIndicator();
  }

  /// Cancel/abort the operation
  void cancelOperation() {
    _hasExplicitOperation = false;
    _clearIndicator();
  }

  void _clearIndicator() {
    // Cancelling the timer is what guarantees a fast operation never mounts
    // an indicator at all.
    _showTimer?.cancel();
    _showTimer = null;
    _pending = null;
    state = null;
  }

  @override
  void dispose() {
    // A timer surviving the notifier would assign state after disposal.
    _showTimer?.cancel();
    super.dispose();
  }
}

/// Global progress provider
final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressInfo?>(
  (ref) {
    return ProgressNotifier();
  },
);
