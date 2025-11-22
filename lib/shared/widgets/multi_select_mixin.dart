import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Selection state for individual items
///
/// Used to determine visual feedback in list components:
/// - none: Not selected (no highlight)
/// - primary: Primary/most recent selection (primary border + tint)
/// - multiSelected: Part of multi-selection (secondary border + tint)
enum SelectionState {
  /// Item is not selected
  none,
  /// Item is the primary/most recent selection
  primary,
  /// Item is selected as part of multi-selection (but not primary)
  multiSelected,
}

/// Platform-aware multi-selection helper
///
/// Provides standard multi-selection behavior:
/// - Windows/Linux: Ctrl+Click for multi-select, Shift+Click for range
/// - macOS: Cmd+Click for multi-select, Shift+Click for range
///
/// Usage:
/// ```dart
/// final selectionManager = MultiSelectManager<GitCommit>();
///
/// // In your tap handler:
/// selectionManager.handleItemClick(
///   item: commit,
///   allItems: allCommits,
///   isControlPressed: HardwareKeyboard.instance.isControlPressed,
///   isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
///   onSelectionChanged: () => setState(() {}),
/// );
///
/// // Get selection state for visual feedback:
/// final state = selectionManager.getSelectionState(commit);
/// // Use with BaseListItem:
/// BaseListItem(
///   isSelected: state == SelectionState.primary,
///   isMultiSelected: state == SelectionState.multiSelected,
///   ...
/// )
/// ```
class MultiSelectManager<T> {
  final Set<T> selectedItems = {};
  T? _lastSelectedItem;

  /// Check if the platform-appropriate multi-select modifier is pressed
  /// (Ctrl on Windows/Linux, Cmd on macOS)
  static bool isMultiSelectModifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return keyboard.isMetaPressed; // Cmd key on macOS
    } else {
      return keyboard.isControlPressed; // Ctrl key on Windows/Linux
    }
  }

  /// Check if Shift key is pressed
  static bool isRangeSelectModifierPressed() {
    return HardwareKeyboard.instance.isShiftPressed;
  }

  /// Handle item click with platform-aware modifiers
  ///
  /// [item] - The clicked item
  /// [allItems] - List of all items for range selection
  /// [isControlPressed] - Whether Ctrl/Cmd is pressed
  /// [isShiftPressed] - Whether Shift is pressed
  /// [onSelectionChanged] - Callback when selection changes
  void handleItemClick({
    required T item,
    required List<T> allItems,
    required bool isControlPressed,
    required bool isShiftPressed,
    required VoidCallback onSelectionChanged,
  }) {
    if (isShiftPressed && _lastSelectedItem != null) {
      // Range selection
      _handleRangeSelect(item, allItems, onSelectionChanged);
    } else if (isControlPressed) {
      // Toggle individual item
      _handleToggleSelect(item, onSelectionChanged);
    } else {
      // Single selection (clear others)
      _handleSingleSelect(item, onSelectionChanged);
    }
  }

  void _handleSingleSelect(T item, VoidCallback onSelectionChanged) {
    selectedItems.clear();
    selectedItems.add(item);
    _lastSelectedItem = item;
    onSelectionChanged();
  }

  void _handleToggleSelect(T item, VoidCallback onSelectionChanged) {
    if (selectedItems.contains(item)) {
      selectedItems.remove(item);
      if (_lastSelectedItem == item) {
        _lastSelectedItem = selectedItems.isNotEmpty ? selectedItems.last : null;
      }
    } else {
      selectedItems.add(item);
      _lastSelectedItem = item;
    }
    onSelectionChanged();
  }

  void _handleRangeSelect(T item, List<T> allItems, VoidCallback onSelectionChanged) {
    if (_lastSelectedItem == null) {
      _handleSingleSelect(item, onSelectionChanged);
      return;
    }

    final startIndex = allItems.indexOf(_lastSelectedItem as T);
    final endIndex = allItems.indexOf(item);

    if (startIndex == -1 || endIndex == -1) {
      _handleSingleSelect(item, onSelectionChanged);
      return;
    }

    // Clear and select range
    selectedItems.clear();
    final start = startIndex < endIndex ? startIndex : endIndex;
    final end = startIndex < endIndex ? endIndex : startIndex;

    for (int i = start; i <= end; i++) {
      selectedItems.add(allItems[i]);
    }

    _lastSelectedItem = item;
    onSelectionChanged();
  }

  /// Select all items
  void selectAll(List<T> allItems, VoidCallback onSelectionChanged) {
    selectedItems.clear();
    selectedItems.addAll(allItems);
    _lastSelectedItem = allItems.isNotEmpty ? allItems.last : null;
    onSelectionChanged();
  }

  /// Clear all selections
  void clearSelection(VoidCallback onSelectionChanged) {
    selectedItems.clear();
    _lastSelectedItem = null;
    onSelectionChanged();
  }

  /// Check if item is selected
  bool isItemSelected(T item) {
    return selectedItems.contains(item);
  }

  /// Get the selection state for an item
  ///
  /// Returns:
  /// - [SelectionState.primary] if this is the last selected item (primary selection)
  /// - [SelectionState.multiSelected] if selected but not the last one (secondary selection)
  /// - [SelectionState.none] if not selected
  ///
  /// Use this method to determine visual feedback in list components:
  /// ```dart
  /// final state = selectionManager.getSelectionState(item);
  /// BaseListItem(
  ///   isSelected: state == SelectionState.primary,
  ///   isMultiSelected: state == SelectionState.multiSelected,
  ///   ...
  /// )
  /// ```
  SelectionState getSelectionState(T item) {
    if (!selectedItems.contains(item)) {
      return SelectionState.none;
    }
    if (item == _lastSelectedItem) {
      return SelectionState.primary;
    }
    return SelectionState.multiSelected;
  }

  /// Get count of selected items
  int get selectedCount => selectedItems.length;

  /// Check if any items are selected
  bool get hasSelection => selectedItems.isNotEmpty;
}
