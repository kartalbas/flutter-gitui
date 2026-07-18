import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/merge_conflict.dart';
import '../../shared/components/base_button.dart';
import '../../shared/components/base_menu_item.dart';
import '../../shared/components/base_list_item.dart';
import '../../shared/components/base_dialog.dart';
import '../../shared/components/base_label.dart';

/// Screen for resolving merge conflicts
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  MergeConflict? _selectedConflict;
  bool _isResolving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final mergeState = ref.watch(mergeStateProvider).value;

    if (mergeState == null || !mergeState.isInProgress) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.mergeConflicts),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.checkCircle,
                size: 64,
                color: AppTheme.gitAdded,
              ),
              const SizedBox(height: AppTheme.paddingL),
              TitleLargeLabel(
                AppLocalizations.of(context)!.dialogTitleNoMergeInProgress,
              ),
            ],
          ),
        ),
      );
    }

    final conflicts = mergeState.conflicts;
    final selectedIndex = _selectedConflict != null
        ? conflicts.indexOf(_selectedConflict!)
        : (conflicts.isNotEmpty ? 0 : -1);

    if (selectedIndex >= 0 && _selectedConflict == null) {
      _selectedConflict = conflicts[selectedIndex];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(
            context,
          )!.dialogTitleResolveConflicts(mergeState.mergingBranch ?? "branch"),
        ),
        actions: [
          // Abort merge button
          BaseIconButton(
            icon: PhosphorIconsRegular.xCircle,
            onPressed: _isResolving ? null : () => _showAbortDialog(context),
            tooltip: AppLocalizations.of(context)!.tooltipAbortMerge,
          ),
          const SizedBox(width: AppTheme.paddingS),
        ],
      ),
      body: conflicts.isEmpty
          ? _buildNoConflicts(context, mergeState)
          : Row(
              children: [
                // Conflict list (left panel)
                SizedBox(
                  width: 300,
                  child: _buildConflictList(context, conflicts, selectedIndex),
                ),
                const VerticalDivider(width: 1),

                // Conflict details (right panel)
                Expanded(
                  child: _selectedConflict != null
                      ? _buildConflictDetails(context, _selectedConflict!)
                      : Center(
                          child: BodyMediumLabel(
                            AppLocalizations.of(
                              context,
                            )!.dialogContentSelectConflict,
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar:
          mergeState.unresolvedCount == 0 && conflicts.isNotEmpty
          ? _buildContinueBar(context, mergeState)
          : null,
    );
  }

  Widget _buildConflictList(
    BuildContext context,
    List<MergeConflict> conflicts,
    int selectedIndex,
  ) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.warning, size: 20),
              const SizedBox(width: AppTheme.paddingS),
              Expanded(
                child: TitleSmallLabel(
                  AppLocalizations.of(context)!.conflictsToResolve(
                    conflicts.where((c) => !c.isResolved).length,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Conflict list
        Expanded(
          child: ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              final isSelected = index == selectedIndex;

              return BaseListItem(
                isSelected: isSelected,
                leading: Icon(
                  conflict.isResolved
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.fileText,
                  color: conflict.isResolved
                      ? AppTheme.gitAdded
                      : AppTheme.gitModified,
                ),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conflict.fileName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        decoration: conflict.isResolved
                            ? TextDecoration.lineThrough
                            : null,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    BodySmallLabel(conflict.typeDisplay),
                  ],
                ),
                trailing: conflict.isResolved
                    ? const Icon(
                        PhosphorIconsRegular.check,
                        color: AppTheme.gitAdded,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _selectedConflict = conflict;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConflictDetails(BuildContext context, MergeConflict conflict) {
    return Column(
      children: [
        // File header
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.fileText),
              const SizedBox(width: AppTheme.paddingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleSmallLabel(conflict.filePath),
                    BodySmallLabel(conflict.typeDisplay),
                  ],
                ),
              ),
              if (conflict.isResolved) ...[
                Icon(
                  PhosphorIconsRegular.checkCircle,
                  color: AppTheme.gitAdded,
                ),
                const SizedBox(width: AppTheme.paddingS),
                LabelMediumLabel(AppLocalizations.of(context)!.resolved),
              ],
            ],
          ),
        ),

        // Resolution options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.paddingM),
                    margin: const EdgeInsets.only(bottom: AppTheme.paddingM),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.warningCircle,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                        Expanded(
                          child: BodyMediumLabel(
                            _errorMessage!,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                TitleMediumLabel(
                  AppLocalizations.of(
                    context,
                  )!.dialogContentChooseResolutionStrategy,
                ),
                const SizedBox(height: AppTheme.paddingM),

                // Accept Ours
                _buildResolutionButton(
                  context,
                  title: AppLocalizations.of(context)!.acceptOurs,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.useVersionFromCurrentBranch,
                  icon: PhosphorIconsRegular.arrowLeft,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () =>
                      _resolveConflict(conflict, ResolutionChoice.ours),
                ),
                const SizedBox(height: AppTheme.paddingM),

                // Accept Theirs
                _buildResolutionButton(
                  context,
                  title: AppLocalizations.of(context)!.acceptTheirs,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.useVersionFromMergingBranch,
                  icon: PhosphorIconsRegular.arrowRight,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () =>
                      _resolveConflict(conflict, ResolutionChoice.theirs),
                ),
                const SizedBox(height: AppTheme.paddingM),

                // Accept Both (if applicable)
                if (conflict.type == ConflictType.bothAdded ||
                    conflict.type == ConflictType.bothModified) ...[
                  _buildResolutionButton(
                    context,
                    title: AppLocalizations.of(context)!.acceptBoth,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.keepBothVersionsConcatenated,
                    icon: PhosphorIconsRegular.arrowsLeftRight,
                    color: Theme.of(context).colorScheme.tertiary,
                    onPressed: () =>
                        _resolveConflict(conflict, ResolutionChoice.both),
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                ],

                // Manual resolution info
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(PhosphorIconsRegular.info, size: 20),
                          const SizedBox(width: AppTheme.paddingS),
                          TitleSmallLabel(
                            AppLocalizations.of(context)!.manualResolution,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.paddingS),
                      BodySmallLabel(
                        AppLocalizations.of(
                          context,
                        )!.dialogContentManualResolutionInfo,
                      ),
                    ],
                  ),
                ),

                if (_isResolving) ...[
                  const SizedBox(height: AppTheme.paddingL),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: AppTheme.paddingS),
                  Center(
                    child: Text(
                      AppLocalizations.of(context)!.resolvingConflict,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final isEnabled = !_isResolving;
    final effectiveColor = isEnabled ? color : color.withValues(alpha: 0.38);

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            border: Border.all(color: effectiveColor),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Icon(icon, color: effectiveColor),
              const SizedBox(width: AppTheme.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MenuItemLabel(
                      title,
                      fontWeight: FontWeight.bold,
                      color: effectiveColor,
                    ),
                    BodySmallLabel(subtitle),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.arrowRight, color: effectiveColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoConflicts(BuildContext context, MergeState mergeState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.checkCircle,
              size: 64,
              color: AppTheme.gitAdded,
            ),
            const SizedBox(height: AppTheme.paddingL),
            HeadlineMediumLabel(
              AppLocalizations.of(context)!.allConflictsResolved,
            ),
            const SizedBox(height: AppTheme.paddingM),
            BodyLargeLabel(
              AppLocalizations.of(
                context,
              )!.dialogContentAllMergeConflictsResolved,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingXL),
            BaseButton(
              label: AppLocalizations.of(context)!.continueMerge,
              variant: ButtonVariant.primary,
              leadingIcon: PhosphorIconsRegular.check,
              onPressed: () => _continueMerge(context),
            ),
            const SizedBox(height: AppTheme.paddingM),
            BaseButton(
              label: AppLocalizations.of(context)!.abortMerge,
              variant: ButtonVariant.tertiary,
              leadingIcon: PhosphorIconsRegular.xCircle,
              onPressed: () => _showAbortDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueBar(BuildContext context, MergeState mergeState) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: AppTheme.gitAdded.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.checkCircle,
            color: AppTheme.gitAdded,
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleSmallLabel(
                  AppLocalizations.of(context)!.allConflictsResolved,
                ),
                BodySmallLabel(
                  AppLocalizations.of(context)!.readyToContinueMerge,
                ),
              ],
            ),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.continueMerge,
            variant: ButtonVariant.primary,
            leadingIcon: PhosphorIconsRegular.check,
            onPressed: () => _continueMerge(context),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveConflict(
    MergeConflict conflict,
    ResolutionChoice choice,
  ) async {
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(gitActionsProvider)
          .resolveConflict(conflict.filePath, choice: choice);

      if (mounted) {
        setState(() {
          _isResolving = false;
          // Update selected conflict to show it's resolved
          _selectedConflict = conflict.copyWith(
            isResolved: true,
            resolutionChoice: choice,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToResolveConflict(e.toString());
          _isResolving = false;
        });
      }
    }
  }

  Future<void> _continueMerge(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.gitMerge,
        title: AppLocalizations.of(context)!.dialogTitleContinueMerge,
        content: BodyMediumLabel(
          AppLocalizations.of(context)!.dialogContentContinueMerge,
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.dialogActionContinue,
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(gitActionsProvider).continueMerge();

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToContinueMerge(e.toString());
        });
      }
    }
  }

  Future<void> _showAbortDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BaseDialog(
        icon: PhosphorIconsRegular.warning,
        title: AppLocalizations.of(context)!.dialogTitleAbortMerge,
        content: BodyMediumLabel(
          AppLocalizations.of(context)!.dialogContentAbortMerge,
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.cancel,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          BaseButton(
            label: AppLocalizations.of(context)!.dialogTitleAbortMerge,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(gitActionsProvider).abortMerge();

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.snackbarMergeAborted),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          )!.dialogContentFailedToAbortMerge(e.toString());
        });
      }
    }
  }
}
