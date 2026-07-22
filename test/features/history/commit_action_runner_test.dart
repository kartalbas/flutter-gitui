// The sequencing contract every history action shares. A regression here is
// not one broken action but all five: a failure that never reaches the user,
// a view left stale after a failed reset, or a selection surviving into
// rewritten history.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/history/services/commit_action_runner.dart';

void main() {
  group('runCommitAction', () {
    test('success reports no failure and refreshes before clearing', () async {
      final events = <String>[];

      final failure = await runCommitAction(
        invoke: () async => events.add('invoke'),
        refresh: () => events.add('refresh'),
        clearSelection: () => events.add('clear'),
      );

      expect(failure, isNull);
      // Clearing before the refresh would let the details panel briefly show
      // a commit of the outgoing window as freshly selected.
      expect(events, ['invoke', 'refresh', 'clear']);
    });

    test('failure surfaces the error and still refreshes', () async {
      final events = <String>[];

      final failure = await runCommitAction(
        invoke: () async => throw Exception('merge conflict'),
        refresh: () => events.add('refresh'),
        clearSelection: () => events.add('clear'),
      );

      expect(failure, contains('merge conflict'));
      // The failed call may still have changed the repository, so skipping
      // the reload would leave the view stale on top of the error. The
      // selection stays: it shows what the failed action was aimed at.
      expect(events, ['refresh']);
    });

    test('a synchronous throw behaves like an async failure', () async {
      final events = <String>[];

      final failure = await runCommitAction(
        invoke: () => throw StateError('no repository'),
        refresh: () => events.add('refresh'),
        clearSelection: () => events.add('clear'),
      );

      expect(failure, contains('no repository'));
      expect(events, ['refresh']);
    });
  });
}
