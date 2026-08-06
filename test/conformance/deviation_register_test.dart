/// Static validation of docs/deviation_register.yaml.
///
/// Parseability of the file itself (schema version, required fields, ISO
/// dates, unique tokens) is enforced by the strict loader — any violation
/// surfaces here as a setUpAll failure. The tests below add the contract
/// rules the loader cannot know about.
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/deviation_register.dart';
import 'support/token_manifest.dart';

void main() {
  group('deviation register statics', () {
    late DeviationRegister register;

    setUpAll(() {
      register = DeviationRegister.load();
    });

    test('uses the supported schema version', () {
      expect(register.version, DeviationRegister.supportedVersion);
    });

    test('ids are unique', () {
      final Set<String> seen = <String>{};
      for (final DeviationEntry entry in register.entries) {
        expect(
          seen.add(entry.id),
          isTrue,
          reason: 'duplicate deviation id ${entry.id}',
        );
      }
    });

    test('every registered token exists in the token manifest', () {
      for (final DeviationEntry entry in register.entries) {
        expect(
          conformanceTokenManifest.contains(entry.token),
          isTrue,
          reason:
              'deviation ${entry.id} maps to token ${entry.token}, which '
              'is not in conformanceTokenManifest — a dead entry. Either the '
              'component/property was renamed or the measurement was '
              'removed; fix or delete the entry.',
        );
      }
    });

    test('every entry documents a real divergence', () {
      for (final DeviationEntry entry in register.entries) {
        expect(
          entry.specValue == entry.appValue,
          isFalse,
          reason:
              'deviation ${entry.id} documents spec_value == app_value '
              '(${entry.specValue}); an entry that does not diverge is '
              'stale by construction and must be deleted.',
        );
      }
    });
  });
}
