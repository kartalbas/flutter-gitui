import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_menu_item.dart';
import '../components/base_switcher.dart';
import '../components/base_dialog.dart';
import '../components/base_button.dart';
import '../components/base_label.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../../core/services/notification_service.dart';
import '../../features/branches/dialogs/delete_branch_dialog.dart';
import '../../features/branches/dialogs/rename_branch_dialog.dart';
import '../../core/config/app_config.dart';

/// Branch switcher widget - displays current branch and allows switching
class BranchSwitcher extends ConsumerWidget {
  const BranchSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranchAsync = ref.watch(currentBranchProvider);
    final localBranchesAsync = ref.watch(localBranchesProvider);
    final gitService = ref.watch(gitServiceProvider);

    // Only show if there's an active repository
    if (gitService == null) {
      return const SizedBox.shrink();
    }

    final branchName = currentBranchAsync.when(
      data: (branch) {
        if (branch != null) return branch;
        final l10n = AppLocalizations.of(context)!;
        return l10n.noBranchAvailable;
      },
      loading: () => 'Loading...',
      error: (_, _) => 'Error',
    );

    final branches = localBranchesAsync.value ?? [];

    return BaseSwitcher(
      icon: PhosphorIconsBold.gitBranch,
      label: branchName,
      tooltip: branches.length > 1
          ? AppLocalizations.of(context)!.tooltipSwitchBranch
          : branchName,
      showDropdown: branches.length > 1,
      onTap: branches.length > 1
          ? () => _showBranchMenu(context, ref, branches)
          : null,
    );
  }

  void _showBranchMenu(BuildContext context, WidgetRef ref, List<GitBranch> branches) {
    final l10n = AppLocalizations.of(context)!;

    // Check animation speed setting
    final animationSpeed = Theme.of(context).extension<AnimationSpeedExtension>()?.speed ?? AppAnimationSpeed.normal;

    // Sort branches: protected branches first, then by name
    final sortedBranches = List<GitBranch>.from(branches)..sort((a, b) {
      // Protected branches come first
      if (a.isProtected && !b.isProtected) return -1;
      if (!a.isProtected && b.isProtected) return 1;
      // Within same protection level, sort alphabetically
      return a.name.compareTo(b.name);
    });

    // Check if there are any deletable branches (non-current, non-protected)
    final hasDeletableBranches = sortedBranches.any((b) => !b.isCurrent && !b.isProtected);

    final menuItems = <PopupMenuEntry<dynamic>>[
      // Branch items
      ...sortedBranches.map((branch) {
        final isSelected = branch.isCurrent;
        return PopupMenuItem<GitBranch>(
          value: branch,
          child: Row(
            children: [
              Expanded(
                child: MenuItemContentTwoLine(
                  icon: PhosphorIconsBold.gitBranch,
                  primaryLabel: branch.name,
                  secondaryLabel: branch.lastCommitMessage,
                  iconColor: Theme.of(context).colorScheme.primary,
                  isSelected: isSelected,
                  showCheck: true,
                  iconSize: AppTheme.iconS,
                  spacing: AppTheme.paddingM,
                ),
              ),
              // Protected branch lock icon
              if (branch.isProtected)
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.paddingS),
                  child: Icon(
                    PhosphorIconsRegular.lock,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              // Action buttons (disabled for protected branches)
              if (!branch.isProtected)
                BaseIconButton(
                  icon: PhosphorIconsRegular.pencilSimple,
                  tooltip: l10n.renameBranch(branch.name),
                  size: ButtonSize.small,
                  onPressed: () {
                    Navigator.of(context).pop(); // Close menu
                    _showRenameBranchDialog(context, ref, branch);
                  },
                ),
              if (!isSelected && !branch.isProtected) // Only show delete for non-current, non-protected branches
                BaseIconButton(
                  icon: PhosphorIconsRegular.trash,
                  tooltip: l10n.deleteBranch,
                  size: ButtonSize.small,
                  onPressed: () {
                    Navigator.of(context).pop(); // Close menu
                    _showDeleteBranchDialog(context, ref, branch);
                  },
                ),
            ],
          ),
        );
      }),
      // Add separator and "Delete all except protected" option if there are deletable branches
      if (hasDeletableBranches) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete_all_unprotected',
          child: MenuItemContent(
            icon: PhosphorIconsRegular.trash,
            label: l10n.deleteAllUnprotectedBranches,
            iconColor: Theme.of(context).colorScheme.error,
            labelColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ];

    // Show menu with animation duration adapted to settings
    final menuFuture = showMenu<dynamic>(
      context: context,
      position: _getMenuPosition(context),
      items: menuItems,
      popUpAnimationStyle: AnimationStyle(
        duration: AppTheme.getStandardAnimation(animationSpeed),
      ),
    );

    menuFuture.then((result) {
      if (!context.mounted) return;

      if (result is GitBranch && !result.isCurrent) {
        _switchBranch(context, ref, result);
      } else if (result == 'delete_all_unprotected') {
        _showDeleteAllUnprotectedDialog(context, ref, sortedBranches);
      }
    });
  }

  Future<void> _switchBranch(BuildContext context, WidgetRef ref, GitBranch branch) async {
    try {
      await ref.read(gitActionsProvider).switchBranch(
            branch.name,
            createIfMissing: false,
          );
    } catch (e) {
      if (!context.mounted) return;
      NotificationService.showError(
        context,
        'Failed to switch branch: $e',
      );
    }
  }

  Future<void> _showDeleteBranchDialog(BuildContext context, WidgetRef ref, GitBranch branch) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteBranchDialog(branch: branch),
    );
    // Dialog returns true if delete was confirmed
    if (result == true && context.mounted) {
      try {
        await ref.read(gitActionsProvider).deleteBranch(branch.name);
        if (!context.mounted) return;
        NotificationService.showSuccess(
          context,
          'Branch "${branch.name}" deleted',
        );
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Failed to delete branch: $e',
        );
      }
    }
  }

  Future<void> _showRenameBranchDialog(BuildContext context, WidgetRef ref, GitBranch branch) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => RenameBranchDialog(branch: branch),
    );
    // Dialog returns new branch name if rename was confirmed
    if (result != null && context.mounted) {
      try {
        await ref.read(gitActionsProvider).renameBranch(
              result,
              oldName: branch.name,
            );
        if (!context.mounted) return;
        NotificationService.showSuccess(
          context,
          'Branch "${branch.name}" renamed to "$result"',
        );
      } catch (e) {
        if (!context.mounted) return;
        NotificationService.showError(
          context,
          'Failed to rename branch: $e',
        );
      }
    }
  }

  Future<void> _showDeleteAllUnprotectedDialog(BuildContext context, WidgetRef ref, List<GitBranch> branches) async {
    // Get list of deletable branches
    final deletableBranches = branches.where((b) => !b.isCurrent && !b.isProtected).toList();

    if (deletableBranches.isEmpty) return;

    final result = await showDialog<_BulkDeleteResult>(
      context: context,
      builder: (context) => _BulkDeleteBranchesDialog(branches: deletableBranches),
    );

    if (result != null && result.selectedBranches.isNotEmpty && context.mounted) {
      await _deleteAllUnprotectedBranches(context, ref, result.selectedBranches, force: result.force);
    }
  }

  Future<void> _deleteAllUnprotectedBranches(
    BuildContext context,
    WidgetRef ref,
    List<GitBranch> branches, {
    bool force = false,
  }) async {
    int successCount = 0;
    int failCount = 0;
    final errors = <String>[];

    for (final branch in branches) {
      try {
        await ref.read(gitActionsProvider).deleteBranch(branch.name, force: force);
        successCount++;
      } catch (e) {
        failCount++;
        errors.add('${branch.name}: $e');
      }
    }

    if (!context.mounted) return;

    // Show summary notification
    if (failCount == 0) {
      NotificationService.showSuccess(
        context,
        'Successfully deleted $successCount branch${successCount == 1 ? '' : 'es'}',
      );
    } else if (successCount == 0) {
      NotificationService.showError(
        context,
        'Failed to delete all branches:\n${errors.join('\n')}',
      );
    } else {
      NotificationService.showWarning(
        context,
        'Deleted $successCount branch${successCount == 1 ? '' : 'es'}, but $failCount failed:\n${errors.join('\n')}',
      );
    }
  }

  RelativeRect _getMenuPosition(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay);

    // Position menu below the button by using bottomLeft instead of topLeft
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        Offset(topLeft.dx, bottomRight.dy), // Start from bottom-left of button
        bottomRight,
      ),
      Offset.zero & overlay.size,
    );
    return position;
  }
}

/// Result from bulk delete dialog
class _BulkDeleteResult {
  final List<GitBranch> selectedBranches;
  final bool force;

  _BulkDeleteResult({
    required this.selectedBranches,
    required this.force,
  });
}

/// Dialog for bulk deleting branches with checkboxes
class _BulkDeleteBranchesDialog extends StatefulWidget {
  final List<GitBranch> branches;

  const _BulkDeleteBranchesDialog({required this.branches});

  @override
  State<_BulkDeleteBranchesDialog> createState() => _BulkDeleteBranchesDialogState();
}

class _BulkDeleteBranchesDialogState extends State<_BulkDeleteBranchesDialog> {
  late Map<String, bool> _selectedBranches;

  @override
  void initState() {
    super.initState();
    // Initialize all branches as checked
    _selectedBranches = {
      for (var branch in widget.branches) branch.name: true,
    };
  }

  int get _selectedCount => _selectedBranches.values.where((selected) => selected).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return BaseDialog(
      title: l10n.deleteAllUnprotectedBranches,
      icon: PhosphorIconsRegular.trash,
      variant: DialogVariant.destructive,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyMediumLabel(
            'Select branches to delete ($_selectedCount selected)',
          ),
          const SizedBox(height: AppTheme.paddingS),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: widget.branches.map((branch) {
                  final isMerged = _isBranchMerged(branch);
                  return CheckboxListTile(
                    value: _selectedBranches[branch.name] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedBranches[branch.name] = value ?? false;
                      });
                    },
                    title: Row(
                      children: [
                        Expanded(
                          child: BodyMediumLabel(branch.name),
                        ),
                        if (isMerged)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingXS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.gitAdded.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: BodySmallLabel(
                              'merged',
                              color: AppTheme.gitAdded,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingXS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: BodySmallLabel(
                              'unmerged',
                              color: colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        BaseButton(
          label: 'Delete Selected',
          variant: ButtonVariant.danger,
          onPressed: _selectedCount > 0 ? () => _deleteSelected(force: false) : null,
        ),
        BaseButton(
          label: 'Force Delete Selected',
          variant: ButtonVariant.danger,
          onPressed: _selectedCount > 0 ? () => _deleteSelected(force: true) : null,
        ),
      ],
    );
  }

  bool _isBranchMerged(GitBranch branch) {
    // Simple heuristic: if branch has upstream and is not behind, it's likely merged
    // This is a visual indicator only, not a git merge check
    if (branch.hasUpstream && branch.behindBy != null) {
      return branch.behindBy == 0 && (branch.aheadBy == null || branch.aheadBy == 0);
    }
    // If no tracking info, assume not merged
    return false;
  }

  void _deleteSelected({required bool force}) {
    final selectedBranches = widget.branches
        .where((branch) => _selectedBranches[branch.name] == true)
        .toList();

    Navigator.of(context).pop(_BulkDeleteResult(
      selectedBranches: selectedBranches,
      force: force,
    ));
  }
}
