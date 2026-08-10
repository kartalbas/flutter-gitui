import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../../../shared/components/base_card.dart';
import '../../../shared/components/base_dialog.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../core/git/models/commit.dart';
import '../../../core/git/git_service.dart';
import '../../../generated/app_localizations.dart';

/// Dialog to choose reset mode when resetting to a commit
class ResetModeDialog extends StatelessWidget {
  final GitCommit commit;

  const ResetModeDialog({super.key, required this.commit});

  /// Asks for the reset mode, on the skin's own dialog route.
  ///
  /// The frame is the same on every build and every action only pops, so the
  /// whole dialog can be stated before it exists - which is what lets it
  /// reach `Overlays.dialog` rather than Material's `showDialog`.
  static Future<ResetMode?> show(
    BuildContext context, {
    required GitCommit commit,
  }) => BaseDialog.show<ResetMode>(
    context: context,
    dialog: _dialog(context, commit),
  );

  @override
  Widget build(BuildContext context) => _dialog(context, commit);

  static BaseDialog _dialog(BuildContext context, GitCommit commit) {
    final l10n = AppLocalizations.of(context)!;

    return BaseDialog(
      title: l10n.resetToCommit,
      icon: IconRole.arrowCounterClockwise,
      variant: DialogVariant.normal,
      // `form` is the middle rung, taken here for want of a better one: the
      // dialog states what will happen and offers FOUR answers (soft, mixed,
      // hard, cancel), which is past `alert`'s "a sentence and up to two
      // answers", and it holds no fields. See the reported DialogExtent gap.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BaseLabel(l10n.resetCurrentBranchTo, role: TextRole.body),
          const BaseGap(Proximity.related),
          // **Here is one self-contained object** - the commit the branch
          // pointer is being moved to. The twin of the strip in
          // `create_branch_from_commit_dialog.dart`, and the pair is the
          // corner argument in miniature: same statement, same kind of object,
          // one rounded at 8 and the other at 4, because neither screen could
          // see the other. One member now answers both.
          BaseCard(
            isSelectable: false,
            inset: Inset.normal,
            content: Row(
              children: [
                const BaseIcon(
                  IconRole.gitCommit,
                  scale: ControlScale.compact,
                  tone: Tone.accent,
                ),
                const BaseGap(Proximity.related),
                Expanded(
                  child: Column(
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
                ),
              ],
            ),
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(l10n.chooseResetMode, role: TextRole.sectionTitle),
          const BaseGap(Proximity.related),
          BaseLabel(l10n.branchPointerWillMove, role: TextRole.detail),
        ],
      ),
      // Soft, mixed and hard are three different resets, not one action with
      // two alternatives, so none of them is the affirmative one and Enter
      // must not pick for the user (see the null onSubmit above). The two
      // recoverable modes are peers; only the hard reset destroys work, and
      // saying so on the action is what lets a language that has no red fill
      // still mark it (Cupertino's isDestructiveAction).
      actions: [
        DialogAction(
          label: l10n.cancel,
          role: DialogActionRole.dismissive,
          onPressed: () => Navigator.of(context).pop(),
        ),
        DialogAction(
          label: '${l10n.soft}\n(${l10n.keepChangesStagedSoft})',
          role: DialogActionRole.neutral,
          onPressed: () => Navigator.of(context).pop(ResetMode.soft),
        ),
        DialogAction(
          label: '${l10n.mixed}\n(${l10n.keepChangesUnstagedMixed})',
          role: DialogActionRole.neutral,
          onPressed: () => Navigator.of(context).pop(ResetMode.mixed),
        ),
        DialogAction(
          label: '${l10n.hard}\n(${l10n.discardAllChangesHard})',
          role: DialogActionRole.destructive,
          onPressed: () => Navigator.of(context).pop(ResetMode.hard),
        ),
      ],
    );
  }
}
