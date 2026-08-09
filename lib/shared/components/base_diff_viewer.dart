import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show Inset, Proximity, TextRole, Tone;
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';

import '../../generated/app_localizations.dart';
import '../../core/config/app_config.dart';
import '../../core/diff/diff_parser.dart';
import '../theme/app_theme.dart';
import 'base_label.dart';
import 'base_card.dart';
import 'base_layout.dart';
import 'base_speed_dial.dart';

enum DiffViewMode {
  diff, // Show only changes (default)
  fullFile, // Show entire file content
}

/// Base diff viewer component for rendering diff content with syntax highlighting
///
/// **`surfaces.codeLine` is NOT called here, and that is a finding rather than
/// an omission** (#249, P5). The member exists, is implemented in every skin,
/// and its gutter geometry is byte-for-byte what this file measures — but two
/// facts this viewer renders have no slot on `CodeLineSpec` or on
/// `SkinRequest`, so calling it would silently delete both:
///
///  * **The user's code font SIZE.** The application offers two independent
///    size settings — "Font Size" for the interface and "Code Font Size" for
///    diffs and previews (`theme_section.dart:185`, `AppConfig.previewFontSize`).
///    `SkinRequest` carries `monoFamily`, the code font's FAMILY, but only one
///    `textScale`, and it is the interface one. `CodeLineSpec` has no scale
///    either, so a diff routed through the member renders at the interface
///    size and the "Code Font Size" control goes dead for the one surface it
///    is named after. That is a user-visible setting stopping working, not a
///    pixel moving.
///  * **A one-sided gutter.** [_buildFullFileLine] shows a whole file, which
///    has a single line number, not an old one and a new one. `CodeLineSpec`
///    draws both gutter columns whenever either number is set, so the full-file
///    view would gain a permanently blank 52 dp column and push its content
///    60 dp to the right.
///
/// Both are recorded in `docs/SKIN-CONTRACT-MEMBERS.md`'s terms: a member that
/// cannot say what the site says is a gap in the contract, and the construction
/// stays by hand — pixel for pixel — until the contract can say it. The eleven
/// `AppTheme` reads below therefore stay registered against
/// `surfaces.codeLine` rather than being half-converted around it.
class BaseDiffViewer extends StatefulWidget {
  final List<DiffLine> diffLines;
  final bool compactMode;
  final bool showLineNumbers;
  final VoidCallback? onLineCopied;
  final String? fullFileContent; // Full file content for untracked/new files
  final String? filePath; // File path for display
  final DiffViewMode viewMode; // View mode controlled by parent
  final VoidCallback? onToggleViewMode; // Callback to toggle view mode
  final List<SpeedDialAction>
  additionalActions; // Additional actions for the FAB
  final String fontFamily; // Font family for code display
  final AppFontSize fontSize; // Font size for code display

  const BaseDiffViewer({
    super.key,
    required this.diffLines,
    this.compactMode = false,
    this.showLineNumbers = true,
    this.onLineCopied,
    this.fullFileContent,
    this.filePath,
    this.viewMode = DiffViewMode.diff,
    this.onToggleViewMode,
    this.additionalActions = const [],
    this.fontFamily = 'JetBrains Mono',
    this.fontSize = AppFontSize.medium,
  });

  @override
  State<BaseDiffViewer> createState() => _BaseDiffViewerState();
}

class _BaseDiffViewerState extends State<BaseDiffViewer> {
  bool _fabIsExpanded = false;

  void _collapseFAB() {
    if (_fabIsExpanded) {
      setState(() {
        _fabIsExpanded = false;
      });
    }
  }

  void _toggleFAB() {
    setState(() {
      _fabIsExpanded = !_fabIsExpanded;
    });
  }

  /// Get font size scale factor based on AppFontSize
  double _getFontSizeScale() {
    switch (widget.fontSize) {
      case AppFontSize.tiny:
        return 0.8;
      case AppFontSize.small:
        return 0.9;
      case AppFontSize.medium:
        return 1.0;
      case AppFontSize.large:
        return 1.15;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we can show full file content
    final canShowFullFile =
        widget.fullFileContent != null && widget.fullFileContent!.isNotEmpty;

    // If no diff and no full content, show empty state
    if ((widget.diffLines.isEmpty ||
            (widget.diffLines.length == 1 &&
                widget.diffLines[0].type == DiffLineType.info)) &&
        !canShowFullFile) {
      return _buildEmptyState(context);
    }

    // Main content widget
    final contentWidget =
        widget.viewMode == DiffViewMode.fullFile && canShowFullFile
        ? _buildFullFileView(context)
        : _buildDiffView(context);

    // Wrap in Stack with Speed Dial FAB if we have any actions
    final allActions = <SpeedDialAction>[
      // Toggle view mode action (if available)
      if (widget.onToggleViewMode != null && canShowFullFile)
        SpeedDialAction(
          icon: widget.viewMode == DiffViewMode.diff
              ? PhosphorIconsRegular.file
              : PhosphorIconsRegular.gitDiff,
          label: widget.viewMode == DiffViewMode.diff
              ? 'Show Full File'
              : 'Show Changes Only',
          onPressed: widget
              .onToggleViewMode!, // Safe to use ! because we checked != null above
        ),
      // Additional actions
      ...widget.additionalActions,
    ];

    if (allActions.isNotEmpty) {
      // Wrap with dismissal behaviors: tap-outside and scroll (ESC handled in FAB widget)
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Collapse FAB when scrolling starts
          if (notification is ScrollStartNotification && _fabIsExpanded) {
            _collapseFAB();
          }
          return false; // Allow notification to continue bubbling
        },
        child: GestureDetector(
          // Tap-outside dismissal
          onTap: _collapseFAB,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              contentWidget,
              // Draggable Speed Dial FAB (now controlled by parent, ESC key handled internally)
              BaseSpeedDial(
                actions: allActions,
                isExpanded: _fabIsExpanded,
                onToggle: _toggleFAB,
                onCollapse: _collapseFAB,
              ),
            ],
          ),
        ),
      );
    }

    return contentWidget;
  }

  Widget _buildDiffView(BuildContext context) {
    final displayLines = widget.compactMode
        ? _filterCompactView(widget.diffLines)
        : widget.diffLines;

    if (displayLines.isEmpty) {
      return _buildEmptyState(context);
    }

    return BaseCard(
      inset: Inset.none,
      content: ListView.builder(
        itemCount: displayLines.length,
        itemBuilder: (context, index) {
          return _buildDiffLine(context, displayLines[index]);
        },
      ),
    );
  }

  Widget _buildFullFileView(BuildContext context) {
    if (widget.fullFileContent == null || widget.fullFileContent!.isEmpty) {
      return _buildEmptyState(context);
    }

    final lines = widget.fullFileContent!.split('\n');

    return BaseCard(
      inset: Inset.none,
      content: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return _buildFullFileLine(context, lines[index], index + 1);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // Not `EmptyStateWidget`: this state has no explaining sentence, and the
    // widget renders its message line unconditionally - handing it '' painted
    // a blank body line and its gap under the title, re-tinted the mark and
    // moved two distances. The construction stays by hand, pixel for pixel,
    // until the empty-state surface is a member that can carry "no message".
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The hero mark of an empty state keeps its measure and its ambient
          // colour as literals: no `ControlScale` rung reaches a state's
          // artwork, and a `Tone` can only reach a mark through `BaseIcon`.
          const Icon(Icons.description_outlined, size: AppTheme.iconXL * 2),
          // The mark and the headline are members of one group.
          const BaseGap(Proximity.grouped),
          BaseLabel(
            AppLocalizations.of(context)!.noChanges,
            role: TextRole.pageTitle,
          ),
        ],
      ),
    );
  }

  /// Filter diff lines for compact view - show changes with surrounding context
  List<DiffLine> _filterCompactView(List<DiffLine> allLines) {
    final result = <DiffLine>[];
    const contextLines =
        2; // Number of context lines to show before/after changes

    for (var i = 0; i < allLines.length; i++) {
      final line = allLines[i];

      // Always include headers and file headers for navigation
      if (line.type == DiffLineType.header ||
          line.type == DiffLineType.fileHeader ||
          line.type == DiffLineType.info) {
        result.add(line);
        continue;
      }

      // Include changes (additions/deletions)
      if (line.type == DiffLineType.addition ||
          line.type == DiffLineType.deletion) {
        // Add context lines before the change
        for (var j = contextLines; j > 0; j--) {
          final contextIndex = i - j;
          if (contextIndex >= 0 &&
              allLines[contextIndex].type == DiffLineType.context &&
              !result.contains(allLines[contextIndex])) {
            result.add(allLines[contextIndex]);
          }
        }

        // Add the change itself
        result.add(line);

        // Add context lines after the change
        for (var j = 1; j <= contextLines; j++) {
          final contextIndex = i + j;
          if (contextIndex < allLines.length &&
              allLines[contextIndex].type == DiffLineType.context &&
              !result.contains(allLines[contextIndex])) {
            result.add(allLines[contextIndex]);
          }
        }
      }
    }

    return result;
  }

  Widget _buildDiffLine(BuildContext context, DiffLine line) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? backgroundColor;
    Color? textColor;
    // What the line IS, for the one piece of it that has already crossed onto
    // the contract: the +/- prefix. The `textColor` beside it still has to be a
    // `Color` because the content below is a raw `SelectableText` carrying the
    // user's own diff font, and that whole construction moves into
    // `surfaces.codeLine` at P3d rather than being half-migrated here.
    Tone prefixTone = Tone.neutral;
    String prefix = '';

    switch (line.type) {
      case DiffLineType.addition:
        backgroundColor = context.gitColors.added.withValues(alpha: 0.12);
        textColor = context.gitColors.added;
        prefixTone = Tone.gitAdded;
        prefix = '+';
        break;
      case DiffLineType.deletion:
        backgroundColor = context.gitColors.deleted.withValues(alpha: 0.12);
        textColor = context.gitColors.deleted;
        prefixTone = Tone.gitDeleted;
        prefix = '-';
        break;
      case DiffLineType.header:
        backgroundColor = colorScheme.primary.withValues(alpha: 0.1);
        textColor = colorScheme.primary;
        break;
      case DiffLineType.fileHeader:
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface;
        break;
      case DiffLineType.info:
        textColor = colorScheme.onSurfaceVariant;
        break;
      case DiffLineType.context:
        textColor = colorScheme.onSurface;
        prefix = ' ';
        break;
    }

    // Extract line content (remove +/- prefix if present)
    String displayContent = line.content;
    if (line.type == DiffLineType.addition ||
        line.type == DiffLineType.deletion) {
      if (displayContent.isNotEmpty) {
        displayContent = displayContent.substring(1);
      }
    }

    return InkWell(
      onTap: () {
        // Copy line to clipboard on tap
        Clipboard.setData(ClipboardData(text: displayContent));
        widget.onLineCopied?.call();
      },
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingS,
          vertical: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line numbers
            if (widget.showLineNumbers &&
                (line.type == DiffLineType.context ||
                    line.type == DiffLineType.addition ||
                    line.type == DiffLineType.deletion)) ...[
              SizedBox(
                width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,
                child: BaseLabel(
                  line.oldLineNumber?.toString() ?? '',
                  // A gutter number is code: what makes a column of them
                  // readable is that every digit occupies the same width, which
                  // is alignment carrying meaning rather than a style choice.
                  role: TextRole.code,
                  tone: Tone.muted,
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
              SizedBox(
                width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,
                child: BaseLabel(
                  line.newLineNumber?.toString() ?? '',
                  role: TextRole.code,
                  tone: Tone.muted,
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
            ],
            // Prefix indicator
            if (prefix.isNotEmpty)
              BaseLabel(prefix, role: TextRole.code, tone: prefixTone),
            const SizedBox(width: AppTheme.paddingXS),
            // Line content
            Expanded(
              child: SelectableText(
                displayContent.isEmpty ? ' ' : displayContent,
                style: GoogleFonts.getFont(
                  widget.fontFamily,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.2,
                    fontSize:
                        (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                            14) *
                        _getFontSizeScale(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a line for full file view
  Widget _buildFullFileLine(
    BuildContext context,
    String content,
    int lineNumber,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        // Copy line to clipboard on tap
        Clipboard.setData(ClipboardData(text: content));
        widget.onLineCopied?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingS,
          vertical: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line number
            if (widget.showLineNumbers) ...[
              SizedBox(
                width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,
                child: BaseLabel(
                  lineNumber.toString(),
                  role: TextRole.code,
                  tone: Tone.muted,
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS + AppTheme.paddingXS),
            ],
            // Line content
            Expanded(
              child: SelectableText(
                content.isEmpty ? ' ' : content,
                style: GoogleFonts.getFont(
                  widget.fontFamily,
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.2,
                    fontSize:
                        (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                            14) *
                        _getFontSizeScale(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
