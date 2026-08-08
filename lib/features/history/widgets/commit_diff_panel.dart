import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
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
            ? _CenteredNote(
                mark: Icon(
                  PhosphorIconsRegular.files,
                  size: AppTheme.iconXL,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                message: l10n.messageNoFilesChanged,
              )
            : _CommitFileDiff(commitHash: commitHash, filePath: path),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _CenteredNote(
          mark: Icon(
            PhosphorIconsRegular.warningCircle,
            size: AppTheme.iconXL,
            color: Theme.of(context).colorScheme.error,
          ),
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
        fontFamily: ref.watch(previewFontFamilyProvider),
        fontSize: ref.watch(previewFontSizeProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _CenteredNote(
        mark: Icon(
          PhosphorIconsRegular.warningCircle,
          size: AppTheme.iconXL,
          color: Theme.of(context).colorScheme.error,
        ),
        message: l10n.errorLoadingData('diff'),
        tone: Tone.danger,
      ),
    );
  }
}

/// A mark over a sentence, in the middle of the panel.
///
/// The colour parameter this used to carry was the caller's MEANING wearing a
/// `Color`: "nothing went wrong, this is just empty" or "this failed". Said as
/// a meaning it is a [Tone], and the skin decides what that looks like.
///
/// The mark arrives already built rather than as a [Tone] of its own, because
/// the only application-legal way to draw one from a tone is `BaseIcon`, whose
/// three scales top out at 24 while an empty state's mark is 32. Rather than
/// shrink a glyph inside a phase about typography, the mark stays where the
/// application already decided it and moves when the empty-state surface does.
class _CenteredNote extends StatelessWidget {
  final Widget mark;
  final String message;
  final Tone tone;

  const _CenteredNote({
    required this.mark,
    required this.message,
    this.tone = Tone.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mark,
          // The mark and the sentence under it are members of one statement:
          // `grouped`, Material's 16.
          const BaseGap(Proximity.grouped),
          BaseLabel(message, role: TextRole.body, tone: tone),
        ],
      ),
    );
  }
}
