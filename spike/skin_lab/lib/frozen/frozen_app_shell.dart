// FROZEN COPY - STRUCTURAL REDUCTION. Do not "improve".
//
//   source:  lib/core/navigation/app_shell.dart
//   sha:     7b7aca82efed558523b02e2a6b4bf3b9be8b0865
//   copied:  2026-08-06
//
// This is the ONE component under test that is not a near-verbatim copy, and
// the reason is recorded rather than glossed:
//
//   `AppShell` takes NO parameters at all (`const AppShell({super.key})`,
//   app_shell.dart:88-89). Its 1418 lines read 14 Riverpod providers, own the
//   global shortcut map, drive six batch git operations and show nine dialogs.
//   None of that is a design-language decision, and none of it is reachable
//   from this package. So what is frozen here is the shell's COMPOSITION - the
//   arrangement the skin must reproduce - expressed as the explicit parameter
//   list the component does not have:
//
//     destinations / selectedIndex / onDestinationSelected  (rail, :303-404)
//     railExtended / onToggleRailExtended                   (:304, :353-365)
//     railLeading / railTrailing                            (:313-368)
//     badgeCounts                                           (:369-403)
//     toolbar                                               (:416-435)
//     body                                                  (content region)
//     statusBar                                             (command log strip)
//
//   Introducing that parameter list is itself the first finding for this
//   component: today the shell composition is not a signature at all, so
//   "can the Base* signatures drive three design languages" is not even
//   ASKABLE of the shell until the composition is extracted into one. The
//   Material rendering below reproduces app_shell.dart:294-412 exactly -
//   Scaffold > Stack > Row > [NavigationRail, VerticalDivider,
//   Expanded(Column(toolbar, body, statusBar))] - so the skins are measured
//   against the real arrangement.

import 'package:flutter/material.dart';

import '../app_stubs.dart';
import '../skin.dart';

/// One rail destination, mirroring `AppDestination` (app_shell.dart:369-404).
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// The stash / changed-file counts the rail badges (app_shell.dart:371-389).
  final int? badgeCount;
}

/// The app shell's composition, as the skinnable unit it is not yet.
class FrozenAppShell extends StatelessWidget {
  const FrozenAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.railExtended,
    required this.onToggleRailExtended,
    required this.toolbar,
    required this.body,
    this.statusBar,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool railExtended;
  final VoidCallback onToggleRailExtended;

  /// The band above the content (app_shell.dart:416-435). Deliberately a
  /// `Widget`, exactly as the real shell composes it - and therefore just as
  /// opaque to a skin.
  final Widget toolbar;

  final Widget body;

  /// The command-log strip below the content.
  final Widget? statusBar;

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.shell(this); // SKIN DISPATCH
    // dart format on

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: railExtended,
            backgroundColor: colorScheme.surfaceContainerLow,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            leading: Column(
              children: [
                const SizedBox(height: AppTheme.paddingM),
                Icon(
                  PhosphorIconsBold.gitBranch,
                  size: AppTheme.iconXL,
                  color: colorScheme.primary,
                ),
                if (railExtended) ...[
                  const SizedBox(height: AppTheme.paddingS),
                  TitleMediumLabel(
                    AppLocalizations.of(context)!.appTitle,
                    color: colorScheme.primary,
                  ),
                ],
                const SizedBox(height: AppTheme.paddingL),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.paddingM),
                  child: IconButton(
                    icon: Icon(
                      railExtended
                          ? PhosphorIconsRegular.caretLeft
                          : PhosphorIconsRegular.caretRight,
                    ),
                    onPressed: onToggleRailExtended,
                    tooltip: railExtended
                        ? AppLocalizations.of(context)!.collapse
                        : AppLocalizations.of(context)!.expand,
                  ),
                ),
              ),
            ),
            destinations: [
              for (final ShellDestination dest in destinations)
                NavigationRailDestination(
                  icon: _withBadge(Icon(dest.icon), dest.badgeCount),
                  selectedIcon: _withBadge(
                    Icon(dest.selectedIcon),
                    dest.badgeCount,
                  ),
                  label: BodyMediumLabel(dest.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                toolbar,
                Expanded(child: body),
                ?statusBar,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _withBadge(Widget icon, int? count) {
    if (count == null) return icon;
    return Badge(label: Text('$count'), child: icon);
  }
}
