import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../core/diff/diff_parser.dart';
import '../../core/diff/diff_providers.dart';
import '../../core/config/config_providers.dart';
import '../../core/git/git_providers.dart';
import '../../core/git/models/stash.dart';
import '../components/base_badge.dart';
import '../components/base_diff_viewer.dart';
import '../components/base_button.dart';
import '../components/base_viewer_dialog.dart';
import '../theme/app_theme.dart';

/// Unified diff dialog that handles all diff viewing use cases
class UnifiedDiffDialog extends ConsumerStatefulWidget {
  // For file diffs (working directory)
  final String? filePath;
  final bool staged;

  // For commit diffs
  final String? commitHash;
  final String? commitFilePath;

  // For stash diffs
  final GitStash? stash;

  const UnifiedDiffDialog({
    super.key,
    this.filePath,
    this.staged = false,
    this.commitHash,
    this.commitFilePath,
    this.stash,
  }) : assert(
          (filePath != null && commitHash == null && stash == null) ||
          (filePath == null && commitHash != null && commitFilePath != null && stash == null) ||
          (filePath == null && commitHash == null && stash != null),
          'Must provide either filePath, (commitHash + commitFilePath), or stash',
        );

  /// Factory constructor for file diffs (working directory)
  factory UnifiedDiffDialog.file({
    required String filePath,
    bool staged = false,
  }) {
    return UnifiedDiffDialog(
      filePath: filePath,
      staged: staged,
    );
  }

  /// Factory constructor for commit file diffs
  factory UnifiedDiffDialog.commit({
    required String commitHash,
    required String filePath,
  }) {
    return UnifiedDiffDialog(
      commitHash: commitHash,
      commitFilePath: filePath,
    );
  }

  /// Factory constructor for stash diffs
  factory UnifiedDiffDialog.stash({
    required GitStash stash,
  }) {
    return UnifiedDiffDialog(
      stash: stash,
    );
  }

  @override
  ConsumerState<UnifiedDiffDialog> createState() => _UnifiedDiffDialogState();
}

class _UnifiedDiffDialogState extends ConsumerState<UnifiedDiffDialog> {
  late bool _compactMode;

  @override
  void initState() {
    super.initState();
    // Initialize compact mode from config
    _compactMode = ref.read(configProvider).ui.diffCompactMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String title;
    String subtitle;

    if (widget.stash != null) {
      title = l10n.stashDiffTitle(widget.stash!.ref);
      subtitle = widget.stash!.displayTitle;
    } else if (widget.commitHash != null) {
      title = l10n.commitDiff;
      final shortHash = widget.commitHash!.substring(0, 7);
      subtitle = '$shortHash: ${widget.commitFilePath}';
    } else {
      title = l10n.labelDiffViewer;
      subtitle = widget.filePath!;
    }

    return BaseViewerDialog(
      icon: PhosphorIconsRegular.gitDiff,
      title: title,
      subtitle: subtitle,
      headerActions: [
        // Show staged chip for file diffs
        if (widget.filePath != null && widget.staged)
          BaseBadge(
            label: l10n.labelStaged,
            variant: BadgeVariant.primary,
            size: BadgeSize.medium,
          ),
        // Compact mode toggle (not for stash diffs - they're already simple)
        if (widget.stash == null)
          BaseIconButton(
            icon: _compactMode
                ? PhosphorIconsRegular.textOutdent
                : PhosphorIconsRegular.textIndent,
            tooltip: _compactMode ? 'Compact View' : 'Normal View',
            onPressed: () async {
              setState(() {
                _compactMode = !_compactMode;
              });
              // Save to config
              await ref.read(configProvider.notifier).setDiffCompactMode(_compactMode);
            },
          ),
      ],
      content: _buildDiffView(context),
      actions: _buildActions(context),
    );
  }

  Widget _buildDiffView(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadDiff(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error);
        }

        final diffOutput = snapshot.data ?? '';
        final diffLines = DiffParser.parse(diffOutput);

        return BaseDiffViewer(
          diffLines: diffLines,
          compactMode: _compactMode,
          showLineNumbers: true,
          onLineCopied: () {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.lineCopiedToClipboard),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          fontFamily: ref.watch(previewFontFamilyProvider),
          fontSize: ref.watch(previewFontSizeProvider),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.messageErrorLoadingDiff(error.toString())),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diffTool = ref.watch(selectedDiffToolProvider);

    // External tool only available for file diffs (not commit or stash diffs)
    final canOpenExternalTool = widget.filePath != null && diffTool != null;

    return [
      BaseButton(
        label: l10n.labelCopyAll,
        variant: ButtonVariant.tertiary,
        leadingIcon: PhosphorIconsRegular.copy,
        onPressed: () async {
          final diffOutput = await _loadDiff();
          await Clipboard.setData(ClipboardData(text: diffOutput));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.snackbarDiffCopied)),
            );
          }
        },
      ),
      if (canOpenExternalTool)
        BaseButton(
          label: l10n.labelOpenInExternalTool,
          variant: ButtonVariant.primary,
          leadingIcon: PhosphorIconsRegular.arrowSquareOut,
          onPressed: () async {
            Navigator.of(context).pop();
            // Open in external tool
            try {
              if (widget.staged) {
                await ref.read(diffActionsProvider).diffStagedFile(widget.filePath!);
              } else {
                await ref.read(diffActionsProvider).diffUnstagedFile(widget.filePath!);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.snackbarFailedToOpenExternalTool(e.toString()))),
                );
              }
            }
          },
        ),
    ];
  }

  Future<String> _loadDiff() async {
    final gitService = ref.read(gitServiceProvider);
    if (gitService == null) {
      throw Exception('No repository open');
    }

    // Load diff based on type
    if (widget.stash != null) {
      final result = await gitService.getStashDiff(widget.stash!.ref);
      return result.unwrap();
    } else if (widget.commitHash != null) {
      final result = await gitService.getDiffForCommit(widget.commitHash!, widget.commitFilePath!);
      return result.unwrap();
    } else {
      final result = await gitService.getDiff(widget.filePath!, staged: widget.staged);
      return result.unwrap();
    }
  }
}

/// Show unified diff dialog for file diffs (working directory)
Future<void> showUnifiedDiffDialog(
  BuildContext context, {
  required String filePath,
  bool staged = false,
}) {
  return showDialog(
    context: context,
    builder: (context) => UnifiedDiffDialog.file(
      filePath: filePath,
      staged: staged,
    ),
  );
}

/// Show unified diff dialog for commit file diffs
Future<void> showCommitFileDiffDialog(
  BuildContext context, {
  required String commitHash,
  required String filePath,
}) {
  return showDialog(
    context: context,
    builder: (context) => UnifiedDiffDialog.commit(
      commitHash: commitHash,
      filePath: filePath,
    ),
  );
}

/// Show unified diff dialog for stash diffs
Future<void> showStashDiffDialog(
  BuildContext context, {
  required GitStash stash,
}) {
  return showDialog(
    context: context,
    builder: (context) => UnifiedDiffDialog.stash(
      stash: stash,
    ),
  );
}
