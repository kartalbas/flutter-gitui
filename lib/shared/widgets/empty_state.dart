import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import '../../generated/app_localizations.dart';

import '../components/base_label.dart';
import '../components/base_button.dart';
import '../components/base_layout.dart';

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

  /// The meaning of the single action's mark.
  final IconRole? actionIcon;

  // Multiple structured actions
  final List<EmptyStateAction>? actions;

  /// How large the hero mark is drawn.
  ///
  /// Deliberately a private constant rather than a parameter (#430). This is
  /// the facade that becomes `surfaces.emptyState`, and `EmptyStateSpec`
  /// carries icon, title, message and actions and NO size — a member that
  /// accepts no size owns the size, so a glyph size written at a call site is
  /// a leak by construction. It was a parameter with a default that no call
  /// site ever overrode, which is the leak sitting open rather than in use.
  ///
  /// The value moves into the skin in P5; until then it is Material's answer,
  /// unchanged, and it is stated once here instead of at every empty state.
  static const double _heroGlyph = 64.0;

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
  });

  @override
  Widget build(BuildContext context) {
    // Build action widget based on provided parameters
    Widget? actionWidget;

    if (actionLabel != null && onActionPressed != null) {
      // Structured single action - always BaseButton primary
      actionWidget = BaseButton(
        onPressed: onActionPressed,
        leadingIcon: actionIcon ?? IconRole.plus,
        label: actionLabel!,
        variant: ButtonVariant.primary,
      );
    } else if (actions != null && actions!.isNotEmpty) {
      // Multiple structured actions
      actionWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: actions!.map((emptyStateAction) {
          // Each way out of the empty state is set off from the one above it;
          // across, the button already owns its own width.
          return BaseInset(
            x: Inset.none,
            y: Inset.tight,
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
      // An empty state stands in place of a region's whole content, so it is
      // deliberately generous about how far it keeps from that region's edges.
      child: BaseInset(
        all: Inset.roomy,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left as a raw `Icon` deliberately, and it is the LAST thing in
            // this file that reads a Material role. `BaseIcon` cannot say it:
            // it takes an `IconRole` (this member is still handed an
            // `IconData` by every caller) at one of three `ControlScale`
            // rungs, whose largest is 24 dp. Naming the nearest rung would
            // shrink the hero mark from 64 dp to 24 — rounding a meaning onto
            // the nearest available word, which is what cost #426. The size
            // and the colour leave together when `surfaces.emptyState` owns
            // both; they are one decision and cannot be half-converted.
            Icon(
              icon,
              size: _heroGlyph,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            // The mark and the words it introduces are two groups of one
            // state, not two halves of one statement.
            const BaseGap(Proximity.separate),
            BaseLabel(title, role: TextRole.pageTitle, align: TextAlign.center),
            // The headline and the sentence explaining it are one statement.
            const BaseGap(Proximity.related),
            BaseLabel(
              message,
              role: TextRole.body,
              tone: Tone.muted,
              align: TextAlign.center,
            ),
            if (actionWidget != null) ...[
              // What the user can do about it is a different group from what
              // is being explained.
              const BaseGap(Proximity.separate),
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

  const NoRepositoryEmptyState({super.key, this.contextMessage, this.action});

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

  const ErrorState({super.key, required this.message, this.onRetry});

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
              leadingIcon: IconRole.arrowClockwise,
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
            // The spinner and what it is waiting for are two groups of one
            // state, matching the mark-and-headline rhythm above.
            const BaseGap(Proximity.separate),
            BaseLabel(message!, role: TextRole.body),
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

  /// The meaning of the action's mark; the skin chooses the glyph.
  final IconRole icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}
