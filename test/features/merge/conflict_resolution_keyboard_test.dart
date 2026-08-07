// The merge conflict resolution screen as the keyboard drives it (#290).
//
// This screen is a per-file decision loop, so its keyboard contract has to
// carry the whole loop without a pointer ever being involved: the conflicted
// file list holds initial focus and is one Tab stop whose arrows move the
// highlight while the details pane follows; Enter on a file hands the keyboard
// to the resolution pane; arrows there walk the choices that file offers and
// Enter applies the highlighted one, which git records and both panes then
// show. F6 and Shift+F6 cycle between the two panes in either direction, and
// Escape climbs back out one level at a time — from the resolution pane to the
// file list, from the file list off the screen — while never being able to
// discard a resolution, because a resolution is written to git before the pane
// ever calls it resolved.
//
// The screen offers no editable merge result (manual resolution is delegated
// to an external editor), so it has no field for the `focusedEditableOwnsKey`
// guard to protect; every key below is therefore free by construction.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/config/config_providers.dart';
import 'package:flutter_gitui/core/git/git_providers.dart';
import 'package:flutter_gitui/core/git/models/merge_conflict.dart';
import 'package:flutter_gitui/features/merge/conflict_resolution_screen.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

/// The screen the user came from, so "Escape leaves the screen" is something
/// the test can see rather than infer.
const String _homeMarker = 'repository home';

/// The merge git would report, held in memory so a resolution changes what the
/// next read of [mergeStateProvider] answers — the same round trip the real
/// screen depends on to redraw both panes after a choice.
class _MergeFixture {
  _MergeFixture(this._conflicts);

  List<MergeConflict> _conflicts;

  MergeState get state => MergeState(
    isInProgress: true,
    mergingBranch: 'feature/x',
    currentBranch: 'master',
    conflicts: _conflicts,
  );

  void markResolved(String filePath, ResolutionChoice choice) {
    _conflicts = [
      for (final conflict in _conflicts)
        if (conflict.filePath == filePath)
          conflict.copyWith(isResolved: true, resolutionChoice: choice)
        else
          conflict,
    ];
  }
}

/// Records resolutions instead of running git, so an assertion reads exactly
/// which file the keyboard resolved and with which choice. The optional gate
/// holds the call open, which is how the test observes the window in which a
/// resolution is still in flight.
class _RecordingGitActions extends GitActions {
  _RecordingGitActions(super.ref, this._fixture, this.log, this._gate);

  final _MergeFixture _fixture;
  final List<String> log;
  final Completer<void>? _gate;

  @override
  Future<void> resolveConflict(
    String filePath, {
    required ResolutionChoice choice,
    String? manualContent,
  }) async {
    log.add('$filePath:${choice.name}');
    final gate = _gate;
    if (gate != null) await gate.future;
    _fixture.markResolved(filePath, choice);
    ref.invalidate(mergeStateProvider);
  }
}

MergeConflict _conflict(String path, ConflictType type) =>
    MergeConflict(filePath: path, type: type);

_MergeFixture _twoConflicts() => _MergeFixture([
  _conflict('lib/alpha.dart', ConflictType.bothModified),
  _conflict('docs/beta.md', ConflictType.deletedByThem),
]);

Future<void> _pumpConflictScreen(
  WidgetTester tester, {
  required _MergeFixture fixture,
  required List<String> log,
  Completer<void>? gate,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentRepositoryPathProvider.overrideWith((ref) => '/repo'),
        mergeStateProvider.overrideWith((ref) async => fixture.state),
        gitActionsProvider.overrideWith(
          (ref) => _RecordingGitActions(ref, fixture, log, gate),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: Text(_homeMarker))),
        routes: {'/conflicts': (context) => const ConflictResolutionScreen()},
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The app reaches this screen through its named route, so the walkthrough
  // starts where the user's does: stacked on the screen they came from.
  // Pushing the route is setup; from here on nothing but keys touches the UI.
  unawaited(navigatorKey.currentState!.pushNamed<void>('/conflicts'));
  await tester.pumpAndSettle();
}

/// Presses [key] with Shift held, the chord form the tester needs spelled out.
Future<void> _sendShifted(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

void main() {
  testWidgets('arrows walk the conflicted files and the details pane follows', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpConflictScreen(tester, fixture: _twoConflicts(), log: log);

    // The file list holds initial focus with the first conflict highlighted,
    // so the details pane already describes that file. The pane names the full
    // path while the list row names the file, which is what keeps these
    // assertions to the pane.
    expect(find.text('lib/alpha.dart'), findsOneWidget);
    expect(find.text('docs/beta.md'), findsNothing);
    // A both-modified file can keep both sides, so that choice is offered.
    expect(find.text('Accept Both'), findsOneWidget);

    // ArrowDown moves the highlight to the second conflict and the pane
    // follows it: a different file, and a shorter set of choices, because
    // nothing was added on our side that keeping both could preserve.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('docs/beta.md'), findsOneWidget);
    expect(find.text('lib/alpha.dart'), findsNothing);
    expect(find.text('Accept Ours'), findsOneWidget);
    expect(find.text('Accept Both'), findsNothing);

    // ArrowUp walks back, and walking the list resolves nothing on its own.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('lib/alpha.dart'), findsOneWidget);
    expect(log, isEmpty);
  });

  testWidgets('Enter hands the keyboard to the resolution pane and Enter '
      'there resolves the highlighted file', (tester) async {
    final log = <String>[];
    final fixture = _twoConflicts();
    await _pumpConflictScreen(tester, fixture: fixture, log: log);
    expect(find.text('2 conflicts to resolve'), findsOneWidget);

    // Enter on the highlighted conflict moves the keyboard into the
    // resolution pane, where the highlight starts on the first choice.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Proof that the keyboard really moved panes: ArrowDown now steps through
    // the choices instead of the files, so the pane still shows the same file.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('lib/alpha.dart'), findsOneWidget);
    expect(find.text('docs/beta.md'), findsNothing);

    // Enter applies the highlighted choice — the second one, "take theirs" —
    // to the file the list is pointing at.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['lib/alpha.dart:theirs']);

    // And the choice is visible afterwards, in both panes: the details header
    // calls the file resolved, and the list header counts one conflict fewer.
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('1 conflicts to resolve'), findsOneWidget);
  });

  testWidgets('F6 and Shift+F6 move between the file list and the pane', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpConflictScreen(tester, fixture: _twoConflicts(), log: log);

    // F6 is the desktop pane key, and it reaches the resolution pane from the
    // file list: the next ArrowDown moves a choice, not a file, so the pane
    // still describes the same conflict afterwards.
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('lib/alpha.dart'), findsOneWidget);
    expect(log, isEmpty);

    // What that ArrowDown moved was the choice, which Enter now proves by
    // applying the second one rather than the first.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['lib/alpha.dart:theirs']);

    // Shift+F6 cycles back to the file list, where ArrowDown moves a file
    // again and the pane follows it.
    await _sendShifted(tester, LogicalKeyboardKey.f6);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('docs/beta.md'), findsOneWidget);
    expect(find.text('lib/alpha.dart'), findsNothing);
  });

  testWidgets('Escape leaves the resolution pane first and the screen second', (
    tester,
  ) async {
    final log = <String>[];
    await _pumpConflictScreen(tester, fixture: _twoConflicts(), log: log);

    // Into the resolution pane, then straight back out again without choosing.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text(_homeMarker), findsNothing);

    // The keyboard is back on the file list: ArrowDown moves a file again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('docs/beta.md'), findsOneWidget);

    // With nothing left to leave inside the screen, Escape leaves the screen.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ConflictResolutionScreen), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  testWidgets('Escape after a resolution leaves the screen without '
      'discarding it', (tester) async {
    final log = <String>[];
    final fixture = _twoConflicts();
    await _pumpConflictScreen(tester, fixture: fixture, log: log);

    // Resolve the highlighted file with the first choice, "take ours".
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['lib/alpha.dart:ours']);
    expect(find.text('Resolved'), findsOneWidget);

    // Escape twice — out of the pane, then off the screen. Neither step may
    // roll the resolution back: it went to git before the pane showed it.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(_homeMarker), findsOneWidget);
    expect(log, ['lib/alpha.dart:ours']);

    // Coming back to the screen shows the resolution still standing.
    expect(fixture.state.unresolvedCount, 1);
  });

  testWidgets('Escape while a resolution is in flight neither leaves nor '
      'cancels it', (tester) async {
    final log = <String>[];
    final gate = Completer<void>();
    final fixture = _twoConflicts();
    await _pumpConflictScreen(tester, fixture: fixture, log: log, gate: gate);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Resolving conflict...'), findsOneWidget);

    // The git command is already on its way, so Escape has nothing safe to do
    // and does nothing at all: the screen stays where it is.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text(_homeMarker), findsNothing);
    expect(find.byType(ConflictResolutionScreen), findsOneWidget);

    // And the resolution the Escape did not cancel still lands.
    gate.complete();
    await tester.pumpAndSettle();
    expect(log, ['lib/alpha.dart:ours']);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('1 conflicts to resolve'), findsOneWidget);
  });
}
