// The Updates section of the configuration: defaults for a file that predates
// it, a round-trip of every field through the YAML the app writes, degradation
// of unreadable stored values, and the migration away from the rendered
// English sentence this section used to persist (#393).

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_service.dart';
import 'package:flutter_gitui/core/services/update_check_policy.dart';
import 'package:flutter_gitui/core/services/update_reasons.dart';

/// The updates section as the application would read it back from disk.
UpdatesConfig roundTrip(UpdatesConfig updates) {
  final config = AppConfig.defaults.copyWith(updates: updates);
  final parsed = loadYaml(ConfigService.toYamlString(config.toYaml())) as Map;
  return AppConfig.fromYaml(parsed).updates;
}

void main() {
  test('a config without an updates section gets the defaults', () {
    final config = AppConfig.fromYaml({});

    expect(config.updates.checkFrequency, UpdateCheckFrequency.onStart);
    expect(config.updates.autoDownload, isFalse);
    expect(config.updates.lastCheckTime, isNull);
    expect(config.updates.lastCheckOutcome, isNull);
    expect(config.updates.lastCheckVersion, isNull);
    expect(config.updates.lastCheckFailure, isNull);
  });

  test('every updates field survives the YAML round-trip', () {
    final time = DateTime.utc(2026, 7, 23, 10, 30);
    final read = roundTrip(
      UpdatesConfig(
        checkFrequency: UpdateCheckFrequency.weekly,
        autoDownload: true,
        lastCheckTime: time,
        lastCheckOutcome: UpdateCheckOutcome.failed,
        lastCheckFailure: const UpdateNetworkUnreachable(),
      ),
    );

    expect(read.checkFrequency, UpdateCheckFrequency.weekly);
    expect(read.autoDownload, isTrue);
    expect(read.lastCheckTime, time);
    expect(read.lastCheckOutcome, UpdateCheckOutcome.failed);
    expect(read.lastCheckFailure, const UpdateNetworkUnreachable());
  });

  test('the found version is stored as the version, not as a sentence', () {
    final read = roundTrip(
      const UpdatesConfig(
        lastCheckOutcome: UpdateCheckOutcome.updateAvailable,
        lastCheckVersion: '0.5.15-alpha',
      ),
    );

    expect(read.lastCheckVersion, '0.5.15-alpha');
    expect(read.lastCheckFailure, isNull);
  });

  test('a failure reason keeps its structured data across the file', () {
    final retryAt = DateTime.utc(2026, 7, 23, 11, 15);
    final read = roundTrip(
      UpdatesConfig(
        lastCheckOutcome: UpdateCheckOutcome.failed,
        lastCheckFailure: UpdateRateLimited(retryAt),
      ),
    );

    expect(read.lastCheckFailure, UpdateRateLimited(retryAt));
    expect((read.lastCheckFailure! as UpdateRateLimited).retryAt, retryAt);
  });

  test('every reason survives the file, data and all', () {
    final reasons = <UpdateFailureReason>[
      const UpdateNoReleasePublished(),
      const UpdateReleaseListUnavailable(503),
      UpdateRateLimited(DateTime.utc(2026, 7, 23, 11, 15)),
      const UpdateRateLimited(null),
      const UpdateManifestUnavailable(tag: 'v0.5.15-alpha', statusCode: 404),
      const UpdateReleaseNotInstallable('v0.5.15-alpha'),
      const UpdateNetworkUnreachable(),
      const UpdateCheckTimedOut(10),
      const UpdateResponseUnreadable(),
      const UpdatePlatformUnsupported(),
      const UpdateCheckFailedUnexpectedly(),
    ];

    for (final reason in reasons) {
      final read = roundTrip(
        UpdatesConfig(
          lastCheckOutcome: UpdateCheckOutcome.failed,
          lastCheckFailure: reason,
        ),
      );
      expect(read.lastCheckFailure, reason, reason: 'round-trip of $reason');
    }
  });

  test('nothing user-visible is written to the file as prose', () {
    final yaml = ConfigService.toYamlString(
      AppConfig.defaults
          .copyWith(
            updates: const UpdatesConfig(
              lastCheckOutcome: UpdateCheckOutcome.failed,
              lastCheckFailure: UpdateNetworkUnreachable(),
            ),
          )
          .toYaml(),
    );

    // The code is what is stored; the sentence exists only in the .arb files.
    expect(yaml, contains('network_unreachable'));
    expect(yaml, isNot(contains('GitHub could not be reached')));
    expect(yaml, isNot(contains('last_check_detail')));
  });

  test('an unreadable stored value degrades instead of throwing', () {
    final config = AppConfig.fromYaml({
      'updates': {
        'check_frequency': 'hourly',
        'last_check_time': 'not-a-time',
        'last_check_outcome': 'exploded',
        'last_check_failure': {'code': 'invented_by_a_newer_build'},
      },
    });

    expect(config.updates.checkFrequency, UpdateCheckFrequency.onStart);
    expect(config.updates.lastCheckTime, isNull);
    expect(config.updates.lastCheckOutcome, isNull);
    expect(config.updates.lastCheckFailure, isNull);
  });

  test('a reason whose data is missing degrades to no detail', () {
    final config = AppConfig.fromYaml({
      'updates': {
        'last_check_outcome': 'failed',
        // release_list_unavailable without its status cannot be rendered.
        'last_check_failure': {'code': 'release_list_unavailable'},
      },
    });

    expect(config.updates.lastCheckOutcome, UpdateCheckOutcome.failed);
    expect(config.updates.lastCheckFailure, isNull);
  });

  group('migration from the persisted English sentence', () {
    test('a version left in last_check_detail is carried over', () {
      // A version string is data, identical in every locale, so nothing is
      // gained by dropping it.
      final config = AppConfig.fromYaml({
        'updates': {
          'last_check_outcome': 'updateAvailable',
          'last_check_detail': '0.5.14-alpha',
        },
      });

      expect(config.updates.lastCheckVersion, '0.5.14-alpha');
      expect(config.updates.lastCheckFailure, isNull);
    });

    test('a rendered failure sentence is dropped on read', () {
      // Deliberate: showing it once more would print frozen English on the
      // very line this change exists to translate, and the outcome below
      // still tells the user the check failed.
      final config = AppConfig.fromYaml({
        'updates': {
          'last_check_outcome': 'failed',
          'last_check_detail':
              'GitHub could not be reached. Check your internet connection.',
        },
      });

      expect(config.updates.lastCheckOutcome, UpdateCheckOutcome.failed);
      expect(config.updates.lastCheckFailure, isNull);
      expect(config.updates.lastCheckVersion, isNull);
    });

    test('the stale key is gone the next time the file is written', () {
      final migrated = AppConfig.fromYaml({
        'updates': {
          'last_check_outcome': 'failed',
          'last_check_detail': 'GitHub could not be reached.',
        },
      });

      final yaml = ConfigService.toYamlString(migrated.toYaml());

      expect(yaml, isNot(contains('last_check_detail')));
      expect(yaml, isNot(contains('GitHub could not be reached')));
    });
  });
}
