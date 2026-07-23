import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_panel.dart';
import '../../../shared/components/base_label.dart';
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
          Icon(
            PhosphorIconsRegular.gitDiff,
            size: AppTheme.iconS,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.paddingS),
          TitleSmallLabel(l10n.commitDiff),
          if (filePath != null) ...[
            const SizedBox(width: AppTheme.paddingS),
            Expanded(
              child: BodySmallLabel(
                filePath,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (filePath != null)
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowSquareOut,
            tooltip: l10n.viewDiff,
            size: ButtonSize.small,
            onPressed: () => showCommitFileDiffDialog(
              context,
              commitHash: commitHash,
              filePath: filePath,
            ),
          ),
      ],
      padding: EdgeInsets.zero,
      content: fileAsync.when(
        data: (path) => path == null
            ? _CenteredNote(
                icon: PhosphorIconsRegular.files,
                message: l10n.messageNoFilesChanged,
              )
            : _CommitFileDiff(commitHash: commitHash, filePath: path),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _CenteredNote(
          icon: PhosphorIconsRegular.warningCircle,
          message: l10n.errorLoadingData('diff'),
          color: Theme.of(context).colorScheme.error,
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
        icon: PhosphorIconsRegular.warningCircle,
        message: l10n.errorLoadingData('diff'),
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _CenteredNote({required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppTheme.iconXL, color: effectiveColor),
          const SizedBox(height: AppTheme.paddingM),
          BodyMediumLabel(message, color: effectiveColor),
        ],
      ),
    );
  }
}
