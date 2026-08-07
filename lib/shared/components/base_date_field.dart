import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'base_label.dart';
import 'base_button.dart';
import '../../generated/app_localizations.dart';

/// A Material 3 outlined text field whose value is picked from the date
/// picker instead of typed.
///
/// It is measured against the same oracle as [BaseTextField] — a real SDK
/// `TextField` with an `OutlineInputBorder` — by
/// test/conformance/components/base_date_field_conformance_test.dart, because
/// it is the same M3 component: an `InputDecorator` around a value.
///
/// It therefore speaks the text field's state language rather than a button's:
/// hover darkens the outline to `onSurface` and focus draws it in `primary` at
/// 2 dp (input_decorator.dart:5995), both driven by [InputDecorator.isHovering]
/// and [InputDecorator.isFocused]. That is why the tap surface is a
/// [FocusableActionDetector] and not an `InkWell` — an ink layer would paint a
/// hover and focus highlight *on top of* those two, which is the "never two
/// affordances for one job" defect the design system forbids, and before the
/// outline shape was passed down it painted them as a square behind the
/// rounded field.
class BaseDateField extends StatefulWidget {
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
  State<BaseDateField> createState() => _BaseDateFieldState();
}

class _BaseDateFieldState extends State<BaseDateField> {
  bool _isFocused = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateValue = widget.value;

    // Hover is tracked with a MouseRegion and focus with `onFocusChange`
    // rather than with FocusableActionDetector's two highlight callbacks:
    // those are gated on the focus *highlight mode* and stay silent while the
    // app is in touch mode, whereas a text field shows its focused outline
    // however it was reached — including by a mouse click — and darkens its
    // outline whenever the pointer is over it.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (PointerEnterEvent event) => setState(() => _isHovering = true),
      onExit: (PointerExitEvent event) => setState(() => _isHovering = false),
      child: FocusableActionDetector(
        onFocusChange: (bool value) => setState(() => _isFocused = value),
        // Enter and Space must open the picker: the field is a Tab stop, and a
        // control a keyboard user can reach but not operate is an unfinished
        // control. Both intents are bound because the framework's default
        // shortcuts send ActivateIntent for Space and ButtonActivateIntent for
        // Enter on some platforms.
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) => _selectDate(context),
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (ButtonActivateIntent intent) => _selectDate(context),
          ),
        },
        child: GestureDetector(
          onTap: () => _selectDate(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              // The empty field shows the M3 hint, not a value-styled
              // placeholder: "no date yet" is not a value.
              hintText: AppLocalizations.of(context)!.selectDate,
              border: const OutlineInputBorder(),
              suffixIcon: dateValue != null
                  ? BaseIconButton(
                      icon: PhosphorIconsRegular.x,
                      onPressed: () => widget.onChanged(null),
                      tooltip: AppLocalizations.of(context)!.clear,
                      size: ButtonSize.small,
                    )
                  : const Icon(
                      PhosphorIconsRegular.calendar,
                      size: AppTheme.iconM,
                    ),
            ),
            isEmpty: dateValue == null,
            isFocused: _isFocused,
            isHovering: _isHovering,
            // The value slot always carries a line of input-role text, empty
            // or not, so the field keeps one height whether or not a date is
            // set.
            child: BodyLargeLabel(
              dateValue == null ? '' : dateFormat.format(dateValue),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showThemedDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate:
          widget.lastDate ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      widget.onChanged(date);
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
