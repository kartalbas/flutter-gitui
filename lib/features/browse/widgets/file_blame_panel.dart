import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:timeago/timeago.dart' as timeago;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_viewer_dialog.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/blame.dart';
import '../../history/widgets/commit_details_panel.dart';
import '../../history/widgets/file_tree_panel.dart';

/// GitHub-style Git Blame panel with two-column layout
/// Left: Commit metadata (grouped by commit)
/// Right: Full code with line numbers
class FileBlamePanel extends ConsumerWidget {
  final String filePath;

  const FileBlamePanel({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final blameAsync = ref.watch(fileBlameProvider(filePath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.blame),
            BodySmallLabel(
              fileName,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        actions: [
          BaseIconButton(
            icon: PhosphorIconsRegular.info,
            tooltip: AppLocalizations.of(context)!.tooltipBlameStatistics,
            onPressed: () => blameAsync.value != null
                ? _showBlameInfo(context, blameAsync.value!)
                : null,
          ),
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: () {
              ref.invalidate(fileBlameProvider(filePath));
            },
          ),
        ],
      ),
      body: blameAsync.when(
        data: (blame) {
          if (blame == null) {
            return _buildError(
              context,
              AppLocalizations.of(context)!.couldNotLoadBlame,
            );
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

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildCommitGroup(context, group, index);
      },
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
        // Same commit, add to current group
        currentLines.add(lines[i]);
      } else {
        // Different commit, save current group and start new one
        groups.add(
          CommitGroup(
            commitHash: currentCommit,
            lines: List.from(currentLines),
          ),
        );
        currentCommit = lines[i].commitHash;
        currentLines = [lines[i]];
      }
    }

    // Add last group
    groups.add(CommitGroup(commitHash: currentCommit, lines: currentLines));

    return groups;
  }

  Widget _buildCommitGroup(
    BuildContext context,
    CommitGroup group,
    int groupIndex,
  ) {
    final firstLine = group.lines.first;
    final lineCount = group.lines.length;

    // Alternate background colors for better visual separation
    final isEven = groupIndex % 2 == 0;
    final backgroundColor = isEven
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(color: backgroundColor),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: Commit metadata (fixed width)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: _buildCommitMetadata(context, firstLine, lineCount),
            ),

            // Right column: Code lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.lines.map((line) {
                  return _buildCodeLine(context, line);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitMetadata(
    BuildContext context,
    BlameLine line,
    int lineCount,
  ) {
    final relativeTime = timeago.format(line.authorTime, locale: 'en_short');

    return Tooltip(
      message: _buildFullCommitTooltip(line),
      preferBelow: false,
      child: InkWell(
        onTap: () => _showCommitDetails(context, line),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Author with avatar
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: LabelSmallLabel(
                      line.authorInitials,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                  Expanded(
                    child: BodySmallLabel(
                      line.author,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.paddingS),

              // Relative time
              Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.clock,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingXS),
                  LabelMediumLabel(
                    relativeTime,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.paddingS),

              // Commit hash (clickable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LabelSmallLabel(
                  line.shortHash,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),

              const SizedBox(height: AppTheme.paddingS),

              // Commit summary (first line)
              LabelMediumLabel(
                line.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Line count indicator if group has multiple lines
              if (lineCount > 1) ...[
                const SizedBox(height: AppTheme.paddingS),
                LabelSmallLabel(
                  AppLocalizations.of(context)!.linesCount(lineCount),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeLine(BuildContext context, BlameLine line) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
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
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              textAlign: TextAlign.right,
            ),
          ),

          const SizedBox(width: AppTheme.paddingM),

          // Code content
          Expanded(
            child: SelectableText(
              line.lineContent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.file,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.emptyFile),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(AppLocalizations.of(context)!.noContent),
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
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.errorLoadingBlame),
          const SizedBox(height: AppTheme.paddingS),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
            child: BodyMediumLabel(error, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  String _buildFullCommitTooltip(BlameLine line) {
    return '''
Commit: ${line.commitHash}
Author: ${line.author} <${line.authorEmail}>
Date: ${line.authorTime}

${line.summary}
''';
  }

  void _showCommitDetails(BuildContext context, BlameLine line) async {
    // Fetch the full commit details using the git service
    final ref = ProviderScope.containerOf(context);
    final gitService = ref.read(gitServiceProvider);

    if (gitService == null) {
      return;
    }

    try {
      // Get the full commit object by specifying the commit hash directly
      // Don't use range syntax (^..) as it fails for boundary commits
      final commits = await gitService.getLog(
        limit: 1,
        branch: line.commitHash,
      );

      if (commits.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commit not found in repository history'),
            ),
          );
        }
        return;
      }

      final commit = commits.first;

      if (!context.mounted) return;

      // Show commit details with files in a dialog (similar to History screen)
      final l10n = AppLocalizations.of(context)!;
      BaseViewerDialog.show(
        context: context,
        dialog: BaseViewerDialog(
          icon: PhosphorIconsRegular.gitCommit,
          title: l10n.commitShortHash(line.shortHash),
          subtitle: commit.subject,
          content: Row(
            children: [
              // Left: Commit details panel
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: CommitDetailsPanel(commit: commit),
                ),
              ),

              // Right: Changed files panel
              Expanded(
                flex: 1,
                child: FileTreePanel(commitHash: line.commitHash),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarErrorLoadingCommit(e.toString())),
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.paddingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: TitleSmallLabel('$label:'),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlameInfo(BuildContext context, FileBlame blame) {
    showDialog(
      context: context,
      builder: (context) => BaseDialog(
        title: AppLocalizations.of(context)!.blameStatistics,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                context,
                AppLocalizations.of(context)!.totalLines,
                blame.totalLines.toString(),
              ),
              _buildDetailRow(
                context,
                AppLocalizations.of(context)!.authors,
                blame.uniqueAuthors.length.toString(),
              ),
              _buildDetailRow(
                context,
                AppLocalizations.of(context)!.commitsLabel,
                blame.uniqueCommits.length.toString(),
              ),
              const SizedBox(height: AppTheme.paddingM),
              TitleSmallLabel(
                AppLocalizations.of(context)!.contributors,
              ),
              const SizedBox(height: AppTheme.paddingS),
              ...blame.uniqueAuthors.map((author) {
                final lineCount = blame.linesByAuthor[author]?.length ?? 0;
                final percentage = (lineCount / blame.totalLines * 100)
                    .toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.only(
                    left: AppTheme.paddingM,
                    top: AppTheme.paddingS,
                  ),
                  child: BodyMediumLabel(
                    '• $author: $lineCount lines ($percentage%)',
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          BaseButton(
            label: AppLocalizations.of(context)!.close,
            variant: ButtonVariant.tertiary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Helper class to group consecutive lines from the same commit
class CommitGroup {
  final String commitHash;
  final List<BlameLine> lines;

  CommitGroup({required this.commitHash, required this.lines});
}
