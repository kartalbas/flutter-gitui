import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_viewer_dialog.dart';
import '../../../core/git/git_providers.dart';
import '../../../core/git/models/commit.dart';

/// Dialog listing every commit the newer selected commit contains that the
/// older one does not - `git log older..newer` via
/// `GitService.getCommitsBetween`.
///
/// With two commits on the same line of history that is exactly the commits
/// between them; with commits on diverging branches it is the newer side's
/// exclusive history, which is still the honest answer to "what separates
/// these two".
class CompareCommitsDialog extends ConsumerStatefulWidget {
  final GitCommit newer;
  final GitCommit older;

  const CompareCommitsDialog({
    super.key,
    required this.newer,
    required this.older,
  });

  @override
  ConsumerState<CompareCommitsDialog> createState() =>
      _CompareCommitsDialogState();
}

class _CompareCommitsDialogState extends ConsumerState<CompareCommitsDialog> {
  // Created once: rebuilds from theme or font changes must not re-run git.
  late final Future<List<GitCommit>> _commitsFuture;

  @override
  void initState() {
    super.initState();
    final gitService = ref.read(gitServiceProvider);
    _commitsFuture = gitService == null
        ? Future.value(const [])
        : gitService.getCommitsBetween(widget.older.hash, widget.newer.hash);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseViewerDialog(
      icon: IconRole.gitDiff,
      title: l10n.compareCommits,
      subtitle:
          '${widget.older.shortHash} → ${widget.newer.shortHash}: '
          '${widget.newer.shortSubject}',
      content: FutureBuilder<List<GitCommit>>(
        future: _commitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: BaseLabel(
                l10n.errorLoadingData('commits'),
                role: TextRole.body,
                tone: Tone.danger,
              ),
            );
          }

          final commits = snapshot.data ?? const [];
          if (commits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.gitCommit,
                    size: AppTheme.iconXL,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.paddingM),
                  BaseLabel(
                    l10n.noCommitsInRange,
                    role: TextRole.body,
                    tone: Tone.muted,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(
                l10n.commitsCount(commits.length),
                role: TextRole.detail,
                tone: Tone.muted,
              ),
              const SizedBox(height: AppTheme.paddingS),
              Expanded(
                child: ListView.builder(
                  itemCount: commits.length,
                  itemBuilder: (context, index) =>
                      _CompareCommitRow(commit: commits[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompareCommitRow extends StatelessWidget {
  final GitCommit commit;

  const _CompareCommitRow({required this.commit});

  @override
  Widget build(BuildContext context) {
    return BaseListItem(
      isSelectable: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseLabel(commit.shortSubject, role: TextRole.body, maxLines: 2),
          const SizedBox(height: AppTheme.paddingXS),
          Row(
            children: [
              BaseLabel(
                commit.shortHash,
                role: TextRole.detail,
                tone: Tone.muted,
              ),
              const SizedBox(width: AppTheme.paddingS),
              Icon(
                PhosphorIconsRegular.user,
                size: AppTheme.iconXS,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingXS),
              Flexible(
                child: BaseLabel(
                  commit.author,
                  role: TextRole.detail,
                  tone: Tone.muted,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
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
        ],
      ),
    );
  }
}
