import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, Tone;

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
import '../widgets/empty_state.dart';

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
             (filePath == null &&
                 commitHash != null &&
                 commitFilePath != null &&
                 stash == null) ||
             (filePath == null && commitHash == null && stash != null),
         'Must provide either filePath, (commitHash + commitFilePath), or stash',
       );

  /// Factory constructor for file diffs (working directory)
  factory UnifiedDiffDialog.file({
    required String filePath,
    bool staged = false,
  }) {
    return UnifiedDiffDialog(filePath: filePath, staged: staged);
  }

  /// Factory constructor for commit file diffs
  factory UnifiedDiffDialog.commit({
    required String commitHash,
    required String filePath,
  }) {
    return UnifiedDiffDialog(commitHash: commitHash, commitFilePath: filePath);
  }

  /// Factory constructor for stash diffs
  factory UnifiedDiffDialog.stash({required GitStash stash}) {
    return UnifiedDiffDialog(stash: stash);
  }

  @override
  ConsumerState<UnifiedDiffDialog> createState() => _UnifiedDiffDialogState();
}

class _UnifiedDiffDialogState extends ConsumerState<UnifiedDiffDialog> {
  late bool _compactMode;
  // The dialog rebuilds on the compact toggle and on preview font changes; a
  // future created in build would re-run git and reset the viewer each time.
  late final Future<String> _diffFuture;

  @override
  void initState() {
    super.initState();
    // Initialize compact mode from config
    _compactMode = ref.read(configProvider).ui.diffCompactMode;
    _diffFuture = _loadDiff();
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
      icon: IconRole.gitDiff,
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
            icon: _compactMode ? IconRole.textOutdent : IconRole.textIndent,
            tooltip: _compactMode ? 'Compact View' : 'Normal View',
            onPressed: () async {
              setState(() {
                _compactMode = !_compactMode;
              });
              // Save to config
              await ref
                  .read(configProvider.notifier)
                  .setDiffCompactMode(_compactMode);
            },
          ),
      ],
      content: _buildDiffView(context),
      actions: _buildActions(context),
    );
  }

  Widget _buildDiffView(BuildContext context) {
    return FutureBuilder<String>(
      future: _diffFuture,
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
    // The facade (#430), now that its hero can say a failure (#431). The
    // reason recorded here for staying hand-built was that the facade "wants a
    // headline and a sentence" and this state says one thing - which the
    // facade file itself disproves: `ErrorState` is a one-statement state,
    // built out of this same member with `message: ''`. So the shape was never
    // the blocker; the hero's colour was, and it is a `Tone` now.
    //
    // The statement is passed through unchanged rather than routed via
    // `ErrorState`, which would prefix it with its own localized "Error:" and
    // change what the user reads. One delta rides along and is deliberate: the
    // hero goes from this copy's 48 dp to the member's 64, because the size is
    // the member's answer and a copy that will not follow the member is not a
    // copy. Its COLOUR is unchanged: the facade answers `Tone.danger` with the
    // very scheme role this mark was naming by hand.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: l10n.messageErrorLoadingDiff(error.toString()),
      message: '',
      tone: Tone.danger,
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
        leadingIcon: IconRole.copy,
        onPressed: () async {
          // Reuse the already-resolved diff instead of spawning a second git
          // process for content that is on screen.
          try {
            final diffOutput = await _diffFuture;
            await Clipboard.setData(ClipboardData(text: diffOutput));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.snackbarDiffCopied)));
            }
          } catch (e) {
            // The button stays enabled while the content area shows the load
            // error, and awaiting the failed future rethrows here, so the
            // failure has to be reported instead of escaping unhandled.
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.messageErrorLoadingDiff(e.toString())),
                ),
              );
            }
          }
        },
      ),
      if (canOpenExternalTool)
        BaseButton(
          label: l10n.labelOpenInExternalTool,
          variant: ButtonVariant.primary,
          leadingIcon: IconRole.arrowSquareOut,
          onPressed: () async {
            // Launching the external tool outlives the route's exit
            // transition, so the messenger is captured while the dialog
            // context is still mounted; afterwards the guard would be false
            // and the failure would go unreported.
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            // Open in external tool
            try {
              if (widget.staged) {
                await ref
                    .read(diffActionsProvider)
                    .diffStagedFile(widget.filePath!);
              } else {
                await ref
                    .read(diffActionsProvider)
                    .diffUnstagedFile(widget.filePath!);
              }
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.snackbarFailedToOpenExternalTool(e.toString()),
                  ),
                ),
              );
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
      final result = await gitService.getDiffForCommit(
        widget.commitHash!,
        widget.commitFilePath!,
      );
      return result.unwrap();
    } else {
      final result = await gitService.getDiff(
        widget.filePath!,
        staged: widget.staged,
      );
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
    builder: (context) =>
        UnifiedDiffDialog.file(filePath: filePath, staged: staged),
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
    builder: (context) =>
        UnifiedDiffDialog.commit(commitHash: commitHash, filePath: filePath),
  );
}

/// Show unified diff dialog for stash diffs
Future<void> showStashDiffDialog(
  BuildContext context, {
  required GitStash stash,
}) {
  return showDialog(
    context: context,
    builder: (context) => UnifiedDiffDialog.stash(stash: stash),
  );
}
