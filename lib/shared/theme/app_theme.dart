import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_config.dart';

/// Application theme configuration
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Get light theme with configuration
  static ThemeData lightTheme({
    AppColorScheme colorScheme = AppColorScheme.deepPurple,
    String fontFamily = 'Inter',
    AppFontSize fontSize = AppFontSize.medium,
    AppAnimationSpeed animationSpeed = AppAnimationSpeed.normal,
  }) {
    final theme = FlexThemeData.light(
      scheme: _mapColorScheme(colorScheme),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 9,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        blendOnColors: false,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        defaultRadius: 12.0,
        elevatedButtonRadius: 8.0,
        filledButtonRadius: 8.0,
        outlinedButtonRadius: 8.0,
        textButtonRadius: 8.0,
        inputDecoratorRadius: 8.0,
        fabUseShape: true,
        fabRadius: 16.0,
        chipRadius: 8.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      textTheme: _getTextTheme(fontFamily, fontSize),
    );

    // Apply animation speed overrides and consistent text styling
    return theme.copyWith(
      extensions: [
        AnimationSpeedExtension(speed: animationSpeed),
      ],
      popupMenuTheme: PopupMenuThemeData(
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        iconColor: theme.colorScheme.primary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: theme.colorScheme.primary,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _getPageTransition(animationSpeed),
          TargetPlatform.iOS: _getPageTransition(animationSpeed),
          TargetPlatform.linux: _getPageTransition(animationSpeed),
          TargetPlatform.macOS: _getPageTransition(animationSpeed),
          TargetPlatform.windows: _getPageTransition(animationSpeed),
        },
      ),
    );
  }

  /// Get dark theme with configuration
  static ThemeData darkTheme({
    AppColorScheme colorScheme = AppColorScheme.deepPurple,
    String fontFamily = 'Inter',
    AppFontSize fontSize = AppFontSize.medium,
    AppAnimationSpeed animationSpeed = AppAnimationSpeed.normal,
  }) {
    final theme = FlexThemeData.dark(
      scheme: _mapColorScheme(colorScheme),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 8,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        defaultRadius: 12.0,
        elevatedButtonRadius: 8.0,
        filledButtonRadius: 8.0,
        outlinedButtonRadius: 8.0,
        textButtonRadius: 8.0,
        inputDecoratorRadius: 8.0,
        fabUseShape: true,
        fabRadius: 16.0,
        chipRadius: 8.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      textTheme: _getTextTheme(fontFamily, fontSize),
    );

    // Apply animation speed overrides and consistent text styling
    return theme.copyWith(
      extensions: [
        AnimationSpeedExtension(speed: animationSpeed),
      ],
      popupMenuTheme: PopupMenuThemeData(
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        iconColor: theme.colorScheme.primary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: theme.textTheme.bodyLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: theme.colorScheme.primary,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _getPageTransition(animationSpeed),
          TargetPlatform.iOS: _getPageTransition(animationSpeed),
          TargetPlatform.linux: _getPageTransition(animationSpeed),
          TargetPlatform.macOS: _getPageTransition(animationSpeed),
          TargetPlatform.windows: _getPageTransition(animationSpeed),
        },
      ),
    );
  }

  /// Map AppColorScheme to FlexScheme
  static FlexScheme _mapColorScheme(AppColorScheme colorScheme) {
    switch (colorScheme) {
      case AppColorScheme.deepPurple:
        return FlexScheme.deepPurple;
      case AppColorScheme.indigo:
        return FlexScheme.indigo;
      case AppColorScheme.blue:
        return FlexScheme.blue;
      case AppColorScheme.teal:
        return FlexScheme.aquaBlue;
      case AppColorScheme.green:
        return FlexScheme.green;
      case AppColorScheme.red:
        return FlexScheme.red;
      case AppColorScheme.pink:
        return FlexScheme.rosewood;
      case AppColorScheme.purple:
        return FlexScheme.purpleBrown;
      case AppColorScheme.deepOrange:
        return FlexScheme.deepOrangeM3;
      case AppColorScheme.blueGrey:
        return FlexScheme.blueWhale;
    }
  }

  /// Get discrete font size adjustments (in pixels, not multipliers)
  /// Uses standard optical sizes that fonts are designed for
  static Map<String, double> _getFontSizeAdjustments(AppFontSize fontSize) {
    switch (fontSize) {
      case AppFontSize.tiny:
        return {
          'display': 48.0,      // -9px from standard 57
          'headline': 28.0,     // -4px from standard 32
          'title': 18.0,        // -4px from standard 22
          'body': 13.0,         // -3px from standard 16
          'label': 10.0,        // -1px from standard 11
        };
      case AppFontSize.small:
        return {
          'display': 52.0,      // -5px from standard 57
          'headline': 30.0,     // -2px from standard 32
          'title': 20.0,        // -2px from standard 22
          'body': 14.0,         // -2px from standard 16
          'label': 11.0,        // standard
        };
      case AppFontSize.medium:
        return {
          'display': 57.0,      // Material Design 3 standard
          'headline': 32.0,     // Material Design 3 standard
          'title': 22.0,        // Material Design 3 standard
          'body': 16.0,         // Material Design 3 standard
          'label': 11.0,        // Material Design 3 standard
        };
      case AppFontSize.large:
        return {
          'display': 64.0,      // +7px from standard 57
          'headline': 36.0,     // +4px from standard 32
          'title': 24.0,        // +2px from standard 22
          'body': 18.0,         // +2px from standard 16
          'label': 12.0,        // +1px from standard 11
        };
    }
  }

  /// Get text theme with custom font family and size
  static TextTheme _getTextTheme(String fontFamily, AppFontSize fontSize) {
    final sizeMap = _getFontSizeAdjustments(fontSize);

    // Font features for enhanced rendering
    final fontFeatures = <FontFeature>[
      const FontFeature.enable('kern'), // Enable kerning for better spacing
      const FontFeature.enable('liga'), // Enable ligatures
      const FontFeature.enable('clig'), // Enable contextual ligatures
    ];

    // Get the base text theme from Google Fonts
    TextTheme baseTheme;
    try {
      baseTheme = GoogleFonts.getTextTheme(fontFamily);
    } catch (e) {
      // Fallback to Inter if specified font family is not available
      baseTheme = GoogleFonts.interTextTheme();
    }

    // Helper to apply discrete font sizes and enhanced rendering
    TextStyle? applyEnhancements(TextStyle? style, String category, double defaultSize) {
      if (style == null) return null;

      return style.copyWith(
        fontSize: sizeMap[category] ?? defaultSize,
        letterSpacing: style.letterSpacing ?? 0.0,
        height: style.height ?? 1.4, // Improved line height for readability
        fontFeatures: fontFeatures, // Apply font features
      );
    }

    return TextTheme(
      displayLarge: applyEnhancements(baseTheme.displayLarge, 'display', 57),
      displayMedium: applyEnhancements(baseTheme.displayMedium, 'display', 45),
      displaySmall: applyEnhancements(baseTheme.displaySmall, 'display', 36),
      headlineLarge: applyEnhancements(baseTheme.headlineLarge, 'headline', 32),
      headlineMedium: applyEnhancements(baseTheme.headlineMedium, 'headline', 28),
      headlineSmall: applyEnhancements(baseTheme.headlineSmall, 'headline', 24),
      titleLarge: applyEnhancements(baseTheme.titleLarge, 'title', 22),
      titleMedium: applyEnhancements(baseTheme.titleMedium, 'title', 16),
      titleSmall: applyEnhancements(baseTheme.titleSmall, 'title', 14),
      bodyLarge: applyEnhancements(baseTheme.bodyLarge, 'body', 16),
      bodyMedium: applyEnhancements(baseTheme.bodyMedium, 'body', 14),
      bodySmall: applyEnhancements(baseTheme.bodySmall, 'body', 12),
      labelLarge: applyEnhancements(baseTheme.labelLarge, 'label', 14),
      labelMedium: applyEnhancements(baseTheme.labelMedium, 'label', 12),
      labelSmall: applyEnhancements(baseTheme.labelSmall, 'label', 11),
    );
  }

  /// Apply enhanced rendering properties to text theme
  /// Note: Currently unused but kept for potential future enhancements
  // ignore: unused_element
  static TextTheme _applyEnhancedRendering(
    TextTheme theme,
    List<FontFeature> fontFeatures,
  ) {
    TextStyle? enhance(TextStyle? style) {
      if (style == null) return null;
      return style.copyWith(
        letterSpacing: style.letterSpacing ?? 0.0,
        height: style.height ?? 1.4, // Improved line height for readability
        fontFeatures: fontFeatures, // Apply font features
      );
    }

    return TextTheme(
      displayLarge: enhance(theme.displayLarge),
      displayMedium: enhance(theme.displayMedium),
      displaySmall: enhance(theme.displaySmall),
      headlineLarge: enhance(theme.headlineLarge),
      headlineMedium: enhance(theme.headlineMedium),
      headlineSmall: enhance(theme.headlineSmall),
      titleLarge: enhance(theme.titleLarge),
      titleMedium: enhance(theme.titleMedium),
      titleSmall: enhance(theme.titleSmall),
      bodyLarge: enhance(theme.bodyLarge),
      bodyMedium: enhance(theme.bodyMedium),
      bodySmall: enhance(theme.bodySmall),
      labelLarge: enhance(theme.labelLarge),
      labelMedium: enhance(theme.labelMedium),
      labelSmall: enhance(theme.labelSmall),
    );
  }

  /// Monospace text theme for code (JetBrains Mono)
  static TextTheme monoTextTheme({AppFontSize fontSize = AppFontSize.medium}) {
    // Font features for monospace fonts
    final fontFeatures = <FontFeature>[
      const FontFeature.enable('kern'), // Enable kerning
      const FontFeature.enable('liga'), // Enable ligatures for coding fonts
      const FontFeature.enable('clig'), // Contextual ligatures
      const FontFeature.enable('zero'), // Slashed zero for better distinction
    ];

    final baseTheme = GoogleFonts.jetBrainsMonoTextTheme();
    final sizeMap = _getFontSizeAdjustments(fontSize);

    // Helper to apply discrete font sizes and enhanced rendering
    TextStyle? applyEnhancements(TextStyle? style, String category, double defaultSize) {
      if (style == null) return null;

      return style.copyWith(
        fontSize: sizeMap[category] ?? defaultSize,
        letterSpacing: style.letterSpacing ?? 0.0,
        height: style.height ?? 1.5, // Slightly taller line height for code
        fontFeatures: fontFeatures, // Apply font features
      );
    }

    return TextTheme(
      displayLarge: applyEnhancements(baseTheme.displayLarge, 'display', 57),
      displayMedium: applyEnhancements(baseTheme.displayMedium, 'display', 45),
      displaySmall: applyEnhancements(baseTheme.displaySmall, 'display', 36),
      headlineLarge: applyEnhancements(baseTheme.headlineLarge, 'headline', 32),
      headlineMedium: applyEnhancements(baseTheme.headlineMedium, 'headline', 28),
      headlineSmall: applyEnhancements(baseTheme.headlineSmall, 'headline', 24),
      titleLarge: applyEnhancements(baseTheme.titleLarge, 'title', 22),
      titleMedium: applyEnhancements(baseTheme.titleMedium, 'title', 16),
      titleSmall: applyEnhancements(baseTheme.titleSmall, 'title', 14),
      bodyLarge: applyEnhancements(baseTheme.bodyLarge, 'body', 16),
      bodyMedium: applyEnhancements(baseTheme.bodyMedium, 'body', 14),
      bodySmall: applyEnhancements(baseTheme.bodySmall, 'body', 12),
      labelLarge: applyEnhancements(baseTheme.labelLarge, 'label', 14),
      labelMedium: applyEnhancements(baseTheme.labelMedium, 'label', 12),
      labelSmall: applyEnhancements(baseTheme.labelSmall, 'label', 11),
    );
  }

  /// List of available fonts for the app
  /// Includes both sans-serif and monospace fonts
  /// All fonts are bundled locally for offline use
  static const List<String> availableFonts = [
    'Inter', // Default sans-serif font (modern, readable)
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Roboto Mono',
    'IBM Plex Mono',
    'Inconsolata',
    'Courier Prime',
    'Space Mono',
    'Anonymous Pro',
    'Overpass Mono',
    'DM Mono',
    'Noto Sans Mono',
  ];

  /// List of available monospace fonts for code/diff preview
  /// These fonts are optimized for code readability
  static const List<String> availableMonospaceFonts = [
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Roboto Mono',
    'IBM Plex Mono',
    'Inconsolata',
    'Courier Prime',
    'Space Mono',
    'Anonymous Pro',
    'Overpass Mono',
    'DM Mono',
    'Noto Sans Mono',
  ];

  /// Common padding values
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  /// Common border radius
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  /// Icon sizes
  static const double iconXS = 12.0;
  static const double iconS = 16.0;
  static const double iconM = 20.0;
  static const double iconL = 24.0;
  static const double iconXL = 32.0;

  /// Standardized icon sizes for UX consistency
  /// Use these for new components to ensure visual hierarchy
  static const double iconSizeSmall = 16.0;     // Tab icons, inline indicators
  static const double iconSizeDefault = 24.0;   // Buttons (use default, don't specify)
  static const double iconSizeLarge = 32.0;     // Headers, emphasis
  static const double iconSizeXL = 48.0;        // Empty states
  static const double iconSizeXXL = 64.0;       // Drag overlays, splash screens

  /// Navigation rail width
  static const double navigationRailWidth = 72.0;
  static const double navigationRailWidthExpanded = 256.0;

  /// Git status colors
  static const Color gitAdded = Color(0xFF4CAF50); // Green
  static const Color gitModified = Color(0xFFFF9800); // Orange
  static const Color gitDeleted = Color(0xFFF44336); // Red
  static const Color gitRenamed = Color(0xFF2196F3); // Blue
  static const Color gitUntracked = Color(0xFF9E9E9E); // Grey
  static const Color gitConflict = Color(0xFFE91E63); // Pink

  /// Branch colors
  static const Color branchLocal = Color(0xFF4CAF50); // Green
  static const Color branchRemote = Color(0xFF2196F3); // Blue
  static const Color branchTag = Color(0xFFFF9800); // Orange
  static const Color branchStash = Color(0xFF9C27B0); // Purple

  // ============================================
  // Animation Durations
  // ============================================

  /// Base animation durations (before speed multiplier applied)
  static const Duration _baseAnimationFast = Duration(milliseconds: 150);
  static const Duration _baseAnimationNormal = Duration(milliseconds: 250);
  static const Duration _baseAnimationSlow = Duration(milliseconds: 350);

  /// Get animation duration based on speed setting
  ///
  /// Usage in widgets:
  /// ```dart
  /// AnimatedContainer(
  ///   duration: AppTheme.getAnimationDuration(ref.watch(uiConfigProvider).animationSpeed),
  ///   // ... other properties
  /// )
  /// ```
  static Duration getAnimationDuration(
    AppAnimationSpeed speed, {
    Duration baseSpeed = _baseAnimationNormal,
  }) {
    switch (speed) {
      case AppAnimationSpeed.none:
        return Duration.zero;
      case AppAnimationSpeed.fast:
        return Duration(milliseconds: (baseSpeed.inMilliseconds * 0.7).round());
      case AppAnimationSpeed.normal:
        return baseSpeed;
      case AppAnimationSpeed.slow:
        return Duration(milliseconds: (baseSpeed.inMilliseconds * 1.5).round());
    }
  }

  /// Quick animation - for subtle UI feedback (e.g., hover effects, ripples)
  static Duration getQuickAnimation(AppAnimationSpeed speed) {
    return getAnimationDuration(speed, baseSpeed: _baseAnimationFast);
  }

  /// Standard animation - for most UI transitions (e.g., dialogs, menus, modals)
  static Duration getStandardAnimation(AppAnimationSpeed speed) {
    return getAnimationDuration(speed, baseSpeed: _baseAnimationNormal);
  }

  /// Slow animation - for emphasized transitions (e.g., page transitions, major state changes)
  static Duration getSlowAnimation(AppAnimationSpeed speed) {
    return getAnimationDuration(speed, baseSpeed: _baseAnimationSlow);
  }

  /// Get page transition builder based on animation speed
  static PageTransitionsBuilder _getPageTransition(AppAnimationSpeed speed) {
    if (speed == AppAnimationSpeed.none) {
      return const NoAnimationPageTransitionsBuilder();
    }
    return const FadeUpwardsPageTransitionsBuilder();
  }
}

/// Theme extension to store animation speed in theme
class AnimationSpeedExtension extends ThemeExtension<AnimationSpeedExtension> {
  final AppAnimationSpeed speed;

  const AnimationSpeedExtension({required this.speed});

  @override
  ThemeExtension<AnimationSpeedExtension> copyWith({AppAnimationSpeed? speed}) {
    return AnimationSpeedExtension(speed: speed ?? this.speed);
  }

  @override
  ThemeExtension<AnimationSpeedExtension> lerp(
    ThemeExtension<AnimationSpeedExtension>? other,
    double t,
  ) {
    if (other is! AnimationSpeedExtension) {
      return this;
    }
    return this;
  }
}

/// Page transition builder with no animation
class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Extension on BuildContext to easily get animation duration from theme
extension AnimationSpeedContext on BuildContext {
  /// Get the current animation speed from theme
  AppAnimationSpeed get animationSpeed {
    return Theme.of(this).extension<AnimationSpeedExtension>()?.speed ?? AppAnimationSpeed.normal;
  }

  /// Get quick animation duration (e.g., for hover effects, ripples)
  Duration get quickAnimation => AppTheme.getQuickAnimation(animationSpeed);

  /// Get standard animation duration (e.g., for dialogs, menus, modals, tabs)
  Duration get standardAnimation => AppTheme.getStandardAnimation(animationSpeed);

  /// Get slow animation duration (e.g., for page transitions, major state changes)
  Duration get slowAnimation => AppTheme.getSlowAnimation(animationSpeed);
}
