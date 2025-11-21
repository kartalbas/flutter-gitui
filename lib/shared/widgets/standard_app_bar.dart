import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import '../components/base_animated_widgets.dart';
import '../components/base_button.dart';

/// Standardized app bar for all screens
///
/// Enforces consistent action placement and spacing across the application.
/// All create actions should be in the More menu, not as separate app bar buttons.
///
/// Example usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: StandardAppBar(
///       title: l10n.tags,
///       onRefresh: () => _refreshTags(),
///       moreMenuItems: [
///         // Create action always first
///         PopupMenuItem(
///           child: Row(
///             children: [
///               Icon(PhosphorIconsRegular.plus),
///               SizedBox(width: AppTheme.paddingM),
///               Text(l10n.createTag),
///             ],
///           ),
///           onTap: () => _showCreateTagDialog(),
///         ),
///         PopupMenuDivider(),
///         // Other actions
///         PopupMenuItem(
///           child: Row(
///             children: [
///               Icon(PhosphorIconsRegular.downloadSimple),
///               SizedBox(width: AppTheme.paddingM),
///               Text(l10n.fetchFromRemote),
///             ],
///           ),
///           onTap: () => _fetchTags(),
///         ),
///       ],
///     ),
///     body: _buildBody(),
///   );
/// }
/// ```
class StandardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onRefresh;
  final VoidCallback? onSearch;
  final List<PopupMenuEntry<dynamic>> moreMenuItems;
  final List<Widget>? additionalActions;

  const StandardAppBar({
    super.key,
    required this.title,
    this.onRefresh,
    this.onSearch,
    required this.moreMenuItems,
    this.additionalActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      title: Text(title),
      actions: [
        // Search (if provided - though most screens use inline search now)
        if (onSearch != null) ...[
          BaseIconButton(
            icon: PhosphorIconsRegular.magnifyingGlass,
            tooltip: l10n.search,
            onPressed: onSearch,
          ),
          const SizedBox(width: AppTheme.paddingS),
        ],

        // Refresh (if provided)
        if (onRefresh != null) ...[
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowsClockwise,
            tooltip: l10n.refresh,
            onPressed: onRefresh,
          ),
          const SizedBox(width: AppTheme.paddingS),
        ],

        // Additional actions (if provided)
        // Example: View mode toggle, advanced filters button
        if (additionalActions != null) ...additionalActions!,

        // More menu (always present) - uses BasePopupMenuButton for centralized animation control
        BasePopupMenuButton(
          icon: const Icon(PhosphorIconsRegular.dotsThreeVertical, size: AppTheme.iconM),
          iconSize: AppTheme.iconM,
          tooltip: l10n.moreActions,
          itemBuilder: (context) => moreMenuItems,
        ),

        const SizedBox(width: AppTheme.paddingS),
      ],
    );
  }
}
