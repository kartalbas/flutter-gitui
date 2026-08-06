import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../theme/app_theme.dart';
import 'base_label.dart';

/// Action shown as a labeled mini-FAB in a [BaseSpeedDial].
class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// Draggable Speed Dial FAB.
///
/// A floating action button that expands into a vertical list of labeled
/// [SpeedDialAction] buttons. The dial can be dragged anywhere on screen;
/// its position is clamped to the viewport. Expansion state is controlled
/// by the parent via [isExpanded], [onToggle] and [onCollapse], and ESC
/// collapses the dial while it has focus. Must be placed inside a [Stack],
/// as it positions itself relative to the bottom-right corner.
class BaseSpeedDial extends StatefulWidget {
  final List<SpeedDialAction> actions;
  final bool isExpanded; // Controlled by parent
  final VoidCallback onToggle; // Callback to toggle expansion
  final VoidCallback onCollapse; // Callback to collapse (for actions)

  const BaseSpeedDial({
    super.key,
    required this.actions,
    required this.isExpanded,
    required this.onToggle,
    required this.onCollapse,
  });

  @override
  State<BaseSpeedDial> createState() => _BaseSpeedDialState();
}

class _BaseSpeedDialState extends State<BaseSpeedDial> {
  Offset _position = const Offset(
    AppTheme.paddingM,
    AppTheme.paddingM,
  ); // Default position (from bottom-right)
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: _position.dx,
      bottom: _position.dy,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          // ESC key dismissal
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              widget.isExpanded) {
            widget.onCollapse();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Update position by subtracting delta (since we're using right/bottom positioning)
              _position = Offset(
                (_position.dx - details.delta.dx).clamp(
                  AppTheme.paddingM,
                  MediaQuery.of(context).size.width - 80,
                ),
                (_position.dy - details.delta.dy).clamp(
                  AppTheme.paddingM,
                  MediaQuery.of(context).size.height - 80,
                ),
              );
            });
          },
          onTap: () {
            // Request focus when tapped so ESC key works
            _focusNode.requestFocus();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expanded action buttons
              if (widget.isExpanded)
                ...widget.actions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppTheme.paddingS + AppTheme.paddingXS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: AppTheme.elevationLevel2,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal:
                                  AppTheme.paddingS + AppTheme.paddingXS,
                              vertical: AppTheme.paddingS,
                            ),
                            child: BodySmallLabel(action.label),
                          ),
                        ),
                        const SizedBox(
                          width: AppTheme.paddingS + AppTheme.paddingXS,
                        ),
                        // Action button
                        FloatingActionButton.small(
                          // No hero: these buttons never survive a route
                          // change, so the animation is meaningless, and a tag
                          // is a liability. Flutter throws when two heroes in
                          // one route share a tag, and the previous tag was
                          // the action's localized label -- a constraint
                          // invisible from the call site, which a translation
                          // could break without touching this file.
                          heroTag: null,
                          onPressed: () {
                            action.onPressed();
                            // Collapse after action
                            widget.onCollapse();
                          },
                          child: Icon(action.icon),
                        ),
                      ],
                    ),
                  ),
                ),
              // Main FAB
              FloatingActionButton(
                // Same reasoning, and here the tag was a shared string
                // literal: two dials on one route -- a screen's own and the
                // one inside an open diff viewer -- would have collided.
                heroTag: null,
                onPressed: () {
                  widget.onToggle();
                  // Request focus so ESC key works
                  _focusNode.requestFocus();
                },
                child: AnimatedRotation(
                  turns: widget.isExpanded
                      ? 0.125
                      : 0, // 45 degrees when expanded
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.isExpanded
                        ? PhosphorIconsRegular.x
                        : PhosphorIconsRegular.list,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
