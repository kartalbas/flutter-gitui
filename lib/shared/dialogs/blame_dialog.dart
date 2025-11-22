import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;

import '../../generated/app_localizations.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/blame.dart';
import '../components/base_label.dart';
import '../components/base_viewer_dialog.dart';
import '../theme/app_theme.dart';
import '../components/base_card.dart';

/// Blame dialog for viewing file blame information
class BlameDialog extends ConsumerWidget {
  final String filePath;

  const BlameDialog({super.key, required this.filePath});

  /// Factory constructor for showing blame dialog
  factory BlameDialog.show({
    required BuildContext context,
    required String filePath,
  }) {
    showDialog(
      context: context,
      builder: (context) => BlameDialog(filePath: filePath),
    );
    return BlameDialog(filePath: filePath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final blameAsync = ref.watch(fileBlameProvider(filePath));
    final l10n = AppLocalizations.of(context)!;

    return BaseViewerDialog(
      icon: PhosphorIconsRegular.userList,
      title: l10n.blame,
      subtitle: fileName,
      content: blameAsync.when(
        data: (blame) {
          if (blame == null) {
            return _buildError(context, l10n.couldNotLoadBlame);
          }
          return _buildBlameView(context, blame);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildBlameView(BuildContext context, FileBlame blame) {
    if (blame.lines.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group consecutive lines by commit
    final groups = _groupLinesByCommit(blame.lines);

    return BaseCard(
      padding: EdgeInsets.zero,
      content: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return _buildCommitGroup(context, group, index);
        },
      ),
    );
  }

  /// Groups consecutive lines that share the same commit hash
  List<CommitGroup> _groupLinesByCommit(List<BlameLine> lines) {
    final groups = <CommitGroup>[];

    if (lines.isEmpty) return groups;

    var currentCommit = lines[0].commitHash;
    var currentLines = <BlameLine>[lines[0]];

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].commitHash == currentCommit) {
        currentLines.add(lines[i]);
      } else {
        groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));
        currentCommit = lines[i].commitHash;
        currentLines = [lines[i]];
      }
    }

    // Add the last group
    groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));

    return groups;
  }

  Widget _buildCommitGroup(BuildContext context, CommitGroup group, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstLine = group.lines.first;
    final isEven = index % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        color: isEven
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: Commit metadata (only shown once per group)
            Container(
              width: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Commit hash
                  BodySmallLabel(
                    firstLine.commitHash.substring(0, 7),
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: AppTheme.paddingXS),
                  // Author
                  TitleSmallLabel(
                    firstLine.author,
                  ),
                  const SizedBox(height: 2),
                  // Date
                  BodySmallLabel(
                    timeago.format(firstLine.authorTime),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.paddingS),
                  // Summary
                  BodySmallLabel(
                    firstLine.summary,
                    color: colorScheme.onSurfaceVariant,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            // Right column: Code lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.lines.map((line) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line number
                        SizedBox(
                          width: 50,
                          child: BodySmallLabel(
                            line.lineNumber.toString(),
                            color: colorScheme.onSurfaceVariant,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Line content
                        Expanded(
                          child: SelectableText(
                            line.lineContent.isEmpty ? ' ' : line.lineContent,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface,
                                  height: 1.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.userList, size: 48),
          const SizedBox(height: AppTheme.paddingM),
          TitleMediumLabel(AppLocalizations.of(context)!.couldNotLoadBlame),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingM),
          Text(error),
        ],
      ),
    );
  }
}

/// Helper class to group consecutive lines by commit
class CommitGroup {
  final String commitHash;
  final List<BlameLine> lines;

  CommitGroup({required this.commitHash, required this.lines});
}

/// Show blame dialog for a file
Future<void> showBlameDialog(BuildContext context, {required String filePath}) {
  return showDialog(
    context: context,
    builder: (context) => BlameDialog(filePath: filePath),
  );
}
