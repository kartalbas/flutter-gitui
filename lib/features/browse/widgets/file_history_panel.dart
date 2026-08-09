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
      // The card's corner is the skin's now that `BaseCard` is a facade over
      // `surfaces.card`, so this well no longer restates it. The copy was
      // wrong as well as redundant - it rounded the ripple at 8 inside a card
      // the member clips at 12 - and a corner the application does not know
      // cannot be copied at all.
      //
      // The well itself stays, and that is a reported contract finding rather
      // than an unfinished conversion: `CardSpec.onTap` would move the press
      // onto the card, but the member draws every card with
      // `canRequestFocus: false` because a card grid is one Tab stop with a
      // roving highlight - and this is a plain `ListView`, where each commit
      // card is its own Tab stop today. Handing the tap to the member would
      // take these cards off the keyboard.
      content: InkWell(
        onTap: () => _viewCommitDiff(context, commit),
        child: BaseInset(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commit hash and author
              Row(
                children: [
                  // Hash badge
                  Container(
                    // The chip's fill and corner stay, and this site no longer
                    // claims they are waiting for `surfaces.badge`. It is the
                    // same construction as the blame gutter's hash chip
                    // (`file_blame_panel.dart`), and #438 decided that one
                    // twice over: its fill names a Material CONTAINER role
                    // (`secondaryContainer`) that no contract tone can promise
                    // because neither Fluent nor macOS has a paired-container
                    // concept, and a hash chip is not a badge at all - its
                    // content is code the user reads, not a count riding on
                    // something else. Recording a member that will never take
                    // it was the one thing worse than recording nothing, so
                    // the blocker is restated honestly: what this wants is an
                    // inline-code span, which is a member to derive from need
                    // rather than a growth of the badge.
                    //
                    // Its inset stays a literal for its own reason: across it
                    // is `tight` exactly, but down the page a chip keeps
                    // itself to the height of the card row it leads, and 4
                    // sits between `hairline` and `tight` on a ladder that
                    // skips it - naming either rung would move the whole first
                    // row of every commit card.
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
    // The facade, for the reason file_blame_panel.dart's error state now
    // records: the one fact that kept this column hand-built was that
    // `EmptyStateWidget` painted every hero in the supporting foreground, and
    // that fact is a `Tone` on the member now (#431). `Tone.danger` says why
    // the mark is red - the state is a failure - instead of naming the colour
    // Material happens to answer that with, and the `64` leaves with it.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.messageErrorLoadingHistory,
      message: error,
      tone: Tone.danger,
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
