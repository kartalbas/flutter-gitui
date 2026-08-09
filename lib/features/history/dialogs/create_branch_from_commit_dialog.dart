import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../core/git/models/commit.dart';

/// Dialog for creating a branch from a commit in the history view.
///
/// Returns `{'branchName': String, 'checkout': bool}` like the tag variant,
/// so the caller runs the actual `git branch` through the shared commit
/// action sequence instead of the dialog invoking git itself.
class CreateBranchFromCommitDialog extends StatefulWidget {
  final GitCommit commit;

  const CreateBranchFromCommitDialog({super.key, required this.commit});

  @override
  State<CreateBranchFromCommitDialog> createState() =>
      _CreateBranchFromCommitDialogState();
}

class _CreateBranchFromCommitDialogState
    extends State<CreateBranchFromCommitDialog> {
  final _branchNameController = TextEditingController();
  bool _checkout = true;
  String? _errorMessage;

  @override
  void dispose() {
    _branchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.createBranchFromCommit,
      icon: IconRole.gitBranch,
      onSubmit: _createBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source commit info: **here is one self-contained object** - the
          // commit this branch will start from. Its fill and its 4 dp corner
          // were a card drawn by hand, and the corner is the sharpest evidence
          // that the application should never have been naming one: the twin
          // strip in `reset_mode_dialog.dart` says the same thing about the
          // same kind of object and rounded it at 8. Neither screen could see
          // the other; the member answers both with one corner.
          BaseCard(
            isSelectable: false,
            inset: Inset.normal,
            content: Row(
              children: [
                const BaseIcon(
                  IconRole.gitCommit,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(
                        l10n.sourceCommit,
                        role: TextRole.micro,
                        tone: Tone.muted,
                      ),
                      BaseLabel(
                        '${widget.commit.shortHash} '
                        '${widget.commit.shortSubject}',
                        role: TextRole.body,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Two groups inside one form: `separate`.
          const BaseGap(Proximity.separate),

          // Branch name input
          BaseTextField(
            controller: _branchNameController,
            label: l10n.branchName,
            hintText: l10n.branchNameHint,
            prefixIcon: IconRole.gitBranch,
            autofocus: true,
            errorText: _errorMessage,
            onChanged: (value) {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
          const BaseGap(Proximity.grouped),

          // Checkout option
          CheckboxListTile(
            value: _checkout,
            onChanged: (value) {
              setState(() {
                _checkout = value ?? true;
              });
            },
            title: BaseLabel(
              l10n.checkoutBranchAfterCreation,
              role: TextRole.body,
            ),
            subtitle: BaseLabel(
              l10n.checkoutBranchAfterCreationHint,
              role: TextRole.detail,
              tone: Tone.muted,
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: l10n.createBranch,
          role: DialogActionRole.affirmative,
          icon: IconRole.gitBranch,
          onPressed: _createBranch,
        ),
      ],
    );
  }

  void _createBranch() {
    final branchName = _branchNameController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (branchName.isEmpty) {
      setState(() {
        _errorMessage = l10n.branchNameRequired;
      });
      return;
    }

    Navigator.of(
      context,
    ).pop({'branchName': branchName, 'checkout': _checkout});
  }
}
