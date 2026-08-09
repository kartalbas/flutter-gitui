import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show IconRole, MenuAnchorSpec, MenuEntry, Overlays, Proximity;
import '../../generated/app_localizations.dart';
import '../components/base_button.dart';
import '../components/base_layout.dart';

/// Standardized app bar for all screens
///
/// Enforces consistent action placement and spacing across the application.
/// All create actions should be in the More menu, not as separate app bar buttons.
///
/// **The overflow anchor is the SKIN's** (#249, P4). This bar used to grow a
/// Material `PopupMenuButton` and take its entries as `PopupMenuEntry` widgets,
/// which welded one design language's menu *classes* into the signature every
/// screen in the application fills in — the exact typed hole
/// [MenuEntry] exists to close. The entries now travel as data and the skin
/// builds the trigger, measures it and opens the menu against it.
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
///         MenuAction(
///           icon: IconRole.plus,
///           label: l10n.createTag,
///           onPressed: () => _showCreateTagDialog(),
///         ),
///         MenuSeparator(),
///         // Other actions
///         MenuAction(
///           icon: IconRole.downloadSimple,
///           label: l10n.fetchFromRemote,
///           onPressed: () => _fetchTags(),
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

  /// What the overflow menu offers, as data rather than as widgets.
  final List<MenuEntry> moreMenuItems;
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
            icon: IconRole.magnifyingGlass,
            tooltip: l10n.search,
            onPressed: onSearch,
          ),
          // Two commands of one action bar, side by side.
          const BaseGap(Proximity.related),
        ],

        // Refresh (if provided)
        if (onRefresh != null) ...[
          BaseIconButton(
            icon: IconRole.arrowsClockwise,
            tooltip: l10n.refresh,
            onPressed: onRefresh,
          ),
          // Two commands of one action bar, side by side.
          const BaseGap(Proximity.related),
        ],

        // Additional actions (if provided)
        // Example: View mode toggle, advanced filters button
        ...?additionalActions,

        // More menu (always present). The trigger, its measured position and
        // the menu opened against it are one thing with two halves, and both
        // halves are the skin's through `overlays.menuAnchor` - which is why
        // the `iconSize` this bar used to state is gone: the button's own box
        // is the skin's arithmetic now.
        Overlays.anchor(
          spec: MenuAnchorSpec(
            icon: IconRole.dotsThreeVertical,
            tooltip: l10n.moreActions,
          ),
          entries: moreMenuItems,
        ),

        // The last command and the bar's trailing edge.
        const BaseGap(Proximity.related),
      ],
    );
  }
}
