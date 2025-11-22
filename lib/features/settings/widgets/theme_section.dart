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
    final currentPreviewFont = AppTheme.availableMonospaceFonts.contains(ui.previewFontFamily)
        ? ui.previewFontFamily
        : 'JetBrains Mono';

    return SettingsSection(
      title: l10n.appearance,
      icon: PhosphorIconsRegular.palette,
      children: [
        BaseListItem(
          leading: const Icon(PhosphorIconsRegular.palette),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.colorScheme),
              BodySmallLabel(getColorSchemeName(ui.colorScheme)),
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
                child: BodyMediumLabel(getColorSchemeName(scheme)),
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
          leading: const Icon(PhosphorIconsRegular.textAa),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.fontFamily),
              BodySmallLabel(currentFont),
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
                child: BodyMediumLabel(font),
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
          leading: const Icon(PhosphorIconsRegular.textT),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.fontSize),
              BodySmallLabel(getFontSizeName(ui.fontSize)),
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
                child: BodyMediumLabel(getFontSizeName(size)),
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
          leading: const Icon(PhosphorIconsRegular.codeSimple),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.previewFontFamily),
              BodySmallLabel(currentPreviewFont),
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
                child: BodyMediumLabel(font),
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
          leading: const Icon(PhosphorIconsRegular.textT),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyMediumLabel(l10n.previewFontSize),
              BodySmallLabel(getFontSizeName(ui.previewFontSize)),
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
                child: BodyMediumLabel(getFontSizeName(size)),
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
