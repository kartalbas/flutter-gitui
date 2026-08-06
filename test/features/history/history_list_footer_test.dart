// The footer is the affordance that distinguishes "end of what is loaded"
// from "end of the history": a loadable window shows the Load button naming
// the page size, a fully loaded window shows the terminal marker and no
// button, and a failed page shows the error with a retry instead of losing
// the window.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/features/history/widgets/history_list_footer.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

Widget harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('more history: the Load button names the page size', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      harness(
        HistoryListFooter(
          loadedCount: 400,
          hasMore: true,
          isLoadingMore: false,
          pageSize: 200,
          onLoadMore: () => loads++,
        ),
      ),
    );

    expect(find.text('400 commits loaded'), findsOneWidget);
    await tester.tap(find.text('Load 200 older commits'));
    expect(loads, 1);
  });

  testWidgets('end of history: the terminal marker and no button', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        HistoryListFooter(
          loadedCount: 137,
          hasMore: false,
          isLoadingMore: false,
          pageSize: 200,
          onLoadMore: () {},
        ),
      ),
    );

    expect(
      find.text('Beginning of history - all 137 commits loaded'),
      findsOneWidget,
    );
    expect(find.textContaining('older commits'), findsNothing);
  });

  testWidgets('a failed page offers retry without losing the window', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      harness(
        HistoryListFooter(
          loadedCount: 200,
          hasMore: true,
          isLoadingMore: false,
          pageSize: 200,
          loadMoreError: 'boom',
          onLoadMore: () => retries++,
        ),
      ),
    );

    expect(find.textContaining('boom'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('an active search on a partial window offers the deep search', (
    tester,
  ) async {
    var deep = 0;
    await tester.pumpWidget(
      harness(
        HistoryListFooter(
          loadedCount: 200,
          hasMore: true,
          isLoadingMore: false,
          pageSize: 200,
          searchActive: true,
          onLoadMore: () {},
          onSearchAllHistory: () => deep++,
        ),
      ),
    );

    await tester.tap(find.text('Search entire history'));
    expect(deep, 1);
  });
}
