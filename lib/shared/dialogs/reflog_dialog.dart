import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, Proximity, TextRole, Tone;

import '../../generated/app_localizations.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
    // The sibling of `_buildEmpty` above, and the one shape the facade cannot
    // take: the blocker is the mark's COLOUR, not its size.
    // `EmptyStateWidget` paints its hero in the supporting foreground
    // unconditionally and carries no tone slot, so adopting it here would turn
    // a red failure mark grey - the whole difference between "there is nothing
    // here" and "this went wrong" - which is a change of appearance rather
    // than a rename. Reported instead: the facade needs a tone on its hero
    // before this converts, and the size leaves with the colour.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const BaseGap(Proximity.separate),
          BaseLabel(
            AppLocalizations.of(context)!.errorLoadingReflog,
            role: TextRole.pageTitle,
          ),
          const BaseGap(Proximity.related),
          BaseLabel(
            error.toString(),
            role: TextRole.detail,
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReflogList(BuildContext context, List<ReflogEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info banner
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: BaseInset(
            child: Row(
              children: [
                // The mark of an ordinary notice, at the ordinary size: it
                // belongs to the line beside it rather than standing over it.
                const BaseIcon(IconRole.info),
                const BaseGap(Proximity.related),
                Expanded(
                  child: BaseLabel(
                    AppLocalizations.of(
                      context,
                    )!.reflogEntriesInfo(entries.length),
                    role: TextRole.detail,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // The chip's inset stays a literal: across it is `tight` exactly,
        // but its vertical 4 is on no `Inset` rung - rounding it up to
        // `tight` would grow every reflog row's leading chip 8px taller.
        // Both halves wait for `surfaces.badge`, whose skin owns a badge's
        // measure.
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
