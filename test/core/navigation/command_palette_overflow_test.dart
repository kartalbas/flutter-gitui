// Issue #377: the palette is presented with showModalBottomSheet, which
// Material 3 caps at 640 logical pixels of width. At the application's
// minimum window size (AppConstants.minWindowWidth x minWindowHeight,
// 800x600 - reachable, since main.dart enforces exactly this floor) the
// footer row used to lay out three fixed key hints plus the trailing
// command count with nothing allowed to shrink, so under the test font it
// overflowed by 67 pixels on the right. The palette must open, lay out and
// scroll through the full command list at that window size without a
// single overflow exception.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/constants/app_constants.dart';
import 'package:flutter_gitui/core/navigation/command_palette.dart';
import 'package:flutter_gitui/core/navigation/git_commands.dart';
import 'package:flutter_gitui/generated/app_localizations.dart';

void main() {
  testWidgets(
    'the palette opened as a modal bottom sheet at the 800x600 minimum '
    'window scrolls through the full command list without overflowing',
    (tester) async {
      tester.view.physicalSize = const Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      );
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );

      // Mirror the production presentation (AppShell._showCommandPalette):
      // the same sheet call with the same flags, so the palette lays out
      // under the real Material 3 width cap of a modal bottom sheet.
      final BuildContext context = tester.element(find.byType(Scaffold));
      showModalBottomSheet<GitCommand>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0),
        builder: (context) => const CommandPalette(),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'opening the palette must not overflow its sheet',
      );

      // The footer is present with all commands available; the first item of
      // the list is rendered.
      expect(find.byType(ListView), findsOneWidget);

      // Scroll through the entire list. The draggable sheet consumes a whole
      // drag gesture while the list is at its top (the first drag expands the
      // sheet to its maximum extent), and ListView.builder refines its
      // maxScrollExtent estimate as items are laid out, so drag until the
      // position actually settles on the end of the list. Every item and the
      // footer lay out at the sheet's capped width along the way.
      ScrollPosition position() {
        final ScrollableState scrollable = tester.state(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        return scrollable.position;
      }

      var drags = 0;
      while (position().pixels < position().maxScrollExtent) {
        drags++;
        expect(
          drags,
          lessThan(10),
          reason: 'the command list never reached its end',
        );
        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'scrolling the full command list must not overflow',
        );
      }

      // The list actually reached its end: the whole command list, including
      // the last item, was laid out without a single overflow report.
      expect(position().pixels, position().maxScrollExtent);
      expect(position().maxScrollExtent, greaterThan(0));
    },
  );
}
