import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_config.dart';
import 'git_semantic_colors.dart';

export 'git_semantic_colors.dart';

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
        // Every radius below names a rung of the app's corner scale
        // ([radiusXS] .. [radiusXL] further down this class) rather than a
        // bare literal, so the scale stays the one place a corner is chosen.
        // These tokens are live: `BaseButton` takes its corner from
        // `filledButtonRadius` / `outlinedButtonRadius` / `textButtonRadius`
        // and nothing else, so editing [radiusM] moves the buttons on screen.
        // `inputDecoratorRadius` is the exception — the input components
        // deliberately render [radiusS] instead (registered as the FIELD
        // deviations), and this value only reaches SDK-owned fields such as
        // the date picker's.
        defaultRadius: radiusL,
        elevatedButtonRadius: radiusM,
        filledButtonRadius: radiusM,
        outlinedButtonRadius: radiusM,
        textButtonRadius: radiusM,
        inputDecoratorRadius: radiusM,
        fabUseShape: true,
        fabRadius: radiusXL,
        chipRadius: radiusM,
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
        GitSemanticColors.light,
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
        style: _layerOn(
          TextButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.textButtonTheme.style,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _layerOn(
          ElevatedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.elevatedButtonTheme.style,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _layerOn(
          OutlinedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.outlinedButtonTheme.style,
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        // A field's label keeps one style whether it rests inside the field
        // or floats above it, so this repeats `labelStyle` deliberately
        // rather than leaving the slot empty. It has to be spelled out:
        // `FlexSubThemesData` supplies a state-resolving `floatingLabelStyle`
        // of its own, and while the sub-theme was being replaced wholesale
        // that never arrived, so the floating label silently fell back to
        // `labelStyle`. Merging the sub-theme (see [_layerOn]) lets it
        // through, and it would grow the floating label from bodyMedium to
        // bodyLarge and recolour it — a restyling this app never chose.
        // Whether the label should instead follow Material 3's bodySmall
        // floating role is a separate decision for the FIELD family.
        floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
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
        // The same corner scale as the light theme; see the comment there.
        defaultRadius: radiusL,
        elevatedButtonRadius: radiusM,
        filledButtonRadius: radiusM,
        outlinedButtonRadius: radiusM,
        textButtonRadius: radiusM,
        inputDecoratorRadius: radiusM,
        fabUseShape: true,
        fabRadius: radiusXL,
        chipRadius: radiusM,
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
        GitSemanticColors.dark,
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
        style: _layerOn(
          TextButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.textButtonTheme.style,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _layerOn(
          ElevatedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.elevatedButtonTheme.style,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _layerOn(
          OutlinedButton.styleFrom(textStyle: theme.textTheme.bodyLarge),
          theme.outlinedButtonTheme.style,
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        // A field's label keeps one style whether it rests inside the field
        // or floats above it, so this repeats `labelStyle` deliberately
        // rather than leaving the slot empty. It has to be spelled out:
        // `FlexSubThemesData` supplies a state-resolving `floatingLabelStyle`
        // of its own, and while the sub-theme was being replaced wholesale
        // that never arrived, so the floating label silently fell back to
        // `labelStyle`. Merging the sub-theme (see [_layerOn]) lets it
        // through, and it would grow the floating label from bodyMedium to
        // bodyLarge and recolour it — a restyling this app never chose.
        // Whether the label should instead follow Material 3's bodySmall
        // floating role is a separate decision for the FIELD family.
        floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
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

  /// Layers the app's own [addition] on top of the sub-theme
  /// [FlexColorScheme] already built, instead of replacing it.
  ///
  /// This exists because `ThemeData.copyWith` *substitutes* a sub-theme: a
  /// bare `copyWith(textButtonTheme: TextButtonThemeData(style: …))` throws
  /// away everything [FlexSubThemesData] configured for text buttons —
  /// including the corner radius — and the tokens above would silently reach
  /// no widget at all. `ButtonStyle.merge` is the composing operation: the
  /// receiver's non-null fields win and the argument only fills the gaps, so
  /// passing [addition] as the receiver keeps the app's explicit choice in
  /// front while every token it says nothing about survives.
  ///
  /// [base] is nullable because a `…ButtonThemeData` may legitimately carry
  /// no style at all; there is then nothing to merge into.
  static ButtonStyle _layerOn(ButtonStyle addition, ButtonStyle? base) {
    return base == null ? addition : addition.merge(base);
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
  static const double radiusXS = 2.0;
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  /// Material 3 elevation levels.
  ///
  /// The six-level ladder from the M3 spec (0, 1, 3, 6, 8, 12 dp), matching
  /// Flutter's M3 component defaults: the navigation rail rests at level 0,
  /// cards at level 1, menus and popup menus at level 2, and dialogs at
  /// level 3. Levels 4 and 5 are reserved by the spec for transient surfaces
  /// that must sit above a dialog. Never write a raw elevation literal —
  /// pick the level that matches the surface's role.
  static const double elevationLevel0 = 0.0; // Flat: rails, resting app bars
  static const double elevationLevel1 = 1.0; // Resting cards and panels
  static const double elevationLevel2 = 3.0; // Menus and dropdown overlays
  static const double elevationLevel3 = 6.0; // Dialogs, floating action buttons
  static const double elevationLevel4 = 8.0; // Above-dialog transient surfaces
  static const double elevationLevel5 = 12.0; // Highest transient surfaces

  /// Icon sizes — the single icon scale for the app.
  ///
  /// `iconL` (24) is the Material 3 default icon size (icon buttons,
  /// navigation, app bars). `iconXS` (12) is reserved for non-interactive
  /// inline indicators in dense list rows and must not be used on tappable
  /// controls. Sizes above 32 are expressed as multiples of the scale,
  /// e.g. `iconXL * 2` (64) for empty-state artwork.
  static const double iconXS = 12.0; // Non-interactive inline indicators
  static const double iconS = 16.0; // Dense tree/list icons, small buttons
  static const double iconM = 20.0; // Compact toolbar and secondary icons
  static const double iconL = 24.0; // M3 default icon size (buttons, nav)
  static const double iconXL = 32.0; // Headers, emphasis, empty states

  /// Navigation rail width
  static const double navigationRailWidth = 72.0;
  static const double navigationRailWidthExpanded = 256.0;

  // ============================================
  // Animation Durations
  // ============================================

  /// Base animation durations (before speed multiplier applied).
  ///
  /// These are the Material 3 duration tokens short3 / medium1 / medium3
  /// (see [Durations] in the Flutter SDK). Never use raw [Duration]
  /// constants for animations — always route timing through
  /// [getQuickAnimation] / [getStandardAnimation] / [getSlowAnimation]
  /// (or the `BuildContext` extension) so the user's animation-speed
  /// setting is respected.
  static const Duration _baseAnimationFast = Durations.short3; // 150 ms
  static const Duration _baseAnimationNormal = Durations.medium1; // 250 ms
  static const Duration _baseAnimationSlow = Durations.medium3; // 350 ms

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
