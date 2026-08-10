import 'package:flutter/widgets.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        AvatarSpec,
        ControlScale,
        IconRole,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;

import '../../../generated/app_localizations.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../shared/widgets/file_status_badge.dart';
import '../../../core/git/models/file_status.dart';

/// Individual file item in the changes list
class FileListItem extends StatelessWidget {
  final FileStatus file;
  final bool isStaged;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onStage;
  final VoidCallback? onUnstage;
  final VoidCallback? onDiscard;
  final VoidCallback? onDiff;

  const FileListItem({
    super.key,
    required this.file,
    required this.isStaged,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onStage,
    this.onUnstage,
    this.onDiscard,
    this.onDiff,
  });

  @override
  Widget build(BuildContext context) {
    final status = file.primaryStatus;
    final isRenamed = status == FileStatusType.renamed;

    return BaseListItem(
      isSelected: isSelected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      leading: _buildStatusIndicator(status, context),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File path
          BaseLabel(file.path, role: TextRole.body, maxLines: 1),
          // The path and the status beneath it are two halves of one thing:
          // `hairline`. This row and every comparable row in the application
          // used to say that relationship with two different numbers; naming
          // it settles both on the skin's single answer.
          const BaseGap(Proximity.hairline),

          // Status and old path for renames
          Row(
            children: [
              // The status pill, drawn by the one component that owns its
              // drawing rather than by a hand-painted copy of it: this row
              // and the status tree said the same fact at two different
              // insets (h6/v2 here against the component's h4/v2), and the
              // collapse settles both on the component's answer. The pill
              // narrows 2px per side here, deliberately - one meaning, one
              // measure, stated once until `surfaces.badge` makes it the
              // skin's.
              FileStatusBadge(
                code: status.displayName,
                color: status.colorOf(context),
                tone: status.toneOf,
              ),

              // Old path for renames
              if (isRenamed && file.oldPath != null) ...[
                const BaseGap(Proximity.related),
                Flexible(
                  child: BaseLabel(
                    'from ${file.oldPath}',
                    role: TextRole.detail,
                    tone: Tone.muted,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: _buildActions(context),
    );
  }

  Widget _buildStatusIndicator(FileStatusType status, BuildContext context) {
    // What happened to this file, as a mark rather than as a glyph: the switch
    // names the IDEA and the skin picks the drawing, so a language with its
    // own vocabulary for "added" is not stuck with Phosphor's plus.
    final IconRole role = switch (status) {
      FileStatusType.added => IconRole.plus,
      FileStatusType.modified => IconRole.pencilSimple,
      FileStatusType.deleted => IconRole.minus,
      FileStatusType.renamed => IconRole.arrowsLeftRight,
      FileStatusType.copied => IconRole.copy,
      FileStatusType.untracked => IconRole.filePlus,
      _ => IconRole.file,
    };

    // A fill, a corner, an inset and a glyph size around one mark is the
    // application drawing an avatar by hand — the same construction the
    // workspace card and the workspace row both gave up last pass, and the
    // member's own words for it: "which person or thing is this, as a single
    // compact mark". At the head of this row the mark stands for WHAT KIND OF
    // THING the row is about — a modified file, an added one — which is the
    // question the leading slot asks.
    //
    // The mark and the ground it sits on disagreed here, and that is what the
    // corner was hiding. The glyph read `toneOf` while the wash under it read
    // `colorOf`, and the two differ for exactly one status: an unmerged file
    // wore the conflict colour on the deletion colour, because `colorOf` had
    // to borrow the strongest signal the old palette carried. The member
    // resolves the ground and the mark from ONE tone, so a conflicted file is
    // conflict-coloured through and through and the pair cannot drift again.
    return SkinScope.render(
      context,
      (Skin skin, BuildContext inner) => skin.surfaces.avatar(
        inner,
        AvatarSpec(
          glyph: role,
          tone: status.toneOf,
          // A row-level mark is `compact`, and the plate moves to say it:
          // the hand-painted ~28 dp rounded square (a 6 dp inset around a
          // 16 dp glyph, an 8 dp corner, a 20 % wash) becomes the member's
          // 24 dp circle drawing its glyph at 12 — the same measure every
          // workspace row's avatar already wears, which is why the member's
          // answer is right and the copy was the drift. Nothing on a shipped
          // screen moves TODAY: this widget has no call site left in lib/
          // (the changes screen renders its tree view instead) and survives
          // for the material conformance scene `screen_changes_file_rows`,
          // whose Linux-rendered golden this conversion moves. Its deletion
          // — widget, scene section and glyph-census entry together —
          // belongs to the changes-screen slice, not to a token sweep.
          scale: ControlScale.compact,
          semanticsLabel: status.displayName,
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Diff button
        if (onDiff != null)
          BaseIconButton(
            icon: IconRole.gitDiff,
            tooltip: AppLocalizations.of(context)!.tooltipViewDiff,
            onPressed: onDiff,
            size: ButtonSize.small,
          ),

        const BaseGap(Proximity.hairline),

        // Stage/Unstage button
        if (isStaged)
          BaseIconButton(
            icon: IconRole.minus,
            tooltip: AppLocalizations.of(context)!.tooltipUnstage,
            onPressed: onUnstage,
            size: ButtonSize.small,
          )
        else
          BaseIconButton(
            icon: IconRole.plus,
            tooltip: AppLocalizations.of(context)!.tooltipStage,
            onPressed: onStage,
            size: ButtonSize.small,
          ),

        // Discard button (only for unstaged files)
        if (!isStaged && onDiscard != null) ...[
          const BaseGap(Proximity.hairline),
          BaseIconButton(
            icon: IconRole.trash,
            tooltip: AppLocalizations.of(context)!.tooltipDiscardChanges,
            onPressed: onDiscard,
            size: ButtonSize.small,
            variant: ButtonVariant.danger,
          ),
        ],
      ],
    );
  }
}
