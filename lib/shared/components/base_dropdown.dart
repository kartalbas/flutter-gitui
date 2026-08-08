import 'package:flutter/material.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, TextRole, Tone;

import '../theme/app_theme.dart';
import 'base_icon.dart';
import 'base_label.dart';
import 'base_text_field.dart';

/// Base dropdown component for consistent dropdown styling across the app.
///
/// Geometry, outline colors per state and typography are asserted against a
/// real SDK `DropdownButtonFormField` by
/// packages/gitui_skin_material/test/conformance/components/base_dropdown_conformance_test.dart;
/// the single deliberate divergence is registered as DROP-001 in
/// packages/gitui_skin_material/docs/deviation_register.yaml.
class BaseDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final String? labelText;
  final String? hintText;

  /// The meaning of an optional leading mark; the skin chooses the glyph.
  final IconRole? prefixIcon;
  final List<BaseDropdownItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool isExpanded;

  /// Focus this dropdown when the dialog opens, so the keyboard lands on the
  /// dialog's first field (Space/Enter opens the menu, arrows pick a value).
  final bool autofocus;
  final FocusNode? focusNode;

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
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: isExpanded,
      autofocus: autofocus,
      focusNode: focusNode,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        // Shape only: the content padding and the minimum height are the
        // Material 3 defaults for an outlined field
        // (EdgeInsetsDirectional.fromSTEB(12, 20, 12, 12) plus the border's
        // 4 dp gap padding, Flutter 3.44.4
        // packages/flutter/lib/src/material/input_decorator.dart:2629-2635,
        // floored at kMinInteractiveDimension by :1331). The dropdown used to
        // set `isDense` and its own padding, which shrank it to 40 dp — below
        // the minimum interactive dimension, and 15 dp shorter than a
        // BaseTextField standing next to it in the same dialog.
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon == null
            ? null
            : BaseIcon(prefixIcon!, scale: ControlScale.normal),
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

  const BaseDropdownItem({required this.value, required this.builder});

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
          // One line, because a menu entry is a row: the line cap is the fact
          // the application states, and how the skin truncates the last line
          // is the skin's idiom.
          Expanded(
            child: BaseLabel(label, role: TextRole.control, maxLines: 1),
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
  ///
  /// The `badgeColor` / `badgeTextColor` pair this used to accept is gone. It
  /// let a caller hand in a fill and a foreground as two independent `Color`s,
  /// which is two design decisions crossing an application API and, worse, two
  /// that can contradict each other — a caller could set the fill and leave the
  /// text pairing behind. No call site ever passed either, so nothing is lost
  /// today; when the badge becomes `surfaces.badge` at P3d it will carry a
  /// single [Tone] and the skin will pair the foreground with the fill itself,
  /// which is the one arrangement that cannot be got wrong.
  factory BaseDropdownItem.withBadge({
    required T value,
    required String label,
    IconData? icon,
    String? badgeText,
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
            child: BaseLabel(label, role: TextRole.control, maxLines: 1),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: AppTheme.paddingS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingXS,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              // The surface publishes the foreground it pairs with, and the
              // label reads it. That is the whole of Material's on-colour model
              // (`docs/SKIN-CONTRACT-MEMBERS.md` §10.2) and the reason the
              // label itself now says nothing about colour: a container that
              // states its own pairing cannot be given text that disagrees
              // with it.
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                child: BaseLabel(badgeText, role: TextRole.control),
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

  /// The meaning of an optional leading mark; the skin chooses the glyph.
  final IconRole? prefixIcon;
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
  State<SearchableBaseDropdown<T>> createState() =>
      _SearchableBaseDropdownState<T>();
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
            elevation: AppTheme.elevationLevel2,
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
    final selectedItem = widget.items
        .where((item) => item.value == widget.value)
        .firstOrNull;
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
                // A field's own label is text the user operates, which is what
                // `TextRole.control` names explicitly. It was drawn a rung
                // below every other field label in the application; this is the
                // disagreement being removed rather than a size being chosen.
                BaseLabel(widget.labelText!, role: TextRole.control),
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
                        BaseIcon(
                          widget.prefixIcon!,
                          scale: ControlScale.compact,
                          tone: Tone.muted,
                        ),
                        const SizedBox(width: AppTheme.paddingS),
                      ],
                      Expanded(
                        child: BaseLabel(
                          displayText,
                          role: TextRole.body,
                          // Nothing has been chosen yet, so this line is a
                          // placeholder rather than a value.
                          tone: selectedItem != null
                              ? Tone.neutral
                              : Tone.muted,
                          // A closed field is one line tall whatever it holds;
                          // wrapping here would grow the field as the user
                          // picks a longer value.
                          maxLines: 1,
                        ),
                      ),
                      BaseIcon(
                        _isOpen ? IconRole.caretUp : IconRole.caretDown,
                        scale: ControlScale.compact,
                        tone: Tone.muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (formState.hasError) ...[
                const SizedBox(height: AppTheme.paddingXS),
                BaseLabel(
                  formState.errorText ?? '',
                  role: TextRole.detail,
                  tone: Tone.danger,
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
  State<_SearchableDropdownOverlay<T>> createState() =>
      _SearchableDropdownOverlayState<T>();
}

class _SearchableDropdownOverlayState<T>
    extends State<_SearchableDropdownOverlay<T>> {
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
        ? widget.items
              .where(
                (item) => item.searchText.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList()
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
                prefixIcon: IconRole.magnifyingGlass,
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
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
            ),

            // Items list
            Flexible(
              child: filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppTheme.paddingL),
                      child: Center(
                        child: BaseLabel(
                          'No items found',
                          role: TextRole.detail,
                          tone: Tone.muted,
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
                BaseLabel(label, role: TextRole.control, maxLines: 1),
                if (subtitle != null)
                  BaseLabel(subtitle, role: TextRole.micro, tone: Tone.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
