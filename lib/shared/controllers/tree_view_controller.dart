import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tree_node.dart';

/// Controller for managing tree view navigation, selection, and scrolling.
///
/// This controller provides:
/// - Keyboard navigation (up/down arrows)
/// - Selection management with index-based tracking
/// - Auto-scrolling to keep selection visible
/// - Directory expansion/collapse via Space/Enter
///
/// Usage:
/// ```dart
/// final controller = TreeViewController<MyTreeNode>();
///
/// // Update when tree changes
/// controller.updateNodes(rootNodes);
///
/// // In build method
/// CallbackShortcuts(
///   bindings: controller.keyBindings,
///   child: Focus(
///     focusNode: controller.focusNode,
///     child: ListView.builder(
///       controller: controller.scrollController,
///       itemCount: controller.flattenedNodes.length,
///       itemBuilder: (context, index) {
///         final node = controller.flattenedNodes[index];
///         final isSelected = controller.isSelected(index);
///         // Build item...
///       },
///     ),
///   ),
/// );
/// ```
class TreeViewController<T extends TreeNodeMixin> extends ChangeNotifier {
  /// Focus node for keyboard shortcuts
  final FocusNode focusNode = FocusNode();

  /// Scroll controller for auto-scrolling to selection
  final ScrollController scrollController = ScrollController();

  /// Currently selected index in the flattened tree
  int _selectedIndex = -1;

  /// Flattened list of visible nodes for efficient navigation
  List<T> _flattenedNodes = [];

  /// Root nodes of the tree
  List<T> _rootNodes = [];

  /// Approximate height of each tree item (for scroll calculations)
  final double itemHeight;

  /// Whether to skip directories when navigating (select files only)
  final bool skipDirectories;

  /// Callback when selection changes
  final void Function(T? node)? onSelectionChanged;

  /// Callback when a node should be toggled (directory expand/collapse or file action)
  final void Function(T node)? onToggleNode;

  /// Async callback to load children before expanding a directory (for lazy loading)
  /// Return true if children were loaded successfully
  final Future<bool> Function(T node)? onLoadChildren;

  TreeViewController({
    this.itemHeight = 32.0,
    this.skipDirectories = false,
    this.onSelectionChanged,
    this.onToggleNode,
    this.onLoadChildren,
  });

  /// Get the currently selected index
  int get selectedIndex => _selectedIndex;

  /// Get the flattened nodes list
  List<T> get flattenedNodes => _flattenedNodes;

  /// Get the root nodes
  List<T> get rootNodes => _rootNodes;

  /// Get the currently selected node
  T? get selectedNode {
    if (_selectedIndex >= 0 && _selectedIndex < _flattenedNodes.length) {
      return _flattenedNodes[_selectedIndex];
    }
    return null;
  }

  /// Check if a given index is selected
  bool isSelected(int index) => index == _selectedIndex;

  /// Keyboard bindings for CallbackShortcuts
  Map<ShortcutActivator, VoidCallback> get keyBindings => {
        const SingleActivator(LogicalKeyboardKey.arrowUp): navigateUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): navigateDown,
        const SingleActivator(LogicalKeyboardKey.space): toggleSelectedNode,
        const SingleActivator(LogicalKeyboardKey.enter): toggleSelectedNode,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): collapseSelected,
        const SingleActivator(LogicalKeyboardKey.arrowRight): expandSelected,
      };

  /// Update the tree with new root nodes
  void updateNodes(List<T> rootNodes) {
    _rootNodes = rootNodes;
    _flattenedNodes = _flattenTree(rootNodes);
    _validateSelection();
    notifyListeners();
  }

  /// Set the selected index directly
  void setSelectedIndex(int index) {
    if (index >= -1 && index < _flattenedNodes.length) {
      _selectedIndex = index;
      onSelectionChanged?.call(selectedNode);
      notifyListeners();
    }
  }

  /// Select a node by its full path
  void selectByPath(String? path) {
    if (path == null) {
      _selectedIndex = -1;
      onSelectionChanged?.call(null);
      notifyListeners();
      return;
    }

    for (int i = 0; i < _flattenedNodes.length; i++) {
      if (_flattenedNodes[i].fullPath == path) {
        _selectedIndex = i;
        onSelectionChanged?.call(_flattenedNodes[i]);
        notifyListeners();
        scrollToSelected();
        return;
      }
    }
  }

  /// Navigate to previous item
  void navigateUp() {
    if (_flattenedNodes.isEmpty) return;

    int newIndex = _selectedIndex - 1;

    if (skipDirectories) {
      // Find previous non-directory
      while (newIndex >= 0 && _flattenedNodes[newIndex].isDirectory) {
        newIndex--;
      }
    }

    if (newIndex >= 0) {
      _selectedIndex = newIndex;
      onSelectionChanged?.call(selectedNode);
      notifyListeners();
      scrollToSelected();
      focusNode.requestFocus();
    }
  }

  /// Navigate to next item
  void navigateDown() {
    if (_flattenedNodes.isEmpty) return;

    int newIndex = _selectedIndex + 1;

    if (skipDirectories) {
      // Find next non-directory
      while (newIndex < _flattenedNodes.length &&
          _flattenedNodes[newIndex].isDirectory) {
        newIndex++;
      }
    }

    if (newIndex < _flattenedNodes.length) {
      _selectedIndex = newIndex;
      onSelectionChanged?.call(selectedNode);
      notifyListeners();
      scrollToSelected();
      focusNode.requestFocus();
    }
  }

  /// Toggle the selected node (expand/collapse directory or trigger action)
  void toggleSelectedNode() {
    if (_flattenedNodes.isEmpty ||
        _selectedIndex < 0 ||
        _selectedIndex >= _flattenedNodes.length) {
      return;
    }

    final node = _flattenedNodes[_selectedIndex];

    if (node.isDirectory) {
      // Toggle directory expansion
      if (!node.isExpanded && onLoadChildren != null && node.children.isEmpty) {
        // Load children first if expanding and empty
        onLoadChildren!(node).then((success) {
          if (success) {
            node.isExpanded = true;
            _flattenedNodes = _flattenTree(_rootNodes);
            notifyListeners();
          }
        });
      } else {
        node.isExpanded = !node.isExpanded;
        _flattenedNodes = _flattenTree(_rootNodes);
        notifyListeners();
      }
    } else {
      // Trigger callback for file action
      onToggleNode?.call(node);
    }
  }

  /// Collapse the selected directory
  void collapseSelected() {
    if (_flattenedNodes.isEmpty ||
        _selectedIndex < 0 ||
        _selectedIndex >= _flattenedNodes.length) {
      return;
    }

    final node = _flattenedNodes[_selectedIndex];

    if (node.isDirectory && node.isExpanded) {
      node.isExpanded = false;
      _flattenedNodes = _flattenTree(_rootNodes);
      notifyListeners();
    }
  }

  /// Expand the selected directory
  void expandSelected() {
    if (_flattenedNodes.isEmpty ||
        _selectedIndex < 0 ||
        _selectedIndex >= _flattenedNodes.length) {
      return;
    }

    final node = _flattenedNodes[_selectedIndex];

    if (node.isDirectory && !node.isExpanded) {
      // If lazy loading callback is provided and children are empty, load them first
      if (onLoadChildren != null && node.children.isEmpty) {
        onLoadChildren!(node).then((success) {
          if (success) {
            node.isExpanded = true;
            _flattenedNodes = _flattenTree(_rootNodes);
            notifyListeners();
          }
        });
      } else {
        node.isExpanded = true;
        _flattenedNodes = _flattenTree(_rootNodes);
        notifyListeners();
      }
    }
  }

  /// Toggle expansion of a specific node
  void toggleNodeExpansion(T node) {
    if (node.isDirectory) {
      if (!node.isExpanded && onLoadChildren != null && node.children.isEmpty) {
        // Load children first if expanding and empty
        onLoadChildren!(node).then((success) {
          if (success) {
            node.isExpanded = true;
            _flattenedNodes = _flattenTree(_rootNodes);
            notifyListeners();
          }
        });
      } else {
        node.isExpanded = !node.isExpanded;
        _flattenedNodes = _flattenTree(_rootNodes);
        notifyListeners();
      }
    }
  }

  /// Scroll to keep the selected item visible
  void scrollToSelected() {
    if (!scrollController.hasClients) return;
    if (_selectedIndex < 0) return;

    final position = _selectedIndex * itemHeight;
    final viewportHeight = scrollController.position.viewportDimension;
    final currentScroll = scrollController.offset;

    if (position < currentScroll) {
      // Scroll up
      scrollController.jumpTo(position);
    } else if (position > currentScroll + viewportHeight - itemHeight) {
      // Scroll down
      scrollController.jumpTo(position - viewportHeight + itemHeight);
    }
  }

  /// Request focus on the tree view
  void requestFocus() {
    focusNode.requestFocus();
  }

  /// Flatten the tree into a list of visible nodes
  List<T> _flattenTree(List<T> nodes) {
    final result = <T>[];
    for (final node in nodes) {
      result.add(node);
      if (node.isDirectory && node.isExpanded && node.children.isNotEmpty) {
        result.addAll(_flattenTree(node.children.cast<T>()));
      }
    }
    return result;
  }

  /// Validate and adjust selection after tree updates
  void _validateSelection() {
    if (_flattenedNodes.isEmpty) {
      _selectedIndex = -1;
      return;
    }

    // Keep selection within bounds
    if (_selectedIndex >= _flattenedNodes.length) {
      _selectedIndex = _flattenedNodes.length - 1;
    }

    if (_selectedIndex < 0) {
      // Find first selectable item
      if (skipDirectories) {
        _selectedIndex = 0;
        while (_selectedIndex < _flattenedNodes.length &&
            _flattenedNodes[_selectedIndex].isDirectory) {
          _selectedIndex++;
        }
        if (_selectedIndex >= _flattenedNodes.length) {
          _selectedIndex = -1;
        }
      } else {
        _selectedIndex = 0;
      }
    }

    // If current selection is a directory and we skip directories, find nearest file
    if (skipDirectories &&
        _selectedIndex >= 0 &&
        _selectedIndex < _flattenedNodes.length &&
        _flattenedNodes[_selectedIndex].isDirectory) {
      // Try next
      int newIndex = _selectedIndex + 1;
      while (newIndex < _flattenedNodes.length &&
          _flattenedNodes[newIndex].isDirectory) {
        newIndex++;
      }
      if (newIndex < _flattenedNodes.length) {
        _selectedIndex = newIndex;
      } else {
        // Try previous
        newIndex = _selectedIndex - 1;
        while (newIndex >= 0 && _flattenedNodes[newIndex].isDirectory) {
          newIndex--;
        }
        _selectedIndex = newIndex;
      }
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
