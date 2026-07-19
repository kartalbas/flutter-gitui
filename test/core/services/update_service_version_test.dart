// Semantic versioning precedence used by the update check.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/update_service.dart';

/// Asserts that [versions] is ordered strictly from lowest to highest.
///
/// Every pair is checked in both directions, so an ordering that merely
/// happens to be transitive by accident still fails.
void expectAscending(List<String> versions) {
  for (var i = 0; i < versions.length; i++) {
    for (var j = i + 1; j < versions.length; j++) {
      expect(
        UpdateService.isNewerVersion(versions[j], versions[i]),
        isTrue,
        reason: '${versions[j]} must rank above ${versions[i]}',
      );
      expect(
        UpdateService.isNewerVersion(versions[i], versions[j]),
        isFalse,
        reason: '${versions[i]} must not rank above ${versions[j]}',
      );
    }
  }
}

void main() {
  group('UpdateService.isNewerVersion', () {
    test('offers the final release to a pre-release of that same release', () {
      expect(UpdateService.isNewerVersion('0.5.0', '0.5.0-alpha'), isTrue);
      expect(UpdateService.isNewerVersion('0.5.0-alpha', '0.5.0'), isFalse);
    });

    test('orders pre-release suffixes below the release they lead to', () {
      expectAscending(['0.5.0-alpha', '0.5.0-alpha.2', '0.5.0-beta', '0.5.0']);
    });

    test('compares numeric pre-release identifiers numerically', () {
      expectAscending(['1.0.0-alpha.2', '1.0.0-alpha.10']);
    });

    test('compares alphanumeric pre-release identifiers lexically', () {
      expectAscending(['1.0.0-alpha', '1.0.0-beta', '1.0.0-rc']);
    });

    test('ranks a numeric identifier below an alphanumeric one', () {
      expectAscending(['1.0.0-1', '1.0.0-alpha']);
    });

    test('ranks a longer identifier list above its own prefix', () {
      expectAscending(['1.0.0-alpha', '1.0.0-alpha.1']);
    });

    test('orders major, minor and patch ahead of any suffix', () {
      expectAscending(['0.4.9', '0.5.0-alpha', '0.5.0', '0.5.1', '1.0.0']);
    });

    test('ignores build metadata for precedence', () {
      expect(UpdateService.isNewerVersion('0.5.0+1', '0.5.0-alpha+99'), isTrue);
      expect(
        UpdateService.isNewerVersion('0.5.0-alpha+99', '0.5.0+1'),
        isFalse,
      );
      expect(
        UpdateService.isNewerVersion('0.5.0-alpha.2+1', '0.5.0-alpha+99'),
        isTrue,
      );
    });

    test('reports an identical version as not newer', () {
      expect(UpdateService.isNewerVersion('0.5.0', '0.5.0'), isFalse);
      expect(
        UpdateService.isNewerVersion('0.5.0-alpha', '0.5.0-alpha'),
        isFalse,
      );
    });

    test('still sees a higher build number of the same version', () {
      // Releases cut between two tags share major.minor.patch and differ only
      // in the build number, so that tie-break has to survive this change.
      expect(UpdateService.isNewerVersion('0.5.0+2', '0.5.0+1'), isTrue);
      expect(UpdateService.isNewerVersion('0.5.0+1', '0.5.0+2'), isFalse);
    });
  });
}
