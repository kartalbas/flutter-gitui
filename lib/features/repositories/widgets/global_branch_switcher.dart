import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_switcher.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/workspace/workspace_provider.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../providers/global_branch_provider.dart';
import '../services/batch_operations_service.dart';
import '../dialogs/batch_operation_progress_dialog.dart';
import '../repository_batch_error_provider.dart';

/// Global branch switcher widget - displays most common branch and allows batch checkout
class GlobalBranchSwitcher extends ConsumerWidget {
  const GlobalBranchSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(globalBranchesProvider);

    return branchesAsync.when(
      data: (branches) {
        // Determine label to show
        String label;
        if (branches.isNotEmpty) {
          // Show most common branch (branch that can be switched in most repos)
          label = branches.first.branchName;
        } else {
          label = 'No branches';
        }

        return BaseSwitcher(
          icon: PhosphorIconsBold.gitBranch,
          label: label,
          tooltip: branches.isEmpty
              ? 'No branches available to switch'
              : 'Checkout branch across repositories',
          showDropdown: branches.isNotEmpty,
          onTap: branches.isNotEmpty
              ? () => _showBranchMenu(context, ref, branches)
              : null,
        );
      },
      loading: () => BaseSwitcher(
        icon: PhosphorIconsBold.gitBranch,
        label: 'Loading...',
        tooltip: 'Loading branches',
        showDropdown: false,
        onTap: null,
      ),
      error: (error, stack) => BaseSwitcher(
        icon: PhosphorIconsBold.gitBranch,
        label: 'Error',
        tooltip: 'Error loading branches: $error',
        showDropdown: false,
        onTap: null,
      ),
    );
  }

  void _showBranchMenu(
    BuildContext context,
    WidgetRef ref,
    List<GlobalBranchInfo> branches,
  ) {
    showMenu<GlobalBranchInfo>(
      context: context,
      position: _getMenuPosition(context),
      items: branches.map((branchInfo) {
        return PopupMenuItem<GlobalBranchInfo>(
          value: branchInfo,
          child: _buildBranchMenuItem(context, branchInfo),
        );
      }).toList(),
    ).then((selectedBranchInfo) {
      if (!context.mounted || selectedBranchInfo == null) return;
      _checkoutBranchInAll(context, ref, selectedBranchInfo);
    });
  }

  Widget _buildBranchMenuItem(
    BuildContext context,
    GlobalBranchInfo branchInfo,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingS,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIconsBold.gitBranch,
            size: AppTheme.iconS,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                BodyMediumLabel(
                  branchInfo.branchName,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: AppTheme.paddingXS),
                BodySmallLabel(
                  'Switch ${branchInfo.repositoryCount} of ${branchInfo.totalRepositories} repos:',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                ...branchInfo.repositoryNames.map(
                  (repoName) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: BodySmallLabel(
                      '• $repoName',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  RelativeRect _getMenuPosition(BuildContext context) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    return RelativeRect.fromLTRB(
      position.dx,
      position.dy + button.size.height,
      overlay.size.width - position.dx - button.size.width,
      overlay.size.height - position.dy,
    );
  }

  Future<void> _checkoutBranchInAll(
    BuildContext context,
    WidgetRef ref,
    GlobalBranchInfo branchInfo,
  ) async {
    final repositories = ref.read(workspaceProvider);
    final statuses = ref.read(workspaceRepositoryStatusProvider);
    final gitExecutablePath = ref.read(gitExecutablePathProvider);

    // Filter repositories to only those that need to checkout this branch
    // Only checkout repos that are:
    // 1. Not already on this branch
    // 2. Actually have this branch available (in the branchInfo.repositoryPaths list)
    final reposToCheckout = repositories.where((repo) {
      final status = statuses[repo.path];
      // Only checkout if repo is not already on this branch AND is in the list of repos that have this branch
      return status?.currentBranch != branchInfo.branchName &&
             branchInfo.repositoryPaths.contains(repo.path);
    }).toList();

    if (reposToCheckout.isEmpty) {
      if (context.mounted) {
        NotificationService.showInfo(
          context,
          'All repositories are already on ${branchInfo.branchName}',
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Show progress dialog
    final results = await showDialog<List<BatchOperationResult>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BatchOperationProgressDialog(
        title: 'Checking out ${branchInfo.branchName}',
        repositories: reposToCheckout,
        operation: (onProgress) {
          final service = BatchOperationsService(
            gitExecutablePath: gitExecutablePath,
            onLog: (msg) => Logger.info(msg),
          );
          return service.checkoutBranchInAll(
            reposToCheckout,
            statuses,
            branchInfo.branchName,
            onProgress: onProgress,
          );
        },
      ),
    );

    if (results == null || !context.mounted) return;

    // Store results for error display
    final resultsMap = <String, RepositoryBatchResult>{};
    for (final result in results) {
      resultsMap[result.repository.path] = RepositoryBatchResult(
        success: result.success,
        message: result.error ?? result.message ?? '',
      );
    }
    ref.read(repositoryBatchErrorProvider.notifier).setResults(resultsMap);

    // Update selected branch
    ref.read(selectedGlobalBranchProvider.notifier).state =
        branchInfo.branchName;

    // Refresh only the repositories that were checked out
    // File watchers may not catch all changes immediately, so we refresh manually
    for (final result in results) {
      if (result.success) {
        ref
            .read(workspaceRepositoryStatusProvider.notifier)
            .refreshStatus(result.repository);
      }
    }

    // Show summary notification
    final successCount = results.where((r) => r.success).length;
    final failCount = results.length - successCount;

    if (failCount == 0) {
      NotificationService.showSuccess(
        context,
        'Successfully checked out $successCount repositories to ${branchInfo.branchName}',
      );
    } else {
      NotificationService.showWarning(
        context,
        'Checked out $successCount repositories, $failCount failed',
      );
    }
  }
}
