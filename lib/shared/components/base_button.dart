// This file is the design system's sanctioned wrapper around the Material
// button widgets: every other file must use BaseButton, and the design-system
// lint bans the raw widgets app-wide so keyboard focus, state layers and tap
// targets cannot be hand-rolled twice. Building the wrapper ON the real
// Material buttons is the point of the component, so the bans are lifted for
// this file only (precedent: base_dialog.dart, base_text_field.dart).
// ignore_for_file: avoid_filled_button, avoid_outlined_button, avoid_text_button, avoid_icon_button

import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Button visual variants
enum ButtonVariant {
  /// Filled with primary color - for primary actions
  primary,

  /// Outlined with secondary color - for secondary actions
  secondary,

  /// Text only, subtle - for tertiary actions
  tertiary,

  /// Red/destructive color - for dangerous actions
  danger,

  /// Transparent, hover only - for minimal actions
  ghost,

  /// Green/success color - for positive actions (git bisect good, success states)
  success,

  /// Red outlined - for destructive secondary actions
  dangerSecondary,
}

/// Button size variants
enum ButtonSize {
  /// Compact, for tight spaces
  small,

  /// Default size
  medium,

  /// Prominent actions
  large,
}

/// Base button component for all button patterns in the app.
///
/// Built on the Material 3 button classes — [FilledButton], [OutlinedButton]
/// and [TextButton] — so every button is keyboard-operable out of the box:
/// Tab reaches it, a focus state layer marks it, and Enter and Space activate
/// it. Divergences from the M3 defaults are registered in
/// packages/gitui_skin_material/docs/deviation_register.yaml
/// (BTN-001..BTN-006) and asserted by
/// packages/gitui_skin_material/test/conformance/components/base_button_conformance_test.dart.
///
/// ## Size Standards
/// Sizes describe the visual container; every size sits inside a >= 48 dp
/// hit area via the padded tap target, so a compact button never shrinks the
/// touch target.
/// - **Small**: 32 dp container (BTN-002), labelMedium text (BTN-003),
///   16 dp icons (BTN-004) — dense rows and banners
/// - **Medium**: the stock M3 button — 40 dp container, labelLarge text,
///   18 dp icons (default)
/// - **Large**: 48 dp container (BTN-005), labelLarge text, 18 dp icons —
///   hero and empty-state actions
///
/// All sizes share the 8 dp control corner (BTN-001) instead of the M3
/// stadium shape. That corner is not written here: it comes from the
/// `filledButtonRadius` / `outlinedButtonRadius` / `textButtonRadius` tokens
/// the app theme configures (lib/shared/theme/app_theme.dart), which are in
/// turn one rung of the `AppTheme.radius*` corner scale. Editing that scale
/// therefore changes what this component renders.
///
/// ## Variant Standards
/// - **Primary**: filled, primary/onPrimary - for primary actions
/// - **Secondary**: outlined, primary label with outline border - for
///   secondary actions
/// - **Tertiary**: the M3 text button, primary label - for tertiary actions
/// - **Danger**: filled, error/onError - for destructive confirms
/// - **Ghost**: text button with a neutral onSurface label (BTN-006) - for
///   chrome-less repeated actions; unlike tertiary it must not read as a link
/// - **Success**: filled with the git semantic green - for positive actions
///   (git bisect good)
/// - **DangerSecondary**: outlined with error label and border - for
///   destructive secondary actions; the border falls back to the M3 disabled
///   treatment so the error tint never survives into disabled
///
/// ## Icon Guidelines
/// - Use leading icons for actions (check, plus, arrow)
/// - Use trailing icons for navigation/expansion (arrowRight, caretDown)
/// - Icons are automatically sized and colored by the button style
///
/// Example usage:
/// ```dart
/// // Primary action with leading icon
/// BaseButton(
///   label: 'Commit Changes',
///   variant: ButtonVariant.primary,
///   size: ButtonSize.medium,
///   leadingIcon: PhosphorIconsRegular.check,
///   onPressed: () => commitChanges(),
/// )
///
/// // Destructive action
/// BaseButton(
///   label: 'Discard All',
///   variant: ButtonVariant.danger,
///   leadingIcon: PhosphorIconsRegular.trash,
///   onPressed: () => discardAll(),
/// )
///
/// // Loading state
/// BaseButton(
///   label: 'Saving...',
///   variant: ButtonVariant.primary,
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// Button text label
  final String label;

  /// Visual variant (primary, secondary, tertiary, danger, ghost)
  final ButtonVariant variant;

  /// Size variant (small, medium, large)
  final ButtonSize size;

  /// Leading icon (optional)
  final IconData? leadingIcon;

  /// Trailing icon (optional)
  final IconData? trailingIcon;

  /// Whether button is in loading state (shows spinner)
  final bool isLoading;

  /// Whether button is disabled
  final bool isDisabled;

  /// Whether button should expand to full width
  final bool fullWidth;

  /// The variant's colors, expressed through the concrete class's
  /// `styleFrom` so the state layers derive from the right foreground with
  /// the M3 opacities (pressed/focused 10%, hovered 8%).
  ///
  /// Every variant shares the M3 disabled treatment (onSurface at 38% for
  /// the foreground, at 12% for filled containers and outlined borders), so
  /// no semantic tint survives into disabled.
  ButtonStyle _variantStyle(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color disabledForeground = colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final Color disabledContainer = colorScheme.onSurface.withValues(
      alpha: 0.12,
    );

    switch (variant) {
      case ButtonVariant.primary:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.danger:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.success:
        final Color added = context.gitColors.added;
        return FilledButton.styleFrom(
          backgroundColor: added,
          foregroundColor: GitSemanticColors.foregroundOn(added),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.secondary:
        // The border is deliberately not pinned: the M3 default side already
        // does the right thing per state (outline enabled, primary focused,
        // onSurface at 12% disabled).
        return OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.dangerSecondary:
        return OutlinedButton.styleFrom(
          foregroundColor: colorScheme.error,
          disabledForegroundColor: disabledForeground,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: disabledContainer);
            }
            return BorderSide(color: colorScheme.error);
          }),
        );
      case ButtonVariant.tertiary:
        return TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.ghost:
        // BTN-006: neutral onSurface instead of the M3 primary, so the
        // chrome-less variant does not read as a link.
        return TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  /// The button content. Text carries no style and icons carry no size or
  /// color: the button style's DefaultTextStyle and IconTheme supply them,
  /// so label, spinner and both icons always match the resolved foreground.
  Widget _content(BuildContext context, double iconSize) {
    final Widget labelText = Text(label);
    final bool hasTrailing = trailingIcon != null && !isLoading;
    if (!isLoading && leadingIcon == null && !hasTrailing) {
      return labelText;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppTheme.paddingS,
      children: [
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // While loading the button is disabled, so the spinner paints
              // in the M3 disabled foreground like the rest of the content.
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          )
        else if (leadingIcon != null)
          Icon(leadingIcon),
        labelText,
        if (hasTrailing) Icon(trailingIcon),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isEffectivelyDisabled =
        isDisabled || isLoading || onPressed == null;
    final VoidCallback? effectiveOnPressed = isEffectivelyDisabled
        ? null
        : onPressed;

    // Per-size metrics. Medium is the stock M3 button; small and large are
    // the registered desktop sizes (BTN-002..BTN-005). Where padding is
    // null the framework's scaled padding applies.
    final (
      TextStyle? labelStyle,
      double iconSize,
      Size minimumSize,
      EdgeInsetsGeometry? padding,
    ) = switch (size) {
      // BTN-002 container, BTN-003 label, BTN-004 icon; the 48 dp minimum
      // width keeps even a one-character small button a full hit target.
      ButtonSize.small => (
        textTheme.labelMedium,
        AppTheme.iconS,
        const Size(48, 32),
        const EdgeInsets.symmetric(horizontal: AppTheme.paddingM),
      ),
      ButtonSize.medium => (
        textTheme.labelLarge,
        18.0,
        const Size(64, 40),
        null,
      ),
      // BTN-005 container.
      ButtonSize.large => (
        textTheme.labelLarge,
        18.0,
        const Size(64, 48),
        null,
      ),
    };

    // Every property this component *owns* is pinned at the widget so
    // conformance stays deterministic: the app theme's bodyLarge button text
    // style and its comfortable visual density are size decisions this
    // component makes per size, and neither may leak in. The padded tap
    // target plus standard density guarantee the >= 48 dp hit area around
    // every container size.
    //
    // `shape` is deliberately NOT among them. It is the one measured property
    // the theme owns: `ButtonStyleButton` resolves widget style before
    // `themeStyleOf`, so any widget-level shape makes the corner unreachable
    // from the theme forever — which is exactly how the configured
    // `filledButtonRadius` / `outlinedButtonRadius` / `textButtonRadius`
    // tokens (app_theme.dart) came to govern nothing. Leaving the slot empty
    // hands the control corner to those tokens.
    //
    // BTN-001 does not weaken by moving: the conformance suite measures the
    // corner this component actually RENDERS under the real app theme and
    // compares it against the M3 stadium oracle, so the 8 dp stays a
    // registered, asserted deviation. Should the token ever stop arriving,
    // the button would fall back to the stadium, and `expectConformant`
    // would fail the entry as a stale deviation rather than pass quietly.
    final ButtonStyle style = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(labelStyle),
      iconSize: WidgetStatePropertyAll<double>(iconSize),
      minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
      padding: padding == null
          ? null
          : WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_variantStyle(context));

    final Widget child = _content(context, iconSize);

    final Widget button = switch (_baseOf(variant)) {
      _MaterialBase.filled => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      _MaterialBase.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      _MaterialBase.text => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };

    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// The three Material button families the variants map onto: filled is
/// FilledButton / IconButton.filled, outlined is OutlinedButton /
/// IconButton.outlined, text is TextButton / the standard IconButton.
enum _MaterialBase { filled, outlined, text }

/// The Material button family a variant renders through, shared by
/// [BaseButton] and [BaseIconButton] so the two components can never map the
/// same variant onto different emphasis levels.
_MaterialBase _baseOf(ButtonVariant variant) {
  switch (variant) {
    case ButtonVariant.primary:
    case ButtonVariant.danger:
    case ButtonVariant.success:
      return _MaterialBase.filled;
    case ButtonVariant.secondary:
    case ButtonVariant.dangerSecondary:
      return _MaterialBase.outlined;
    case ButtonVariant.tertiary:
    case ButtonVariant.ghost:
      return _MaterialBase.text;
  }
}

/// Icon-only button component for compact spaces.
///
/// Built on the Material 3 icon button constructors — [IconButton],
/// [IconButton.filled] and [IconButton.outlined] — so every icon action is
/// keyboard-operable out of the box: Tab reaches it, a focus state layer
/// marks it, and Enter and Space activate it. Divergences from the M3
/// defaults are registered in
/// packages/gitui_skin_material/docs/deviation_register.yaml
/// (ICO-001..ICO-005) and asserted by
/// packages/gitui_skin_material/test/conformance/components/base_icon_button_conformance_test.dart.
///
/// ## Size Standards
/// Sizes describe the visual container; every size sits inside a >= 48 dp
/// hit area via the padded tap target, so a compact button never shrinks
/// the touch target.
/// - **Small**: 32 dp container (ICO-002), 16 dp icon (ICO-003) — dense
///   rows and toolbars
/// - **Medium**: 40 dp container, 20 dp icon (ICO-004) (default)
/// - **Large**: 48 dp container (ICO-005), 24 dp icon
///
/// All sizes share the 8 dp control corner (ICO-001) instead of the M3
/// stadium shape — the same corner [BaseButton] takes from the theme, but
/// named here as a constant because no icon-button radius token exists to
/// carry it (see the `shape` comment in `build`).
///
/// ## Variant Standards
/// - **Primary**: filled, primary/onPrimary - for affirmative icon actions
/// - **Secondary**: outlined, stock onSurfaceVariant icon with the outline
///   border - for emphasized toolbar actions
/// - **Tertiary / Ghost**: the standard chrome-less M3 icon button with the
///   stock onSurfaceVariant icon - for toolbars and repeated row actions
/// - **Danger**: filled, error/onError - for destructive icon actions
/// - **Success**: filled with the git semantic green - for positive actions
/// - **DangerSecondary**: outlined with error icon and border - the border
///   falls back to the M3 disabled treatment so the error tint never
///   survives into disabled
///
/// ## Usage Guidelines
/// - Always provide a tooltip: it is the hover name of the action and the
///   semantic label the labeled-tap-target guideline requires
/// - Use ghost variant (default) for toolbar buttons
/// - Use danger variant for destructive icon actions
/// - Use primary variant for affirmative icon actions
///
/// Example usage:
/// ```dart
/// // Toolbar button
/// BaseIconButton(
///   icon: PhosphorIconsRegular.trash,
///   tooltip: 'Delete',
///   variant: ButtonVariant.ghost,
///   onPressed: () => deleteItem(),
/// )
///
/// // Destructive action
/// BaseIconButton(
///   icon: PhosphorIconsRegular.x,
///   tooltip: 'Remove',
///   variant: ButtonVariant.danger,
///   size: ButtonSize.small,
///   onPressed: () => removeItem(),
/// )
/// ```
class BaseIconButton extends StatelessWidget {
  const BaseIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.variant = ButtonVariant.ghost,
    this.size = ButtonSize.medium,
    this.isDisabled = false,
    this.isSelected,
  });

  /// Callback when button is pressed (null if disabled)
  final VoidCallback? onPressed;

  /// Icon to display
  final IconData icon;

  /// Tooltip text (optional)
  final String? tooltip;

  /// Visual variant
  final ButtonVariant variant;

  /// Size variant
  final ButtonSize size;

  /// Whether button is disabled
  final bool isDisabled;

  /// Marks a toggle-style button's state, mirroring [IconButton.isSelected]:
  /// null (the default) is a plain action button with no selected state,
  /// false a toggle that is currently off, and true a toggle that is on
  /// (e.g. a favorited star). While selected the glyph adopts the primary
  /// role — the Base layer's selected treatment — without changing the
  /// button chrome. Ignored while disabled, because the selected tint must
  /// never survive into the disabled treatment.
  final bool? isSelected;

  /// The variant's colors, expressed through [IconButton.styleFrom] so the
  /// state layers derive from the right foreground with the M3 opacities
  /// (pressed/focused 10%, hovered 8%).
  ///
  /// Every variant shares the M3 disabled treatment (onSurface at 38% for
  /// the foreground, at 12% for filled containers and outlined borders), so
  /// no semantic tint survives into disabled.
  ButtonStyle _variantStyle(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color disabledForeground = colorScheme.onSurface.withValues(
      alpha: 0.38,
    );
    final Color disabledContainer = colorScheme.onSurface.withValues(
      alpha: 0.12,
    );

    switch (variant) {
      case ButtonVariant.primary:
        return IconButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.danger:
        return IconButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.success:
        final Color added = context.gitColors.added;
        return IconButton.styleFrom(
          backgroundColor: added,
          foregroundColor: GitSemanticColors.foregroundOn(added),
          disabledBackgroundColor: disabledContainer,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.secondary:
        // The border is deliberately not pinned: the M3 default side of the
        // outlined icon button already does the right thing per state
        // (outline enabled, onSurface at 12% disabled).
        return IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor: disabledForeground,
        );
      case ButtonVariant.dangerSecondary:
        return IconButton.styleFrom(
          foregroundColor: colorScheme.error,
          disabledForegroundColor: disabledForeground,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: disabledContainer);
            }
            return BorderSide(color: colorScheme.error);
          }),
        );
      case ButtonVariant.tertiary:
      case ButtonVariant.ghost:
        // The stock standard icon button: chrome-less, onSurfaceVariant.
        // Both variants collapse onto it because an icon-only control has
        // no label to carry the text button's tertiary emphasis.
        return IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor: disabledForeground,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEffectivelyDisabled = isDisabled || onPressed == null;
    final VoidCallback? effectiveOnPressed = isEffectivelyDisabled
        ? null
        : onPressed;

    // Per-size metrics. Medium is the stock M3 container; small and large
    // are the registered desktop sizes (ICO-002..ICO-005). The container is
    // the glyph plus the stock 8 dp padding, clamped up by the minimum size,
    // so 16+16 = 32 exactly and 20/24 sit centered in 40/48.
    final (double containerSize, double iconSize) = switch (size) {
      // ICO-002 container, ICO-003 icon.
      ButtonSize.small => (32.0, AppTheme.iconS),
      // ICO-004 icon.
      ButtonSize.medium => (40.0, AppTheme.iconM),
      // ICO-005 container.
      ButtonSize.large => (48.0, AppTheme.iconL),
    };

    // Every measured property is pinned at the widget so conformance stays
    // deterministic regardless of icon-button sub-themes or the ambient
    // IconTheme. The padded tap target plus standard density guarantee the
    // >= 48 dp hit area around every container size.
    ButtonStyle style = ButtonStyle(
      iconSize: WidgetStatePropertyAll<double>(iconSize),
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(containerSize)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(AppTheme.paddingS),
      ),
      // ICO-001: the shared control corner instead of the M3 stadium.
      //
      // Unlike [BaseButton], which lets the theme own its corner, this one
      // has to name the constant: `FlexSubThemesData` exposes a radius token
      // for every button family EXCEPT the icon button (there is no
      // `iconButtonRadius`), so no configured token can reach an
      // `IconButton`. Reading the same rung of the corner scale the theme's
      // button radii are configured from is what keeps the two components on
      // one corner; `theme_token_reach_test.dart` asserts they still agree,
      // so this constant cannot drift away from the tokens unnoticed.
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    ).merge(_variantStyle(context));

    if (isSelected ?? false) {
      // The selected treatment recolors the glyph only: the state layers
      // keep deriving from the variant foreground, and the disabled
      // treatment always wins, so the selected tint never survives into
      // disabled.
      final ColorScheme colorScheme = Theme.of(context).colorScheme;
      final Color disabledForeground = colorScheme.onSurface.withValues(
        alpha: 0.38,
      );
      style = style.copyWith(
        iconColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledForeground;
          }
          return colorScheme.primary;
        }),
      );
    }

    // The icon carries no size or color: the style's IconTheme applies both.
    // isSelected passes through so the framework's native toggle support
    // maintains WidgetState.selected and the selected semantics.
    return switch (_baseOf(variant)) {
      _MaterialBase.filled => IconButton.filled(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
      _MaterialBase.outlined => IconButton.outlined(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
      _MaterialBase.text => IconButton(
        onPressed: effectiveOnPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        isSelected: isSelected,
        style: style,
      ),
    };
  }
}
