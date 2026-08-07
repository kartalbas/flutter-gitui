import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../generated/app_localizations.dart';
import '../../core/constants/constants.dart';
import '../../shared/theme/app_theme.dart';
import '../utils/keyboard_guards.dart';
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
///
/// The rule itself lives in [focusedEditableOwnsKey]; this asks it about a
/// plain Enter press for callers that hold no key event of their own.
bool focusedEditableKeepsEnter() => focusedEditableOwnsKey(
  const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.enter,
    logicalKey: LogicalKeyboardKey.enter,
    timeStamp: Duration.zero,
  ),
);

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

  /// Dialog content (scrollable if long).
  ///
  /// The content is wrapped in a [SingleChildScrollView], which hands it
  /// unbounded height. A [Column] passed here must therefore not contain an
  /// [Expanded], [Spacer] or tight [Flexible] child - a scroll view leaves no
  /// "remaining space" to distribute, so such a child is a RenderFlex error,
  /// not a layout. Give an inner list a bounded height instead (for example a
  /// [ConstrainedBox] with `maxHeight` around a shrink-wrapped list), so the
  /// dialog grows with its content up to the cap and scrolls beyond it.
  /// [build] asserts the direct-child case in debug builds.
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
    // Turn the runtime RenderFlex error into an immediate, named one: the
    // content sits in a scroll view, so a flex child of a content Column can
    // never get the remaining space it asks for. This mirrors RenderFlex's
    // own condition (a tight flex child always throws under unbounded
    // height; a loose Flexible only when the Column wants MainAxisSize.max),
    // so a legal loose Flexible in a min Column stays allowed. Only direct
    // children are checkable here; the doc on [content] covers the rest.
    assert(() {
      final inner = content;
      if (inner is Flex && inner.direction == Axis.vertical) {
        for (final child in inner.children) {
          final alwaysThrows =
              child is Spacer ||
              (child is Flexible && child.fit == FlexFit.tight);
          final throwsInMaxColumn =
              child is Flexible &&
              child.fit == FlexFit.loose &&
              inner.mainAxisSize == MainAxisSize.max;
          if (alwaysThrows || throwsInMaxColumn) {
            throw FlutterError(
              'BaseDialog content must not contain an unbounded flex child.\n'
              'BaseDialog scrolls its content, so the content Column has '
              'unbounded height and a ${child.runtimeType} inside it is a '
              'RenderFlex error, not a layout. Give the child a bounded '
              'height instead, e.g. a ConstrainedBox(maxHeight: ...) around '
              'a shrink-wrapped list.',
            );
          }
        }
      }
      return true;
    }());

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

    return DialogKeyboardHost(
      barrierDismissible: barrierDismissible,
      onSubmit: onSubmit,
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

                    // Actions section. A Wrap, not a Row: a Row overflows
                    // when the buttons outgrow the dialog width (the update
                    // dialog's three actions did); wrapping onto a second
                    // end-aligned run is the M3 fallback for that case and
                    // renders identically while one line fits.
                    if (actions != null && actions!.isNotEmpty) ...{
                      SizedBox(height: AppTheme.paddingXL),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppTheme.paddingM,
                        runSpacing: AppTheme.paddingS,
                        children: actions!,
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

/// The keyboard host every dialog is wrapped in, so the dialog keyboard
/// contract is inherited from one place instead of being re-typed per dialog
/// component. [BaseDialog] and `BaseViewerDialog` both build on it.
///
/// It carries two responsibilities that are each easy to get wrong on their
/// own:
///
/// **The keys.** Escape closes a dismissible dialog and Enter fires
/// [onSubmit], both from anywhere inside it — a dialog that can only be
/// completed with the mouse is unfinished. The single exception is a focused
/// multiline editable, which keeps its Enter because Enter inserts a newline
/// there (see [focusedEditableKeepsEnter]); hijacking it would make the field
/// impossible to fill.
///
/// **The focus.** The host must hold focus for those keys to arrive, but it
/// must not steal it: an eager `Focus(autofocus: true)` wrapper registers
/// before any descendant and wins the autofocus race, which silently defeated
/// `autofocus: true` on the first field of every dialog (the focus manager
/// discards later autofocus requests once the scope has a focused child). So
/// the host claims focus only after the autofocus pipeline settled and nothing
/// inside the dialog took it; key events from a focused field still bubble up
/// to this node either way.
///
/// It is deliberately not a Tab stop ([FocusNode.skipTraversal]). The node
/// covers the whole dialog and draws nothing, so leaving it in the traversal
/// ring gave every dialog one stop where the user sees no focus ring and has
/// nothing to operate — Tab is supposed to walk the dialog's *controls*.
/// Skipping traversal keeps it focusable for the fallback above and for the
/// keys, and Tab from it still moves on to the first real control.
class DialogKeyboardHost extends StatefulWidget {
  const DialogKeyboardHost({
    super.key,
    required this.barrierDismissible,
    required this.onSubmit,
    required this.child,
  });

  /// Whether Escape may close the dialog, mirroring the host route's own
  /// barrier behaviour so both dismissal paths agree.
  final bool barrierDismissible;

  /// The dialog's primary action, fired by Enter. Null leaves Enter inert,
  /// which is what a destructive prompt wants.
  final VoidCallback? onSubmit;

  final Widget child;

  @override
  State<DialogKeyboardHost> createState() => _DialogKeyboardHostState();
}

class _DialogKeyboardHostState extends State<DialogKeyboardHost> {
  final FocusNode _node = FocusNode(debugLabel: 'DialogKeyboardHost');

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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.barrierDismissible) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }

    // Enter confirms from anywhere in the dialog, not only while a single
    // text field happens to hold focus. The exception is a multiline
    // editable: Enter inserts a newline there, and hijacking it would make
    // the field impossible to fill.
    final onSubmit = widget.onSubmit;
    if (onSubmit != null &&
        !focusedEditableKeepsEnter() &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      onSubmit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
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
