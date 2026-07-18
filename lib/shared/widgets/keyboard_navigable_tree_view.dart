import 'package:flutter/material.dart';

import '../controllers/tree_view_controller.dart';
import '../models/tree_node.dart';

/// A widget that wraps a tree view with keyboard navigation support.
///
/// This widget provides:
/// - Arrow key navigation (up/down to move, left/right to collapse/expand)
/// - Space/Enter to toggle directory or trigger action
/// - Auto-focus and focus management
///
/// Usage:
/// ```dart
/// KeyboardNavigableTreeView<MyTreeNode>(
///   controller: treeController,
///   itemBuilder: (context, node, depth, isSelected) {
///     return Container(
///       color: isSelected ? Colors.blue : null,
///       child: Text(node.name),
///     );
///   },
/// )
/// ```
class KeyboardNavigableTreeView<T extends TreeNodeMixin> extends StatelessWidget {
  /// The tree view controller
  final TreeViewController<T> controller;

  /// Builder for each tree item
  final Widget Function(BuildContext context, T node, int depth, bool isSelected)
      itemBuilder;

  /// Whether to autofocus when built
  final bool autofocus;

  /// Additional key bindings to merge with the default navigation bindings
  final Map<ShortcutActivator, VoidCallback>? additionalBindings;

  /// Callback when the tree view is tapped (to request focus)
  final VoidCallback? onTap;

  const KeyboardNavigableTreeView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.autofocus = true,
    this.additionalBindings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Merge bindings
    final bindings = <ShortcutActivator, VoidCallback>{
      ...controller.keyBindings,
      if (additionalBindings != null) ...additionalBindings!,
    };

    return GestureDetector(
      onTap: () {
        controller.requestFocus();
        onTap?.call();
      },
      child: CallbackShortcuts(
        bindings: bindings,
        child: Focus(
          focusNode: controller.focusNode,
          autofocus: autofocus,
          skipTraversal: false,
          canRequestFocus: true,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return ListView.builder(
                controller: controller.scrollController,
                itemCount: controller.flattenedNodes.length,
                itemBuilder: (context, index) {
                  final node = controller.flattenedNodes[index];
                  final depth = _calculateDepth(node);
                  final isSelected = controller.isSelected(index);

                  return itemBuilder(context, node, depth, isSelected);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Calculate the depth of a node based on path separators
  int _calculateDepth(T node) {
    final pathSeparators = node.fullPath.split('/').length - 1;
    // Also handle Windows path separators
    final windowsSeparators = node.fullPath.split('\\').length - 1;
    return pathSeparators > windowsSeparators
        ? pathSeparators
        : windowsSeparators;
  }
}
