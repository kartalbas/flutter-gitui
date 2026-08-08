import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, TextRole;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ui = ref.watch(uiConfigProvider);

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
          trailing: DropdownButton<AppColorScheme>(
            value: ui.colorScheme,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
