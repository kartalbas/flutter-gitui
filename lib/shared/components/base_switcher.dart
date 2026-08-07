import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../../core/config/app_config.dart';

/// Base switcher widget with consistent styling for workspace, repository, and branch switchers
///
/// The switcher takes its natural width when unconstrained. Under a tighter
/// max-width constraint it keeps its icon, border and dropdown affordance and
/// ellipsizes the label instead of overflowing; the tooltip carries the full
/// text.
class BaseSwitcher extends StatelessWidget {
  const BaseSwitcher({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.showDropdown = false,
    this.onTap,
  });

  /// The narrowest width a switcher can be squeezed to before its fixed
  /// chrome would overflow: 1+1 border, 16+16 padding, 16 icon, 8+8 gaps and
  /// the 16 dropdown arrow come to 82, plus room for the ellipsis to start.
  /// A width-limited container of switchers (the toolbar) must not constrain
  /// one below this.
  static const double minShrunkWidth = 90;

  final IconData icon;
  final String label;
  final String tooltip;
  final bool showDropdown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Check animation speed setting
    final animationSpeed =
        Theme.of(context).extension<AnimationSpeedExtension>()?.speed ??
        AppAnimationSpeed.normal;
    final disableAnimations = animationSpeed == AppAnimationSpeed.none;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      splashColor: disableAnimations
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0)
          : null,
      highlightColor: disableAnimations
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0)
          : null,
      hoverColor: disableAnimations
          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0)
          : null,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingM,
            vertical: AppTheme.paddingS,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppTheme.iconS,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.paddingS),
              // Flexible, so a width-constrained switcher shrinks its label
              // (ellipsized) rather than overflowing; when unconstrained the
              // loose fit leaves the natural width untouched.
              Flexible(
                child: BodyMediumLabel(
                  label,
                  color: Theme.of(context).colorScheme.onSurface,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showDropdown) ...[
                const SizedBox(width: AppTheme.paddingS),
                Icon(
                  Icons.arrow_drop_down,
                  size: AppTheme.iconS,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
