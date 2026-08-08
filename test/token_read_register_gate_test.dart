/// Pins the two-way token-read register that arms `token_read_is_mechanical`
/// (#249; the register lives in
/// `lint_rules/flutter_gitui_lint/lib/token_read_register.dart`).
///
/// The armed rule reports two ways: an `AppTheme.*` read the classifier finds
/// that has no register entry, and a register entry whose site the classifier
/// no longer finds (stale). A register that checks only the first direction
/// looks identical to one that checks both — right up until it rots into an
/// excuse list — so this suite exercises the shared reconciliation function
/// on synthetic registers and fails if either direction has been removed.
/// The custom_lint run then proves the same function is actually wired into
/// the reporting path; this suite proves the function itself cannot lose a
/// direction silently.
///
/// It also covers the one case the lint is structurally blind to: a
/// registered file that has been deleted or renamed. The rule reconciles a
/// file when the analyzer visits it, and the analyzer never visits a file
/// that no longer exists, so that entry would sit unreported forever. This
/// suite reads the register from `flutter test` and demands every registered
/// file exist and still carry its site line.
///
/// Finally it pins the register's total read count, shrink-only. Growth is
/// already impossible without editing the register (an unregistered read is
/// a custom_lint error), so the pin's job is to make *register* growth as
/// loud as code growth: converting a read lowers the number here in the same
/// change; raising it is the forbidden direction, because new code states
/// its lengths through the contract instead of registering exceptions.
library;

import 'dart:io';

import 'package:flutter_gitui_lint/token_read_register.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reconciliation reports both directions', () {
    const entry = TokenReadRegisterEntry(
      file: 'lib/example.dart',
      site: 'width: AppTheme.iconXL + AppTheme.paddingM,',
      reads: 2,
      waitsFor: 'surfaces.example',
      reason: 'Synthetic entry for the direction tests.',
    );

    test('a read with no register entry is reported as unregistered', () {
      final result = reconcileTokenReads(
        file: 'lib/example.dart',
        readLineTexts: const ['height: AppTheme.paddingM + 1,'],
        register: const [],
      );

      expect(
        result.unregistered,
        [0],
        reason:
            'An unregistered read must be reported. If this fails, the '
            'register has lost its first direction and the armed rule is '
            'silently allowing new token reads.',
      );
      expect(result.stale, isEmpty);
    });

    test('a registered read is consumed, not reported', () {
      final result = reconcileTokenReads(
        file: 'lib/example.dart',
        readLineTexts: const [
          'width: AppTheme.iconXL + AppTheme.paddingM,',
          'width: AppTheme.iconXL + AppTheme.paddingM,',
        ],
        register: const [entry],
      );

      expect(result.unregistered, isEmpty);
      expect(result.stale, isEmpty);
    });

    test('an entry whose site is clean is reported as stale', () {
      final result = reconcileTokenReads(
        file: 'lib/example.dart',
        readLineTexts: const [],
        register: const [entry],
      );

      expect(
        result.stale,
        hasLength(1),
        reason:
            'A stale entry must be reported. If this fails, the register '
            'has lost its second direction and can rot into an excuse list '
            'that no longer counts anything.',
      );
      expect(result.stale.single.entry.site, entry.site);
      expect(result.stale.single.found, 0);
      expect(result.unregistered, isEmpty);
    });

    test('an entry only partly consumed is stale with the found count', () {
      final result = reconcileTokenReads(
        file: 'lib/example.dart',
        readLineTexts: const ['width: AppTheme.iconXL + AppTheme.paddingM,'],
        register: const [entry],
      );

      expect(result.stale, hasLength(1));
      expect(result.stale.single.found, 1);
      expect(result.unregistered, isEmpty);
    });

    test('reads beyond the registered budget are reported', () {
      final result = reconcileTokenReads(
        file: 'lib/example.dart',
        readLineTexts: const [
          'width: AppTheme.iconXL + AppTheme.paddingM,',
          'width: AppTheme.iconXL + AppTheme.paddingM,',
          'width: AppTheme.iconXL + AppTheme.paddingM,',
        ],
        register: const [entry],
      );

      expect(
        result.unregistered,
        [2],
        reason:
            'A budget of 2 must not cover a third read: the register '
            'suppresses a counted remainder, not a site forever.',
      );
      expect(result.stale, isEmpty);
    });

    test('the default register parameter is the real register', () {
      // Every direction test above passes `register:` explicitly, and the
      // worktree tests read the tokenReadRegister constant directly, so none
      // of them would notice the default parameter being gutted (say, to
      // `const []`) — only the custom_lint run would. This test closes that
      // redundancy gap by reconciling a real registered file WITHOUT passing
      // `register:`, in both directions.
      final file = tokenReadRegister.first.file;
      final entries = [
        for (final entry in tokenReadRegister)
          if (entry.file == file) entry,
      ];

      final consumed = reconcileTokenReads(
        file: file,
        readLineTexts: [
          for (final entry in entries)
            for (var i = 0; i < entry.reads; i++) entry.site,
        ],
      );
      expect(
        consumed.unregistered,
        isEmpty,
        reason:
            'reconcileTokenReads must default to the real tokenReadRegister. '
            'If this fails, the default has been swapped or emptied and every '
            'explicit-register test above stays green while the armed rule '
            'judges against a different register than this suite pins.',
      );
      expect(consumed.stale, isEmpty);

      final unconsumed = reconcileTokenReads(file: file, readLineTexts: []);
      expect(
        unconsumed.stale,
        hasLength(entries.length),
        reason:
            'The stale direction must flow through the default register too.',
      );
    });

    test('an entry never leaks across files', () {
      final result = reconcileTokenReads(
        file: 'lib/other.dart',
        readLineTexts: const ['width: AppTheme.iconXL + AppTheme.paddingM,'],
        register: const [entry],
      );

      expect(
        result.unregistered,
        [0],
        reason:
            'The same line text in a different file is a different '
            'decision; an entry must only spend its budget in its own file.',
      );
      expect(
        result.stale,
        isEmpty,
        reason:
            'The entry belongs to lib/example.dart, which was not '
            'reconciled here, so it is not stale either.',
      );
    });
  });

  group('the register is well-formed', () {
    test('every entry names exactly one cause: a member or a missing word', () {
      for (final entry in tokenReadRegister) {
        final hasMember = entry.waitsFor != null;
        final hasGap = entry.vocabularyGap != null;
        expect(
          hasMember ^ hasGap,
          isTrue,
          reason:
              '${entry.file} site "${entry.site}": an entry waits for a P5 '
              'member XOR names a vocabulary gap. Both or neither files the '
              'remainder under the wrong cause.',
        );
      }
    });

    test('every entry carries a reason, a positive count and a lib/ path', () {
      for (final entry in tokenReadRegister) {
        expect(
          entry.reason.trim(),
          isNotEmpty,
          reason:
              '${entry.file} site "${entry.site}" has no reason; the '
              'register is the single place the remainder is argued.',
        );
        expect(
          entry.reads,
          greaterThanOrEqualTo(1),
          reason: '${entry.file} site "${entry.site}"',
        );
        expect(
          entry.file,
          startsWith('lib/'),
          reason: 'Register keys are repo-relative with forward slashes.',
        );
        expect(
          entry.file.contains(r'\'),
          isFalse,
          reason: 'Register keys use forward slashes.',
        );
        expect(
          entry.site,
          contains('AppTheme.'),
          reason:
              'A site line without an AppTheme read cannot be a '
              'token-read site.',
        );
        expect(
          entry.site,
          equals(entry.site.trim()),
          reason:
              'Sites are trimmed line texts; padding would never '
              'match the classifier\'s trimmed lines.',
        );
      }
    });

    test('no two entries share a (file, site) key', () {
      final seen = <String>{};
      for (final entry in tokenReadRegister) {
        final key = '${entry.file}::${entry.site}';
        expect(
          seen.add(key),
          isTrue,
          reason:
              'Duplicate entry for $key: the reconciliation keeps one budget '
              'per (file, site), so a duplicate would silently vanish.',
        );
      }
    });
  });

  group('the register matches the worktree', () {
    test('every registered file exists and still carries its site line', () {
      // The lint reconciles a file when the analyzer visits it; a deleted or
      // renamed file is never visited, so its entries would never go stale
      // there. This test is the direction only `flutter test` can check.
      final contentsByFile = <String, List<String>>{};

      for (final entry in tokenReadRegister) {
        final lines = contentsByFile.putIfAbsent(entry.file, () {
          final file = File(entry.file);
          expect(
            file.existsSync(),
            isTrue,
            reason:
                '${entry.file} is registered but does not exist. Delete or '
                're-key its entries.',
          );
          return [for (final line in file.readAsLinesSync()) line.trim()];
        });

        expect(
          lines.contains(entry.site),
          isTrue,
          reason:
              '${entry.file} no longer contains the line "${entry.site}". '
              'The entry is stale; the custom_lint run reports the same '
              'thing at the file.',
        );
      }
    });

    test('the total registered read count only shrinks', () {
      final total = tokenReadRegister.fold<int>(
        0,
        (sum, entry) => sum + entry.reads,
      );

      // 77 is the 2026-08-09 census: 66 reads waiting for a named P5 member,
      // 11 blocked on a missing vocabulary word. Converting a read lowers
      // this number in the same change that deletes its entry. Raising it is
      // the forbidden direction: new code states its lengths through the
      // contract, it does not register exceptions.
      expect(
        total,
        77,
        reason:
            'The register must shrink deliberately: update this pin in the '
            'same change that shrinks (never grows) the register.',
      );
    });
  });
}
