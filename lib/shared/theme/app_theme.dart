import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/app_config.dart';
import 'contrast.dart';
import 'git_semantic_colors.dart';

export 'contrast.dart';
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
      textTheme: _brightnessCorrectedTextTheme(theme),
      chipTheme: _stateAwareChipTheme(theme),
      popupMenuTheme: layeredPopupMenuTheme(theme),
      dialogTheme: layeredDialogTheme(theme),
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
        // Material 3's hint role is `onSurfaceVariant` (Flutter 3.44.4
        // packages/flutter/lib/src/material/input_decorator.dart:5956,
        // `_InputDecoratorDefaultsM3.hintStyle`). The 60 % `onSurface` this
        // used to be is a dimmed colour rather than a role, and it measures
        // 4.14 : 1 against the filled field's own container in the worst of
        // the ten selectable schemes - under the 4.5 : 1 SC 1.4.3 asks of
        // placeholder text, which is text like any other.
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      textSelectionTheme: layeredTextSelectionTheme(theme),
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
      textTheme: _brightnessCorrectedTextTheme(theme),
      chipTheme: _stateAwareChipTheme(theme),
      popupMenuTheme: layeredPopupMenuTheme(theme),
      dialogTheme: layeredDialogTheme(theme),
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
        // Material 3's hint role is `onSurfaceVariant` (Flutter 3.44.4
        // packages/flutter/lib/src/material/input_decorator.dart:5956,
        // `_InputDecoratorDefaultsM3.hintStyle`). The 60 % `onSurface` this
        // used to be is a dimmed colour rather than a role, and it measures
        // 4.14 : 1 against the filled field's own container in the worst of
        // the ten selectable schemes - under the 4.5 : 1 SC 1.4.3 asks of
        // placeholder text, which is text like any other.
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      textSelectionTheme: layeredTextSelectionTheme(theme),
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

  /// The type scale, recoloured for the brightness the theme is built for.
  ///
  /// The scale is built from a Google Fonts base theme, and that base theme
  /// carries a colour of its own: `#1D1B20`, which is Material 3's *light*
  /// `onSurface`. `ThemeData` merges a supplied `TextTheme` over
  /// `Typography.white` in a dark theme, so a non-null colour wins, and the
  /// dark type scale came out near-black.
  ///
  /// Almost nothing showed it, because almost everything that paints text here
  /// names its own colour — `BaseLabel` first among them. The exception is the
  /// one role the SDK reads straight off the scale: a `TextField` takes the
  /// colour of the text the user types from `textTheme.bodyLarge.color`
  /// (Flutter 3.44.4 packages/flutter/lib/src/material/text_field.dart,
  /// `_m3StateInputStyle`), so a dark-mode field painted #1D1B20 on its
  /// #2A2A2B fill: 1.17 : 1, an invisible value.
  ///
  /// Applying the scheme's `onSurface` here is what makes the scale
  /// brightness-aware — the same correction the git palette got when it became
  /// a per-brightness extension — and it keeps the SDK's disabled derivation
  /// intact, because that derivation is this colour at 38 %.
  static TextTheme _brightnessCorrectedTextTheme(ThemeData theme) {
    return theme.textTheme.apply(
      bodyColor: theme.colorScheme.onSurface,
      displayColor: theme.colorScheme.onSurface,
    );
  }

  /// The chip theme with a label colour that follows the chip's own state.
  ///
  /// `RawChip` *replaces* the Material 3 default label style with the theme's
  /// whenever the theme carries one (Flutter 3.44.4
  /// packages/flutter/lib/src/material/chip.dart:1367, `chipTheme.labelStyle
  /// ?? chipDefaults.labelStyle!`), and `FlexSubThemesData` always carries
  /// one, with a single flat colour. That silently dropped the per-state role
  /// `_FilterChipDefaultsM3.labelStyle` resolves (filter_chip.dart:332-337):
  /// a selected chip kept the unselected `onSurfaceVariant` label while its
  /// container had already turned `secondaryContainer`, which measures
  /// 2.86 : 1 in the dark theme.
  ///
  /// The colour is resolved per state instead, which `RawChip` supports
  /// (chip.dart:1376 resolves `labelStyle.color` against the chip's states).
  /// The resting colour is left exactly as the sub-theme had it, and so is the
  /// disabled one: whether a disabled chip should follow M3's `onSurface` at
  /// 38 % is a separate decision from this one, and making it here would
  /// change a state that is not at fault.
  ///
  /// `secondaryLabelStyle` carries the same selected colour, because a
  /// *single-choice* chip never reaches the resolver above: `ChoiceChip` hands
  /// `RawChip` the theme's `secondaryLabelStyle` outright while selected
  /// (choice_chip.dart:230), so leaving it alone would have fixed the filter
  /// chips and left the choice chips at 4.45 : 1 — the two sit side by side in
  /// the same dialogs.
  static ChipThemeData _stateAwareChipTheme(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? configured = theme.chipTheme.labelStyle;
    final Color resting = configured?.color ?? colors.onSurfaceVariant;
    final Color selected = readableForeground(
      preferred: colors.onSecondaryContainer,
      background: colors.secondaryContainer,
      // `secondaryContainer` is an opaque scheme role, so it composites to
      // itself and the base only has to be named, not chosen.
      backgroundBase: colors.surface,
    );
    final TextStyle base =
        configured ?? theme.textTheme.labelLarge ?? const TextStyle();
    return theme.chipTheme.copyWith(
      labelStyle: base.copyWith(
        color: WidgetStateColor.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return resting;
          }
          return states.contains(WidgetState.selected) ? selected : resting;
        }),
      ),
      secondaryLabelStyle: (theme.chipTheme.secondaryLabelStyle ?? base)
          .copyWith(color: selected),
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
  ///
  /// ## The rule this helper states
  ///
  /// **Nothing handed to `copyWith` above may be a freshly constructed
  /// sub-theme.** Every sub-theme applied to the built theme has to be layered
  /// onto the one [FlexThemeData] produced, and there are exactly two ways to
  /// do that:
  ///
  ///   * a `ButtonStyle` layers with `merge`, which is this helper, because the
  ///     app builds a whole style with `…Button.styleFrom` and needs it in
  ///     front of the configured one; and
  ///   * a `…ThemeData` layers with **its own** `copyWith` on the built
  ///     instance — `theme.dialogTheme.copyWith(…)` rather than
  ///     `DialogThemeData(…)` — which composes the same way round: the named
  ///     arguments are the app's explicit choice and every field they omit is
  ///     the configured value, kept.
  ///
  /// The distinction is only in the spelling; the rule is one rule. It was
  /// broken twice, for four sub-themes in #399 and for three more in #416, in
  /// both cases by writing the constructor form, and both times the loss was
  /// silent because a discarded token has no symptom until someone measures
  /// it.
  ///
  /// ## How the rule is enforced rather than merely stated
  ///
  /// Reading a value back off the built `ThemeData` is *not* enough on its own:
  /// a substituted sub-theme that happens to hard-code the same numbers reads
  /// back identically. So the three `…ThemeData` layers are written as the
  /// named methods below — [layeredPopupMenuTheme], [layeredDialogTheme] and
  /// [layeredTextSelectionTheme] — and `theme_token_reach_test.dart` drives
  /// those methods with a *probe* [FlexSubThemesData] whose elevations and
  /// corners are values no literal in this file could coincide with. A layered
  /// method carries the probe values out; a substituting one carries this
  /// file's own constants out and fails there by name.
  static ButtonStyle _layerOn(ButtonStyle addition, ButtonStyle? base) {
    return base == null ? addition : addition.merge(base);
  }

  /// The menu sub-theme, layered onto the one [FlexColorScheme] built for
  /// [configured] rather than substituted for it (see [_layerOn] for the rule).
  ///
  /// What the substitution used to discard is the configured menu elevation
  /// ([elevationLevel2]), which is also Material 3's own popup elevation
  /// (Flutter 3.44.4 packages/flutter/lib/src/material/popup_menu.dart:1839,
  /// `_PopupMenuDefaultsM3`), so the menu was already painting that number as
  /// an SDK fallback and letting it through moves nothing on screen.
  @visibleForTesting
  static PopupMenuThemeData layeredPopupMenuTheme(ThemeData configured) {
    return configured.popupMenuTheme.copyWith(
      textStyle: configured.textTheme.bodyMedium?.copyWith(
        color: configured.colorScheme.onSurface,
      ),
    );
  }

  /// The dialog sub-theme, layered onto the one [FlexColorScheme] built for
  /// [configured] rather than substituted for it.
  ///
  /// This is the sub-theme with the most to lose: the wholesale replacement
  /// discarded the configured dialog background (`surfaceContainerHigh`),
  /// elevation ([elevationLevel3]), corner ([radiusL]) and action-row padding
  /// all at once. None of the four changes a pixel. The background, the
  /// elevation and the padding are the values Material 3 resolves anyway when
  /// the theme says nothing (Flutter 3.44.4
  /// packages/flutter/lib/src/material/dialog.dart:1962-1998,
  /// `_DialogDefaultsM3`), and the corner is the one `BaseDialog` and
  /// `BaseViewerDialog` already pin on the widget, where a widget value beats a
  /// theme value (registered DLG-001). What changes is only that the dialog
  /// surface is now *described* by this theme instead of falling back to the
  /// SDK.
  ///
  /// That has one consequence outside this file, and it is the reason this
  /// method is worth naming. `Dialog` and `AlertDialog` read `dialogTheme`
  /// **before** `_DialogDefaultsM3` (dialog.dart:290-297 and :886), so every
  /// field returned here is a field a stock `AlertDialog` pumped under this
  /// theme reports as if it were the specification. The two dialog conformance
  /// suites therefore pin exactly these seven tokens from `_DialogDefaultsM3`
  /// instead of pumping an oracle for them, and
  /// `base_dialog_conformance_test.dart` carries a guard that fails if this
  /// method ever starts returning an eighth.
  @visibleForTesting
  static DialogThemeData layeredDialogTheme(ThemeData configured) {
    return configured.dialogTheme.copyWith(
      titleTextStyle: configured.textTheme.titleLarge?.copyWith(
        color: configured.colorScheme.onSurface,
      ),
      contentTextStyle: configured.textTheme.bodyMedium?.copyWith(
        color: configured.colorScheme.onSurface,
      ),
      iconColor: configured.colorScheme.primary,
    );
  }

  /// The text-selection sub-theme, layered onto the one [FlexColorScheme] built
  /// for [configured] rather than substituted for it.
  ///
  /// `TextSelectionThemeData` holds exactly three fields and all three are
  /// named here, so this particular layering is **provably inert today**: the
  /// constructor form would produce a byte-identical result, and no test can
  /// tell the two apart. It is written this way anyway so the rule has no
  /// exception to argue from — the day the SDK adds a fourth field, or
  /// [FlexSubThemesData] starts configuring one, it arrives instead of
  /// vanishing. `theme_token_reach_test.dart` asserts the exhaustiveness rather
  /// than the layering, and fails the moment that premise stops holding.
  ///
  /// The one thing the layering direction *does* decide here is which side wins
  /// where both speak: [FlexSubThemesData] tints the dark theme's selection at
  /// 50 %, and the app's 30 % stays in front of it.
  @visibleForTesting
  static TextSelectionThemeData layeredTextSelectionTheme(
    ThemeData configured,
  ) {
    final Color primary = configured.colorScheme.primary;
    return configured.textSelectionTheme.copyWith(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.3),
      selectionHandleColor: primary,
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
  /// deviation is recorded in
  /// packages/gitui_skin_material/docs/deviation_register.yaml with the M3
  /// value noted inline below. The other settings derive from medium via
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
