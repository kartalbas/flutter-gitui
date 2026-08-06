import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
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

/// Whether the widget holding primary focus is a multiline editable text.
///
/// Enter inside such a field inserts a newline; a dialog-level Enter-to-submit
/// handler must let it through or the field becomes impossible to fill.
/// Single-line fields lose nothing: their Enter has no editing meaning.
/// (EditableText attaches its focus node to a Focus widget inside its own
/// subtree, so the editable is found as an ancestor of the focused context.)
bool focusedEditableKeepsEnter() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  final editable = focusContext?.findAncestorStateOfType<EditableTextState>();
  return editable != null && editable.widget.maxLines != 1;
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
    this.onSubmit,
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

  /// The dialog's primary action, triggered by Enter from anywhere inside it.
  ///
  /// A dialog that can only be completed with the mouse is unfinished: Esc
  /// already cancels from anywhere, and Enter has to confirm the same way.
  /// A multiline field keeps its Enter (it inserts a newline there); every
  /// other focus position submits. Left null for a dialog with no single
  /// primary action — or deliberately for one whose affirmative action
  /// destroys something, where Enter must never wave the loss through
  /// (see [showDestructiveDialog]).
  final VoidCallback? onSubmit;

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

    return _DialogFocus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (barrierDismissible) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }

        // Enter confirms from anywhere in the dialog, not only while a single
        // text field happens to hold focus. The exception is a multiline
        // editable: Enter inserts a newline there, and hijacking it would
        // make the field impossible to fill.
        if (onSubmit != null &&
            !focusedEditableKeepsEnter() &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onSubmit!();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = MediaQuery.of(context).size.width;
          final availableHeight = MediaQuery.of(context).size.height;
          // Honour the caller's maxWidth, which was accepted and then ignored:
          // every dialog rendered at 90% of the window regardless. The 90% only
          // survives as a ceiling so a wide dialog cannot outgrow a small
          // screen; the height still shrinks to its content below.
          final widthCeiling = availableWidth * 0.9;
          final dialogWidth = maxWidth < widthCeiling ? maxWidth : widthCeiling;
          final dialogHeight = availableHeight * 0.9;

          // ignore: avoid_dialog
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth.clamp(
                  AppConstants.minDialogWidth,
                  double.infinity,
                ),
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
                          Icon(variantIcon, size: 28, color: iconColor),
                          SizedBox(width: AppTheme.paddingM),
                        },
                        Expanded(
                          child: HeadlineSmallLabel(title, color: titleColor),
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
                    Flexible(child: SingleChildScrollView(child: content)),

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

/// The dialog's keyboard host.
///
/// It must hold focus for Esc/Enter to arrive, but it must not steal it: an
/// eager `Focus(autofocus: true)` wrapper registers before any descendant and
/// wins the autofocus race, which silently defeated `autofocus: true` on the
/// first field of every dialog (the focus manager discards later autofocus
/// requests once the scope has a focused child). So the wrapper claims focus
/// only after the autofocus pipeline settled and nothing inside the dialog
/// took it; key events from a focused field still bubble up to this node.
class _DialogFocus extends StatefulWidget {
  const _DialogFocus({required this.onKeyEvent, required this.child});

  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final Widget child;

  @override
  State<_DialogFocus> createState() => _DialogFocusState();
}

class _DialogFocusState extends State<_DialogFocus> {
  final FocusNode _node = FocusNode(debugLabel: 'BaseDialog');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pending autofocus requests (a field's, queued in its own post-frame
      // callback) are applied in a microtask after this frame's callbacks;
      // decide on the next frame, after they ran, and make sure that frame
      // actually comes.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (FocusScope.of(context).focusedChild == null) {
          _node.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: widget.onKeyEvent,
      child: widget.child,
    );
  }
}

/// Helper function for confirmation dialogs
///
/// Returns true if confirmed, false if cancelled or dismissed.
/// Enter confirms, Esc cancels.
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
      // Enter confirms: a confirmation prompt's whole job is a quick yes.
      onSubmit: () => Navigator.of(context).pop(true),
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
      // Deliberately no onSubmit: Enter must never trigger a destructive
      // action, or the key repeat of the keystroke that opened this prompt
      // destroys data. Esc cancels from anywhere; the red button stays
      // reachable with Tab + Enter/Space, which is the deliberate two-step.
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
