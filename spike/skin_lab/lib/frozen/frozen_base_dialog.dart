// FROZEN COPY - do not "improve".
//
//   source:  lib/shared/components/base_dialog.dart
//   sha:     09949eaf5942a045a59d20f5a4f23de6c4899f5c
//   copied:  2026-08-06
//
// Permitted edits, and the complete list of them:
//   1. imports retargeted to `../app_stubs.dart` and the frozen button;
//   2. class renamed BaseDialog -> FrozenBaseDialog (pure rename);
//   3. exactly TWO dispatch lines, marked `SKIN DISPATCH` - one in build()
//      for the surface and one in the static show() for the route. That is
//      already a FINDING: the dialog is the only component under test whose
//      per-language behaviour cannot be reached from the widget alone, because
//      route, barrier, transition and dismissal are properties of the route
//      that `showDialog` creates, not of the widget it displays;
//   4. long-form doc comments condensed; every `final` is verbatim.
//
// ignore_for_file: avoid_dialog

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_stubs.dart';
import '../skin.dart';
import 'frozen_base_button.dart';

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
bool focusedEditableKeepsEnter() => focusedEditableOwnsKey(
  const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.enter,
    logicalKey: LogicalKeyboardKey.enter,
    timeStamp: Duration.zero,
  ),
);

/// Base component for all dialog patterns in the app.
class FrozenBaseDialog extends StatelessWidget {
  const FrozenBaseDialog({
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
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.dialog(this); // SKIN DISPATCH
    // dart format on

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
              'BaseDialog content must not contain an unbounded flex child.',
            );
          }
        }
      }
      return true;
    }());

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
      switch (variant) {
        case DialogVariant.normal:
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
          final widthCeiling = availableWidth * 0.9;
          final dialogWidth = maxWidth < widthCeiling ? maxWidth : widthCeiling;
          final dialogHeight = availableHeight * 0.9;

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
                padding: const EdgeInsets.all(AppTheme.paddingXL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (variantIcon != null) ...{
                          Icon(variantIcon, size: 28, color: iconColor),
                          const SizedBox(width: AppTheme.paddingM),
                        },
                        Expanded(
                          child: HeadlineSmallLabel(title, color: titleColor),
                        ),
                        if (barrierDismissible) ...{
                          const SizedBox(width: AppTheme.paddingM),
                          FrozenBaseIconButton(
                            icon: PhosphorIconsRegular.x,
                            tooltip: l10n.close,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        },
                      ],
                    ),

                    const SizedBox(height: AppTheme.paddingL),

                    Flexible(child: SingleChildScrollView(child: content)),

                    if (actions != null && actions!.isNotEmpty) ...{
                      const SizedBox(height: AppTheme.paddingXL),
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
    required FrozenBaseDialog dialog,
  }) {
    // dart format off
    if (Skin.maybeOf(context) case final Skin skin) return skin.showDialog<T>(context, dialog); // SKIN DISPATCH
    // dart format on

    return showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }
}

/// The keyboard host every dialog is wrapped in.
class DialogKeyboardHost extends StatefulWidget {
  const DialogKeyboardHost({
    super.key,
    required this.barrierDismissible,
    required this.onSubmit,
    required this.child,
  });

  final bool barrierDismissible;
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
