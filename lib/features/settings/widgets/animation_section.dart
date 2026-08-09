import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        BannerSpec,
        ControlScale,
        IconRole,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        Tone;
import '../../../generated/app_localizations.dart';

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
          // No `style:` here, and the absence is the statement. Each entry is a
          // `BaseLabel` at `TextRole.body` that pins its own ramp step and
          // takes only its COLOUR from the enclosing `DefaultTextStyle`, which
          // is precisely `Tone.neutral` - "whatever this surface's ordinary
          // foreground is" - and is what every one of them already says by
          // default. Spelling `onSurface` out again here said the same thing
          // in Material's words. Nothing moves: the fallback ramp step carries
          // the scheme's `onSurface` too
          // (`AppTheme._brightnessCorrectedTextTheme`), and the labels own the
          // size.
          trailing: DropdownButton<AppAnimationSpeed>(
            value: ui.animationSpeed,
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
        // The distance between the setting and the note that qualifies it.
        const BaseGap(Proximity.related),

        // "This is worth knowing and nothing is wrong" — `surfaces.banner`,
        // and the fifth site to say it. The four notices in the rebase, bisect
        // and merge dialogs were the same construction and moved last pass;
        // this one survived only because it lives in a settings section rather
        // than a dialog.
        //
        // It was carrying the same defect they were: an `info` MARK on a
        // NEUTRAL fill (`surfaceContainerHighest`) with `muted` words — three
        // parts of one statement, each answering "what does this mean" its own
        // way. The member resolves the fill, the mark and the words from the
        // single `Tone.info`, so they cannot disagree again.
        //
        // Louder than it was, in every part, and deliberately: the card sat
        // inside its own `BaseInset` with an 8 dp corner; the banner spans
        // the section edge to edge with the member's square corners, the
        // quiet box becomes a full-strength `primaryContainer` strip, the
        // `muted` `detail` words rise to `titleMedium`, and the 20 dp mark
        // grows to the ambient 24. This is the one banner the pinned scene
        // register actually renders — the five fences this construction was
        // (two BaseInsets, the mark, its gap and its label) are two now (the
        // gap above and the banner), which is the -3 the settings and shell
        // scene counts moved by.
        SkinScope.render(
          context,
          (Skin skin, BuildContext inner) => skin.surfaces.banner(
            inner,
            BannerSpec(
              tone: Tone.info,
              icon: IconRole.info,
              title: l10n.animationSpeedInfo,
            ),
          ),
        ),
      ],
    );
  }
}
