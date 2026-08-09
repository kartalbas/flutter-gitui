import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Inset, Proximity, TextRole, Tone;
import '../../shared/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import 'base_button.dart';
import 'base_icon.dart';
import 'base_label.dart';
import 'base_layout.dart';

/// Component for displaying text that can be copied to clipboard.
///
/// Shows a copy button on hover. Displays "Copied!" feedback.
/// Useful for commit hashes, branch names, file paths, etc.
///
/// Everything it shows is [TextRole.code], and that is no longer a switch the
/// caller flips. The three parameters that used to decide it — a `TextStyle`, a
/// `bool isMonospace` and a `TextOverflow` — were three design decisions
/// crossing an application API to answer one question the component already
/// knows the answer to: what this widget exists for is exactly the role's own
/// definition, "diffs, hashes, paths, command output", where alignment is
/// meaning rather than style. Every call site passed `isMonospace: true`
/// anyway, so the flag was recording a decision nobody was making.
///
/// Example usage:
/// ```dart
/// CopyableText(text: 'a1b2c3d4e5f6', icon: IconRole.gitCommit)
/// ```
class CopyableText extends StatefulWidget {
  const CopyableText({
    super.key,
    required this.text,
    this.icon,
    this.maxLines = 1,
    this.showCopyButton = true,
    this.selectOnClick = false,
    this.copiedMessage = 'Copied!',
  });

  /// Text to display and copy
  final String text;

  /// Optional leading icon
  /// The meaning of an optional leading mark; the skin chooses the glyph.
  final IconRole? icon;

  /// Maximum lines to display. What happens at the last one is the skin's
  /// truncation idiom — Material ellipsizes at the end, AppKit truncates a path
  /// in the middle — which is why there is no `overflow` beside it.
  final int maxLines;

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
                BaseIcon(
                  widget.icon!,
                  scale: ControlScale.compact,
                  tone: Tone.muted,
                ),
                const BaseGap(Proximity.related),
              ],

              // Text content
              Flexible(
                child: BaseLabel(
                  widget.text,
                  role: TextRole.code,
                  maxLines: widget.maxLines,
                ),
              ),

              // Copy button or copied feedback
              if (widget.showCopyButton) ...[
                const BaseGap(Proximity.related),
                if (_showCopiedFeedback)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    // The wash and the corner stay on the container; the
                    // breathing room it owes the confirmation crosses the
                    // seam. `hairline` down the page is this pill's 2 exactly,
                    // so nothing moves.
                    child: BaseInset(
                      x: Inset.tight,
                      y: Inset.hairline,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.check,
                            size: 12,
                            color: colorScheme.primary,
                          ),
                          const BaseGap(Proximity.hairline),
                          Text(
                            widget.copiedMessage,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isHovered)
                  SizedBox(
                    width: AppTheme.paddingL,
                    height: AppTheme.paddingL,
                    child: BaseIconButton(
                      icon: IconRole.copy,
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
