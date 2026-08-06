/// Cooperative cancellation for long-running git calls.
///
/// A token is created by the owner of one logical operation - a page load, a
/// whole-history search - handed down into [GitService], and cancelled when
/// the operation is abandoned: the query changed, the screen was left, the
/// repository switched. The git layer registers the kill of its process on
/// [onCancel], so cancelling stops the actual work instead of merely
/// discarding its result.
class GitCancellationToken {
  bool _cancelled = false;
  final List<void Function()> _callbacks = [];

  /// Whether [cancel] has been called.
  ///
  /// Callers check this after an awaited git call: a killed process produces
  /// garbage output or a failure, and neither may reach the UI as if it were
  /// a real result or a real error.
  bool get isCancelled => _cancelled;

  /// Abandons the operation. Idempotent.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final callbacks = List.of(_callbacks);
    _callbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  /// Registers [callback] to run on cancellation. Runs it immediately when
  /// the token is already cancelled, so a registration that loses the race
  /// with [cancel] cannot leak a process nothing will ever kill.
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }
}
