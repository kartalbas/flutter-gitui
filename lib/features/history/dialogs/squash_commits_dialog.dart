import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        IconRole,
        Inset,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../shared/components/base_card.dart';
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
          // **Something about this whole surface needs saying**, and the
          // surface leaves with it, exactly as this site predicted. The fill
          // and the corner were the callout; so was the
          // `DefaultTextStyle.merge` that had to state the paired foreground
          // because the application had chosen the fill. `Tone.danger`
          // resolves under Material to the same
          // `errorContainer`/`onErrorContainer` pair, so the pairing survives
          // without either half crossing the seam.
          if (errorMessage != null)
            SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.banner(
                inner,
                // The message is the banner's `title` and not its `body`,
                // because `title` is "the statement" in the spec's own words
                // and this callout has exactly one - what it says is why the
                // selection cannot be squashed.
                BannerSpec(
                  tone: Tone.danger,
                  title: errorMessage,
                  icon: IconRole.warningCircle,
                ),
              );
            }),
          const BaseGap(Proximity.grouped),

          BaseLabel(
            l10n.squashingCommitsCount(_selectedCommits.length),
            role: TextRole.sectionTitle,
          ),
          // A section title and the list it names are two parts of one
          // statement: `related`.
          const BaseGap(Proximity.related),

          // List of commits being squashed.
          //
          // The bordered box round the list is a CARD, and `Inset.none` is
          // the rung `BaseCard`'s own doc names for it: "a list that must
          // reach the card's border". The stroke and the corner were the
          // card's edge drawn by hand - the application picking Material's
          // `outline` and its own 8 - and both are the skin's now, so the
          // rows inside are clipped by whatever corner this language rounds
          // its cards at instead of overhanging one the screen invented.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: BaseCard(
              isSelectable: false,
              inset: Inset.none,
              content: ListView.builder(
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

          // The second banner in this dialog, and it passes the test the
          // member's own question sets: it says what the dialog's action will
          // do to the whole selection, not what one control above it means.
          // `Tone.info` - "this is worth knowing and nothing is wrong" - is
          // what the accent info mark was already saying in Material's words,
          // and it is now said once instead of split between a mark's tone
          // and a container's fill.
          SkinScope.render(context, (Skin skin, BuildContext inner) {
            return skin.surfaces.banner(
              inner,
              BannerSpec(
                tone: Tone.info,
                title: l10n.squashCommitsInfo,
                icon: IconRole.info,
              ),
            );
          }),
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
