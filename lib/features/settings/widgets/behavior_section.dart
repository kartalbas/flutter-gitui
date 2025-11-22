import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import 'settings_section.dart';

/// Behavior settings section for settings screen
class BehaviorSection extends ConsumerWidget {
  final VoidCallback onEditAutoFetchInterval;

  const BehaviorSection({
    super.key,
    required this.onEditAutoFetchInterval,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final behavior = ref.watch(behaviorConfigProvider);

    return SettingsSection(
      title: l10n.behavior,
      icon: PhosphorIconsRegular.sliders,
      children: [
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.arrowsClockwise),
          title: Text(l10n.autoFetch),
          subtitle: Text(l10n.autoFetchDescription),
          value: behavior.autoFetch,
          onChanged: (value) {
            ref.read(configProvider.notifier).setAutoFetch(value);
          },
        ),
        if (behavior.autoFetch)
          BaseListItem(
            leading: const Icon(PhosphorIconsRegular.timer),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyMediumLabel(l10n.autoFetchInterval),
                BodySmallLabel(l10n.autoFetchIntervalMinutes(behavior.autoFetchInterval)),
              ],
            ),
            trailing: BaseIconButton(
              icon: PhosphorIconsRegular.pencil,
              onPressed: onEditAutoFetchInterval,
            ),
          ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.arrowUp),
          title: Text(l10n.confirmPush),
          subtitle: Text(l10n.confirmPushDescription),
          value: behavior.confirmPush,
          onChanged: (value) {
            ref.read(configProvider.notifier).setConfirmPush(value);
          },
        ),
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.warningCircle),
          title: Text(l10n.confirmForcePush),
          subtitle: Text(l10n.confirmForcePushDescription),
          value: behavior.confirmForcePush,
          onChanged: (value) {
            ref.read(configProvider.notifier).setConfirmForcePush(value);
          },
        ),
        SwitchListTile(
          secondary: const Icon(PhosphorIconsRegular.trash),
          title: Text(l10n.confirmDelete),
          subtitle: Text(l10n.confirmDeleteDescription),
          value: behavior.confirmDelete,
          onChanged: (value) {
            ref.read(configProvider.notifier).setConfirmDelete(value);
          },
        ),
      ],
    );
  }
}
