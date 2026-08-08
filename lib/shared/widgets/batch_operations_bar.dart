import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
import '../components/base_button.dart';

/// Standardized batch operations bar for multi-selection
///
/// Appears at bottom of screen when items are selected.
/// Provides consistent UI for batch operations across all screens.
///
/// Example usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: AppBar(title: Text('Tags')),
///     body: _buildTagList(),
///     bottomNavigationBar: _selectedTags.isNotEmpty
///         ? BatchOperationsBar(
///             selectedCount: _selectedTags.length,
///             onClear: () => setState(() => _selectedTags.clear()),
///             actions: [
///               BatchAction(
///                 label: l10n.push,
///                 icon: IconRole.upload,
///                 onPressed: () => _pushSelectedTags(),
///                 enabled: _canPushSelected(),
///               ),
///               BatchAction(
///                 label: l10n.delete,
///                 icon: IconRole.trash,
///                 onPressed: () => _deleteSelectedTags(),
///                 isDestructive: true,
///               ),
///             ],
///           )
///         : null,
///   );
/// }
/// ```
class BatchOperationsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final List<BatchAction> actions;

  const BatchOperationsBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      // The bar is a region of its own along the bottom edge, so it owes its
      // controls the ordinary reading distance from its own edges.
      child: BaseInset(
        all: Inset.normal,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Selected count
              const BaseIcon(IconRole.checkSquare, tone: Tone.accent),
              // The mark and the count it introduces are two halves of one
              // statement.
              const BaseGap(Proximity.related),
              // "N selected" is prose that has to stand out from the prose
              // beside it, and the explicit bold was this call site answering
              // that question with Material's weight. `TextRole.emphasis` asks
              // the question instead: this language answers with a semibold,
              // and a language that answers with a fill behind the words is
              // equally right.
              BaseLabel(
                l10n.selectedCount(selectedCount),
                role: TextRole.emphasis,
                tone: Tone.accent,
              ),

              const Spacer(),

              // Action buttons. Each one's leading padding was the space
              // between it and the action before it wearing a padding idiom,
              // and it is the only thing the two branches differed by - so the
              // space is stated once here, between neighbours, and the button
              // is written once.
              for (final action in actions) ...[
                // Two commands of one batch, side by side.
                const BaseGap(Proximity.related),
                BaseButton(
                  label: action.label,
                  variant: action.isDestructive
                      ? ButtonVariant.dangerSecondary
                      : ButtonVariant.secondary,
                  leadingIcon: action.icon,
                  onPressed: action.enabled ? action.onPressed : null,
                ),
              ],

              // The batch actions and the way out of the selection.
              const BaseGap(Proximity.related),

              // Clear selection
              BaseButton(
                label: l10n.clearSelection,
                variant: ButtonVariant.tertiary,
                leadingIcon: IconRole.x,
                onPressed: onClear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Represents a single batch action button
class BatchAction {
  final String label;

  /// The meaning of the action's mark; the skin chooses the glyph.
  final IconRole icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool isDestructive;

  const BatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.isDestructive = false,
  });
}
