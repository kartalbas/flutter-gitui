import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../generated/app_localizations.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';

/// Reusable empty state widget for displaying empty states throughout the app
///
/// Supports structured actions to enforce FilledButton pattern.
/// Use actionLabel/onActionPressed for single action, or actions list for multiple.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  // Legacy support - deprecated, use structured actions instead
  final Widget? action;

  // Structured single action (preferred)
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;

  // Multiple structured actions
  final List<EmptyStateAction>? actions;

  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.actions,
    this.iconSize = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    // Build action widget based on provided parameters
    Widget? actionWidget;

    if (actionLabel != null && onActionPressed != null) {
      // Structured single action - always BaseButton primary
      actionWidget = BaseButton(
        onPressed: onActionPressed,
        leadingIcon: actionIcon ?? PhosphorIconsRegular.plus,
        label: actionLabel!,
        variant: ButtonVariant.primary,
      );
    } else if (actions != null && actions!.isNotEmpty) {
      // Multiple structured actions
      actionWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: actions!.map((emptyStateAction) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.paddingS),
            child: BaseButton(
              onPressed: emptyStateAction.onPressed,
              leadingIcon: emptyStateAction.icon,
              label: emptyStateAction.label,
              variant: emptyStateAction.isPrimary
                  ? ButtonVariant.primary
                  : ButtonVariant.secondary,
            ),
          );
        }).toList(),
      );
    } else if (action != null) {
      // Legacy widget support (backward compatibility)
      actionWidget = action;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.paddingL),
            TitleLargeLabel(
              title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              message,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
            if (actionWidget != null) ...[
              const SizedBox(height: AppTheme.paddingL),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }
}

/// Pre-configured empty state for when no repository is open
class NoRepositoryEmptyState extends StatelessWidget {
  final String? contextMessage;
  final Widget? action;

  const NoRepositoryEmptyState({
    super.key,
    this.contextMessage,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.folderOpen,
      title: l10n.noRepositoryOpen,
      message: contextMessage ?? l10n.openRepositoryToContinue,
      action: action,
    );
  }
}

/// Pre-configured empty state for empty lists
class EmptyListState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyListState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: icon,
      title: title,
      message: message,
      action: action,
    );
  }
}

/// Pre-configured error state
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: l10n.error(message),
      message: '',
      action: onRetry != null
          ? BaseButton(
              onPressed: onRetry!,
              leadingIcon: PhosphorIconsRegular.arrowClockwise,
              label: l10n.retry,
              variant: ButtonVariant.primary,
            )
          : null,
    );
  }
}

/// Pre-configured loading state
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppTheme.paddingL),
            BodyMediumLabel(message!),
          ],
        ],
      ),
    );
  }
}

/// Structured action for empty states
///
/// Enforces FilledButton for primary actions, OutlinedButton for secondary.
/// Ensures consistent button styling across all empty states.
class EmptyStateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}
