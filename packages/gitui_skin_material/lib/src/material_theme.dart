import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart';

import 'material_ink.dart';

/// The theme factory: `AppTheme.lightTheme` and `AppTheme.darkTheme`, moved.
///
/// This file is the extraction of `lib/shared/theme/app_theme.dart`'s
/// `FlexThemeData` factory into `chrome.wrapRoot`, exactly as
/// `docs/SKIN-CONTRACT.md` §5.3 specifies. Every sub-theme, every radius rung
/// and every layering rule below was moved from that file, together with the
/// comments that record why each one is the way it is - those comments are the
/// record of defects already paid for, and this repository has re-introduced a
/// defect once by dropping one.
///
/// **What the extraction translates rather than copies** is only the input:
/// the application's `AppColorScheme` / `AppFontSize` / `AppAnimationSpeed`
/// configuration enums cannot be named here (a skin package never reaches back
/// into `lib/`), so the factory reads the contract's [SkinRequest] instead.
/// The mapping is exact: `accentSeed` indexes the same ten schemes in the same
/// declaration order, `textScale` is the same factor `AppTheme._fontSizeFactor`
/// resolved (0.85 / 0.92 / 1.0 / 1.10), and `animationScale` is the same
/// multiplier `AppTheme.getAnimationDuration` applied (0 / 0.7 / 1.0 / 1.5).
///
/// **What the extraction deliberately does not carry** are the two
/// `ThemeExtension`s the application's factory attaches:
///
///  * `GitSemanticColors` - the skin answers the same question from its own
///    [MaterialGitPalette], resolved per brightness, so the extension is a
///    duplicate the migration deletes rather than a value this theme misses;
///  * `AnimationSpeedExtension` - the whole point of `SkinRequest` is that the
///    application never reads a motion value again, so the skin carries the
///    request in [MaterialRequestScope] and resolves durations in
///    [MaterialMotionDurations] instead of publishing them through the theme.
///
/// Neither absence may be read as "the application's extensions stop at the
/// seam". A `ThemeData` carries its extensions, so installing this one below
/// the application root would drop whatever the application attached to its
/// own - and four widgets in `lib/` still read `AnimationSpeedExtension` for
/// the user's reduced-motion setting, which is an accessibility choice rather
/// than a look. The application re-publishes its own extensions inside the
/// content port (`_ApplicationThemeExtensions` in `lib/main.dart`) until those
/// four have members to move into. This factory takes no position on them
/// either way; it simply does not invent them.
abstract final class MaterialThemeFactory {
  /// The theme for [request], light or dark from its brightness.
  static ThemeData themeFor(SkinRequest request) =>
      request.brightness == Brightness.light ? _light(request) : _dark(request);

  static ThemeData _light(SkinRequest request) {
    final ThemeData theme = FlexThemeData.light(
      scheme: _scheme(request.accentSeed),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 9,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        blendOnColors: false,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        // Every radius below names a rung of this skin's corner scale
        // (MaterialMetrics.radiusXS .. radiusXL) rather than a bare literal,
        // so the scale stays the one place a corner is chosen. These tokens
        // are live: the button members take their corner from
        // `filledButtonRadius` / `outlinedButtonRadius` / `textButtonRadius`
        // and nothing else, so editing radiusM moves the buttons on screen.
        // `inputDecoratorRadius` is the exception - the input components
        // deliberately render radiusS instead (registered as the FIELD
        // deviations), and this value only reaches SDK-owned fields such as
        // the date picker's.
        defaultRadius: MaterialMetrics.radiusL,
        elevatedButtonRadius: MaterialMetrics.radiusM,
        filledButtonRadius: MaterialMetrics.radiusM,
        outlinedButtonRadius: MaterialMetrics.radiusM,
        textButtonRadius: MaterialMetrics.radiusM,
        inputDecoratorRadius: MaterialMetrics.radiusM,
        fabUseShape: true,
        fabRadius: MaterialMetrics.radiusXL,
        chipRadius: MaterialMetrics.radiusM,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      textTheme: _textTheme(request.uiFamily, request.textScale),
    );
    return _finish(theme, request);
  }

  static ThemeData _dark(SkinRequest request) {
    final ThemeData theme = FlexThemeData.dark(
      scheme: _scheme(request.accentSeed),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 8,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        // The same corner scale as the light theme; see the comment there.
        defaultRadius: MaterialMetrics.radiusL,
        elevatedButtonRadius: MaterialMetrics.radiusM,
        filledButtonRadius: MaterialMetrics.radiusM,
        outlinedButtonRadius: MaterialMetrics.radiusM,
        textButtonRadius: MaterialMetrics.radiusM,
        inputDecoratorRadius: MaterialMetrics.radiusM,
        fabUseShape: true,
        fabRadius: MaterialMetrics.radiusXL,
        chipRadius: MaterialMetrics.radiusM,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      textTheme: _textTheme(request.uiFamily, request.textScale),
    );
    return _finish(theme, request);
  }

  /// The application-level overrides on the built theme, identical between
  /// the two brightnesses, exactly as `AppTheme` applied them.
  static ThemeData _finish(ThemeData theme, SkinRequest request) {
    return theme.copyWith(
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
        // bodyLarge and recolour it - a restyling this app never chose.
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
      // The one measured divergence from `AppTheme`'s own map, and it is
      // deliberate: the application listed five platforms by hand and this
      // iterates `TargetPlatform.values`, so the skin also answers for
      // `TargetPlatform.fuchsia`. It cannot change what any user sees - the
      // application ships for Windows and Linux, and a target that is never
      // reached cannot render a transition - and covering the enum is what
      // stops the map going stale the next time the SDK adds a platform.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final TargetPlatform platform in TargetPlatform.values)
            platform: _pageTransition(request.animationScale),
        },
      ),
    );
  }

  /// The ten selectable schemes, in the declaration order the application's
  /// `AppColorScheme` has always used. [SkinRequest.accentSeed] is that
  /// enum's index carried as an opaque integer, so position is identity here
  /// and the order must never be re-sorted.
  static const List<FlexScheme> _schemes = <FlexScheme>[
    FlexScheme.deepPurple, // deepPurple
    FlexScheme.indigo, // indigo
    FlexScheme.blue, // blue
    FlexScheme.aquaBlue, // teal
    FlexScheme.green, // green
    FlexScheme.red, // red
    FlexScheme.rosewood, // pink
    FlexScheme.purpleBrown, // purple
    FlexScheme.deepOrangeM3, // deepOrange
    FlexScheme.blueWhale, // blueGrey
  ];

  static FlexScheme _scheme(int accentSeed) =>
      _schemes[accentSeed % _schemes.length];

  /// The type scale, recoloured for the brightness the theme is built for.
  ///
  /// The scale is built from a Google Fonts base theme, and that base theme
  /// carries a colour of its own: `#1D1B20`, which is Material 3's *light*
  /// `onSurface`. `ThemeData` merges a supplied `TextTheme` over
  /// `Typography.white` in a dark theme, so a non-null colour wins, and the
  /// dark type scale came out near-black.
  ///
  /// Almost nothing showed it, because almost everything that paints text here
  /// names its own colour. The exception is the one role the SDK reads
  /// straight off the scale: a `TextField` takes the colour of the text the
  /// user types from `textTheme.bodyLarge.color` (Flutter 3.44.4
  /// packages/flutter/lib/src/material/text_field.dart, `_m3StateInputStyle`),
  /// so a dark-mode field painted #1D1B20 on its #2A2A2B fill: 1.17 : 1, an
  /// invisible value.
  ///
  /// Applying the scheme's `onSurface` here is what makes the scale
  /// brightness-aware - the same correction the git palette got when it became
  /// per-brightness - and it keeps the SDK's disabled derivation intact,
  /// because that derivation is this colour at 38 %.
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
  /// chips and left the choice chips at 4.45 : 1 - the two sit side by side in
  /// the same dialogs.
  static ChipThemeData _stateAwareChipTheme(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? configured = theme.chipTheme.labelStyle;
    final Color resting = configured?.color ?? colors.onSurfaceVariant;
    final Color selected = _readableForeground(
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

  /// Layers this skin's own [addition] on top of the sub-theme
  /// `FlexColorScheme` already built, instead of replacing it.
  ///
  /// This exists because `ThemeData.copyWith` *substitutes* a sub-theme: a
  /// bare `copyWith(textButtonTheme: TextButtonThemeData(style: ...))` throws
  /// away everything `FlexSubThemesData` configured for text buttons -
  /// including the corner radius - and the tokens above would silently reach
  /// no widget at all. `ButtonStyle.merge` is the composing operation: the
  /// receiver's non-null fields win and the argument only fills the gaps, so
  /// passing [addition] as the receiver keeps the explicit choice in front
  /// while every token it says nothing about survives.
  ///
  /// ## The rule this helper states
  ///
  /// **Nothing handed to `copyWith` above may be a freshly constructed
  /// sub-theme.** Every sub-theme applied to the built theme has to be layered
  /// onto the one `FlexThemeData` produced: a `ButtonStyle` layers with
  /// `merge` (this helper), and a `...ThemeData` layers with **its own**
  /// `copyWith` on the built instance - `theme.dialogTheme.copyWith(...)`
  /// rather than `DialogThemeData(...)`. The rule was broken twice in the
  /// application, for four sub-themes in #399 and for three more in #416, in
  /// both cases by writing the constructor form, and both times the loss was
  /// silent because a discarded token has no symptom until someone measures
  /// it. The named `layered*` methods below keep the layering testable the
  /// same way `theme_token_reach_test.dart` tests the application's copies.
  static ButtonStyle _layerOn(ButtonStyle addition, ButtonStyle? base) {
    return base == null ? addition : addition.merge(base);
  }

  /// The menu sub-theme, layered onto the one `FlexColorScheme` built for
  /// [configured] rather than substituted for it (see [_layerOn] for the
  /// rule).
  ///
  /// What the substitution used to discard is the configured menu elevation,
  /// which is also Material 3's own popup elevation (Flutter 3.44.4
  /// packages/flutter/lib/src/material/popup_menu.dart:1839,
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

  /// The dialog sub-theme, layered onto the one `FlexColorScheme` built for
  /// [configured] rather than substituted for it.
  ///
  /// This is the sub-theme with the most to lose: the wholesale replacement
  /// discarded the configured dialog background (`surfaceContainerHigh`),
  /// elevation, corner and action-row padding all at once. None of the four
  /// changes a pixel - the background, the elevation and the padding are the
  /// values Material 3 resolves anyway when the theme says nothing (Flutter
  /// 3.44.4 packages/flutter/lib/src/material/dialog.dart:1962-1998,
  /// `_DialogDefaultsM3`), and the corner is the one the dialog surface pins
  /// on the widget, where a widget value beats a theme value (registered
  /// DLG-001). What changes is only that the dialog surface is *described* by
  /// this theme instead of falling back to the SDK.
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

  /// The text-selection sub-theme, layered onto the one `FlexColorScheme`
  /// built for [configured] rather than substituted for it.
  ///
  /// `TextSelectionThemeData` holds exactly three fields and all three are
  /// named here, so this particular layering is provably inert today: the
  /// constructor form would produce a byte-identical result. It is written
  /// this way anyway so the rule has no exception to argue from - the day the
  /// SDK adds a fourth field, or `FlexSubThemesData` starts configuring one,
  /// it arrives instead of vanishing. The one thing the layering direction
  /// *does* decide here is which side wins where both speak:
  /// `FlexSubThemesData` tints the dark theme's selection at 50 %, and this
  /// skin's 30 % stays in front of it.
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

  /// Font features shared by every proportional text style.
  static const List<FontFeature> _textFontFeatures = <FontFeature>[
    FontFeature.enable('kern'), // Kerning for better spacing
    FontFeature.enable('liga'), // Standard ligatures
    FontFeature.enable('clig'), // Contextual ligatures
  ];

  /// Builds the type scale from a Google Fonts base theme.
  ///
  /// This is the single place this skin defines its type scale: all 15
  /// Material 3 text roles with distinct sizes, plus the letter spacing and
  /// line height of the Material 3 2021 English-like type ramp
  /// (`Typography.englishLike2021`).
  ///
  /// `size` is the font size at a text scale of 1.0 in logical pixels.
  /// Display, headline, title and body sizes are deliberately tuned below the
  /// phone-first Material 3 defaults for this dense desktop application;
  /// every deviation is recorded in `docs/deviation_register.yaml` with the
  /// M3 value noted inline below. The other settings derive from these via
  /// [scale], which is the same factor `AppTheme._fontSizeFactor` resolved
  /// per user setting (0.85 / 0.92 / 1.0 / 1.10).
  ///
  /// `tracking` (letter spacing in logical pixels) and `height` (line height
  /// as a multiple of the font size) are carried unchanged from the M3 ramp.
  /// They must be set explicitly: the Google Fonts base theme supplies only
  /// font family and colour - its letterSpacing and height are always null -
  /// so relying on it would drop the M3 metrics.
  static TextTheme _buildTextTheme(TextTheme baseTheme, double scale) {
    TextStyle? role(
      TextStyle? style, {
      required double size,
      required double tracking,
      required double height,
    }) {
      if (style == null) return null;
      return style.copyWith(
        fontSize: (size * scale).roundToDouble(),
        letterSpacing: tracking,
        height: height,
        fontFeatures: _textFontFeatures,
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

  /// The type scale for the user's interface family and text scale.
  static TextTheme _textTheme(String family, double scale) {
    TextTheme baseTheme;
    try {
      baseTheme = GoogleFonts.getTextTheme(family);
    } catch (_) {
      // Fall back to Inter when the asked-for family is not available, the
      // same fallback the application has always used.
      baseTheme = GoogleFonts.interTextTheme();
    }
    return _buildTextTheme(baseTheme, scale);
  }

  /// The page transition for the user's motion preference.
  ///
  /// A zero scale means "no motion", which the skin honours by resolving the
  /// transition to nothing rather than by animating quickly.
  static PageTransitionsBuilder _pageTransition(double animationScale) {
    if (animationScale == 0) {
      return const _NoAnimationPageTransitionsBuilder();
    }
    return const FadeUpwardsPageTransitionsBuilder();
  }

  /// The foreground to paint on [background] over [backgroundBase]: the
  /// preferred Material role whenever that pair clears WCAG 2.1 SC 1.4.3's
  /// 4.5 : 1, and otherwise the black or white that does.
  ///
  /// The extraction of `readableForeground` in `lib/shared/theme/contrast.dart`,
  /// which exists because of a defect class the component matrix kept
  /// producing: a selected state swaps the container for a tonal colour and
  /// the label stays on the role that was chosen against the *unselected*
  /// background. The fallback is not a second design decision - it is the
  /// same black-or-white rule [MaterialInk.foregroundOn] applies to a solid
  /// semantic colour, and it only ever takes over where the scheme's own
  /// on-role misses the threshold. In this skin's dark themes that happens on
  /// the selection containers, where `onSecondaryContainer` reaches 4.45 : 1 -
  /// close enough to look designed and still a failure.
  static Color _readableForeground({
    required Color preferred,
    required Color background,
    required Color backgroundBase,
  }) {
    // sRGB source-over, exactly what the compositor does: computeLuminance()
    // ignores alpha, so a translucent background must be flattened over the
    // colour painted behind it before it is measured, or the ratio describes
    // a colour nobody painted.
    final Color flat = Color.alphaBlend(background, backgroundBase);
    return _wcagContrast(preferred, flat) >= 4.5
        ? preferred
        : MaterialInk.foregroundOn(flat);
  }

  /// WCAG 2.x contrast ratio between two opaque colours - the same formula
  /// the conformance suite's contrast tests apply.
  static double _wcagContrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

/// A page transition that does not animate, for a motion preference of zero.
///
/// The extraction of the application's `NoAnimationPageTransitionsBuilder`.
class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

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

/// Where the user's request lives while this skin is drawing.
///
/// Installed once by `chrome.wrapRoot` and read from the tree by the facets
/// that need a per-user value the theme deliberately does not publish: the
/// motion facet resolves durations against `animationScale`, and the type
/// facet resolves `TextRole.code` against `monoFamily`. This replaces the
/// application's `AnimationSpeedExtension`, whose entire purpose was to make
/// a `Duration` readable by application code - the one thing the contract
/// exists to end.
final class MaterialRequestScope extends InheritedWidget {
  /// Installs [request] over [child].
  const MaterialRequestScope({
    super.key,
    required this.request,
    required super.child,
  });

  /// The user's choices, as the application stated them.
  final SkinRequest request;

  /// The request in force at [context], or null outside `wrapRoot` - which
  /// only a test that renders a facet without its root can arrange.
  static SkinRequest? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MaterialRequestScope>()
      ?.request;

  @override
  bool updateShouldNotify(covariant MaterialRequestScope oldWidget) =>
      oldWidget.request != request;
}

/// The one door a facet uses to turn a [TextRole] into a style.
///
/// [MaterialTypeScale] states the RAMP - which of Material's fifteen steps a
/// role lands on - and nothing else, because it lives beside the numbers and
/// has no way to reach the user's request. This adds the second half: the one
/// role whose FAMILY is the user's own choice rather than this skin's.
///
/// It exists as a separate door because the split was a live defect. The type
/// facet resolved the family itself, in a private helper, while
/// `surfaces.codeLine` and `surfaces.codeBlock` called the ramp directly - so
/// `type.text(role: code)` rendered in the family the user picked for diffs and
/// a diff line rendered in the proportional interface family, inside one skin,
/// for one role. Nothing showed it, because the surfaces that disagreed are not
/// wired to a call site yet; it would have arrived as "every diff loses its
/// column alignment" on the day P3 routed the diff viewer through the contract.
/// A single door is what makes that disagreement unrepresentable.
abstract final class MaterialTypeResolution {
  /// The style [role] takes under the theme and the request in force at
  /// [context].
  ///
  /// Every role but `code` is [MaterialTypeScale]'s answer unchanged. Code is
  /// special because the family is the user's choice - the application lets the
  /// user pick the diff font and carries it across the contract as
  /// [SkinRequest.monoFamily] - while the ramp step stays this skin's.
  static TextStyle? styleOf(BuildContext context, TextRole role) {
    final TextStyle? base = MaterialTypeScale.styleOf(context, role);
    if (role != TextRole.code || base == null) return base;
    final String? family = MaterialRequestScope.maybeOf(context)?.monoFamily;
    if (family == null || family.isEmpty) return base;
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } catch (_) {
      // An unknown family keeps the ramp's own monospace fallback rather than
      // failing the build - the same forgiveness the theme factory extends to
      // an unknown interface family.
      return base;
    }
  }
}

/// How this skin turns a [MotionRole] into a duration.
///
/// The three base durations are the application's own, moved: `AppTheme`
/// pinned them to the Material 3 duration tokens short3 / medium1 / medium3
/// (150 / 250 / 350 ms) and multiplied them by the user's animation-speed
/// setting (0 / 0.7 / 1.0 / 1.5). [SkinRequest.animationScale] is that same
/// multiplier carried across the contract, so the arithmetic below reproduces
/// `AppTheme.getQuickAnimation` / `getStandardAnimation` / `getSlowAnimation`
/// exactly for every value the application ever passed.
abstract final class MaterialMotionDurations {
  /// Quick - subtle feedback: hover effects, ripples. M3 short3.
  static const Duration _fast = Durations.short3; // 150 ms

  /// Standard - most transitions: dialogs, menus, modals. M3 medium1.
  static const Duration _normal = Durations.medium1; // 250 ms

  /// Slow - emphasised transitions: page changes, major state. M3 medium3.
  static const Duration _slow = Durations.medium3; // 350 ms

  /// The duration [role] takes at the user's [scale].
  ///
  /// [MotionRole.instant] is zero regardless of the scale, because "state
  /// that must be true before the user's eye arrives" is not a fast
  /// animation - it is no animation.
  static Duration of(MotionRole role, double scale) {
    final Duration base = switch (role) {
      MotionRole.instant => Duration.zero,
      MotionRole.feedback => _fast,
      MotionRole.transition => _normal,
      MotionRole.emphasis => _slow,
    };
    if (base == Duration.zero || scale == 0) return Duration.zero;
    return Duration(milliseconds: (base.inMilliseconds * scale).round());
  }

  /// The duration [role] takes under the request in force at [context].
  ///
  /// Falls back to a scale of 1.0 where no scope is installed, which renders
  /// the application's default speed rather than freezing or hiding motion.
  static Duration resolve(BuildContext context, MotionRole role) =>
      of(role, MaterialRequestScope.maybeOf(context)?.animationScale ?? 1.0);
}
