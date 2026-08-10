import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Skin, SkinRegistry, TextRole;
import '../../../generated/app_localizations.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../shared/components/base_icon.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_list_item.dart';
import 'settings_section.dart';

/// Theme/appearance section for settings screen
class ThemeSection extends ConsumerWidget {
  final String Function(AppColorScheme scheme) getColorSchemeName;
  final String Function(AppFontSize size) getFontSizeName;

  const ThemeSection({
    super.key,
    required this.getColorSchemeName,
    required this.getFontSizeName,
  });

  /// The name a skin answers to in the settings picker.
  ///
  /// A skin names ITSELF, with a localisation key (`Skin.nameKey`) rather
  /// than a string, because the application owns its translations and a skin
  /// package must not ship its own. This switch is the application's side of
  /// that agreement - the keys it has translations for. A skin whose key is
  /// not translated yet is shown by its id instead of being silently renamed
  /// to the nearest known skin.
  String _skinName(BuildContext context, Skin skin) {
    final l10n = AppLocalizations.of(context)!;
    return switch (skin.nameKey) {
      'skinMaterial' => l10n.skinMaterial,
      'skinBlueprint' => l10n.skinBlueprint,
      'skinFluent' => l10n.skinFluent,
      _ => skin.id,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ui = ref.watch(uiConfigProvider);

    // The design languages a user may choose in THIS build: the registry's
    // own list, in registration order, minus the instruments in release. The
    // section never names a skin - a package that registers itself appears
    // here without this file changing, which is the property #249 calls
    // "plugin".
    final List<Skin> skins = SkinRegistry.selectable;

    // A saved id this build does not offer (a debug-only skin in a release
    // build, a package that left the build) must not crash the dropdown; the
    // shipping skin is what main.dart renders under in that case, so it is
    // what the picker shows too.
    final String currentSkinId = skins.any((skin) => skin.id == ui.skinId)
        ? ui.skinId
        : kShippingSkinId;
    final Skin currentSkin = SkinRegistry.byId(currentSkinId);

    // Ensure current font is in the available list, otherwise use default
    final currentFont = AppTheme.availableFonts.contains(ui.fontFamily)
        ? ui.fontFamily
        : 'JetBrains Mono';

    // Ensure current preview font is in the monospace fonts list, otherwise use default
    final currentPreviewFont =
        AppTheme.availableMonospaceFonts.contains(ui.previewFontFamily)
        ? ui.previewFontFamily
        : 'JetBrains Mono';

    return SettingsSection(
      title: l10n.appearance,
      icon: IconRole.palette,
      children: [
        BaseListItem(
          // The row's own mark, same shape as every sibling below: prominent
          // scale, colour left to the row.
          leading: const BaseIcon(
            IconRole.desktop,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.designLanguage, role: TextRole.body),
              BaseLabel(_skinName(context, currentSkin), role: TextRole.detail),
            ],
          ),
          // The same dropdown as its four siblings, saying the same thing the
          // same way: each entry is a `BaseLabel` at `TextRole.body`, taking
          // only its colour from the surface. Switching redraws the running
          // application in place - the config provider rebuilds the root,
          // `SkinScope` notifies on the skin change, and the navigator
          // survives through its GlobalKey
          // (test/settings_propagation_test.dart pins both halves).
          trailing: DropdownButton<String>(
            value: currentSkinId,
            items: skins.map((skin) {
              return DropdownMenuItem(
                value: skin.id,
                child: BaseLabel(_skinName(context, skin), role: TextRole.body),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setSkinId(value);
              }
            },
          ),
        ),
        BaseListItem(
          // The row's own mark. The prominent scale is what a bare `Icon`
          // rendered at under the row's ambient icon theme, and the neutral
          // tone leaves the colour to the row, as before.
          leading: const BaseIcon(
            IconRole.palette,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.colorScheme, role: TextRole.body),
              BaseLabel(
                getColorSchemeName(ui.colorScheme),
                role: TextRole.detail,
              ),
            ],
          ),
          // The `style:` this dropdown used to carry said `onSurface` a second
          // time, in Material's words. Every entry below is a `BaseLabel` at
          // `TextRole.body`, which pins its own ramp step and leaves only the
          // COLOUR to the enclosing `DefaultTextStyle` - and that is exactly
          // what `Tone.neutral` means ("whatever this surface's ordinary
          // foreground is"), which every one of them already says by default.
          // Saying nothing here is therefore the conversion rather than a
          // deletion: the meaning is stated once, in the vocabulary, instead
          // of twice with one of the two naming a Material role. It moves no
          // pixel - `DropdownButton` falls back to `textTheme.titleMedium`,
          // and `AppTheme._brightnessCorrectedTextTheme` gives every step of
          // this scale the scheme's `onSurface` - and the size never came from
          // here, because `isDense` is false and the labels pin their own.
          // The four dropdowns below say the same thing the same way.
          trailing: DropdownButton<AppColorScheme>(
            value: ui.colorScheme,
            items: AppColorScheme.values.map((scheme) {
              return DropdownMenuItem(
                value: scheme,
                child: BaseLabel(
                  getColorSchemeName(scheme),
                  role: TextRole.body,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setColorScheme(value);
              }
            },
          ),
        ),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.textAa,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.fontFamily, role: TextRole.body),
              BaseLabel(currentFont, role: TextRole.detail),
            ],
          ),
          trailing: DropdownButton<String>(
            value: currentFont,
            items: AppTheme.availableFonts.map((font) {
              return DropdownMenuItem(
                value: font,
                child: BaseLabel(font, role: TextRole.body),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setFontFamily(value);
              }
            },
          ),
        ),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.textT,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.fontSize, role: TextRole.body),
              BaseLabel(getFontSizeName(ui.fontSize), role: TextRole.detail),
            ],
          ),
          trailing: DropdownButton<AppFontSize>(
            value: ui.fontSize,
            items: AppFontSize.values.map((size) {
              return DropdownMenuItem(
                value: size,
                child: BaseLabel(getFontSizeName(size), role: TextRole.body),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setFontSize(value);
              }
            },
          ),
        ),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.codeSimple,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.previewFontFamily, role: TextRole.body),
              BaseLabel(currentPreviewFont, role: TextRole.detail),
            ],
          ),
          trailing: DropdownButton<String>(
            value: currentPreviewFont,
            items: AppTheme.availableMonospaceFonts.map((font) {
              return DropdownMenuItem(
                value: font,
                child: BaseLabel(font, role: TextRole.body),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setPreviewFontFamily(value);
              }
            },
          ),
        ),
        BaseListItem(
          leading: const BaseIcon(
            IconRole.textT,
            scale: ControlScale.prominent,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseLabel(l10n.previewFontSize, role: TextRole.body),
              BaseLabel(
                getFontSizeName(ui.previewFontSize),
                role: TextRole.detail,
              ),
            ],
          ),
          trailing: DropdownButton<AppFontSize>(
            value: ui.previewFontSize,
            items: AppFontSize.values.map((size) {
              return DropdownMenuItem(
                value: size,
                child: BaseLabel(getFontSizeName(size), role: TextRole.body),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(configProvider.notifier).setPreviewFontSize(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
