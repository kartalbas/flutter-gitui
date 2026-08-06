import 'package:flutter/material.dart';
import 'package:flutter_gitui/core/config/app_config.dart';
import 'package:flutter_gitui/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Material 3 type scale as shipped in the Flutter SDK
/// (packages/flutter/lib/src/material/typography.dart, `englishLike2021`),
/// paired with the size this app renders at `AppFontSize.medium`.
///
/// Where the two differ the app value is a registered desktop-density
/// deviation; see docs/deviation_register.yaml, entries TYPE-001..TYPE-009.
const _mediumScale =
    <String, ({double app, double m3, double tracking, double height})>{
      'displayLarge': (app: 45, m3: 57, tracking: -0.25, height: 1.12),
      'displayMedium': (app: 36, m3: 45, tracking: 0.0, height: 1.16),
      'displaySmall': (app: 32, m3: 36, tracking: 0.0, height: 1.22),
      'headlineLarge': (app: 28, m3: 32, tracking: 0.0, height: 1.25),
      'headlineMedium': (app: 24, m3: 28, tracking: 0.0, height: 1.29),
      'headlineSmall': (app: 22, m3: 24, tracking: 0.0, height: 1.33),
      'titleLarge': (app: 20, m3: 22, tracking: 0.0, height: 1.27),
      'titleMedium': (app: 16, m3: 16, tracking: 0.15, height: 1.50),
      'titleSmall': (app: 14, m3: 14, tracking: 0.1, height: 1.43),
      'bodyLarge': (app: 15, m3: 16, tracking: 0.5, height: 1.50),
      'bodyMedium': (app: 13, m3: 14, tracking: 0.25, height: 1.43),
      'bodySmall': (app: 12, m3: 12, tracking: 0.4, height: 1.33),
      'labelLarge': (app: 14, m3: 14, tracking: 0.1, height: 1.43),
      'labelMedium': (app: 12, m3: 12, tracking: 0.5, height: 1.33),
      'labelSmall': (app: 11, m3: 11, tracking: 0.5, height: 1.45),
    };

TextStyle? _role(TextTheme theme, String name) => switch (name) {
  'displayLarge' => theme.displayLarge,
  'displayMedium' => theme.displayMedium,
  'displaySmall' => theme.displaySmall,
  'headlineLarge' => theme.headlineLarge,
  'headlineMedium' => theme.headlineMedium,
  'headlineSmall' => theme.headlineSmall,
  'titleLarge' => theme.titleLarge,
  'titleMedium' => theme.titleMedium,
  'titleSmall' => theme.titleSmall,
  'bodyLarge' => theme.bodyLarge,
  'bodyMedium' => theme.bodyMedium,
  'bodySmall' => theme.bodySmall,
  'labelLarge' => theme.labelLarge,
  'labelMedium' => theme.labelMedium,
  'labelSmall' => theme.labelSmall,
  _ => throw ArgumentError('unknown text role: $name'),
};

void main() {
  // Building the theme resolves a Google Fonts family, which reads the asset
  // bundle. The same switch main.dart sets keeps that resolution offline.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('type scale', () {
    test('every Material 3 role has its own size at the medium setting', () {
      final textTheme = AppTheme.lightTheme().textTheme;

      for (final entry in _mediumScale.entries) {
        final style = _role(textTheme, entry.key);
        expect(
          style,
          isNotNull,
          reason: '${entry.key} is missing from the theme',
        );
        expect(
          style!.fontSize,
          entry.value.app,
          reason:
              '${entry.key} font size drifted. Material 3 specifies '
              '${entry.value.m3}; this app renders ${entry.value.app} as a '
              'registered desktop deviation (docs/deviation_register.yaml).',
        );
      }
    });

    test('the three roles inside a category never collapse to one size', () {
      final textTheme = AppTheme.lightTheme().textTheme;

      const categories = {
        'display': ['displayLarge', 'displayMedium', 'displaySmall'],
        'headline': ['headlineLarge', 'headlineMedium', 'headlineSmall'],
        'title': ['titleLarge', 'titleMedium', 'titleSmall'],
        'body': ['bodyLarge', 'bodyMedium', 'bodySmall'],
        'label': ['labelLarge', 'labelMedium', 'labelSmall'],
      };

      for (final category in categories.entries) {
        final sizes = category.value
            .map((role) => _role(textTheme, role)!.fontSize)
            .toList();
        expect(
          sizes.toSet(),
          hasLength(3),
          reason:
              'The ${category.key} roles rendered at $sizes. A category that '
              'applies one size to all three of its roles is the defect this '
              'test exists to catch.',
        );
        expect(
          sizes,
          orderedEquals(<double?>[...sizes]..sort((a, b) => b!.compareTo(a!))),
          reason: 'The ${category.key} ramp must decrease from large to small.',
        );
      }
    });

    test('Material 3 letter spacing and line height survive the theme', () {
      final textTheme = AppTheme.lightTheme().textTheme;

      for (final entry in _mediumScale.entries) {
        final style = _role(textTheme, entry.key)!;
        expect(
          style.letterSpacing,
          entry.value.tracking,
          reason:
              '${entry.key} lost its Material 3 tracking. The Google Fonts '
              'base theme carries no letterSpacing, so the theme must set it '
              'explicitly rather than defaulting it away.',
        );
        expect(
          style.height,
          entry.value.height,
          reason:
              '${entry.key} lost its Material 3 line height. A uniform height '
              'across all roles is the defect this test exists to catch.',
        );
      }
    });

    test('every user font-size setting keeps the ramp distinct', () {
      for (final setting in AppFontSize.values) {
        final textTheme = AppTheme.lightTheme(fontSize: setting).textTheme;

        final sizes = _mediumScale.keys
            .map((role) => _role(textTheme, role)!.fontSize!)
            .toList();

        expect(
          sizes.every((size) => size > 0),
          isTrue,
          reason: 'A role rendered at zero on the $setting setting.',
        );

        for (final roles in const [
          ['displayLarge', 'displayMedium', 'displaySmall'],
          ['headlineLarge', 'headlineMedium', 'headlineSmall'],
          ['titleLarge', 'titleMedium', 'titleSmall'],
          ['bodyLarge', 'bodyMedium', 'bodySmall'],
          ['labelLarge', 'labelMedium', 'labelSmall'],
        ]) {
          final categorySizes = roles
              .map((role) => _role(textTheme, role)!.fontSize)
              .toSet();
          expect(
            categorySizes,
            hasLength(3),
            reason:
                'Rounding collapsed $roles on the $setting setting: '
                '$categorySizes.',
          );
        }
      }
    });

    test('the dark theme carries the same scale as the light theme', () {
      final light = AppTheme.lightTheme().textTheme;
      final dark = AppTheme.darkTheme().textTheme;

      for (final role in _mediumScale.keys) {
        expect(
          _role(dark, role)!.fontSize,
          _role(light, role)!.fontSize,
          reason: '$role differs between the light and dark themes.',
        );
      }
    });
  });
}
