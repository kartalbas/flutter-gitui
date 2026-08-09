import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show TextRole;
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          // The switcher's internal distances stay LITERALS, deliberately,
          // and this is a CONTRACT FINDING rather than an unconverted site:
          // this control is one hand-painted unit - its fill, border and
          // corner are stated right above as Material's own numbers - and its
          // inset and gaps are that unit's anatomy, so they leave together
          // when the switcher becomes a member (`controls` owes it one; the
          // toolbar's width arithmetic in overflow_action_bar.dart is the
          // same §1 residue with the same P5 home). Resolving the distances
          // through the skin while the box stayed hand-painted was tried and
          // taken back at closing, on the review pass's own precedent
          // ("returned to literals rather than staying rounded onto rungs
          // that moved their pixels"): under the blueprint the collapsed
          // insets widened the toolbar's overflow bar by three actions and
          // made the scene sweep's skin-independent register skin-DEPENDENT,
          // and at DISTANCE=64 the stretched gaps overflowed this very Row -
          // a T2 failure the resting gates never see.
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingM,
            vertical: AppTheme.paddingS,
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
                child: BaseLabel(label, role: TextRole.body, maxLines: 1),
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
