import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, TextRole;
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import 'settings_section.dart';

/// History settings section for settings screen
class HistorySection extends ConsumerWidget {
  final VoidCallback onEditCommitHistoryLimit;

  const HistorySection({super.key, required this.onEditCommitHistoryLimit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(historyConfigProvider);

    return SettingsSection(
      title: l10n.history,
      icon: IconRole.clockCounterClockwise,
      children: [
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.listNumbers),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.defaultCommitLimit, role: TextRole.body),
              BaseLabel(
                l10n.defaultCommitLimitDescription(history.defaultCommitLimit),
                role: TextRole.detail,
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: IconRole.pencil,
            // Every icon-only control names its action, for the tooltip a
            // pointer user reads and for the label a keyboard or screen-reader
            // user hears when Tab lands here.
            tooltip: l10n.edit,
            onPressed: onEditCommitHistoryLimit,
          ),
        ),
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.graph),
          title: Text(l10n.showCommitGraph),
          subtitle: Text(l10n.showCommitGraphDescription),
          value: history.showCommitGraph,
          onChanged: (value) {
            ref.read(configProvider.notifier).setShowCommitGraph(value);
          },
        ),
      ],
    );
  }
}
