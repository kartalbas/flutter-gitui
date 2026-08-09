import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import '../../generated/app_localizations.dart';

import '../components/base_label.dart';
import '../components/base_button.dart';
import '../components/base_layout.dart';
import '../theme/app_theme.dart';

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

  /// What the state MEANS, worn by the hero mark - `EmptyStateSpec.tone`,
  /// mirrored on the facade.
  ///
  /// A meaning rather than a colour, and the one appearance question a call
  /// site still gets to answer: the member owns the hero's size and its
  /// colour WORDS, but "there is nothing here yet" ([Tone.muted], the
  /// default) and "this could not be loaded" ([Tone.danger]) are different
  /// statements, and the mark is where the difference is loudest (#431). A
  /// real error state that adopted the always-muted hero would have misstated
  /// itself, which is exactly what kept the hand-rolled failure columns alive
  /// until the tone existed.
  final Tone tone;

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
    this.tone = Tone.muted,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.actions,
  }) : // `identical` rather than `==`, for the reason BaseLabel records: Tone
       // carries a custom `==`, a const constructor may only use primitive
       // equality, and every named tone is a const singleton.
       assert(
         identical(tone, Tone.muted) || identical(tone, Tone.danger),
         'The empty-state hero can currently say exactly two things: '
         'Tone.muted ("there is nothing here yet") and Tone.danger ("this '
         'failed"). This facade quotes one Material colour word per meaning '
         'below, so a third meaning must be added there and in both skins\' '
         'emptyState members deliberately - never silently painted as the '
         'nearest of these two.',
       );

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
            // and the colour WORDS leave together when `surfaces.emptyState`
            // owns both; what a call site states is only [tone], and the two
            // colour words written here are Material's answers to the two
            // meanings the hero can carry — the supporting foreground for
            // muted, the scheme's error role for danger (#431) — quoted once
            // here instead of at every state, exactly as the 64 is.
            Icon(
              icon,
              size: _heroGlyph,
              color: identical(tone, Tone.danger)
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
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

/// A mark over one sentence, standing in for a single PANE's content.
///
/// The in-panel sibling of [EmptyStateWidget], and what separates them is
/// scale rather than decoration. The hero above stands in place of a whole
/// REGION: a 64 dp mark with a `pageTitle` above its sentence. This note
/// stands inside a panel that its own header already names, so it is half that
/// mark and carries no headline at all — and that difference is not a nuance,
/// it is precisely why four of these stayed hand-rolled through two conversion
/// passes (#430). Adopting the hero would have doubled each mark and promoted
/// each sentence out of `body` into a slot it does not belong in, which is
/// rounding a meaning onto the nearest available word — the mistake that cost
/// #426.
///
/// [tone] is the one thing a call site says, and it says it once: "there is
/// nothing here" ([Tone.muted]) or "this could not be loaded" ([Tone.danger]).
/// It reaches the sentence as a tone through [BaseLabel]; it reaches the mark
/// as this member's own quotation of Material's answer to it, for the reason
/// the hero above records in the same words — a tone reaches a glyph only
/// through `BaseIcon`, whose three `ControlScale` rungs top out at 24 dp while
/// this mark is 32. Stating that quotation ONCE here is the whole point: the
/// four call sites that adopted this had each stated it themselves, and each
/// had written a paragraph explaining why it had to.
///
/// The size and the two colour words leave together when P5 gives the in-panel
/// note a member of its own, exactly as [EmptyStateWidget]'s do.
class PanelNote extends StatelessWidget {
  const PanelNote({
    super.key,
    required this.icon,
    required this.message,
    this.tone = Tone.muted,
  }) : // `identical` rather than `==`, for the reason BaseLabel records: Tone
       // carries a custom `==`, a const constructor may only use primitive
       // equality, and every named tone is a const singleton.
       assert(
         identical(tone, Tone.muted) || identical(tone, Tone.danger),
         'The in-panel note can say exactly two things: Tone.muted ("there is '
         'nothing here") and Tone.danger ("this failed"). Like the hero above '
         'it, this member quotes one Material colour word per meaning, so a '
         'third meaning must be added here and in both skins\' members '
         'deliberately — never silently painted as the nearer of these two.',
       );

  /// The glyph. An `IconData` rather than an `IconRole` for the same reason
  /// [EmptyStateWidget] takes one: the role would have to arrive at `BaseIcon`
  /// to mean anything, and `BaseIcon` cannot draw this size.
  final IconData icon;

  /// The one sentence. There is no headline slot, by design — see above.
  final String message;

  /// What the note MEANS. Worn by the mark and by the sentence together.
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppTheme.iconXL,
            color: identical(tone, Tone.danger)
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          // The mark and the sentence under it are members of one statement:
          // `grouped`. The hero above says `separate` at the same boundary
          // because its two parts are a mark and a HEADLINE; here there is one
          // statement in two pieces, and the smaller distance is the meaning.
          const BaseGap(Proximity.grouped),
          BaseLabel(message, role: TextRole.body, tone: tone),
        ],
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
      // A failure is not an emptiness. Until the hero carried a tone this
      // state drew its mark in the supporting foreground like every other
      // adopter, which dressed "this went wrong" as "there is nothing here" -
      // the exact misstatement that kept the hand-rolled error columns from
      // adopting the facade at all (#431).
      tone: Tone.danger,
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
