import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_theme.dart';
import '../components/base_text_field.dart';

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

  const InlineSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      child: BaseTextField(
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
      ),
    );
  }
}
