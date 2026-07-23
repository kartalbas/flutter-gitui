// The scheduling behaviour behind automatic update checks (#294): the user's
// frequency choice plus the persisted last-check time decide whether a check
// runs, and nothing else may.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/update_check_policy.dart';

void main() {
  final now = DateTime(2026, 7, 23, 12);

  group('on every start', () {
    test('checks even when the last check just happened', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.onStart,
          lastCheck: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('checks when no check has ever run', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.onStart,
          lastCheck: null,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('never', () {
    test('does not check even when no check has ever run', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.never,
          lastCheck: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('does not check no matter how old the last check is', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.never,
          lastCheck: now.subtract(const Duration(days: 365)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('daily', () {
    test('checks when no check has ever run', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.daily,
          lastCheck: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('stays quiet while the last check is younger than a day', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.daily,
          lastCheck: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
    });

    test('checks once a full day has passed', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.daily,
          lastCheck: now.subtract(const Duration(hours: 24)),
          now: now,
        ),
        isTrue,
      );
    });

    test('checks when the stored time lies in the future', () {
      // A clock moved backwards must not silence checks until it catches up.
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.daily,
          lastCheck: now.add(const Duration(hours: 2)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('weekly', () {
    test('checks when no check has ever run', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.weekly,
          lastCheck: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('stays quiet six days after the last check', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.weekly,
          lastCheck: now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isFalse,
      );
    });

    test('checks seven days after the last check', () {
      expect(
        shouldCheckForUpdates(
          frequency: UpdateCheckFrequency.weekly,
          lastCheck: now.subtract(const Duration(days: 7)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
