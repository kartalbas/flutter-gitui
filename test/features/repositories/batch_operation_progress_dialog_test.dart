// The batch progress dialog used to discard the per-repository callbacks the
// service fed it: the bar stayed indeterminate, the counter read 0/N and
// everything snapped to done only when the whole run returned (#286). These
// tests pin the consuming side of that contract: the service reports each
// repository before working on it, so a callback for repository `current`
// must mark every earlier one completed, keep the fraction determinate and
// monotonic, and surface which repository is active right now.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/workspace/models/workspace_repository.dart';
import 'package:flutter_gitui/features/repositories/dialogs/batch_operation_progress_dialog.dart';
import 'package:flutter_gitui/features/repositories/services/batch_operations_service.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

typedef ProgressCallback =
    void Function(WorkspaceRepository repository, int, int, String);

WorkspaceRepository _repo(int n) => WorkspaceRepository(
  path: '/repos/repo$n',
  name: 'repo$n',
  lastAccessed: DateTime(2026),
);

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<WorkspaceRepository> repositories,
  required Future<List<BatchOperationResult>> Function(ProgressCallback?)
  operation,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BatchOperationProgressDialog(
        title: 'Pull Repositories',
        repositories: repositories,
        operation: operation,
      ),
    ),
  );
}

double? _barValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value;

void main() {
  testWidgets('progress callbacks advance the count and the fraction '
      'monotonically', (tester) async {
    final repos = [for (var i = 1; i <= 3; i++) _repo(i)];
    late ProgressCallback progress;
    final completer = Completer<List<BatchOperationResult>>();

    await _pumpDialog(
      tester,
      repositories: repos,
      operation: (onProgress) {
        progress = onProgress!;
        return completer.future;
      },
    );

    // Determinate from the first frame: an empty bar is information, the
    // indeterminate animation is not.
    expect(_barValue(tester), 0.0);
    expect(find.text('0 / 3'), findsOneWidget);

    // The service reports before each repository, so the first callback
    // means work has started but nothing is finished yet.
    progress(repos[0], 1, 3, 'Pulling changes...');
    await tester.pump();
    expect(_barValue(tester), 0.0);
    expect(find.text('0 / 3'), findsOneWidget);

    progress(repos[1], 2, 3, 'Pulling changes...');
    await tester.pump();
    expect(_barValue(tester), closeTo(1 / 3, 1e-9));
    expect(find.text('1 / 3'), findsOneWidget);

    progress(repos[2], 3, 3, 'Pulling changes...');
    await tester.pump();
    expect(_barValue(tester), closeTo(2 / 3, 1e-9));
    expect(find.text('2 / 3'), findsOneWidget);

    completer.complete([
      for (final repo in repos)
        BatchOperationResult(repository: repo, success: true, message: 'Done'),
    ]);
    await tester.pump();

    expect(_barValue(tester), 1.0);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('the active repository is surfaced while the others wait', (
    tester,
  ) async {
    final repos = [for (var i = 1; i <= 3; i++) _repo(i)];
    late ProgressCallback progress;
    final completer = Completer<List<BatchOperationResult>>();

    await _pumpDialog(
      tester,
      repositories: repos,
      operation: (onProgress) {
        progress = onProgress!;
        return completer.future;
      },
    );

    // Nothing reported yet: no row may claim to be running.
    expect(find.text('Waiting...'), findsNWidgets(3));

    progress(repos[0], 1, 3, 'Pulling changes...');
    await tester.pump();

    // The active repository shows in its row and pinned under the bar, so it
    // stays visible when the list scrolls it out of view.
    expect(find.text('repo1'), findsNWidgets(2));
    expect(find.text('Pulling changes...'), findsOneWidget);
    expect(find.text('Waiting...'), findsNWidgets(2));

    progress(repos[1], 2, 3, 'Pulling changes...');
    await tester.pump();

    expect(find.text('repo2'), findsNWidgets(2));
    expect(find.text('repo1'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Waiting...'), findsOneWidget);

    completer.complete([
      for (final repo in repos)
        BatchOperationResult(repository: repo, success: true, message: 'Done'),
    ]);
    await tester.pump();

    // The pinned line is gone once the run is over; every row shows its
    // final result instead.
    expect(find.text('repo2'), findsOneWidget);
    expect(find.text('Waiting...'), findsNothing);
    expect(find.text('Done'), findsNWidgets(3));
  });

  testWidgets('a failure mid-run still advances the count and ends '
      'determinate', (tester) async {
    final repos = [for (var i = 1; i <= 3; i++) _repo(i)];
    late ProgressCallback progress;
    final completer = Completer<List<BatchOperationResult>>();

    await _pumpDialog(
      tester,
      repositories: repos,
      operation: (onProgress) {
        progress = onProgress!;
        return completer.future;
      },
    );

    progress(repos[0], 1, 3, 'Pulling changes...');
    await tester.pump();

    // The first repository fails, the service moves on and reports the next
    // one; the count must advance even though the failure is not known yet.
    progress(repos[1], 2, 3, 'Pulling changes...');
    await tester.pump();
    expect(_barValue(tester), closeTo(1 / 3, 1e-9));
    expect(find.text('1 / 3'), findsOneWidget);

    progress(repos[2], 3, 3, 'Pulling changes...');
    await tester.pump();
    expect(_barValue(tester), closeTo(2 / 3, 1e-9));
    expect(find.text('2 / 3'), findsOneWidget);

    completer.complete([
      BatchOperationResult(
        repository: repos[0],
        success: false,
        error: 'merge conflict',
      ),
      BatchOperationResult(
        repository: repos[1],
        success: true,
        message: 'Done',
      ),
      BatchOperationResult(
        repository: repos[2],
        success: true,
        message: 'Done',
      ),
    ]);
    await tester.pump();

    expect(_barValue(tester), 1.0);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('merge conflict'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
