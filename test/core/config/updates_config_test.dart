// The Updates section of the configuration: defaults for a file that predates
// it, a round-trip of every field through the YAML the app writes, and
// degradation of unreadable stored values.

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/core/config/config_service.dart';
import 'package:flutter_gitui/core/services/update_check_policy.dart';

void main() {
  test('a config without an updates section gets the defaults', () {
    final config = AppConfig.fromYaml({});

    expect(config.updates.checkFrequency, UpdateCheckFrequency.onStart);
    expect(config.updates.autoDownload, isFalse);
    expect(config.updates.lastCheckTime, isNull);
    expect(config.updates.lastCheckOutcome, isNull);
    expect(config.updates.lastCheckDetail, isNull);
  });

  test('every updates field survives the YAML round-trip', () {
    final time = DateTime.utc(2026, 7, 23, 10, 30);
    final config = AppConfig.defaults.copyWith(
      updates: UpdatesConfig(
        checkFrequency: UpdateCheckFrequency.weekly,
        autoDownload: true,
        lastCheckTime: time,
        lastCheckOutcome: UpdateCheckOutcome.failed,
        lastCheckDetail: 'GitHub could not be reached.',
      ),
    );

    final parsed = loadYaml(ConfigService.toYamlString(config.toYaml())) as Map;
    final read = AppConfig.fromYaml(parsed);

    expect(read.updates.checkFrequency, UpdateCheckFrequency.weekly);
    expect(read.updates.autoDownload, isTrue);
    expect(read.updates.lastCheckTime, time);
    expect(read.updates.lastCheckOutcome, UpdateCheckOutcome.failed);
    expect(read.updates.lastCheckDetail, 'GitHub could not be reached.');
  });

  test('an unreadable stored value degrades instead of throwing', () {
    final config = AppConfig.fromYaml({
      'updates': {
        'check_frequency': 'hourly',
        'last_check_time': 'not-a-time',
        'last_check_outcome': 'exploded',
      },
    });

    expect(config.updates.checkFrequency, UpdateCheckFrequency.onStart);
    expect(config.updates.lastCheckTime, isNull);
    expect(config.updates.lastCheckOutcome, isNull);
  });
}
