import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show BannerSpec, IconRole, Proximity, Skin, SkinScope, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../components/base_progress.dart';
import '../theme/app_theme.dart';
import '../components/copyable_text.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../../core/git/models/reflog_entry.dart';
import '../components/base_list_item.dart';
import '../components/base_layout.dart';
import '../widgets/empty_state.dart';

/// Dialog for viewing Git reflog
class ReflogDialog extends ConsumerWidget {
  const ReflogDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reflogAsync = ref.watch(reflogProvider);

    return BaseDialog(
      icon: IconRole.clockCounterClockwise,
      title: AppLocalizations.of(context)!.gitReflog,
      onSubmit: () => Navigator.of(context).pop(),
      content: reflogAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _buildEmpty(context);
          }
          return _buildReflogList(context, entries);
        },
        loading: () => const BaseProgress.block(),
        error: (error, _) => _buildError(context, error),
      ),
      actions: [
        // Refresh re-reads the reflog and leaves the dialog open, so it is a
        // peer of the close action rather than a second way to finish.
        DialogAction(
          label: AppLocalizations.of(context)!.refresh,
          role: DialogActionRole.neutral,
          onPressed: () {
            ref.invalidate(reflogProvider);
          },
        ),
        // A viewer with nothing to confirm: closing it is completing it, and
        // Enter fires exactly this action.
        DialogAction(
          label: AppLocalizations.of(context)!.close,
          role: DialogActionRole.affirmative,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // A reflog with nothing in it stands in place of this dialog's whole
    // content, which is the empty-state hero rather than a column this dialog
    // arranges itself (#430). The `64` went with it: `EmptyStateSpec` takes an
    // icon, a headline, a sentence and the ways out and NO size, so a glyph
    // size written here was a leak by construction - and `colorScheme
    // .onSurfaceVariant` was Material's answer to the supporting foreground
    // the member already paints its hero in, unchanged.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.clockCounterClockwise,
      title: AppLocalizations.of(context)!.noReflogEntries,
      message: AppLocalizations.of(context)!.referenceLogEmpty,
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    // The sibling of `_buildEmpty` above, and no longer the one shape the
    // facade cannot take: the hero carries a tone now (#431), and
    // `Tone.danger` is the whole difference between "there is nothing here"
    // and "this went wrong", stated as a meaning rather than as a colour
    // this dialog picked. The `64` goes the way `_buildEmpty`'s went (#430),
    // and the sentence under the headline takes the member's own treatment
    // with it.
    return EmptyStateWidget(
      icon: PhosphorIconsRegular.warningCircle,
      title: AppLocalizations.of(context)!.errorLoadingReflog,
      message: error.toString(),
      tone: Tone.danger,
    );
  }

  Widget _buildReflogList(BuildContext context, List<ReflogEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **Something about this whole surface needs saying**: how many
        // entries the reflog below is showing. The comment this line replaces
        // called it a banner and then drew one by hand - a neutral wash, a
        // 12 dp corner, an inset, a mark and a line of `detail` - and every
        // one of those five is the SURFACE, which is the member's. `Tone.info`
        // is the word for what it says ("this is worth knowing and nothing is
        // wrong"), so the mark no longer has to carry that meaning alone
        // beside a wash that carried none: Material answers info with the
        // primary container, which is why the strip is tinted now rather than
        // grey.
        SkinScope.render(context, (Skin skin, BuildContext inner) {
          return skin.surfaces.banner(
            inner,
            BannerSpec(
              tone: Tone.info,
              title: AppLocalizations.of(
                context,
              )!.reflogEntriesInfo(entries.length),
              icon: IconRole.info,
            ),
          );
        }),
        const BaseGap(Proximity.grouped),

        // The list needs a bounded height: BaseDialog wraps the content in a
        // SingleChildScrollView, so a flex child would sit in an unbounded
        // Column and throw. The cap lets the dialog grow with its content up
        // to 400 and scroll beyond that.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            // Not `BaseSeparator`: `height: 1` is a measurement - a rule
            // between dense rows that takes no layout space - which the
            // separator member deliberately does not carry.
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildReflogItem(context, entry);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReflogItem(BuildContext context, ReflogEntry entry) {
    return BaseListItem(
      leading: Container(
        decoration: BoxDecoration(
          color: _getActionColor(
            entry.actionType,
            context,
          ).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        // The chip is washed with the action's own colour and states it as its
        // foreground; the action name inside reads that. `_getActionColor`
        // stays a `Color` for now because the same value paints the wash, and
        // until this chip is `surfaces.badge` at P3d there is no contract
        // member that can tint a surface from a `Tone`.
        //
        // A second blocker sits underneath that one and outlives it, so it is
        // named here rather than discovered again: two of the eight actions
        // answer with `colorScheme.tertiary` (Merge, Cherry-pick) and two with
        // `colorScheme.secondary` (Rebase, Revert), and [Tone] has no word for
        // either. They are not `accent` - `primary` is already spoken for by
        // Checkout and Pull right beside them, so calling all six `accent`
        // would erase a distinction this list draws deliberately. Reported
        // rather than rounded (#426): converting this helper needs either a
        // second and third accent in the vocabulary or a decision that the
        // reflog should stop colour-coding by action at all.
        //
        // The chip's inset stays a literal: across it is `tight` exactly,
        // but its vertical 4 is on no `Inset` rung - rounding it up to
        // `tight` would grow every reflog row's leading chip 8px taller.
        // Both halves wait for `surfaces.badge`, whose skin owns a badge's
        // measure.
        //
        // The 4 dp corner stays for the same reason and only that reason. It
        // is not waiting for a corner word - there is none and there will be
        // none - it is waiting for the decoration it belongs to to become
        // `surfaces.badge`, and it dies with that decoration in one move. It
        // is the only radius left in this file, and the only one in it that a
        // member cannot take today.
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingS,
          vertical: AppTheme.paddingXS,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: _getActionColor(entry.actionType, context)),
          child: BaseLabel(entry.actionType, role: TextRole.detail),
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Hash (copyable)
              CopyableText(text: entry.shortHash, icon: IconRole.gitCommit),
              const BaseGap(Proximity.related),
              // Selector
              BaseLabel(
                entry.selector,
                role: TextRole.detail,
                tone: Tone.accent,
              ),
            ],
          ),
          BaseLabel(entry.fullDescription, role: TextRole.detail, maxLines: 2),
        ],
      ),
    );
  }

  Color _getActionColor(String actionType, BuildContext context) {
    switch (actionType) {
      case 'Commit':
        return context.gitColors.added;
      case 'Checkout':
        return Theme.of(context).colorScheme.primary;
      case 'Merge':
        return Theme.of(context).colorScheme.tertiary;
      case 'Rebase':
        return Theme.of(context).colorScheme.secondary;
      case 'Reset':
        return context.gitColors.deleted;
      case 'Pull':
        return Theme.of(context).colorScheme.primary;
      case 'Cherry-pick':
        return Theme.of(context).colorScheme.tertiary;
      case 'Revert':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}

/// Show reflog dialog
Future<void> showReflogDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const ReflogDialog(),
  );
}
