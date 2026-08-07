// BaseSelectAllButton always carries a real, localized label — the labelless
// variant is a separate component, BaseSelectAllIconButton, which renders as
// an icon-only control with a tooltip instead of a button with an empty label.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/generated/app_localizations.dart';
import 'package:flutter_gitui/shared/components/base_select_all_button.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('BaseSelectAllButton', () {
    testWidgets('labels the button "Select All" while not everything is '
        'selected', (tester) async {
      await _pump(
        tester,
        BaseSelectAllButton(isAllSelected: false, onPressed: () {}),
      );

      expect(find.text('Select All'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
    });

    testWidgets('labels the button "Deselect All" once everything is '
        'selected', (tester) async {
      await _pump(
        tester,
        BaseSelectAllButton(isAllSelected: true, onPressed: () {}),
      );

      expect(find.text('Deselect All'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.checkSquare), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var pressed = 0;
      await _pump(
        tester,
        BaseSelectAllButton(isAllSelected: false, onPressed: () => pressed++),
      );

      await tester.tap(find.byType(BaseSelectAllButton));
      await tester.pump();

      expect(pressed, 1);
    });
  });

  group('BaseSelectAllIconButton', () {
    testWidgets('renders icon-only with the action as a tooltip, not as an '
        'empty label', (tester) async {
      await _pump(
        tester,
        BaseSelectAllIconButton(isAllSelected: false, onPressed: () {}),
      );

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byTooltip('Select All'), findsOneWidget);
      // No inline label: the text exists only inside the (hidden) tooltip.
      expect(find.text('Select All'), findsNothing);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var pressed = 0;
      await _pump(
        tester,
        BaseSelectAllIconButton(
          isAllSelected: true,
          onPressed: () => pressed++,
        ),
      );

      await tester.tap(find.byType(BaseSelectAllIconButton));
      await tester.pump();

      expect(pressed, 1);
    });
  });
}
