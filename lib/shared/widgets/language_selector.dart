import 'package:flutter/material.dart';
import '../components/base_animated_widgets.dart';
import '../components/base_menu_item.dart';
import '../components/country_flag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui' as ui;

import '../theme/app_theme.dart';
import '../../core/config/config_providers.dart';
import '../../generated/app_localizations.dart';

/// Language option model
class LanguageOption {
  final String? code; // null for system default
  final String label; // Display label (e.g., "EN", "SYS") - deprecated, use icon instead
  final String name; // Full name (e.g., "English", "System Default")
  final String? countryCode; // ISO country code (e.g., "GB") for flag display, null for system default

  const LanguageOption({
    required this.code,
    required this.label,
    required this.name,
    this.countryCode,
  });
}

/// Get available language options with localized names
List<LanguageOption> _getLanguageOptions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    LanguageOption(code: null, label: 'SYS', name: l10n.systemDefault, countryCode: null),
    LanguageOption(code: 'en', label: 'EN', name: l10n.english, countryCode: 'US'),
    LanguageOption(code: 'ar', label: 'AR', name: l10n.arabic, countryCode: 'SA'),
    LanguageOption(code: 'de', label: 'DE', name: l10n.german, countryCode: 'DE'),
    LanguageOption(code: 'es', label: 'ES', name: l10n.spanish, countryCode: 'ES'),
    LanguageOption(code: 'fr', label: 'FR', name: l10n.french, countryCode: 'FR'),
    LanguageOption(code: 'it', label: 'IT', name: l10n.italian, countryCode: 'IT'),
    LanguageOption(code: 'ru', label: 'RU', name: l10n.russian, countryCode: 'RU'),
    LanguageOption(code: 'tr', label: 'TR', name: l10n.turkish, countryCode: 'TR'),
    LanguageOption(code: 'zh', label: 'ZH', name: l10n.chinese, countryCode: 'CN'),
  ];
}

/// Standalone language selector widget
/// Shows current language as an icon button with popup menu
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final languageOptions = _getLanguageOptions(context);
    final l10n = AppLocalizations.of(context)!;

    // Get current language option
    final currentOption = _getCurrentLanguageOption(context, currentLocale, languageOptions);

    return BasePopupMenuButton<String?>(
      tooltip: l10n.tooltipLanguage,
      offset: const Offset(0, 40),
      child: _buildLanguageBadge(context, currentOption),
      itemBuilder: (context) => languageOptions.map((option) {
        final isSelected = option.code == currentLocale;

        return PopupMenuItem<String?>(
          value: option.code,
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (!context.mounted) return;
              final container = ProviderScope.containerOf(context);
              container.read(configProvider.notifier).setLocale(option.code);
            });
          },
          child: Row(
            children: [
              // Flag icon
              _buildFlagIcon(context, option, isSelected),
              const SizedBox(width: AppTheme.paddingM),
              // Language name
              Expanded(
                child: MenuItemLabel(
                  option.name,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // Checkmark for selected
              if (isSelected) ...[
                const SizedBox(width: AppTheme.paddingM),
                Icon(
                  PhosphorIconsBold.check,
                  size: AppTheme.iconM,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Get current language option based on locale setting
  LanguageOption _getCurrentLanguageOption(
    BuildContext context,
    String? locale,
    List<LanguageOption> languageOptions,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (locale == null) {
      // System default - try to get actual system language
      final systemLocale = _getSystemLocale();
      final matchedOption = languageOptions.firstWhere(
        (opt) => opt.code == systemLocale,
        orElse: () => languageOptions.first,
      );

      // If system language is supported, show its flag, otherwise show globe icon
      if (matchedOption.code != null) {
        return LanguageOption(
          code: null,
          label: matchedOption.label,
          name: '${l10n.systemDefault} (${matchedOption.name})',
          countryCode: matchedOption.countryCode,
        );
      }
      return languageOptions.first; // Globe icon for system default
    }

    return languageOptions.firstWhere(
      (opt) => opt.code == locale,
      orElse: () => languageOptions.first,
    );
  }

  /// Get system locale code
  String? _getSystemLocale() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      return systemLocale.languageCode;
    } catch (e) {
      return null;
    }
  }

  /// Build language badge button with flag icon
  Widget _buildLanguageBadge(BuildContext context, LanguageOption option) {
    // For system default, use globe icon from PhosphorIcons
    if (option.countryCode == null) {
      return Icon(
        PhosphorIconsRegular.globe,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface,
      );
    }

    // For language flags, show the SVG flag with circular shape
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CountryFlag.fromCountryCode(
          option.countryCode!,
        ),
      ),
    );
  }

  /// Build flag icon for menu items
  Widget _buildFlagIcon(BuildContext context, LanguageOption option, bool isSelected) {
    // For system default, use globe icon
    if (option.countryCode == null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(
          PhosphorIconsRegular.globe,
          size: 16,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    // For language flags, show the SVG flag with circular shape
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CountryFlag.fromCountryCode(
          option.countryCode!,
        ),
      ),
    );
  }
}
