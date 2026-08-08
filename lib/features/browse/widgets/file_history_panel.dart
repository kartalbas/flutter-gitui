import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Inset, Proximity, TextRole, Tone;
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_viewer_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';
import '../../history/widgets/commit_details_panel.dart';
import '../../history/widgets/file_tree_panel.dart';

/// File history panel - shows git history for a specific file
class FileHistoryPanel extends ConsumerWidget {
  final String filePath;

  const FileHistoryPanel({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = path.basename(filePath);
    final fileHistory = ref.watch(fileHistoryProvider(filePath));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.fileHistory),
            BaseLabel(fileName, role: TextRole.detail, tone: Tone.muted),
          ],
        ),
        actions: [
          BaseIconButton(
            icon: IconRole.arrowClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: () {
              ref.invalidate(fileHistoryProvider(filePath));
            },
          ),
        ],
      ),
      body: fileHistory.when(
        data: (commits) => _buildCommitList(context, commits),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildCommitList(BuildContext context, List<GitCommit> commits) {
    if (commits.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      // The facade rather than another hand-built copy of it (#430). The `64`
      // and the on-surface-variant role beside it were one decision
      // and it belongs to the member: `EmptyStateSpec` accepts no size, so a
      // size written at a call site is a leak by construction, and the colour
      // paired with it cannot be half-converted away from it.
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.clockCounterClockwise,
        title: l10n.emptyStateNoHistory,
        message: l10n.emptyStateNoHistoryMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      itemCount: commits.length,
      separatorBuilder: (context, index) => const BaseGap(Proximity.related),
      itemBuilder: (context, index) =>
          _buildCommitCard(context, commits[index]),
    );
  }

  Widget _buildCommitCard(BuildContext context, GitCommit commit) {
    return BaseCard(
      inset: Inset.none,
      content: InkWell(
        onTap: () => _viewCommitDiff(context, commit),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: BaseInset(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commit hash and author
              Row(
                children: [
                  // Hash badge
                  Container(
                    // The badge's fill and corner stay: they are the surface.
                    // Its inset stays a literal too: across it is `tight`
                    // exactly, but down the page a badge keeps itself to the
                    // height of the card row it leads, and 4 sits between
                    // `hairline` and `tight` on a ladder that skips it -
                    // naming either rung would move the whole first row of
                    // every commit card. Both halves wait for
                    // `surfaces.badge`, whose skin owns a badge's measure.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingS,
                      vertical: AppTheme.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    // The badge paints its own fill and states the
                    // foreground that pairs with it.
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      child: BaseLabel(commit.shortHash, role: TextRole.detail),
                    ),
                  ),
                  const BaseGap(Proximity.related),
                  Expanded(
                    child: BaseLabel(
                      commit.author,
                      role: TextRole.body,
                      maxLines: 1,
                    ),
                  ),
                  const BaseGap(Proximity.related),
                  Flexible(
                    child: BaseLabel(
                      commit.authorDateDisplay(
                        Localizations.localeOf(context).languageCode,
                      ),
                      role: TextRole.detail,
                      tone: Tone.muted,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const BaseGap(Proximity.related),
              // Commit message
              BaseLabel(commit.subject, role: TextRole.body),
              if (commit.body.isNotEmpty) ...[
                // A subject and the body that continues it are two halves of
                // one thing: `hairline`.
                const BaseGap(Proximity.hairline),
                BaseLabel(
                  commit.body,
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 3,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Not `EmptyStateWidget`, for the reason spelled out at
          // file_blame_panel.dart's error state: the facade owns its hero
          // glyph's colour and answers it with `onSurfaceVariant`, so adopting
          // it here would repaint a red failure mark neutral - a change to
          // what the user sees, not a change of vocabulary. The read cannot
          // move on its own either: no `Tone` says "the command came back with
          // an error", only "this destroys", "this may be a mistake" and "fix
          // this value".
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.messageErrorLoadingHistory,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(error, role: TextRole.body, align: TextAlign.center),
        ],
      ),
    );
  }

  void _viewCommitDiff(BuildContext context, GitCommit commit) {
    final l10n = AppLocalizations.of(context)!;

    // Show commit details with files in a dialog (similar to file blame panel and history screen)
    BaseViewerDialog.show(
      context: context,
      dialog: BaseViewerDialog(
        icon: IconRole.gitCommit,
        title: l10n.commitShortHash(commit.shortHash),
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
            Expanded(flex: 1, child: FileTreePanel(commitHash: commit.hash)),
          ],
        ),
      ),
    );
  }
}
