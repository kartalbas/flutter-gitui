import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/models/commit.dart';
import '../models/commit_graph.dart';
import 'commit_graph_painter.dart';

/// Individual commit item in the history list
class CommitListItem extends ConsumerWidget {
  final GitCommit commit;
  final bool isSelected;
  final bool isMultiSelected;
  final VoidCallback onTap;
  final String? currentBranch;

  /// This commit's precomputed lanes, or null when the displayed list is not
  /// the window the graph pass walked (an in-memory filter removed rows).
  final CommitGraphRow? graphRow;

  /// Lane columns of the whole window, so every row reserves the same width
  /// and the lanes line up vertically.
  final int graphLaneCount;

  /// Right-click handler, handed the global cursor position so the caller
  /// can anchor a context menu on the commit under the cursor.
  final void Function(Offset globalPosition)? onSecondaryTap;

  const CommitListItem({
    super.key,
    required this.commit,
    required this.isSelected,
    required this.onTap,
    this.isMultiSelected = false,
    this.currentBranch,
    this.graphRow,
    this.graphLaneCount = 0,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCommitGraph = ref.watch(showCommitGraphProvider);
    final row = graphRow;

    final listItem = BaseListItem(
      isSelected: isSelected,
      isMultiSelected: isMultiSelected,
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      // With lanes available the leading slot only reserves their width; the
      // drawing happens in the overlay below, which can span the full row
      // height. Without lanes a plain dot still marks the commit.
      leading: !showCommitGraph
          ? null
          : row != null
          ? SizedBox(
              width: CommitGraphRowPainter.leadingWidthFor(graphLaneCount),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: commit.isMergeCommit
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 2,
                  ),
                ),
              ),
            ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject line
          BodyMediumLabel(
            commit.shortSubject,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurface,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: AppTheme.paddingXS),

          // Refs (branches, tags)
          if (commit.refs.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: commit.refs.map((ref) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ref.contains('tag:')
                            ? PhosphorIconsRegular.tag
                            : PhosphorIconsRegular.gitBranch,
                        size: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 2),
                      LabelSmallLabel(
                        ref,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.paddingXS),
          ],

          // Author and time
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.user,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  commit.author,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
              Icon(
                PhosphorIconsRegular.clock,
                size: AppTheme.iconXS,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BodySmallLabel(
                  commit.authorDateDisplay(
                    Localizations.localeOf(context).languageCode,
                  ),
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Short hash and current branch
          Row(
            children: [
              LabelMediumLabel(
                commit.shortHash,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              if (currentBranch != null) ...[
                const SizedBox(width: AppTheme.paddingS),
                Icon(
                  PhosphorIconsRegular.gitBranch,
                  size: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.paddingXS),
                LabelMediumLabel(
                  currentBranch!,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (!showCommitGraph || row == null) {
      return listItem;
    }

    // The overlay, not the leading widget, carries the painter: only here
    // does it cover the full item height, divider strip included, so this
    // row's lane lines meet the neighboring rows' without gaps. It ignores
    // pointers so the item underneath keeps receiving taps.
    return Stack(
      children: [
        listItem,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: CommitGraphRowPainter(row: row)),
          ),
        ),
      ],
    );
  }
}
