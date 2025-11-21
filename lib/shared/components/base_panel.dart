import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../shared/theme/app_theme.dart';

/// Base component for all panel patterns in the app.
///
/// A panel is a card with a header section containing a title and
/// optional action buttons, plus a content area and optional footer.
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
    this.elevation = 2,
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
    if (widget.isCollapsible != oldWidget.isCollapsible && !widget.isCollapsible) {
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
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      color: colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: widget.hasBorder
              ? Border.all(
                  color: colorScheme.outline,
                  width: 1,
                )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
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
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.paddingL),
                    child: Row(
                      children: [
                        // Title
                        Expanded(child: widget.title),

                        // Action buttons
                        if (widget.actions != null && widget.actions!.isNotEmpty) ...{
                          SizedBox(width: AppTheme.paddingM),
                          ...widget.actions!.map((action) => Padding(
                                padding: EdgeInsets.only(left: AppTheme.paddingS),
                                child: action,
                              )),
                        },

                        // Collapse/expand icon
                        if (widget.isCollapsible) ...{
                          SizedBox(width: AppTheme.paddingM),
                          Icon(
                            _isExpanded
                                ? PhosphorIconsRegular.caretUp
                                : PhosphorIconsRegular.caretDown,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        },
                      ],
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
