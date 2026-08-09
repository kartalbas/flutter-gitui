import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;

import '../theme/app_theme.dart';
import '../components/base_icon.dart';
import '../components/base_label.dart';
import '../components/base_layout.dart';
import '../../generated/app_localizations.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_providers.dart';
import '../../core/navigation/navigation_item.dart';
import '../components/base_animated_widgets.dart';
import '../components/base_menu_item.dart';

/// Quick access settings dropdown menu
///
/// **Stays hand-painted, by decision (#438).** The theme-mode and font-size
/// sections are one-of-N sets the contract can state today (`MenuChoice`
/// under `MenuSection`), but the colour-scheme rows lead with a seed-colour
/// SWATCH - per-row artwork the sealed data set deliberately cannot carry
/// (see `_getColorForScheme`: the missing word is a theme-picker member, not
/// a menu slot), and a menu converts whole or not at all: converting two
/// sections and leaving the third would put one menu half in each world.
class QuickSettingsMenu extends ConsumerWidget {
  const QuickSettingsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final l10n = AppLocalizations.of(context)!;

    return BasePopupMenuButton<String>(
      icon: const BaseIcon(IconRole.gear),
      tooltip: l10n.tooltipQuickSettings,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        // Theme Mode Section
        const PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: BaseInset(
            x: Inset.roomy,
            y: Inset.tight,
            child: BaseLabel(
              'THEME MODE',
              role: TextRole.micro,
              tone: Tone.muted,
            ),
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
        const PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: BaseInset(
            x: Inset.roomy,
            y: Inset.tight,
            child: BaseLabel(
              'FONT SIZE',
              role: TextRole.micro,
              tone: Tone.muted,
            ),
          ),
        ),
        _buildFontSizeItem(context, 'Tiny', AppFontSize.tiny, fontSize),
        _buildFontSizeItem(context, 'Small', AppFontSize.small, fontSize),
        _buildFontSizeItem(context, 'Medium', AppFontSize.medium, fontSize),
        _buildFontSizeItem(context, 'Large', AppFontSize.large, fontSize),
        const PopupMenuDivider(),

        // Color Scheme Section
        const PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: BaseInset(
            x: Inset.roomy,
            y: Inset.tight,
            child: BaseLabel(
              'COLOR SCHEME',
              role: TextRole.micro,
              tone: Tone.muted,
            ),
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
        _buildColorSchemeItem(context, 'Red', AppColorScheme.red, colorScheme),
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
            icon: IconRole.gear,
            label: 'All Settings',
            tone: Tone.accent,
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'full_settings') {
          // Navigate to settings screen
          ref.read(navigationDestinationProvider.notifier).state =
              AppDestination.settings;
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
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          const BaseGap(Proximity.grouped),
          Expanded(
            // The checkmark to the right is what says "this is the one in
            // force" — the fact `MenuCheckable.checked` will carry once this
            // menu is a contract member. The semibold and the accent tint were
            // a third and fourth statement of it, chosen by a call site.
            child: BaseLabel(label, role: TextRole.control),
          ),
          if (isSelected) ...[
            const BaseGap(Proximity.grouped),
            const BaseIcon(
              IconRole.check,
              scale: ControlScale.compact,
              tone: Tone.accent,
            ),
          ],
        ],
      ),
    );
  }

  /// The seed colour that identifies one selectable [AppColorScheme].
  ///
  /// **These ten hex values are NOT the skin's colour series and must not be
  /// converted into `Tone.series(n)`.** They look like it from a distance -
  /// eight of the ten also appear in `MaterialInk.seriesPalette` - and they
  /// are a different statement: `Tone.series(n)` names "the nth identity
  /// colour of whatever design language is running", whereas each value here
  /// names the seed of ONE Material scheme the user is choosing between
  /// (`AppTheme._mapColorScheme` maps each to its `FlexScheme`). Two of them,
  /// deep purple `0xFF673AB7` and deep orange `0xFFFF5722`, are not in the
  /// series at all, and the orders differ - so indexing into the series would
  /// draw the wrong swatch beside eight of the ten names and an arbitrary one
  /// beside the other two.
  ///
  /// The vocabulary has no word for "the colour that identifies this theme
  /// choice", which is a missing member rather than a rounding job: the swatch
  /// belongs to a theme picker the contract does not yet carry, and it stays a
  /// literal until it does. Recorded here rather than folded into the nearest
  /// available rung, which is how a palette becomes wrong quietly.
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
