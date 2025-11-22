import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';
import '../components/base_menu_item.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/branch.dart';
import '../../core/services/notification_service.dart';
import '../components/base_dialog.dart';
import '../components/base_list_item.dart';

/// Dialog for switching between git branches
class BranchSwitcherDialog extends ConsumerStatefulWidget {
  const BranchSwitcherDialog({super.key});

  @override
  ConsumerState<BranchSwitcherDialog> createState() =>
      _BranchSwitcherDialogState();
}

class _BranchSwitcherDialogState extends ConsumerState<BranchSwitcherDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showRemoteBranches = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localBranchesAsync = ref.watch(localBranchesProvider);
    final remoteBranchesAsync = ref.watch(remoteBranchesProvider);

    return BaseDialog(
      icon: PhosphorIconsBold.gitBranch,
      title: AppLocalizations.of(context)!.switchBranch,
      content: Column(
        children: [
          // Search field
          BaseTextField(
            controller: _searchController,
            autofocus: true,
            hintText: AppLocalizations.of(context)!.searchBranches,
            prefixIcon: PhosphorIconsRegular.magnifyingGlass,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: AppTheme.paddingM),

          // iOS-style toggle for remote branches
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  context,
                  label: AppLocalizations.of(context)!.localTab,
                  isSelected: !_showRemoteBranches,
                  onTap: () => setState(() => _showRemoteBranches = false),
                ),
                _buildToggleButton(
                  context,
                  label: AppLocalizations.of(context)!.remoteTab,
                  isSelected: _showRemoteBranches,
                  onTap: () => setState(() => _showRemoteBranches = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Branch list
          Expanded(
            child: localBranchesAsync.when(
              data: (localBranches) {
                final remoteBranches = _showRemoteBranches
                    ? (remoteBranchesAsync.value ?? [])
                    : <GitBranch>[];

                final allBranches = [...localBranches, ...remoteBranches];

                // Filter branches by search query
                final filteredBranches = allBranches.where((branch) {
                  if (_searchQuery.isEmpty) return true;
                  return branch.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
                }).toList();

                // Sort: current first, then by name
                filteredBranches.sort((a, b) {
                  if (a.isCurrent && !b.isCurrent) return -1;
                  if (!a.isCurrent && b.isCurrent) return 1;
                  return a.name.compareTo(b.name);
                });

                if (filteredBranches.isEmpty) {
                  return Center(
                    child: BodyLargeLabel(
                      AppLocalizations.of(context)!.noBranchesFound,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredBranches.length,
                  itemBuilder: (context, index) {
                    final branch = filteredBranches[index];
                    final isCurrent = branch.isCurrent;
                    final isRemote = branch.isRemote;

                    return BaseListItem(
                      isSelected: isCurrent,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Active indicator
                          SizedBox(
                            width: AppTheme.paddingL,
                            child: isCurrent
                                ? Icon(
                                    PhosphorIconsBold.check,
                                    size: AppTheme.iconS,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppTheme.paddingS),
                          // Remote indicator
                          if (isRemote)
                            Icon(
                              PhosphorIconsRegular.cloud,
                              size: AppTheme.paddingM,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BodyMediumLabel(branch.name),
                          if (branch.lastCommitMessage != null)
                            LabelMediumLabel(
                              branch.lastCommitMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Icon(
                        PhosphorIconsBold.gitBranch,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _switchBranch(branch),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: BodyMediumLabel(
                  AppLocalizations.of(
                    context,
                  )!.errorLoadingBranches(error.toString()),
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _switchBranch(GitBranch branch) async {
    // Don't switch if already on this branch
    if (branch.isCurrent) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    try {
      // Switch to the branch
      await ref
          .read(gitActionsProvider)
          .switchBranch(branch.name, createIfMissing: branch.isRemote);
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          AppLocalizations.of(context)!.failedToSwitchBranch(e.toString()),
        );
      }
    }
  }

  Widget _buildToggleButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingS + AppTheme.paddingXS,
          vertical: AppTheme.paddingXS,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: MenuItemLabel(
          label,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
