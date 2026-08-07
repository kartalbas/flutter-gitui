import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import '../../generated/app_localizations.dart';
import 'base_dialog.dart' show DialogKeyboardHost;
import '../../shared/theme/app_theme.dart';
import 'base_button.dart';
import 'base_label.dart';

/// Base component for full-screen viewer dialogs.
///
/// Use this for dialogs that need:
/// - Full-screen layout (90% of viewport)
/// - Custom header with icon, title, subtitle, and X close button
/// - Expanded content area (not wrapped in scroll view)
/// - Optional actions at bottom
///
/// Example usage:
/// ```dart
/// BaseViewerDialog(
///   icon: PhosphorIconsRegular.gitDiff,
///   title: 'Commit Diff',
///   subtitle: 'abc1234: file.dart',
///   headerActions: [
///     BaseIconButton(
///       icon: PhosphorIconsRegular.textIndent,
///       tooltip: 'Toggle compact',
///       onPressed: () {},
///     ),
///   ],
///   content: BaseDiffViewer(...),
///   actions: [
///     BaseButton(
///       label: 'Copy All',
///       variant: ButtonVariant.tertiary,
///       onPressed: () {},
///     ),
///   ],
/// );
/// ```
class BaseViewerDialog extends StatelessWidget {
  const BaseViewerDialog({
    super.key,
    required this.title,
    required this.content,
    this.subtitle,
    this.icon,
    this.headerActions,
    this.headerMetadata,
    this.actions,
    this.footer,
    this.barrierDismissible = true,
    this.onSubmit,
    this.widthFactor = 0.9,
    this.heightFactor = 0.9,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.footerBackgroundColor,
  });

  /// Dialog title
  final String title;

  /// Optional subtitle (e.g., file path, description)
  final String? subtitle;

  /// Optional icon in header
  final IconData? icon;

  /// Main content (takes full available space)
  final Widget content;

  /// Optional actions in header (between title and close button)
  final List<Widget>? headerActions;

  /// Optional metadata display in header (e.g., "Page 1 of 5", "100 rows x 5 columns")
  final Widget? headerMetadata;

  /// Optional action buttons (bottom row with buttons)
  final List<Widget>? actions;

  /// Optional footer widget (for custom controls like PDF navigation)
  final Widget? footer;

  /// Allow closing by clicking outside dialog
  final bool barrierDismissible;

  /// The dialog's primary action, triggered by Enter from anywhere inside it
  /// (same contract as [BaseDialog.onSubmit], including the multiline-field
  /// exception). For a pure viewer this is typically "close".
  final VoidCallback? onSubmit;

  /// Width as factor of screen width (default 0.9)
  final double widthFactor;

  /// Height as factor of screen height (default 0.9)
  final double heightFactor;

  /// Optional custom background color for dialog
  final Color? backgroundColor;

  /// Optional custom background color for header
  final Color? headerBackgroundColor;

  /// Optional custom background color for footer
  final Color? footerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // The same keyboard host BaseDialog uses, rather than a second copy of
    // the Esc/Enter handler: this component used to wrap itself in an eager
    // `Focus(autofocus: true)`, which registers before any descendant and
    // therefore won the autofocus race against a field inside the viewer, so
    // such a viewer opened with focus on the dialog frame and nothing to type
    // into. The shared host defers its claim until the autofocus pipeline has
    // settled, and stays out of the Tab ring.
    return DialogKeyboardHost(
      barrierDismissible: barrierDismissible,
      onSubmit: onSubmit,
      child: Dialog(
        backgroundColor: backgroundColor,
        // The same 12 dp corner BaseDialog carries, and for the same reason:
        // see DLG-001/VIEW-001 in docs/deviation_register.yaml. A viewer fills
        // 90% of the window, where Material 3's 28 dp would cut a visible arc
        // out of every corner of what is effectively a second window.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * widthFactor,
          height: MediaQuery.of(context).size.height * heightFactor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: headerBackgroundColor != null
                    ? BoxDecoration(color: headerBackgroundColor)
                    : null,
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: headerBackgroundColor != null
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.paddingS),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleLargeLabel(
                            title,
                            color: headerBackgroundColor != null
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                          if (subtitle != null)
                            BodySmallLabel(
                              subtitle!,
                              color: headerBackgroundColor != null
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.7,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    if (headerMetadata != null) ...[
                      headerMetadata!,
                      const SizedBox(width: AppTheme.paddingM),
                    ],
                    if (headerActions != null) ...[
                      ...headerActions!,
                      const SizedBox(width: AppTheme.paddingS),
                    ],
                    BaseIconButton(
                      icon: PhosphorIconsRegular.x,
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Content (expanded)
              Expanded(child: content),

              // Footer (custom widget like PDF navigation)
              if (footer != null)
                Container(
                  decoration: footerBackgroundColor != null
                      ? BoxDecoration(color: footerBackgroundColor)
                      : null,
                  child: footer,
                ),

              // Actions (row of buttons)
              if (actions != null && actions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions!.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppTheme.paddingS),
                        actions![i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show viewer dialog helper
  static Future<T?> show<T>({
    required BuildContext context,
    required BaseViewerDialog dialog,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dialog.barrierDismissible,
      builder: (context) => dialog,
    );
  }
}
