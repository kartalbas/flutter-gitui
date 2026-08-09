import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/git/git_providers.dart';
import '../../../generated/app_localizations.dart';

/// Dialog for squashing multiple commits into one
///
/// [selectedCommits] arrives already resolved against the displayed history,
/// newest first, so the dialog never has to decide what an unlisted hash means.
Future<bool?> showSquashCommitsDialog(
  BuildContext context, {
  required List<GitCommit> selectedCommits,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _SquashCommitsDialog(selectedCommits: selectedCommits),
  );
}

class _SquashCommitsDialog extends ConsumerStatefulWidget {
  final List<GitCommit> selectedCommits;

  const _SquashCommitsDialog({required this.selectedCommits});

  @override
  ConsumerState<_SquashCommitsDialog> createState() =>
      _SquashCommitsDialogState();
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

    _selectedCommits = widget.selectedCommits;

    // Check if commits are consecutive
    _areConsecutive = _checkIfConsecutive();

    // Initialize message with the first (newest) commit's message
    if (_selectedCommits.isNotEmpty) {
      _messageController = TextEditingController(
        text: _selectedCommits.first.message,
      );
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
        _errorMessage = AppLocalizations.of(
          context,
        )!.commitMessageCannotBeEmpty;
      });
      return;
    }

    try {
      // The selection arrives in display order, so reversing it yields the
      // oldest-to-newest range the squash resets onto.
      final oldestFirst = _selectedCommits.reversed.toList();

      // Get the commit range
      final oldestCommit = oldestFirst.first;
      final newestCommit = oldestFirst.last;

      // Call squash method
      // confirmed-by: this dialog itself; writing the message and pressing
      // Squash is the confirmation.
      await ref
          .read(gitActionsProvider)
          .squashCommits(
            fromCommit: oldestCommit.hash,
            toCommit: newestCommit.hash,
            newMessage: newMessage,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(
          context,
        )!.failedToSquashCommits(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Localization lookups register an inherited-widget dependency, which is
    // forbidden while initState runs, so the checks done there only record
    // flags and the message is resolved here.
    final errorMessage =
        _errorMessage ??
        (_isRootCommit
            ? l10n.cannotSquashRootCommit
            : (!_areConsecutive
                  ? l10n.selectedCommitsMustBeConsecutive
                  : null));

    return BaseDialog(
      title: l10n.squashCommitsDialog,
      icon: IconRole.arrowsInLineVertical,
      variant: DialogVariant.normal,
      // The combined commit message is a field the user fills in, so this is
      // the `form` extent (BaseDialog's default) and how wide a form should be
      // is the skin's answer rather than a constant named here.
      // The message field is multiline, so Enter inside it writes a newline;
      // Enter anywhere else squashes.
      onSubmit: _areConsecutive ? _squash : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null)
            Container(
              // The callout's fill and corner stay: they are the surface, and
              // the surface leaves with `surfaces.banner`.
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              // The callout paints its own fill, so it states the paired
              // foreground once here and the message inside says nothing
              // about colour.
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                child: BaseInset(
                  child: Row(
                    children: [
                      // The error banner's mark, at the same rung as the
                      // identical banner in the clone, initialize and merge
                      // dialogs: one meaning, one scale, and that scale is
                      // the ordinary one. What it means is that the selection
                      // this dialog was opened on cannot be squashed, which
                      // is `danger` rather than a colour slot.
                      const BaseIcon(IconRole.warningCircle, tone: Tone.danger),
                      const BaseGap(Proximity.grouped),
                      Expanded(
                        child: BaseLabel(errorMessage, role: TextRole.body),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const BaseGap(Proximity.grouped),

          BaseLabel(
            l10n.squashingCommitsCount(_selectedCommits.length),
            role: TextRole.sectionTitle,
          ),
          // A section title and the list it names are two parts of one
          // statement: `related`.
          const BaseGap(Proximity.related),

          // List of commits being squashed
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _selectedCommits.length,
              itemBuilder: (context, index) {
                final commit = _selectedCommits[index];
                return BaseListItem(
                  leading: const BaseIcon(
                    IconRole.gitCommit,
                    scale: ControlScale.compact,
                    tone: Tone.accent,
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(
                        commit.shortSubject,
                        role: TextRole.body,
                        maxLines: 1,
                      ),
                      BaseLabel(
                        '${commit.shortHash} by ${commit.author}',
                        role: TextRole.detail,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Two groups inside one form: `separate`.
          const BaseGap(Proximity.separate),

          BaseLabel(l10n.newCommitMessage, role: TextRole.sectionTitle),
          const BaseGap(Proximity.related),

          BaseTextField(
            controller: _messageController,
            hintText: l10n.enterCommitMessageForSquashed,
            maxLines: 5,
            autofocus: true,
          ),

          const BaseGap(Proximity.grouped),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              child: Row(
                children: [
                  // A note's own mark: dense, and carrying the application's
                  // colour. It named a number on no ladder in the application,
                  // for want of a word for the job.
                  const BaseIcon(
                    IconRole.info,
                    scale: ControlScale.compact,
                    tone: Tone.accent,
                  ),
                  const BaseGap(Proximity.related),
                  Expanded(
                    child: BaseLabel(
                      l10n.squashCommitsInfo,
                      role: TextRole.detail,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogAction(
          label: l10n.squashCommits,
          role: DialogActionRole.affirmative,
          enabled: _areConsecutive,
          onPressed: _squash,
        ),
      ],
    );
  }
}
