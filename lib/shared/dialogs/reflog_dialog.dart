import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../components/base_label.dart';
import '../theme/app_theme.dart';
import '../components/base_button.dart';
import '../components/copyable_text.dart';
import '../../core/git/git_providers.dart';
import '../components/base_dialog.dart';
import '../../core/git/models/reflog_entry.dart';
import '../components/base_list_item.dart';

/// Dialog for viewing Git reflog
class ReflogDialog extends ConsumerWidget {
  const ReflogDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reflogAsync = ref.watch(reflogProvider);

    return BaseDialog(
      icon: PhosphorIconsRegular.clockCounterClockwise,
      title: AppLocalizations.of(context)!.gitReflog,
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
        BaseButton(
          label: AppLocalizations.of(context)!.refresh,
          variant: ButtonVariant.tertiary,
          onPressed: () {
            ref.invalidate(reflogProvider);
          },
        ),
        BaseButton(
          label: AppLocalizations.of(context)!.close,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.clockCounterClockwise,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.noReflogEntries),
          const SizedBox(height: AppTheme.paddingS),
          BodyMediumLabel(AppLocalizations.of(context)!.referenceLogEmpty),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.paddingL),
          TitleLargeLabel(AppLocalizations.of(context)!.errorLoadingReflog),
          const SizedBox(height: AppTheme.paddingS),
          BodySmallLabel(error.toString(), textAlign: TextAlign.center),
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
          padding: const EdgeInsets.all(AppTheme.paddingM),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.info, size: 20),
              const SizedBox(width: AppTheme.paddingS),
              Expanded(
                child: BodySmallLabel(AppLocalizations.of(context)!.reflogEntriesInfo(entries.length)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.paddingM),

        // Reflog list
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingS,
          vertical: AppTheme.paddingXS,
        ),
        decoration: BoxDecoration(
          color: _getActionColor(entry.actionType, context).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: BodySmallLabel(
          entry.actionType,
          color: _getActionColor(entry.actionType, context),
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Hash (copyable)
              CopyableText(
                text: entry.shortHash,
                isMonospace: true,
                icon: PhosphorIconsRegular.gitCommit,
              ),
              const SizedBox(width: AppTheme.paddingS),
              // Selector
              BodySmallLabel(
                entry.selector,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          BodySmallLabel(
            entry.fullDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String actionType, BuildContext context) {
    switch (actionType) {
      case 'Commit':
        return AppTheme.gitAdded;
      case 'Checkout':
        return Theme.of(context).colorScheme.primary;
      case 'Merge':
        return Theme.of(context).colorScheme.tertiary;
      case 'Rebase':
        return Theme.of(context).colorScheme.secondary;
      case 'Reset':
        return AppTheme.gitDeleted;
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

