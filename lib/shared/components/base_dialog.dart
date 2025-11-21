import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../generated/app_localizations.dart';
import '../../core/constants/constants.dart';
import '../../shared/theme/app_theme.dart';
import 'base_button.dart';
import 'base_label.dart';

/// Dialog visual variants
enum DialogVariant {
  /// Standard dialog
  normal,

  /// Confirmation dialog (OK/Cancel)
  confirmation,

  /// Destructive action dialog (red accent)
  destructive,
}

/// Base component for all dialog patterns in the app.
///
/// Provides 3 variants:
/// - Normal: Standard dialog
/// - Confirmation: OK/Cancel dialog
/// - Destructive: Red accent for destructive actions
///
/// Example usage:
/// ```dart
/// BaseDialog.show(
///   context: context,
///   dialog: BaseDialog(
///     title: 'Delete branch?',
///     content: Text('This action cannot be undone.'),
///     variant: DialogVariant.destructive,
///     icon: PhosphorIconsRegular.warning,
///     actions: [
///       BaseButton(
///         label: 'Cancel',
///         variant: ButtonVariant.tertiary,
///         onPressed: () => Navigator.pop(context, false),
///       ),
///       BaseButton(
///         label: 'Delete',
///         variant: ButtonVariant.danger,
///         onPressed: () {
///           deleteBranch();
///           Navigator.pop(context, true);
///         },
///       ),
///     ],
///   ),
/// );
/// ```
class BaseDialog extends StatelessWidget {
  const BaseDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.variant = DialogVariant.normal,
    this.icon,
    this.maxWidth = AppConstants.defaultDialogWidth,
    this.barrierDismissible = true,
  });

  /// Dialog title
  final String title;

  /// Dialog content (scrollable if long)
  final Widget content;

  /// Action buttons (bottom) - typically Cancel and Confirm buttons
  final List<Widget>? actions;

  /// Dialog variant (visual style)
  final DialogVariant variant;

  /// Optional icon in title area
  final IconData? icon;

  /// Maximum dialog width
  final double maxWidth;

  /// Allow closing by clicking outside dialog
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Determine icon and color based on variant
    IconData? variantIcon = icon;
    Color? iconColor;
    Color titleColor;

    if (icon == null) {
      switch (variant) {
        case DialogVariant.normal:
          variantIcon = null;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.confirmation:
          variantIcon = PhosphorIconsRegular.question;
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.destructive:
          variantIcon = PhosphorIconsRegular.warning;
          iconColor = colorScheme.error;
          titleColor = colorScheme.error;
          break;
      }
    } else {
      // Custom icon provided
      switch (variant) {
        case DialogVariant.normal:
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.confirmation:
          iconColor = colorScheme.primary;
          titleColor = colorScheme.onSurface;
          break;
        case DialogVariant.destructive:
          iconColor = colorScheme.error;
          titleColor = colorScheme.error;
          break;
      }
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (barrierDismissible) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate dialog size as 90% of available space (10% margins on all sides)
          final availableWidth = MediaQuery.of(context).size.width;
          final availableHeight = MediaQuery.of(context).size.height;
          final dialogWidth = availableWidth * 0.9;
          final dialogHeight = availableHeight * 0.9;

          // ignore: avoid_dialog
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth.clamp(AppConstants.minDialogWidth, double.infinity),
                maxHeight: dialogHeight,
              ),
              child: Padding(
            padding: EdgeInsets.all(AppTheme.paddingXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title section with optional icon and X close button
                Row(
                  children: [
                    if (variantIcon != null) ...{
                      Icon(
                        variantIcon,
                        size: 28,
                        color: iconColor,
                      ),
                      SizedBox(width: AppTheme.paddingM),
                    },
                    Expanded(
                      child: HeadlineSmallLabel(
                        title,
                        color: titleColor,
                      ),
                    ),
                    if (barrierDismissible) ...{
                      SizedBox(width: AppTheme.paddingM),
                      BaseIconButton(
                        icon: PhosphorIconsRegular.x,
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    },
                  ],
                ),

                SizedBox(height: AppTheme.paddingL),

                // Content section (scrollable if long)
                Flexible(
                  child: SingleChildScrollView(
                    child: content,
                  ),
                ),

                // Actions section
                if (actions != null && actions!.isNotEmpty) ...{
                  SizedBox(height: AppTheme.paddingXL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions!.length; i++) ...{
                        if (i > 0) SizedBox(width: AppTheme.paddingM),
                        actions![i],
                      },
                    ],
                  ),
                },
              ],
            ),
          ),
        ),
          );
        },
      ),
    );
  }

  /// Show dialog helper
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseDialog dialog,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }
}

/// Helper function for confirmation dialogs
///
/// Returns true if confirmed, false if cancelled or dismissed.
///
/// Example usage:
/// ```dart
/// final confirmed = await showConfirmationDialog(
///   context: context,
///   title: 'Confirm Action',
///   message: 'Are you sure you want to proceed?',
/// );
///
/// if (confirmed) {
///   // User confirmed
/// }
/// ```
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      content: Text(message),
      variant: DialogVariant.confirmation,
      actions: [
        BaseButton(
          label: cancelText ?? l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: confirmText ?? l10n.confirm,
          variant: ButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Helper function for destructive action dialogs
///
/// Returns true if confirmed, false if cancelled or dismissed.
///
/// Example usage:
/// ```dart
/// final confirmed = await showDestructiveDialog(
///   context: context,
///   title: 'Delete Branch',
///   message: 'Are you sure you want to delete this branch? This action cannot be undone.',
///   confirmText: 'Delete',
/// );
///
/// if (confirmed) {
///   // User confirmed deletion
///   deleteBranch();
/// }
/// ```
Future<bool> showDestructiveDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await BaseDialog.show<bool>(
    context: context,
    dialog: BaseDialog(
      title: title,
      content: Text(message),
      variant: DialogVariant.destructive,
      actions: [
        BaseButton(
          label: cancelText ?? l10n.cancel,
          variant: ButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BaseButton(
          label: confirmText ?? l10n.delete,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  return result ?? false;
}
