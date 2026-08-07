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

/// Shows the SDK date picker under the app's own theme, with the picker's
/// text and label colours stated explicitly so both brightnesses read
/// correctly.
///
/// Every override it applies is *layered onto* what the app already
/// configured rather than substituted for it. `ThemeData.copyWith` and
/// `TextTheme.copyWith` both replace the slot they are handed, so a freshly
/// built `InputDecorationTheme` — or a bare `TextStyle(color: …)` in a text
/// role — discards everything the app configured there: the input decorator's
/// corner radius (`inputDecoratorRadius`), its fill, the body-sized label and
/// hint of [AppTheme], and the family, size, tracking and line height of the
/// two body roles. The picker's manual-entry field then renders on the
/// framework defaults for anything not spelled out inline, which is the
/// defect #400 records — the same one #399 fixed a level up, where
/// `AppTheme._layerOn` is the equivalent merge for the button sub-themes.
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
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final inputTheme = theme.inputDecorationTheme;
      final textTheme = theme.textTheme;

      return Theme(
        data: theme.copyWith(
          inputDecorationTheme: inputTheme.copyWith(
            labelStyle: _withColor(
              inputTheme.labelStyle,
              colorScheme.onSurface,
            ),
            hintStyle: _withColor(
              inputTheme.hintStyle,
              colorScheme.onSurfaceVariant,
            ),
            floatingLabelStyle: _withColor(
              inputTheme.floatingLabelStyle,
              colorScheme.primary,
            ),
          ),
          textTheme: textTheme.copyWith(
            bodyLarge: _withColor(textTheme.bodyLarge, colorScheme.onSurface),
            bodyMedium: _withColor(textTheme.bodyMedium, colorScheme.onSurface),
          ),
        ),
        child: child!,
      );
    },
  );
}

/// [base] recoloured to [color], keeping every other property it carries.
///
/// The bare fallback applies only where the theme configured nothing at all —
/// the one case in which there is no configuration left to preserve.
TextStyle _withColor(TextStyle? base, Color color) =>
    base?.copyWith(color: color) ?? TextStyle(color: color);
