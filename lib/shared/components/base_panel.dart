import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../shared/theme/app_theme.dart';

/// Base component for all panel patterns in the app.
///
/// A panel is a card with a header section containing a title and
/// optional action buttons, plus a content area and optional footer.
///
/// The container is the Material 3 **elevated card** (`Card`,
/// flutter/lib/src/material/card.dart:301-323): level-1 elevation on
/// `surfaceContainerLow` behind a 12 dp corner. The header is the Material 3
/// **expansion-tile header** (`ExpansionTile`,
/// flutter/lib/src/material/expansion_tile.dart:907-925): a 56 dp minimum
/// height, an `onSurfaceVariant` caret while collapsed and a `primary` one
/// while expanded, and hover/focus/press state layers painted by its
/// [InkWell]. See test/conformance/components/base_panel_conformance_test.dart.
///
/// Example usage:
/// ```dart
/// BasePanel(
///   title: TitleLargeLabel('Branches'),
///   actions: [
///     IconButton(icon: Icon(PhosphorIconsRegular.plus), onPressed: () {}),
///   ],
///   content: ListView(children: [...]),
///   footer: BodyMediumLabel('5 branches total'),
/// )
/// ```
///
/// Collapsible panel example:
/// ```dart
/// BasePanel(
///   title: TitleLargeLabel('Settings'),
///   isCollapsible: true,
///   initiallyExpanded: false,
///   content: Column(children: [...]),
/// )
/// ```
class BasePanel extends StatefulWidget {
  const BasePanel({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.footer,
    this.isCollapsible = false,
    this.initiallyExpanded = true,
    this.elevation = AppTheme.elevationLevel1,
    this.hasBorder = false,
    this.padding = const EdgeInsets.all(AppTheme.paddingL),
  });

  /// Panel title (header)
  final Widget title;

  /// Main content area
  final Widget content;

  /// Optional action buttons in header (top-right)
  final List<Widget>? actions;

  /// Optional footer section
  final Widget? footer;

  /// Allow panel to be collapsed/expanded
  final bool isCollapsible;

  /// Initial expansion state (if collapsible)
  final bool initiallyExpanded;

  /// Panel elevation
  final double elevation;

  /// Show border around panel
  final bool hasBorder;

  /// Content padding
  final EdgeInsets padding;

  /// Smallest height the header may occupy, the Material 3 one-line
  /// list-item height an `ExpansionTile` header is built from
  /// (`_defaultTileHeight`, flutter/lib/src/material/list_tile.dart:1509).
  /// A taller title or an action button grows the header, as it does there.
  static const double headerMinHeight = 56.0;

  @override
  State<BasePanel> createState() => _BasePanelState();
}

class _BasePanelState extends State<BasePanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(BasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset expansion state if collapsible property changes
    if (widget.isCollapsible != oldWidget.isCollapsible &&
        !widget.isCollapsible) {
      _isExpanded = true;
    }
  }

  void _toggleExpanded() {
    if (widget.isCollapsible) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: widget.elevation,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      color: colorScheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: widget.hasBorder
              ? Border.all(color: colorScheme.outlineVariant, width: 1)
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: colorScheme.onSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                InkWell(
                  onTap: widget.isCollapsible ? _toggleExpanded : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BasePanel.headerMinHeight,
                    ),
                    child: Padding(
                      // Horizontal 24 keeps the title on the same optical
                      // left edge as the panel content below the divider
                      // (registered as PANEL-001); vertical 8 is the M3
                      // minVerticalPadding, with the height carried by the
                      // 56 dp minimum above.
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppTheme.paddingL,
                        vertical: AppTheme.paddingS,
                      ),
                      child: Row(
                        children: [
                          // Title. The header's own text role is bodyLarge on
                          // onSurface, the style an ExpansionTile header
                          // inherits from ListTile (list_tile.dart:1844,
                          // expansion_tile.dart:915); a call site that passes
                          // a styled label overrides it.
                          Expanded(
                            child: DefaultTextStyle(
                              style: theme.textTheme.bodyLarge!.copyWith(
                                color: colorScheme.onSurface,
                              ),
                              child: widget.title,
                            ),
                          ),

                          // Action buttons
                          if (widget.actions != null &&
                              widget.actions!.isNotEmpty) ...{
                            const SizedBox(width: AppTheme.paddingM),
                            ...widget.actions!.map(
                              (action) => Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: AppTheme.paddingS,
                                ),
                                child: action,
                              ),
                            ),
                          },

                          // Collapse/expand icon. M3 tints the caret with
                          // `primary` while the tile is expanded and leaves it
                          // `onSurfaceVariant` while collapsed, so the caret
                          // carries the state on its own
                          // (expansion_tile.dart:918 and :924).
                          if (widget.isCollapsible) ...{
                            const SizedBox(width: AppTheme.paddingM),
                            Icon(
                              _isExpanded
                                  ? PhosphorIconsRegular.caretUp
                                  : PhosphorIconsRegular.caretDown,
                              size: AppTheme.iconM,
                              color: _isExpanded
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          },
                        ],
                      ),
                    ),
                  ),
                ),

                // Divider (only if content is visible)
                if (_isExpanded)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),

                // Content section (collapsible)
                if (_isExpanded)
                  Flexible(
                    child: Padding(
                      padding: widget.padding,
                      child: widget.content,
                    ),
                  ),

                // Footer section
                if (_isExpanded && widget.footer != null) ...{
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  Padding(
                    padding: EdgeInsets.all(AppTheme.paddingL),
                    child: widget.footer,
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
