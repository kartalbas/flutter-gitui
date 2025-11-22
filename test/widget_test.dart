// Basic widget tests for Flutter GitUI

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_gitui/main.dart';
import 'package:flutter_gitui/core/config/app_config.dart';

void main() {
  testWidgets('App initializes and shows navigation', (WidgetTester tester) async {
    // Build our app and trigger a frame with default config
    await tester.pumpWidget(ProviderScope(child: FlutterGitUIApp(initialConfig: AppConfig.defaults)));

    // Wait for app to build
    await tester.pumpAndSettle();

    // Verify that the navigation rail is present
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
