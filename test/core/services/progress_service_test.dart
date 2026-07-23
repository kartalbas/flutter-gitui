// Every git command feeds the global progress notifier, so a local read
// finishing in tens of milliseconds used to flash a modal dialog for the few
// frames it ran (#288). These tests pin the show-delay contract at the state
// level, where visibility is decided: nothing may surface before the
// threshold, and overlapping commands must collapse into one calm indicator.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/services/progress_service.dart';

/// Short enough to keep the suite fast; the margins below make the timing
/// deterministic regardless of machine load, because completions happen
/// synchronously before any wait and Dart fires due timers in due-time order.
const showDelay = Duration(milliseconds: 100);

/// Waits long enough that the show timer, if still armed, must have fired.
Future<void> waitPastThreshold() => Future<void>.delayed(showDelay * 4);

void main() {
  group('ProgressNotifier show delay', () {
    late ProgressNotifier notifier;
    late List<ProgressInfo?> emitted;

    setUp(() {
      notifier = ProgressNotifier(showDelay: showDelay);
      emitted = [];
      // Recording every state change makes flicker visible to the test: any
      // emission beyond one show and one hide is an extra visual transition.
      notifier.addListener(
        (state) => emitted.add(state),
        fireImmediately: false,
      );
    });

    tearDown(() => notifier.dispose());

    test('an operation finishing before the threshold never shows', () async {
      notifier.startOperation(
        'git status',
        0,
        isIndeterminate: true,
        isAutomatic: true,
      );
      notifier.completeOperation(isAutomatic: true);

      // Waiting past the threshold proves the delayed show was cancelled,
      // not merely not yet due.
      await waitPastThreshold();

      expect(notifier.state, isNull);
      expect(emitted, isEmpty);
    });

    test('an operation exceeding the threshold shows', () async {
      notifier.startOperation(
        'git fetch',
        0,
        isIndeterminate: true,
        isAutomatic: true,
      );

      // The defect was the indicator mounting instantly.
      expect(notifier.state, isNull);

      await waitPastThreshold();

      final info = notifier.state;
      expect(info, isNotNull);
      expect(info!.isBlocking, isFalse);
      expect(info.isIndeterminate, isTrue);

      notifier.completeOperation(isAutomatic: true);
      expect(notifier.state, isNull);
    });

    test(
      'overlapping automatic operations collapse into one indicator',
      () async {
        notifier.startOperation(
          'git status',
          0,
          isIndeterminate: true,
          isAutomatic: true,
        );
        notifier.startOperation(
          'git log',
          0,
          isIndeterminate: true,
          isAutomatic: true,
        );
        notifier.completeOperation(isAutomatic: true);

        await waitPastThreshold();

        // One command is still in flight, so completing the other must neither
        // hide the indicator nor restart the delay.
        expect(notifier.state, isNotNull);

        notifier.completeOperation(isAutomatic: true);
        expect(notifier.state, isNull);

        // Exactly one show and one hide across the whole busy period.
        expect(emitted, hasLength(2));
        expect(emitted.first, isNotNull);
        expect(emitted.last, isNull);
      },
    );

    test('overlapping fast operations show nothing at all', () async {
      notifier.startOperation(
        'git status',
        0,
        isIndeterminate: true,
        isAutomatic: true,
      );
      notifier.startOperation(
        'git log',
        0,
        isIndeterminate: true,
        isAutomatic: true,
      );
      notifier.completeOperation(isAutomatic: true);
      notifier.completeOperation(isAutomatic: true);

      await waitPastThreshold();

      expect(emitted, isEmpty);
    });

    test('a fast explicit operation does not flash either', () async {
      notifier.startOperation('Deleting tag', 2);
      notifier.updateProgress(1, statusMessage: 'local');
      notifier.completeOperation();

      await waitPastThreshold();

      expect(emitted, isEmpty);
    });

    test(
      'a slow explicit operation shows modally with progress intact',
      () async {
        notifier.startOperation('Deleting tag', 2);
        // Steps taken while the delay holds the indicator back must not be
        // lost, or it would mount showing stale numbers.
        notifier.updateProgress(1, statusMessage: 'local');

        await waitPastThreshold();

        final info = notifier.state;
        expect(info, isNotNull);
        expect(info!.isBlocking, isTrue);
        expect(info.currentStep, 1);
        expect(info.statusMessage, 'local');

        notifier.completeOperation();
        expect(notifier.state, isNull);
      },
    );

    test('automatic progress never overrides an explicit operation', () async {
      notifier.startOperation('Deleting tag', 2);
      notifier.startOperation(
        'git status',
        0,
        isIndeterminate: true,
        isAutomatic: true,
      );

      await waitPastThreshold();

      final info = notifier.state;
      expect(info, isNotNull);
      expect(info!.operationName, 'Deleting tag');
      expect(info.isBlocking, isTrue);

      // The command finishing must not clear the explicit operation.
      notifier.completeOperation(isAutomatic: true);
      expect(notifier.state, isNotNull);

      notifier.completeOperation();
      expect(notifier.state, isNull);
    });
  });
}
