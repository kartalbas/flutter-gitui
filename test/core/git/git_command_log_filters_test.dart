import 'package:flutter_gitui/core/git/git_command_log_filters.dart';
import 'package:flutter_gitui/core/git/models/git_command_log.dart';
import 'package:flutter_test/flutter_test.dart';

GitCommandLog entry(String command, {int? exitCode = 0}) => GitCommandLog(
  command: command,
  timestamp: DateTime(2026, 7, 23, 12),
  exitCode: exitCode,
);

void main() {
  group('filterCommandLogs', () {
    test('failures-only keeps exactly the failed entries', () {
      final logs = [
        entry('git status'),
        entry('git push origin master', exitCode: 128),
        entry('git branch -vv'),
        entry('git fetch --all', exitCode: 1),
      ];

      final result = filterCommandLogs(logs, failuresOnly: true);

      expect(result.map((log) => log.command), [
        'git push origin master',
        'git fetch --all',
      ]);
    });

    test('a null exit code is not treated as a failure', () {
      final logs = [
        entry('git status', exitCode: null),
        entry('git push', exitCode: 1),
      ];

      final result = filterCommandLogs(logs, failuresOnly: true);

      expect(result.map((log) => log.command), ['git push']);
    });

    test('search matches the command substring case-insensitively', () {
      final logs = [
        entry('git BRANCH -vv'),
        entry('git status'),
        entry('git branch --merged'),
      ];

      final result = filterCommandLogs(logs, query: 'Branch');

      expect(result.map((log) => log.command), [
        'git BRANCH -vv',
        'git branch --merged',
      ]);
    });

    test('a blank or whitespace-only query keeps every entry', () {
      final logs = [entry('git status'), entry('git log')];

      expect(filterCommandLogs(logs), logs);
      expect(filterCommandLogs(logs, query: '   '), logs);
    });

    test('search and failures-only combine', () {
      final logs = [
        entry('git push origin master', exitCode: 1),
        entry('git push origin master'),
        entry('git pull', exitCode: 1),
      ];

      final result = filterCommandLogs(logs, failuresOnly: true, query: 'push');

      expect(result, hasLength(1));
      expect(result.single.command, 'git push origin master');
      expect(result.single.isFailure, isTrue);
    });
  });

  group('groupConsecutiveCommandLogs', () {
    test('counts consecutive identical commands as one group', () {
      final logs = [
        entry('git status'),
        entry('git status'),
        entry('git status'),
        entry('git log --oneline'),
      ];

      final groups = groupConsecutiveCommandLogs(logs);

      expect(groups, hasLength(2));
      expect(groups.first.count, 3);
      expect(groups.first.representative.command, 'git status');
      expect(groups.last.count, 1);
      expect(groups.last.representative.command, 'git log --oneline');
    });

    test('never merges across differing exit codes', () {
      final logs = [
        entry('git push'),
        entry('git push', exitCode: 1),
        entry('git push', exitCode: 1),
        entry('git push'),
      ];

      final groups = groupConsecutiveCommandLogs(logs);

      expect(groups.map((group) => group.count), [1, 2, 1]);
      expect(groups.map((group) => group.representative.exitCode), [0, 1, 0]);
    });

    test('non-adjacent duplicates stay separate', () {
      final logs = [entry('git status'), entry('git log'), entry('git status')];

      final groups = groupConsecutiveCommandLogs(logs);

      expect(groups, hasLength(3));
      expect(groups.every((group) => group.count == 1), isTrue);
    });

    test('keeps every entry and the original order', () {
      final logs = [
        entry('git status'),
        entry('git status'),
        entry('git fetch', exitCode: 1),
      ];

      final groups = groupConsecutiveCommandLogs(logs);
      final flattened = groups.expand((group) => group.entries).toList();

      expect(flattened, logs);
    });

    test('empty input yields no groups', () {
      expect(groupConsecutiveCommandLogs([]), isEmpty);
    });
  });
}
