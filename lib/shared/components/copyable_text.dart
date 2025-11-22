import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../shared/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import 'base_button.dart';
import 'base_label.dart';

/// Component for displaying text that can be copied to clipboard.
///
/// Shows a copy button on hover. Displays "Copied!" feedback.
/// Useful for commit hashes, branch names, file paths, etc.
///
/// Example usage:
/// ```dart
/// CopyableText(
///   text: 'a1b2c3d4e5f6',
///   icon: PhosphorIconsRegular.gitCommit,
///   isMonospace: true,
/// )
/// ```
///
/// Commit hash example:
/// ```dart
/// CopyableText(
///   text: commit.hash,
///   icon: PhosphorIconsRegular.gitCommit,
///   isMonospace: true,
///   maxLines: 1,
/// )
/// ```
///
/// File path example:
/// ```dart
/// CopyableText(
///   text: '/path/to/very/long/file/name.txt',
///   icon: PhosphorIconsRegular.file,
///   isMonospace: true,
///   overflow: TextOverflow.ellipsis,
/// )
/// ```
class CopyableText extends StatefulWidget {
  const CopyableText({
    super.key,
    required this.text,
    this.style,
    this.icon,
    this.isMonospace = false,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.showCopyButton = true,
    this.selectOnClick = false,
    this.copiedMessage = 'Copied!',
  });

  /// Text to display and copy
  final String text;

  /// Text style (default to theme bodyMedium or bodyMedium with monospace font)
  final TextStyle? style;

  /// Optional leading icon
  final IconData? icon;

  /// Use monospace font (for hashes, paths, etc.)
  final bool isMonospace;

  /// Maximum lines to display
  final int maxLines;

  /// Text overflow behavior
  final TextOverflow overflow;

  /// Show copy button on hover
  final bool showCopyButton;

  /// Select all text on click
  final bool selectOnClick;

  /// Message to show when copied
  final String copiedMessage;

  @override
  State<CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<CopyableText> {
  bool _isHovered = false;
  bool _showCopiedFeedback = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (mounted) {
      setState(() => _showCopiedFeedback = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showCopiedFeedback = false);
        }
      });
    }
  }

  void _handleClick() {
    if (widget.selectOnClick) {
      // In Flutter web, this would work. For desktop/mobile,
      // we can just copy to clipboard as that's the main use case
      _copyToClipboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: widget.showCopyButton
          ? (_) => setState(() => _isHovered = true)
          : null,
      onExit: widget.showCopyButton
          ? (_) => setState(() => _isHovered = false)
          : null,
      child: GestureDetector(
        onTap: widget.selectOnClick ? _handleClick : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.paddingS,
            vertical: AppTheme.paddingXS,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leading icon
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: AppTheme.paddingS),
              ],

              // Text content
              Flexible(
                child: widget.isMonospace
                    ? BaseLabel(
                        widget.text,
                        style: widget.style ?? TextStyle(
                          fontFamily: 'monospace',
                          fontFeatures: [const FontFeature.tabularFigures()],
                          fontSize: theme.textTheme.bodyMedium?.fontSize,
                        ),
                        maxLines: widget.maxLines,
                        overflow: widget.overflow,
                      )
                    : BodyMediumLabel(
                        widget.text,
                        maxLines: widget.maxLines,
                        overflow: widget.overflow,
                      ),
              ),

              // Copy button or copied feedback
              if (widget.showCopyButton) ...[
                SizedBox(width: AppTheme.paddingS),
                if (_showCopiedFeedback)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.check,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: AppTheme.paddingXS),
                        Text(
                          widget.copiedMessage,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isHovered)
                  SizedBox(
                    width: AppTheme.paddingL,
                    height: AppTheme.paddingL,
                    child: BaseIconButton(
                      icon: PhosphorIconsRegular.copy,
                      onPressed: _copyToClipboard,
                      tooltip: AppLocalizations.of(
                        context,
                      )!.tooltipCopyToClipboard,
                      size: ButtonSize.small,
                    ),
                  )
                else
                  // Placeholder to maintain consistent width
                  const SizedBox(
                    width: AppTheme.paddingL,
                    height: AppTheme.paddingL,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
