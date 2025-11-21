import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import 'base_label.dart';
import 'base_button.dart';
import '../../generated/app_localizations.dart';

/// Base date field component with consistent theming for light/dark modes
class BaseDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const BaseDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateValue = value;

    return InkWell(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: dateValue != null
              ? BaseIconButton(
                  icon: PhosphorIconsRegular.x,
                  onPressed: () => onChanged(null),
                  size: ButtonSize.small,
                )
              : const Icon(PhosphorIconsRegular.calendar, size: 20),
        ),
        child: dateValue != null
            ? BodyMediumLabel(dateFormat.format(dateValue))
            : BodyMediumLabel(
                AppLocalizations.of(context)!.selectDate,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showThemedDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      onChanged(date);
    }
  }
}

/// Show date picker with proper theme for dark mode support
Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            floatingLabelStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          textTheme: Theme.of(context).textTheme.copyWith(
            bodyLarge: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            bodyMedium: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}
