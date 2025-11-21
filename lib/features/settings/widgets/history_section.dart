import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import 'settings_section.dart';

/// History settings section for settings screen
class HistorySection extends ConsumerWidget {
  final VoidCallback onEditCommitHistoryLimit;

  const HistorySection({
    super.key,
    required this.onEditCommitHistoryLimit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(historyConfigProvider);

    return SettingsSection(
      title: l10n.history,
      icon: PhosphorIconsRegular.clockCounterClockwise,
      children: [
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.listNumbers),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.defaultCommitLimit),
              BodySmallLabel(
                l10n.defaultCommitLimitDescription(history.defaultCommitLimit),
              ),
            ],
          ),
          trailing: BaseIconButton(
            icon: PhosphorIconsRegular.pencil,
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
