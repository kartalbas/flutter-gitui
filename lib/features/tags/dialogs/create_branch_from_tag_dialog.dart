import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_text_field.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';

/// Dialog for creating a branch from a tag
class CreateBranchFromTagDialog extends StatefulWidget {
  final String tagName;

  const CreateBranchFromTagDialog({super.key, required this.tagName});

  @override
  State<CreateBranchFromTagDialog> createState() =>
      _CreateBranchFromTagDialogState();
}

class _CreateBranchFromTagDialogState extends State<CreateBranchFromTagDialog> {
  late TextEditingController _branchNameController;
  bool _checkout = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _branchNameController = TextEditingController();
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.createBranchFromTag,
      icon: IconRole.gitBranch,
      onSubmit: _createBranch,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag info: **here is one self-contained object** - the tag this
          // branch will start from. The same strip as the commit variant in
          // `create_branch_from_commit_dialog.dart`, down to the fill and the
          // 4 dp corner, and it becomes the same member so the two cannot
          // drift apart again.
          BaseCard(
            isSelectable: false,
            inset: Inset.normal,
            content: Row(
              children: [
                // The mark on the strip that names the tag this branch will
                // start from: a dense row-level glyph, and secondary to the
                // tag name it introduces rather than competing with it.
                const BaseIcon(
                  IconRole.tag,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseLabel(
                        l10n.sourceTag,
                        role: TextRole.micro,
                        tone: Tone.muted,
                      ),
                      BaseLabel(widget.tagName, role: TextRole.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

    // Return the result
    Navigator.of(
      context,
    ).pop({'branchName': branchName, 'checkout': _checkout});
  }
}
