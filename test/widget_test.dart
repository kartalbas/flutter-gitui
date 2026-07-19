// Basic widget tests for Flutter GitUI

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_gitui/main.dart';
import 'package:flutter_gitui/core/config/app_config.dart';

void main() {
  testWidgets('App boots past the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: FlutterGitUIApp(initialConfig: AppConfig.defaults),
      ),
    );

    // The splash screen is dismissed by a Future.delayed, which pumpAndSettle
    // does not wait for -- it only drains animations. Advance time past it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // The app is up if a MaterialApp is mounted and the splash is gone.
    expect(find.byType(MaterialApp), findsOneWidget);

    // The app also schedules a deferred update check. Let it elapse so no timer
    // is left pending when the tree is torn down. See #177 -- scheduling that
    // from build() is itself a defect.
    await tester.pump(const Duration(seconds: 10));
  });
}
