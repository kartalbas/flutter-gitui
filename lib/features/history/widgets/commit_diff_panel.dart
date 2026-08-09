import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_diff_viewer.dart';
import '../../../core/diff/diff_parser.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/git/widgets/commit_file_diff_dialog.dart';
import '../../../core/services/notification_service.dart';
import '../providers/commit_diff_provider.dart';

/// The highlighted file's diff, shown in place next to the commit metadata.
///
/// This is the in-place counterpart of [showCommitFileDiffDialog]: selecting
/// a commit shows what it changed without opening one dialog per file. The
/// dialog stays reachable from the header for a focused, full-screen read.
class CommitDiffPanel extends ConsumerWidget {
  final String commitHash;

  const CommitDiffPanel({super.key, required this.commitHash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fileAsync = ref.watch(displayedCommitFileProvider(commitHash));
    final filePath = fileAsync.value;

    return BasePanel(
      title: Row(
        children: [
          // A panel header's mark: dense, and carrying the application's own
          // colour rather than Material's `primary` slot.
          const BaseIcon(
            IconRole.gitDiff,
            scale: ControlScale.compact,
            tone: Tone.accent,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(l10n.commitDiff, role: TextRole.sectionTitle),
          if (filePath != null) ...[
            const BaseGap(Proximity.related),
            Expanded(
              child: BaseLabel(
                filePath,
                role: TextRole.detail,
                tone: Tone.muted,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (filePath != null)
          BaseIconButton(
            icon: IconRole.arrowSquareOut,
            tooltip: l10n.viewDiff,
            size: ButtonSize.small,
            onPressed: () => showCommitFileDiffDialog(
              context,
              commitHash: commitHash,
              filePath: filePath,
            ),
          ),
      ],
      inset: Inset.none,
      content: fileAsync.when(
        data: (path) => path == null
            ? PanelNote(
                icon: PhosphorIconsRegular.files,
                message: l10n.messageNoFilesChanged,
              )
            : _CommitFileDiff(commitHash: commitHash, filePath: path),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => PanelNote(
          icon: PhosphorIconsRegular.warningCircle,
          message: l10n.errorLoadingData('diff'),
          tone: Tone.danger,
        ),
      ),
    );
  }
}

/// One file's diff, rendered with the same viewer the dialog uses so both
/// surfaces cannot drift apart in parsing or styling.
class _CommitFileDiff extends ConsumerWidget {
  final String commitHash;
  final String filePath;

  const _CommitFileDiff({required this.commitHash, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final diffAsync = ref.watch(
      commitFileDiffProvider((commitHash: commitHash, filePath: filePath)),
    );

    return diffAsync.when(
      data: (diff) => BaseDiffViewer(
        diffLines: DiffParser.parse(diff),
        compactMode: ref.watch(configProvider).ui.diffCompactMode,
        showLineNumbers: true,
        onLineCopied: () => NotificationService.showSuccess(
          context,
          l10n.lineCopiedToClipboard,
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => PanelNote(
        icon: PhosphorIconsRegular.warningCircle,
        message: l10n.errorLoadingData('diff'),
        tone: Tone.danger,
      ),
    );
  }
}

// `_CenteredNote` used to live here, and its own doc comment named the
// condition on which it would leave: "until the in-panel note becomes a member
// of its own". It has — `PanelNote`, beside the hero it is the small sibling
// of, in lib/shared/widgets/empty_state.dart — so the private copy is gone and
// the three notes above are the member. Two of the four sites that had
// hand-rolled this same shape were in other files entirely, each with its own
// paragraph explaining the same constraint; they are the member now too.
