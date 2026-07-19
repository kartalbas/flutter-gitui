import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../../core/constants/constants.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/git/git_providers.dart';
import '../../../generated/app_localizations.dart';

/// Dialog for squashing multiple commits into one
Future<bool?> showSquashCommitsDialog(
  BuildContext context, {
  required List<GitCommit> commits,
  required Set<String> selectedHashes,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SquashCommitsDialog(
      commits: commits,
      selectedHashes: selectedHashes,
    ),
  );
}

class _SquashCommitsDialog extends ConsumerStatefulWidget {
  final List<GitCommit> commits;
  final Set<String> selectedHashes;

  const _SquashCommitsDialog({
    required this.commits,
    required this.selectedHashes,
  });

  @override
  ConsumerState<_SquashCommitsDialog> createState() => _SquashCommitsDialogState();
}

class _SquashCommitsDialogState extends ConsumerState<_SquashCommitsDialog> {
  late TextEditingController _messageController;
  late List<GitCommit> _selectedCommits;
  bool _areConsecutive = true;
  bool _isRootCommit = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Get selected commits in order
    _selectedCommits = widget.commits
        .where((c) => widget.selectedHashes.contains(c.hash))
        .toList();

    // Check if commits are consecutive
    _areConsecutive = _checkIfConsecutive();

    // Initialize message with the first (newest) commit's message
    if (_selectedCommits.isNotEmpty) {
      _messageController = TextEditingController(text: _selectedCommits.first.message);
    } else {
      _messageController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool _checkIfConsecutive() {
    if (_selectedCommits.length < 2) return false;

    // The displayed list can be search-filtered or truncated by the commit
    // limit, so positions in it say nothing about real adjacency. Walk the
    // parent chain instead: each newer commit must have the next selected
    // commit as its first parent, otherwise the reset-based squash would
    // silently absorb the unselected commits in between.
    for (int i = 1; i < _selectedCommits.length; i++) {
      final newer = _selectedCommits[i - 1];
      if (newer.parents.isEmpty ||
          newer.parents.first != _selectedCommits[i].hash) {
        return false;
      }
    }

    // The root commit has no parent to reset onto, so it cannot be squashed.
    if (_selectedCommits.last.parents.isEmpty) {
      _isRootCommit = true;
      return false;
    }

    return true;
  }

  Future<void> _squash() async {
    if (!_areConsecutive) {
      return;
    }

    final newMessage = _messageController.text.trim();
    if (newMessage.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.commitMessageCannotBeEmpty;
      });
      return;
    }

    try {
      // Sort commits from oldest to newest for squashing
      final sortedCommits = List<GitCommit>.from(_selectedCommits)
        ..sort((a, b) {
          final aIndex = widget.commits.indexOf(a);
          final bIndex = widget.commits.indexOf(b);
          return bIndex.compareTo(aIndex); // Reverse order (oldest first)
        });

      // Get the commit range
      final oldestCommit = sortedCommits.first;
      final newestCommit = sortedCommits.last;

      // Call squash method
      await ref.read(gitActionsProvider).squashCommits(
        fromCommit: oldestCommit.hash,
        toCommit: newestCommit.hash,
        newMessage: newMessage,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.failedToSquashCommits(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Localization lookups register an inherited-widget dependency, which is
    // forbidden while initState runs, so the checks done there only record
    // flags and the message is resolved here.
    final errorMessage = _errorMessage ??
        (_isRootCommit
            ? l10n.cannotSquashRootCommit
            : (!_areConsecutive ? l10n.selectedCommitsMustBeConsecutive : null));

    return BaseDialog(
      title: l10n.squashCommitsDialog,
      icon: PhosphorIconsRegular.arrowsInLineVertical,
      variant: DialogVariant.normal,
      maxWidth: AppConstants.maxDialogWidth,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.paddingM),
                  Expanded(
                    child: BodyMediumLabel(
                      errorMessage,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppTheme.paddingM),

          TitleSmallLabel(
            l10n.squashingCommitsCount(_selectedCommits.length),
          ),
          const SizedBox(height: AppTheme.paddingS),

          // List of commits being squashed
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _selectedCommits.length,
              itemBuilder: (context, index) {
                final commit = _selectedCommits[index];
                return BaseListItem(
                  leading: Icon(
                    PhosphorIconsRegular.gitCommit,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BodyMediumLabel(
                        commit.shortSubject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      LabelMediumLabel(
                        '${commit.shortHash} by ${commit.author}',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppTheme.paddingL),

          TitleSmallLabel(
            l10n.newCommitMessage,
          ),
          const SizedBox(height: AppTheme.paddingS),

          BaseTextField(
            controller: _messageController,
            hintText: l10n.enterCommitMessageForSquashed,
            maxLines: 5,
            autofocus: true,
          ),

          const SizedBox(height: AppTheme.paddingM),

          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.info,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.paddingS),
                Expanded(
                  child: BodySmallLabel(
                    l10n.squashCommitsInfo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        BaseButton(
          label: l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: l10n.squashCommits,
          variant: ButtonVariant.primary,
          onPressed: _areConsecutive ? _squash : null,
        ),
      ],
    );
  }
}
