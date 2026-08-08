/// Proves the conformance harness end to end by measuring the app's
/// TextTheme against the Material 3 type-scale oracle taken from the
/// framework itself (Typography.englishLike2021,
/// flutter/lib/src/material/typography.dart).
///
/// Each of the fifteen roles is its own test so one mismatch does not hide
/// the others. Every measurement goes through `expectConformant`, so the
/// suite exercises both directions of the deviation register: the nine
/// TYPE-001..TYPE-009 entries in docs/deviation_register.yaml must keep
/// matching what the theme really renders, and the six conforming roles
/// must match the oracle without an entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/components/base_label.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../support/conformance_harness.dart';
import '../support/expect_conformant.dart';

void main() {
  // Building the theme resolves a Google Fonts family, which reads the asset
  // bundle. The same switch main.dart sets keeps that resolution offline.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('TextTheme font sizes vs the Material 3 type-scale oracle', () {
    // The oracle deliberately bypasses the app theme: englishLike2021 is the
    // generated M3 type table the register's spec_source entries cite.
    final Map<String, TextStyle?> oracleRoles = textThemeRoles(
      Typography.englishLike2021,
    );
    late Map<String, TextStyle?> appRoles;

    setUpAll(() {
      appRoles = textThemeRoles(AppTheme.lightTheme().textTheme);
    });

    for (final String role in oracleRoles.keys) {
      test(role, () {
        final TextStyle? appStyle = appRoles[role];
        expect(
          appStyle?.fontSize,
          isNotNull,
          reason: '$role is missing from the app theme',
        );
        expectConformant(
          token: 'TextTheme.$role.fontSize',
          component: 'TextTheme.$role',
          measured: appStyle!.fontSize!,
          expected: oracleRoles[role]!.fontSize!,
        );
      });
    }
  });

  group('conformance fixture', () {
    Text renderedLabelText(WidgetTester tester) {
      return tester.widget<Text>(
        find.descendant(
          of: find.byType(BaseLabel),
          matching: find.byType(Text),
        ),
      );
    }

    testWidgets('pumpConformance renders under the real app theme (light)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        const BaseLabel('Sample', role: TextRole.sectionTitle),
      );

      final ThemeData theme = Theme.of(tester.element(find.byType(BaseLabel)));
      expect(theme.brightness, Brightness.light);
      expect(
        describeTextRole(theme, renderedLabelText(tester).style),
        startsWith('titleMedium'),
        reason:
            'a sectionTitle pumped through the harness must resolve to the '
            "app theme's titleMedium role, which is this skin's answer for "
            'the role',
      );

      // Drain timers scheduled by google_fonts so teardown sees none pending.
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('pumpConformance renders under the real app theme (dark)', (
      WidgetTester tester,
    ) async {
      await pumpConformance(
        tester,
        const BaseLabel('Sample', role: TextRole.sectionTitle),
        brightness: Brightness.dark,
      );

      final ThemeData theme = Theme.of(tester.element(find.byType(BaseLabel)));
      expect(theme.brightness, Brightness.dark);
      expect(
        describeTextRole(theme, renderedLabelText(tester).style),
        startsWith('titleMedium'),
        reason:
            'a sectionTitle pumped through the harness must resolve to the '
            "app theme's titleMedium role, which is this skin's answer for "
            'the role',
      );

      // Drain timers scheduled by google_fonts so teardown sees none pending.
      await tester.pump(const Duration(seconds: 30));
    });
  });
}
