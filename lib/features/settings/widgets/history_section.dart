import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, TextRole, ToggleKind;
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_toggle_row.dart';
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
          // The row's own mark. The prominent scale is what a bare `Icon`
          // rendered at under the row's ambient icon theme, and the neutral
          // tone leaves the colour to the row, as before.
          leading: const BaseIcon(
            IconRole.listNumbers,
            scale: ControlScale.prominent,
          ),
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
        BaseToggleRow(
          leading: IconRole.graph,
          label: l10n.showCommitGraph,
          description: l10n.showCommitGraphDescription,
          value: history.showCommitGraph,
          // Takes effect the moment it changes; nothing to confirm.
          kind: ToggleKind.switching,
          onChanged: (value) {
            ref
                .read(configProvider.notifier)
                .setShowCommitGraph(value ?? false);
          },
        ),
      ],
    );
  }
}
