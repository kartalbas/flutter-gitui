import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../controllers/item_navigation_controller.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';
import 'search_field_handoff.dart';

/// Standardized inline search field
///
/// Provides consistent search UI across all screens.
/// Always visible (not hidden behind icon button) for better discoverability.
///
/// Uses BaseTextField for proper theming in light and dark modes.
///
/// Example usage:
/// ```dart
/// Column(
///   children: [
///     InlineSearchField(
///       controller: _searchController,
///       hintText: l10n.searchPlaceholder,
///       onChanged: (value) => _filterResults(value),
///     ),
///     Expanded(child: _buildFilteredList()),
///   ],
/// )
/// ```
class InlineSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  /// The collection this field filters. When set, ArrowUp/Down typed in the
  /// field move that collection's roving highlight and Enter activates the
  /// highlighted item, while typing continues in the field — see
  /// [SearchFieldHandoff]. Null keeps the field a plain filter.
  final ItemNavigationController? navigationController;

  const InlineSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.navigationController,
  });

  @override
  Widget build(BuildContext context) {
    Widget field = BaseTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: PhosphorIconsRegular.magnifyingGlass,
      showClearButton: true,
      variant: TextFieldVariant.outlined,
      onChanged: (value) {
        onChanged(value);
        if (value.isEmpty) {
          onClear?.call();
        }
      },
    );
    if (navigationController case final navigation?) {
      field = SearchFieldHandoff(controller: navigation, child: field);
    }
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: field,
    );
  }
}
