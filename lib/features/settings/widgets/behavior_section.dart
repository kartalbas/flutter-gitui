import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, TextRole;
import '../../../generated/app_localizations.dart';

import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_layout.dart';
import '../../../shared/components/base_list_item.dart';
import '../../../shared/components/base_button.dart';
import 'settings_section.dart';

/// Behavior settings section for settings screen
class BehaviorSection extends ConsumerWidget {
  final VoidCallback onEditAutoFetchInterval;

  const BehaviorSection({super.key, required this.onEditAutoFetchInterval});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final behavior = ref.watch(behaviorConfigProvider);

    return SettingsSection(
      title: l10n.behavior,
      icon: IconRole.sliders,
      children: [
        SwitchListTile(
          secondary: const BaseIcon(
            IconRole.arrowsClockwise,
            scale: ControlScale.prominent,
          ),
          title: Text(l10n.autoFetch),
          subtitle: Text(l10n.autoFetchDescription),
          value: behavior.autoFetch,
          onChanged: (value) {
            ref.read(configProvider.notifier).setAutoFetch(value);
          },
        ),
        if (behavior.autoFetch)
          BaseListItem(
            // The row's own mark. The prominent scale is what a bare `Icon`
            // rendered at under the row's ambient icon theme, and the neutral
            // tone leaves the colour to the row, as before.
            leading: const BaseIcon(
              IconRole.timer,
              scale: ControlScale.prominent,
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseLabel(l10n.autoFetchInterval, role: TextRole.body),
                BaseLabel(
                  l10n.autoFetchIntervalMinutes(behavior.autoFetchInterval),
                  role: TextRole.detail,
                ),
              ],
            ),
            trailing: BaseIconButton(
              icon: IconRole.pencil,
              tooltip: l10n.autoFetchInterval,
              onPressed: onEditAutoFetchInterval,
            ),
          ),
        const BaseSeparator(),
        SwitchListTile(
          secondary: const BaseIcon(
            IconRole.arrowUp,
            scale: ControlScale.prominent,
          ),
          title: Text(l10n.confirmPush),
          subtitle: Text(l10n.confirmPushDescription),
          value: behavior.confirmPush,
          onChanged: (value) {
            ref.read(configProvider.notifier).setConfirmPush(value);
          },
        ),
        SwitchListTile(
          secondary: const BaseIcon(
            IconRole.warningDiamond,
            scale: ControlScale.prominent,
          ),
          title: Text(l10n.confirmDestructiveActions),
          subtitle: Text(l10n.confirmDestructiveActionsDescription),
          value: behavior.confirmDestructiveActions,
          onChanged: (value) {
            ref
                .read(configProvider.notifier)
                .setConfirmDestructiveActions(value);
          },
        ),
      ],
    );
  }
}
