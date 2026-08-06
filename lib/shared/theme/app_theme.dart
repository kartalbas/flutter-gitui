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
      extensions: [AnimationSpeedExtension(speed: animationSpeed)],
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
        style: TextButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
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
      extensions: [AnimationSpeedExtension(speed: animationSpeed)],
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
        style: TextButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
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

  /// Scale factor applied to every text role's `medium` size for a user
  /// font-size setting.
  ///
  /// The tiny/small/large columns of the type scale derive from the medium
  /// column by one rule - multiply by the factor and round to the nearest
  /// whole logical pixel - instead of hand-picked per-role values. The
  /// factors are chosen so that after rounding every role keeps a distinct
  /// size per setting and no two settings collapse to the same pixel size
  /// for any role.
  static const Map<AppFontSize, double> _fontSizeFactor = {
    AppFontSize.tiny: 0.85,
    AppFontSize.small: 0.92,
    AppFontSize.medium: 1.0,
    AppFontSize.large: 1.10,
  };

  /// Font features shared by every proportional text style.
  static const List<FontFeature> _textFontFeatures = [
    FontFeature.enable('kern'), // Kerning for better spacing
    FontFeature.enable('liga'), // Standard ligatures
    FontFeature.enable('clig'), // Contextual ligatures
  ];

  /// Font features for monospace (code) text styles.
  static const List<FontFeature> _monoFontFeatures = [
    FontFeature.enable('kern'), // Kerning
    FontFeature.enable('liga'), // Ligatures for coding fonts
    FontFeature.enable('clig'), // Contextual ligatures
    FontFeature.enable('zero'), // Slashed zero for better distinction
  ];

  /// Build the app's [TextTheme] from a Google Fonts base theme.
  ///
  /// This is the single place that defines the app's type scale: all 15
  /// Material 3 text roles with distinct sizes, plus the letter spacing and
  /// line height of the Material 3 2021 English-like type ramp
  /// (`Typography.englishLike2021`).
  ///
  /// `size` is the font size at [AppFontSize.medium] in logical pixels.
  /// Display, headline, title and body sizes are deliberately tuned below
  /// the phone-first Material 3 defaults for this dense desktop app; every
  /// deviation is recorded in docs/deviation_register.yaml with the M3 value
  /// noted inline below. The other settings derive from medium via
  /// [_fontSizeFactor].
  ///
  /// `tracking` (letter spacing in logical pixels) and `height` (line height
  /// as a multiple of the font size) are carried unchanged from the M3 ramp.
  /// They must be set explicitly: the Google Fonts base theme supplies only
  /// font family and color - its letterSpacing and height are always null -
  /// so relying on it would drop the M3 metrics.
  static TextTheme _buildTextTheme(
    TextTheme baseTheme,
    AppFontSize fontSize,
    List<FontFeature> fontFeatures,
  ) {
    final factor = _fontSizeFactor[fontSize]!;

    TextStyle? role(
      TextStyle? style, {
      required double size,
      required double tracking,
      required double height,
    }) {
      if (style == null) return null;
      return style.copyWith(
        fontSize: (size * factor).roundToDouble(),
        letterSpacing: tracking,
        height: height,
        fontFeatures: fontFeatures,
      );
    }

    return TextTheme(
      displayLarge: role(
        baseTheme.displayLarge,
        size: 45, // M3: 57
        tracking: -0.25,
        height: 1.12,
      ),
      displayMedium: role(
        baseTheme.displayMedium,
        size: 36, // M3: 45
        tracking: 0.0,
        height: 1.16,
      ),
      displaySmall: role(
        baseTheme.displaySmall,
        size: 32, // M3: 36
        tracking: 0.0,
        height: 1.22,
      ),
      headlineLarge: role(
        baseTheme.headlineLarge,
        size: 28, // M3: 32
        tracking: 0.0,
        height: 1.25,
      ),
      headlineMedium: role(
        baseTheme.headlineMedium,
        size: 24, // M3: 28
        tracking: 0.0,
        height: 1.29,
      ),
      headlineSmall: role(
        baseTheme.headlineSmall,
        size: 22, // M3: 24
        tracking: 0.0,
        height: 1.33,
      ),
      titleLarge: role(
        baseTheme.titleLarge,
        size: 20, // M3: 22
        tracking: 0.0,
        height: 1.27,
      ),
      titleMedium: role(
        baseTheme.titleMedium,
        size: 16,
        tracking: 0.15,
        height: 1.50,
      ),
      titleSmall: role(
        baseTheme.titleSmall,
        size: 14,
        tracking: 0.1,
        height: 1.43,
      ),
      bodyLarge: role(
        baseTheme.bodyLarge,
        size: 15, // M3: 16
        tracking: 0.5,
        height: 1.50,
      ),
      bodyMedium: role(
        baseTheme.bodyMedium,
        size: 13, // M3: 14
        tracking: 0.25,
        height: 1.43,
      ),
      bodySmall: role(
        baseTheme.bodySmall,
        size: 12,
        tracking: 0.4,
        height: 1.33,
      ),
      labelLarge: role(
        baseTheme.labelLarge,
        size: 14,
        tracking: 0.1,
        height: 1.43,
      ),
      labelMedium: role(
        baseTheme.labelMedium,
        size: 12,
        tracking: 0.5,
        height: 1.33,
      ),
      labelSmall: role(
        baseTheme.labelSmall,
        size: 11,
        tracking: 0.5,
        height: 1.45,
      ),
    );
  }

  /// Get text theme with custom font family and size
  static TextTheme _getTextTheme(String fontFamily, AppFontSize fontSize) {
    // Get the base text theme from Google Fonts
    TextTheme baseTheme;
    try {
      baseTheme = GoogleFonts.getTextTheme(fontFamily);
    } catch (e) {
      // Fallback to Inter if specified font family is not available
      baseTheme = GoogleFonts.interTextTheme();
    }
    return _buildTextTheme(baseTheme, fontSize, _textFontFeatures);
  }

  /// Monospace text theme for code (JetBrains Mono)
  static TextTheme monoTextTheme({AppFontSize fontSize = AppFontSize.medium}) {
    return _buildTextTheme(
      GoogleFonts.jetBrainsMonoTextTheme(),
      fontSize,
      _monoFontFeatures,
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
  static const double iconSizeSmall = 16.0; // Tab icons, inline indicators
  static const double iconSizeDefault =
      24.0; // Buttons (use default, don't specify)
  static const double iconSizeLarge = 32.0; // Headers, emphasis
  static const double iconSizeXL = 48.0; // Empty states
  static const double iconSizeXXL = 64.0; // Drag overlays, splash screens

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

  /// Commit graph lane colors
  ///
  /// The history graph cycles through these per branch lane. Mid-tone hues
  /// are chosen so a two-pixel line stays readable on both the light and the
  /// dark surface, which no single colorScheme role guarantees.
  static const List<Color> commitGraphLaneColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFF26C6DA), // Cyan
    Color(0xFFEC407A), // Pink
    Color(0xFF9CCC65), // Light green
    Color(0xFF5C6BC0), // Indigo
  ];

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
    return Theme.of(this).extension<AnimationSpeedExtension>()?.speed ??
        AppAnimationSpeed.normal;
  }

  /// Get quick animation duration (e.g., for hover effects, ripples)
  Duration get quickAnimation => AppTheme.getQuickAnimation(animationSpeed);

  /// Get standard animation duration (e.g., for dialogs, menus, modals, tabs)
  Duration get standardAnimation =>
      AppTheme.getStandardAnimation(animationSpeed);

  /// Get slow animation duration (e.g., for page transitions, major state changes)
  Duration get slowAnimation => AppTheme.getSlowAnimation(animationSpeed);
}
