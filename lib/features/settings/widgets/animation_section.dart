import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import 'settings_section.dart';
import '../../../shared/components/base_layout.dart';

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
      icon: IconRole.filmStrip,
      children: [
        BaseListItem(
          // The row's own mark. The prominent scale is what a bare `Icon`
          // rendered at under the row's ambient icon theme, and the neutral
          // tone leaves the colour to the row, as before.
          leading: const BaseIcon(
            IconRole.filmStrip,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.animationSpeed, role: TextRole.body),
              BaseLabel(
                _getAnimationSpeedName(context, ui.animationSpeed),
                role: TextRole.detail,
              ),
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
                child: BaseLabel(
                  _getAnimationSpeedName(context, speed),
                  role: TextRole.body,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setAnimationSpeed(value);
              }
            },
          ),
        ),
        // Info card. Its margin is the distance between the card and the
        // section around it, which is an inset owed by the container rather
        // than a second padding inside the card.
        BaseInset(
          x: Inset.normal,
          y: Inset.tight,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: BaseInset(
              all: Inset.tight,
              child: Row(
                children: [
                  // The callout's mark says the same thing as the sentence
                  // beside it and is secondary to it, which is what the muted
                  // tone at the ordinary scale states.
                  const BaseIcon(IconRole.info, tone: Tone.muted),
                  const BaseGap(Proximity.related),
                  Expanded(
                    child: BaseLabel(
                      l10n.animationSpeedInfo,
                      role: TextRole.detail,
                      tone: Tone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
