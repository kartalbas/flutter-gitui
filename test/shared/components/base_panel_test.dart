// BasePanel's collapse caret sits on the shared icon scale (AppTheme.iconM)
// instead of a hardcoded size, so retuning the scale reaches the one
// component every panel inherits from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/shared/components/base_panel.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester, {bool initiallyExpanded = true}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasePanel(
            title: const Text('Panel'),
            content: const SizedBox(height: 40),
            isCollapsible: true,
            initiallyExpanded: initiallyExpanded,
          ),
        ),
      ),
    );
  }

  testWidgets('the expanded caret uses the AppTheme.iconM token', (
    tester,
  ) async {
    await pumpPanel(tester);

    final caret = tester.widget<Icon>(
      find.byIcon(PhosphorIconsRegular.caretUp),
    );
    expect(caret.size, AppTheme.iconM);
  });

  testWidgets('the collapsed caret uses the AppTheme.iconM token', (
    tester,
  ) async {
    await pumpPanel(tester, initiallyExpanded: false);

    final caret = tester.widget<Icon>(
      find.byIcon(PhosphorIconsRegular.caretDown),
    );
    expect(caret.size, AppTheme.iconM);
  });
}
