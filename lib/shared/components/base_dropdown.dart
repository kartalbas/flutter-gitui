import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import 'base_menu_item.dart';
import 'base_label.dart';
import 'base_text_field.dart';

/// Base dropdown component for consistent dropdown styling across the app
class BaseDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final List<BaseDropdownItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool isExpanded;
  final bool isDense;

  const BaseDropdown({
    super.key,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    required this.items,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.isDense = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: isExpanded,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: AppTheme.iconS)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingM,
          vertical: AppTheme.paddingS,
        ),
        isDense: isDense,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item.value,
          child: item.builder(context),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// Dropdown item with custom builder for content
class BaseDropdownItem<T> {
  final T value;
  final Widget Function(BuildContext) builder;

  const BaseDropdownItem({
    required this.value,
    required this.builder,
  });

  /// Create a simple dropdown item with icon and label
  factory BaseDropdownItem.simple({
    required T value,
    required String label,
    IconData? icon,
    Widget? trailing,
  }) {
    return BaseDropdownItem(
      value: value,
      builder: (context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const SizedBox(width: AppTheme.paddingS),
          ],
          Expanded(
            child: MenuItemLabel(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.paddingS),
            trailing,
          ],
        ],
      ),
    );
  }

  /// Create a dropdown item with icon, label, and optional badge
  factory BaseDropdownItem.withBadge({
    required T value,
    required String label,
    IconData? icon,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return BaseDropdownItem(
      value: value,
      builder: (context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const SizedBox(width: AppTheme.paddingS),
          ],
          Expanded(
            child: MenuItemLabel(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingXS,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: badgeColor ?? Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(3),
              ),
              child: MenuItemLabel(
                badgeText,
                color: badgeTextColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Searchable dropdown with popup menu and search field
/// Shows a search icon that opens a popup with search field and filtered items
class SearchableBaseDropdown<T> extends StatefulWidget {
  final T? value;
  final String? labelText;
  final String? hintText;
  final String? searchHintText;
  final IconData? prefixIcon;
  final List<SearchableDropdownItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final String Function(T) displayStringForItem;
  final int minSearchLength;

  const SearchableBaseDropdown({
    super.key,
    this.value,
    this.labelText,
    this.hintText,
    this.searchHintText,
    this.prefixIcon,
    required this.items,
    this.onChanged,
    this.validator,
    required this.displayStringForItem,
    this.minSearchLength = 3,
  });

  @override
  State<SearchableBaseDropdown<T>> createState() => _SearchableBaseDropdownState<T>();
}

class _SearchableBaseDropdownState<T> extends State<SearchableBaseDropdown<T>> {
  final _focusNode = FocusNode();
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _showOverlay() {
    if (_isOpen) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: _SearchableDropdownOverlay<T>(
              items: widget.items,
              searchHintText: widget.searchHintText ?? 'Search...',
              minSearchLength: widget.minSearchLength,
              onSelected: (item) {
                widget.onChanged?.call(item);
                _removeOverlay();
              },
              onDismiss: _removeOverlay,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.where((item) => item.value == widget.value).firstOrNull;
    final displayText = selectedItem != null
        ? widget.displayStringForItem(selectedItem.value)
        : widget.hintText ?? '';

    return CompositedTransformTarget(
      link: _layerLink,
      child: FormField<T>(
        initialValue: widget.value,
        validator: widget.validator,
        builder: (formState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.labelText != null) ...[
                LabelMediumLabel(widget.labelText!),
                const SizedBox(height: AppTheme.paddingXS),
              ],
              InkWell(
                onTap: () {
                  if (_isOpen) {
                    _removeOverlay();
                  } else {
                    _showOverlay();
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS + 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: formState.hasError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        Icon(
                          widget.prefixIcon,
                          size: AppTheme.iconS,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                      ],
                      Expanded(
                        child: BodyMediumLabel(
                          displayText,
                          color: selectedItem != null
                              ? null
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _isOpen ? PhosphorIconsRegular.caretUp : PhosphorIconsRegular.caretDown,
                        size: AppTheme.iconS,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (formState.hasError) ...[
                const SizedBox(height: AppTheme.paddingXS),
                LabelSmallLabel(
                  formState.errorText ?? '',
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Overlay content for searchable dropdown
class _SearchableDropdownOverlay<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final String searchHintText;
  final int minSearchLength;
  final void Function(T) onSelected;
  final VoidCallback onDismiss;

  const _SearchableDropdownOverlay({
    required this.items,
    required this.searchHintText,
    required this.minSearchLength,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_SearchableDropdownOverlay<T>> createState() => _SearchableDropdownOverlayState<T>();
}

class _SearchableDropdownOverlayState<T> extends State<_SearchableDropdownOverlay<T>> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field when overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter items based on search query (only if >= minSearchLength chars)
    final filteredItems = _searchQuery.length >= widget.minSearchLength
        ? widget.items.where((item) =>
            item.searchText.toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        : widget.items;

    return TapRegion(
      onTapOutside: (_) => widget.onDismiss(),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(AppTheme.paddingS),
              child: BaseTextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: widget.searchHintText,
                prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Divider
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),

            // Items list
            Flexible(
              child: filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppTheme.paddingL),
                      child: Center(
                        child: BodySmallLabel(
                          'No items found',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return InkWell(
                          onTap: () => widget.onSelected(item.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingM,
                              vertical: AppTheme.paddingS,
                            ),
                            child: item.builder(context),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item for searchable dropdown
class SearchableDropdownItem<T> {
  final T value;
  final String searchText;
  final Widget Function(BuildContext) builder;

  const SearchableDropdownItem({
    required this.value,
    required this.searchText,
    required this.builder,
  });

  /// Create a simple searchable dropdown item with icon, label, and optional subtitle
  factory SearchableDropdownItem.simple({
    required T value,
    required String label,
    String? subtitle,
    IconData? icon,
  }) {
    return SearchableDropdownItem(
      value: value,
      searchText: label,
      builder: (context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: AppTheme.paddingS),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MenuItemLabel(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  LabelSmallLabel(
                    subtitle,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
