import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../generated/app_localizations.dart';
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
      child: Dialog(
        backgroundColor: backgroundColor,
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
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
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
              Expanded(
                child: Padding(
                  padding: headerBackgroundColor == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(0),
                  child: content,
                ),
              ),

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
