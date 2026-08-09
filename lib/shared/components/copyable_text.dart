import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show ControlScale, IconRole, Proximity, TextRole, Tone;
import '../../shared/theme/app_theme.dart';
import '../../generated/app_localizations.dart';
import 'base_badge.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  // **A mark riding on something else** - which is what this
                  // confirmation always was, hand-drawn: a wash of one colour
                  // at 15 %, that same colour as the foreground of a checked
                  // mark and a 600-weight label, and a corner. Every one of
                  // those numbers is `surfaces.badge`'s, reached here through
                  // the application's own badge façade, so the pill is drawn
                  // by the same member as every other pill in the application
                  // instead of beside it.
                  BaseBadge(
                    label: widget.copiedMessage,
                    // The confirmation is the application's accent speaking,
                    // not a git state: `primary` is the variant that resolves
                    // to exactly the `colorScheme.primary` this site named.
                    variant: BadgeVariant.primary,
                    // `small` is the rung this pill's own footprint already
                    // stated - 8 across and 2 down are the compact pill's
                    // numbers exactly. The hand-drawn copy took its padding
                    // from that rung and its type and mark from the next one
                    // up, which is the drift a member cannot repeat: the
                    // badge moves padding, type size, mark size and corner
                    // together, because a pill this small reads as a
                    // rendering fault when only one of them changes.
                    size: BadgeSize.small,
                    icon: IconRole.check,
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
