import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import 'settings_section.dart';

/// Animation/performance section for settings screen
class AnimationSection extends ConsumerWidget {
  const AnimationSection({super.key});

  String _getAnimationSpeedName(BuildContext context, AppAnimationSpeed speed) {
    final l10n = AppLocalizations.of(context)!;
    switch (speed) {
      case AppAnimationSpeed.none:
        return l10n.animationSpeedNone;
      case AppAnimationSpeed.fast:
        return l10n.animationSpeedFast;
      case AppAnimationSpeed.normal:
        return l10n.animationSpeedNormal;
      case AppAnimationSpeed.slow:
        return l10n.animationSpeedSlow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ui = ref.watch(uiConfigProvider);

    return SettingsSection(
      title: l10n.animations,
      icon: PhosphorIconsRegular.filmStrip,
      children: [
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.filmStrip),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.animationSpeed),
              BodySmallLabel(_getAnimationSpeedName(context, ui.animationSpeed)),
            ],
          ),
          trailing: DropdownButton<AppAnimationSpeed>(
            value: ui.animationSpeed,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: AppAnimationSpeed.values.map((speed) {
              return DropdownMenuItem(
                value: speed,
                child: BodyMediumLabel(_getAnimationSpeedName(context, speed)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setAnimationSpeed(value);
              }
            },
          ),
        ),
        // Info card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.paddingM, vertical: AppTheme.paddingS),
          padding: const EdgeInsets.all(AppTheme.paddingS),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.paddingS),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.info,
                size: AppTheme.iconM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.paddingS),
              Expanded(
                child: BodySmallLabel(
                  l10n.animationSpeedInfo,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
