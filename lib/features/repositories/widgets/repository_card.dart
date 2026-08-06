import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_animated_widgets.dart';
import '../../../shared/components/base_menu_item.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/workspace/models/repository_status.dart';
import '../../../core/workspace/models/workspace_repository.dart';
import '../../../core/workspace/repository_status_provider.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../repository_batch_error_provider.dart';
import '../../../shared/dialogs/batch_result_dialog.dart';
import 'sync_on_double_tap.dart';

/// Card widget displaying a workspace repository
class RepositoryCard extends ConsumerWidget {
  final WorkspaceRepository repository;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onOpenInEditor;
  final VoidCallback? onEditRemoteUrl;
  final bool isSelected;
  final bool isMultiSelected;
  final bool showCheckbox;

  /// Whether the grid's roving highlight rests on this card.
  final bool isHighlighted;

  /// Whether the collection holding this card owns keyboard focus. Only the
  /// highlighted card wears the focus ring, and only while the collection is
  /// focused; the current repository keeps its tinted background without
  /// claiming the keyboard.
  final bool containerHasFocus;

  const RepositoryCard({
    super.key,
    required this.repository,
    required this.onTap,
    required this.onRemove,
    required this.onToggleFavorite,
    this.onToggleSelection,
    this.onOpenInEditor,
    this.onEditRemoteUrl,
    this.isSelected = false,
    this.isMultiSelected = false,
    this.showCheckbox = false,
    this.isHighlighted = false,
    this.containerHasFocus = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValid = repository.isValidGitRepo;
    final status = ref.watch(repositoryStatusByPathProvider(repository.path));

    // Repository is only selectable if BOTH checks pass:
    // 1. Synchronous check: repository.isValidGitRepo
    // 2. Async status check: !status.isBroken (unless still loading)
    final isSelectable = isValid && (status.isLoading || !status.isBroken);

    return BaseCard(
      isSelected: isSelected || isHighlighted,
      isMultiSelected: isMultiSelected,
      isSelectable: isSelectable,
      // The focus ring belongs to the roving highlight alone; the current
      // repository keeps the muted tinted treatment.
      containerHasFocus: isHighlighted && containerHasFocus,
      onTap: onTap,
      customBackgroundColor: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : isMultiSelected
          ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with favorite and remove buttons
          Row(
            children: [
              // Multi-selection checkbox
              if (showCheckbox && isSelectable)
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.paddingS),
                  child: Checkbox(
                    value: isMultiSelected,
                    onChanged: onToggleSelection != null
                        ? (_) => onToggleSelection!()
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const Spacer(),
              // Batch operation result icon
              _buildBatchResultIcon(context, ref),
              BaseIconButton(
                icon: repository.isFavorite
                    ? PhosphorIconsFill.star
                    : PhosphorIconsRegular.star,
                iconColor: repository.isFavorite
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: onToggleFavorite,
                tooltip: repository.isFavorite
                    ? AppLocalizations.of(context)!.tooltipRemoveFromFavorites
                    : AppLocalizations.of(context)!.tooltipAddToFavorites,
              ),
              // Repository menu
              if (onOpenInEditor != null ||
                  (status.hasRemote && onEditRemoteUrl != null))
                BasePopupMenuButton<String>(
                  icon: const Icon(
                    PhosphorIconsRegular.dotsThreeVertical,
                    size: AppTheme.iconM,
                  ),
                  tooltip: AppLocalizations.of(context)!.moreActions,
                  itemBuilder: (context) => [
                    if (onOpenInEditor != null)
                      PopupMenuItem<String>(
                        value: 'open_in_editor',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.code,
                          label: AppLocalizations.of(
                            context,
                          )!.openFolderInEditor,
                          iconSize: AppTheme.iconM,
                        ),
                      ),
                    if (status.hasRemote && onEditRemoteUrl != null)
                      PopupMenuItem<String>(
                        value: 'edit_remote_url',
                        child: MenuItemContent(
                          icon: PhosphorIconsRegular.link,
                          label: AppLocalizations.of(
                            context,
                          )!.editRemoteUrl('origin'),
                          iconSize: AppTheme.iconM,
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'open_in_editor':
                        onOpenInEditor?.call();
                        break;
                      case 'edit_remote_url':
                        onEditRemoteUrl?.call();
                        break;
                    }
                  },
                ),
              BaseIconButton(
                icon: PhosphorIconsRegular.trash,
                onPressed: onRemove,
                tooltip: AppLocalizations.of(
                  context,
                )!.tooltipRemoveFromWorkspace,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.paddingM),

          // Repository name
          TitleLargeLabel(
            repository.displayName,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurface,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.paddingS),

          // Path
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.folder,
                size: 14,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  repository.path,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Current branch
          if (status.currentBranch != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.gitBranch,
                  size: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                Flexible(
                  child: BodyMediumLabel(
                    status.currentBranch!,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Where the remote lives. With a workspace spanning providers this is
          // what tells the user which account a repository needs - decisive
          // when its check failed for missing credentials.
          if (status.remoteIdentity case final identity?) ...[
            const SizedBox(height: AppTheme.paddingS),
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.cloud,
                  size: 14,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                Flexible(
                  child: Tooltip(
                    message: status.remoteUrl ?? identity.host,
                    child: BodySmallLabel(
                      identity.accountHint == null
                          ? identity.label
                          : '${identity.label} · ${identity.accountHint}',
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Description if available
          if (repository.description != null) ...[
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              repository.description!,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Status badges - show loading or actual status
          const SizedBox(height: AppTheme.paddingM),
          if (status.isGitNotConfigured)
            _buildStatusBadge(
              context,
              PhosphorIconsRegular.gear,
              'Git not configured',
              Theme.of(context).colorScheme.tertiary,
              isSelected,
            )
          else if (status.isLoading)
            // Show loading indicator while analyzing
            Row(
              children: [
                SizedBox(
                  width: AppTheme.paddingM,
                  height: AppTheme.paddingM,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingS),
                BodySmallLabel(
                  'Analyzing...',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ],
            )
          else
            // Show actual status badges after analysis. Double-clicking them
            // syncs this one repository, which is where a user looking at
            // "↓2" wants to act.
            SyncOnDoubleTap(
              repository: repository,
              onSingleTap: onTap,
              child: Wrap(
                spacing: AppTheme.paddingXS,
                runSpacing: AppTheme.paddingXS,
                children: [
                  // Broken status
                  if (status.isBroken)
                    _buildStatusBadge(
                      context,
                      PhosphorIconsRegular.warningCircle,
                      'Broken',
                      Theme.of(context).colorScheme.error,
                      isSelected,
                    ),

                  // Commits behind (need to pull)
                  if (status.hasIncoming)
                    _buildStatusBadge(
                      context,
                      PhosphorIconsRegular.arrowDown,
                      '↓${status.commitsBehind}',
                      Theme.of(context).colorScheme.tertiary,
                      isSelected,
                    ),

                  // Commits ahead (need to push)
                  if (status.hasOutgoing)
                    _buildStatusBadge(
                      context,
                      PhosphorIconsRegular.arrowUp,
                      '↑${status.commitsAhead}',
                      Theme.of(context).colorScheme.primary,
                      isSelected,
                    ),

                  // Uncommitted changes
                  if (status.hasUncommittedChanges)
                    _buildStatusBadge(
                      context,
                      PhosphorIconsRegular.pencilSimple,
                      'Changes',
                      Theme.of(context).colorScheme.secondary,
                      isSelected,
                    ),

                  // Nothing outstanding. The remote-tracking refs only move on a
                  // fetch, so claiming to be in sync before one has happened
                  // would report a clean state that was never verified. A
                  // repository the check could not reach says why instead, and
                  // the one case the user can resolve offers to do it.
                  if (!status.isBroken &&
                      !status.hasIncoming &&
                      !status.hasOutgoing &&
                      !status.hasUncommittedChanges &&
                      status.exists &&
                      status.isValidGit)
                    _buildVerificationBadge(context, ref, status, isSelected),
                ],
              ),
            ),

          const Spacer(),

          // Invalid repo warning
          if (!isValid) ...[
            const SizedBox(height: AppTheme.paddingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingS),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: AppTheme.iconS,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      'Invalid or missing repository',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Last accessed
          const SizedBox(height: AppTheme.paddingM),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.clock,
                size: 14,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              LabelMediumLabel(
                '${AppLocalizations.of(context)!.accessed} ${repository.lastAccessed.toDisplayString(Localizations.localeOf(context).languageCode)}',
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchResultIcon(BuildContext context, WidgetRef ref) {
    final batchResult = ref.watch(
      repositoryBatchErrorByPathProvider(repository.path),
    );

    if (batchResult == null) {
      return const SizedBox.shrink();
    }

    final isSuccess = batchResult.success;
    final icon = isSuccess
        ? PhosphorIconsBold.checkCircle
        : PhosphorIconsBold.warningCircle;

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.paddingS),
      child: BaseIconButton(
        icon: icon,
        onPressed: () => _showBatchResultDialog(context, ref, batchResult),
        tooltip: isSuccess ? 'Operation successful' : 'Operation failed',
      ),
    );
  }

  void _showBatchResultDialog(
    BuildContext context,
    WidgetRef ref,
    RepositoryBatchResult result,
  ) {
    showBatchResultDialog(
      context: context,
      repositoryName: repository.displayName,
      result: result,
      onDismiss: () {
        ref
            .read(repositoryBatchErrorProvider.notifier)
            .clearResult(repository.path);
      },
    );
  }

  /// The badge for a repository with nothing outstanding.
  ///
  /// "Up to date" is only claimed once the remote was actually contacted.
  /// Otherwise the badge names what stopped the check, because a repository
  /// that silently sits on "not checked" tells the user nothing and offers
  /// nothing to do. The missing-credentials case is the one they can resolve,
  /// so it is a button: pressing it fetches that one repository *with* prompts
  /// allowed, which is legitimate because they asked for it.
  Widget _buildVerificationBadge(
    BuildContext context,
    WidgetRef ref,
    RepositoryStatus status,
    bool isSelected,
  ) {
    if (status.needsSignIn) {
      return Tooltip(
        message: 'This repository needs a sign-in. Click to authenticate.',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          onTap: () => _signIn(context, ref),
          child: _buildStatusBadge(
            context,
            PhosphorIconsRegular.signIn,
            'Sign-in required',
            Theme.of(context).colorScheme.tertiary,
            isSelected,
          ),
        ),
      );
    }

    if (status.isRemoteUnreachable) {
      return Tooltip(
        message: 'The remote could not be reached. It will be retried.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.cloudSlash,
          'Unreachable',
          Theme.of(context).colorScheme.onSurfaceVariant,
          isSelected,
        ),
      );
    }

    if (status.remoteCheckFailedUnknown) {
      return Tooltip(
        message: 'The remote check failed. See the command log for details.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.warningCircle,
          'Check failed',
          Theme.of(context).colorScheme.error,
          isSelected,
        ),
      );
    }

    if (status.isRemoteUnchecked) {
      return Tooltip(
        message: 'Not compared against the remote yet.',
        child: _buildStatusBadge(
          context,
          PhosphorIconsRegular.clockCountdown,
          'Not checked',
          Theme.of(context).colorScheme.onSurfaceVariant,
          isSelected,
        ),
      );
    }

    return _buildStatusBadge(
      context,
      PhosphorIconsRegular.checkCircle,
      'Up to date',
      Theme.of(context).colorScheme.primary,
      isSelected,
    );
  }

  /// Fetches this one repository with credential prompts allowed.
  ///
  /// The background sweep runs without them so it can never interrupt; here the
  /// user explicitly asked, so the helper's sign-in window is expected.
  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    await ref
        .read(workspaceRepositoryStatusProvider.notifier)
        .refreshStatus(repository, fetchRemote: true, allowPrompts: true);
  }

  Widget _buildStatusBadge(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingS,
        vertical: AppTheme.paddingXS,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppTheme.paddingXS),
          LabelMediumLabel(label, color: color),
        ],
      ),
    );
  }
}
