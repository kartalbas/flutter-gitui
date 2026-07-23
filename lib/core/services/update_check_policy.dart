/// How often the application may start an update check on its own.
///
/// The user owns this schedule: `never` means not a single request leaves the
/// machine, and the interval choices must hold across restarts, which is why
/// the last check time is persisted in the configuration rather than kept in
/// session state.
enum UpdateCheckFrequency { onStart, daily, weekly, never }

/// What the most recent completed update check concluded.
enum UpdateCheckOutcome { upToDate, updateAvailable, failed }

/// Whether an automatic update check may run now.
///
/// Pure so the scheduling behaviour is provable in a unit test: the caller
/// passes the configured [frequency], the persisted [lastCheck] time and the
/// current [now].
bool shouldCheckForUpdates({
  required UpdateCheckFrequency frequency,
  required DateTime? lastCheck,
  required DateTime now,
}) {
  switch (frequency) {
    case UpdateCheckFrequency.onStart:
      return true;
    case UpdateCheckFrequency.never:
      return false;
    case UpdateCheckFrequency.daily:
      return _intervalElapsed(lastCheck, now, const Duration(days: 1));
    case UpdateCheckFrequency.weekly:
      return _intervalElapsed(lastCheck, now, const Duration(days: 7));
  }
}

bool _intervalElapsed(DateTime? lastCheck, DateTime now, Duration interval) {
  if (lastCheck == null) return true;
  final elapsed = now.difference(lastCheck);
  // A timestamp from the future means the clock was moved backwards since the
  // last check; trusting it would silence checks for as far ahead as it lies.
  if (elapsed.isNegative) return true;
  return elapsed >= interval;
}
