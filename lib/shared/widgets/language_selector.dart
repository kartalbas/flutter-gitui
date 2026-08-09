import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;
import '../components/base_animated_widgets.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
import '../components/country_flag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'dart:ui' as ui;

import '../theme/app_theme.dart';
import '../../core/config/config_providers.dart';
import '../../generated/app_localizations.dart';

/// Language option model
class LanguageOption {
  final String? code; // null for system default
  final String
  label; // Display label (e.g., "EN", "SYS") - deprecated, use icon instead
  final String name; // Full name (e.g., "English", "System Default")
  final String?
  countryCode; // ISO country code (e.g., "GB") for flag display, null for system default

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
    LanguageOption(
      code: null,
      label: 'SYS',
      name: l10n.systemDefault,
      countryCode: null,
    ),
    LanguageOption(
      code: 'en',
      label: 'EN',
      name: l10n.english,
      countryCode: 'US',
    ),
    LanguageOption(
      code: 'de',
      label: 'DE',
      name: l10n.german,
      countryCode: 'DE',
    ),
    LanguageOption(
      code: 'es',
      label: 'ES',
      name: l10n.spanish,
      countryCode: 'ES',
    ),
    LanguageOption(
      code: 'fr',
      label: 'FR',
      name: l10n.french,
      countryCode: 'FR',
    ),
    LanguageOption(
      code: 'it',
      label: 'IT',
      name: l10n.italian,
      countryCode: 'IT',
    ),
    LanguageOption(
      code: 'tr',
      label: 'TR',
      name: l10n.turkish,
      countryCode: 'TR',
    ),
  ];
}

/// Standalone language selector widget
/// Shows current language as an icon button with popup menu
///
/// **Stays hand-painted, by decision (#438).** Each row leads with per-language
/// flag ARTWORK, and the trigger itself is the current flag. That is
/// application content, not design vocabulary: it renders identically under
/// every design language, which is the inverse of the contract's own test for
/// a member. Admitting an arbitrary-widget slot into the sealed `MenuEntry`
/// data set would reopen the exact typed hole the set exists to close - a
/// `Widget` that compiles cleanly into a foreign menu and ships the wrong
/// language inside it. The menu's one-of-N shape is expressible today
/// (`MenuChoice`); the artwork is what keeps it here, and its remaining raw
/// reads are classifier-mechanical, so no register entry is owed.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final languageOptions = _getLanguageOptions(context);
    final l10n = AppLocalizations.of(context)!;

    // Get current language option
    final currentOption = _getCurrentLanguageOption(
      context,
      currentLocale,
      languageOptions,
    );

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
              // The flag and the name are members of one menu entry.
              const BaseGap(Proximity.grouped),
              // Language name
              // The entry says only what it is; that it is the chosen one is
              // said by the checkmark beside it, which is the fact
              // `MenuCheckable.checked` will carry when this menu becomes a
              // contract member. The semibold and the accent tint were this
              // call site answering "how does a language show 'checked'" —
              // twice, on top of a checkmark that already says it.
              Expanded(child: BaseLabel(option.name, role: TextRole.control)),
              // Checkmark for selected
              if (isSelected) ...[
                // The name and the mark that says it is the chosen one are
                // members of one menu entry.
                const BaseGap(Proximity.grouped),
                // Left as a Phosphor constant deliberately: the heavier stroke
                // is a fact `IconRole` cannot carry, so converting the mark
                // would drop it silently. See the P3d report.
                //
                // Which pins the colour too: a raw `Icon` takes a `Color`, and
                // the application is given no way to resolve `Tone.accent`
                // into one. Glyph and colour are one decision here and they
                // convert together, when a checked menu entry is a member that
                // draws its own mark.
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
    // For system default, use the globe mark
    if (option.countryCode == null) {
      return const BaseIcon(IconRole.globe);
    }

    // For language flags, show the SVG flag with softly rounded corners
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CountryFlag.fromCountryCode(option.countryCode!),
      ),
    );
  }

  /// Build flag icon for menu items
  Widget _buildFlagIcon(
    BuildContext context,
    LanguageOption option,
    bool isSelected,
  ) {
    // For system default, use globe icon
    if (option.countryCode == null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: BaseIcon(
          IconRole.globe,
          scale: ControlScale.compact,
          tone: isSelected ? Tone.accent : Tone.neutral,
        ),
      );
    }

    // For language flags, show the SVG flag with circular shape
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        // Not a tone: a ring at 30% opacity is a selection state layer drawn
        // as a border, which is the `listRow` / selectable-surface question
        // and is answered in P5. Calling it `Tone.accent` would turn a wash
        // into a foreground.
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: CountryFlag.fromCountryCode(option.countryCode!)),
    );
  }
}
