import 'dart:async';

/// A sink that accepts everything and keeps nothing.
///
/// process_run treats a null stdout/stderr as "not configured" and falls back
/// to the process-wide console in its ProcessException handler, which is the
/// one path that matters here: a Windows GUI application has no console
/// attached, so that write fails with an invalid handle and buries the real
/// error under a FileSystemException. Handing it a sink that goes nowhere
/// means the fallback is never reached.
class DiscardingSink implements StreamSink<List<int>> {
  final Completer<void> _done = Completer<void>();

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<void> close() {
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  @override
  Future<void> get done => _done.future;
}
