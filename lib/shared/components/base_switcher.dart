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
        // `Ink`, not `Container`, and that is a repair rather than a
        // refactor. An `InkWell`'s hover, focus and press layers are painted
        // by the nearest `Material` ANCESTOR, underneath everything the well
        // wraps - so an opaque fill drawn by a `Container` inside the well
        // covers them completely. Every switcher in the toolbar therefore had
        // no visible state layer at all: the corner above rounded a ripple
        // nobody could see. `Ink` paints the same fill, border and corner on
        // that same Material canvas, which puts the well's layers back on
        // top; at rest it is pixel-identical, which is why nothing but the
        // hover, focus and press states changes.
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          // The switcher's internal distances stay LITERALS, deliberately, and
          // so do the two corners above: this control is one hand-painted unit
          // - its fill, border and corner are stated right above as Material's
          // own numbers - and its inset and gaps are that unit's anatomy, so
          // they leave together when the switcher becomes a member. WHICH
          // member is settled rather than owed, and the earlier note here
          // ("`controls` owes it one") named the wrong facet: the contract
          // already carries this control as `ToolbarPickerEntry` on
          // `ShellSpec.toolbar`, whose own doc names these four by name - "the
          // four switchers - workspace, repository, branch, global branch -
          // are not actions" - and carries them as DATA precisely because a
          // pre-built control cannot become `MacosPulldownButton` or a
          // `CommandBarBuilderItem`. `chrome.shell` draws it, which is also
          // where the toolbar's width arithmetic in overflow_action_bar.dart
          // goes, so the two are one wait and not two. Resolving the distances
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
