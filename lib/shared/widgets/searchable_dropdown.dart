import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../components/base_label.dart';
import '../components/base_button.dart';

/// A searchable dropdown that allows users to filter options by typing
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T) displayStringForOption;
  final void Function(T?) onChanged;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final InputDecoration? decoration;
  final String? Function(T?)? validator;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.displayStringForOption,
    required this.onChanged,
    this.value,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.decoration,
    this.validator,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.value != null
          ? widget.displayStringForOption(widget.value as T)
          : '',
    );
    _filteredItems = widget.items;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _textController.text = widget.value != null
          ? widget.displayStringForOption(widget.value as T)
          : '';
    }
    if (widget.items != oldWidget.items) {
      _filteredItems = widget.items;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    // Remove overlay without calling setState (widget is being disposed)
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_isOpen) {
      _showOverlay();
    }
  }

  void _filterItems(String query) {
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final displayString = widget
              .displayStringForOption(item)
              .toLowerCase();
          return displayString.contains(query.toLowerCase());
        }).toList();
      }
    });
    _updateOverlay();
  }

  void _showOverlay() {
    if (!mounted) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _updateOverlay() {
    if (mounted) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 4.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _filteredItems.isEmpty
                  ? Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Padding(
                          padding: const EdgeInsets.all(AppTheme.paddingM),
                          child: BodyMediumLabel(
                            l10n.emptyStateNoResultsFound,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.paddingS,
                      ),
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = widget.value == item;

                        return InkWell(
                          onTap: () => _selectItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingM,
                              vertical: AppTheme.paddingS,
                            ),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: 0.3)
                                : null,
                            child: BodyMediumLabel(
                              widget.displayStringForOption(item),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectItem(T item) {
    _textController.text = widget.displayStringForOption(item);
    widget.onChanged(item);
    _removeOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Note: Using TextFormField here is necessary because this component needs:
    // 1. Complex suffixIcon with multiple widgets (Row)
    // 2. onTap handler for overlay management
    // 3. Custom decoration that BaseTextField doesn't fully support
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _textController,
        focusNode: _focusNode,
        decoration:
            widget.decoration ??
            InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_textController.text.isNotEmpty)
                    BaseIconButton(
                      icon: Icons.clear,
                      size: ButtonSize.small,
                      onPressed: () {
                        _textController.clear();
                        widget.onChanged(null);
                        _filterItems('');
                      },
                    ),
                  Icon(
                    _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.paddingS),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingM,
                vertical: AppTheme.paddingM,
              ),
            ),
        onChanged: _filterItems,
        onTap: () {
          if (!_isOpen) {
            _showOverlay();
          }
        },
        validator: widget.validator != null
            ? (String? value) {
                // Find the item that matches the text
                final matchingItem = value != null && value.isNotEmpty
                    ? widget.items.cast<T?>().firstWhere(
                        (item) =>
                            item != null &&
                            widget.displayStringForOption(item) == value,
                        orElse: () => null,
                      )
                    : null;
                return widget.validator!(matchingItem);
              }
            : null,
      ),
    );
  }
}
