import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../../generated/app_localizations.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../../core/navigation/navigation_item.dart';
import '../components/base_animated_widgets.dart';
import '../components/base_menu_item.dart';

/// Quick access settings dropdown menu
class QuickSettingsMenu extends ConsumerWidget {
  const QuickSettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final l10n = AppLocalizations.of(context)!;

    return BasePopupMenuButton<String>(
      icon: const Icon(
        PhosphorIconsRegular.gear,
        size: 20,
      ),
      tooltip: l10n.tooltipQuickSettings,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        // Theme Mode Section
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingL,
            vertical: AppTheme.paddingS,
          ),
          child: LabelSmallLabel(
            'THEME MODE',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _buildThemeModeItem(
          context,
          'System',
          ThemeMode.system,
          themeMode,
          PhosphorIconsRegular.desktop,
        ),
        _buildThemeModeItem(
          context,
          'Light',
          ThemeMode.light,
          themeMode,
          PhosphorIconsRegular.sun,
        ),
        _buildThemeModeItem(
          context,
          'Dark',
          ThemeMode.dark,
          themeMode,
          PhosphorIconsRegular.moon,
        ),
        const PopupMenuDivider(),

        // Font Size Section
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingL,
            vertical: AppTheme.paddingS,
          ),
          child: LabelSmallLabel(
            'FONT SIZE',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _buildFontSizeItem(
          context,
          'Tiny',
          AppFontSize.tiny,
          fontSize,
        ),
        _buildFontSizeItem(
          context,
          'Small',
          AppFontSize.small,
          fontSize,
        ),
        _buildFontSizeItem(
          context,
          'Medium',
          AppFontSize.medium,
          fontSize,
        ),
        _buildFontSizeItem(
          context,
          'Large',
          AppFontSize.large,
          fontSize,
        ),
        const PopupMenuDivider(),

        // Color Scheme Section
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingL,
            vertical: AppTheme.paddingS,
          ),
          child: LabelSmallLabel(
            'COLOR SCHEME',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _buildColorSchemeItem(
          context,
          'Deep Purple',
          AppColorScheme.deepPurple,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Indigo',
          AppColorScheme.indigo,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Blue',
          AppColorScheme.blue,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Teal',
          AppColorScheme.teal,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Green',
          AppColorScheme.green,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Red',
          AppColorScheme.red,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Pink',
          AppColorScheme.pink,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Purple',
          AppColorScheme.purple,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Deep Orange',
          AppColorScheme.deepOrange,
          colorScheme,
        ),
        _buildColorSchemeItem(
          context,
          'Blue Grey',
          AppColorScheme.blueGrey,
          colorScheme,
        ),
        const PopupMenuDivider(),

        // Full Settings Link
        PopupMenuItem(
          value: 'full_settings',
          child: MenuItemContent(
            icon: PhosphorIconsRegular.gear,
            label: 'All Settings',
            iconColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'full_settings') {
          // Navigate to settings screen
          ref.read(navigationDestinationProvider.notifier).state = AppDestination.settings;
        }
      },
    );
  }

  PopupMenuItem<String> _buildThemeModeItem(
    BuildContext context,
    String label,
    ThemeMode mode,
    ThemeMode currentMode,
    IconData icon,
  ) {
    final isSelected = mode == currentMode;

    return PopupMenuItem(
      value: 'theme_${mode.name}',
      onTap: () {
        // Need to delay to avoid popup menu closing issue
        Future.delayed(Duration.zero, () {
          if (!context.mounted) return;
          final container = ProviderScope.containerOf(context);
          container.read(configProvider.notifier).setThemeMode(mode);
        });
      },
      child: MenuItemContentWithCheck(
        icon: icon,
        label: label,
        isSelected: isSelected,
      ),
    );
  }

  PopupMenuItem<String> _buildFontSizeItem(
    BuildContext context,
    String label,
    AppFontSize size,
    AppFontSize currentSize,
  ) {
    final isSelected = size == currentSize;

    return PopupMenuItem(
      value: 'font_${size.name}',
      onTap: () {
        Future.delayed(Duration.zero, () {
          if (!context.mounted) return;
          final container = ProviderScope.containerOf(context);
          container.read(configProvider.notifier).setFontSize(size);
        });
      },
      child: MenuItemContentWithCheck(
        icon: PhosphorIconsRegular.textAa,
        label: label,
        isSelected: isSelected,
      ),
    );
  }

  PopupMenuItem<String> _buildColorSchemeItem(
    BuildContext context,
    String label,
    AppColorScheme scheme,
    AppColorScheme currentScheme,
  ) {
    final isSelected = scheme == currentScheme;

    return PopupMenuItem(
      value: 'color_${scheme.name}',
      onTap: () {
        Future.delayed(Duration.zero, () {
          if (!context.mounted) return;
          final container = ProviderScope.containerOf(context);
          container.read(configProvider.notifier).setColorScheme(scheme);
        });
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _getColorForScheme(scheme),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: MenuItemLabel(
              label,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: AppTheme.paddingM),
            Icon(
              Icons.check,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Color _getColorForScheme(AppColorScheme scheme) {
    switch (scheme) {
      case AppColorScheme.deepPurple:
        return const Color(0xFF673AB7);
      case AppColorScheme.indigo:
        return const Color(0xFF3F51B5);
      case AppColorScheme.blue:
        return const Color(0xFF2196F3);
      case AppColorScheme.teal:
        return const Color(0xFF009688);
      case AppColorScheme.green:
        return const Color(0xFF4CAF50);
      case AppColorScheme.red:
        return const Color(0xFFF44336);
      case AppColorScheme.pink:
        return const Color(0xFFE91E63);
      case AppColorScheme.purple:
        return const Color(0xFF9C27B0);
      case AppColorScheme.deepOrange:
        return const Color(0xFFFF5722);
      case AppColorScheme.blueGrey:
        return const Color(0xFF607D8B);
    }
  }
}
