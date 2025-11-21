import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../generated/app_localizations.dart';
import '../../core/config/app_config.dart';
import '../../core/diff/diff_parser.dart';
import '../theme/app_theme.dart';
import 'base_label.dart';
import 'base_card.dart';

/// Action for the Speed Dial FAB
class DiffViewerAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const DiffViewerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

enum DiffViewMode {
  diff,      // Show only changes (default)
  fullFile,  // Show entire file content
}

/// Base diff viewer component for rendering diff content with syntax highlighting
class BaseDiffViewer extends StatefulWidget {
  final List<DiffLine> diffLines;
  final bool compactMode;
  final bool showLineNumbers;
  final VoidCallback? onLineCopied;
  final String? fullFileContent;  // Full file content for untracked/new files
  final String? filePath;  // File path for display
  final DiffViewMode viewMode;  // View mode controlled by parent
  final VoidCallback? onToggleViewMode;  // Callback to toggle view mode
  final List<DiffViewerAction> additionalActions;  // Additional actions for the FAB
  final String fontFamily;  // Font family for code display
  final AppFontSize fontSize;  // Font size for code display

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
    final canShowFullFile = widget.fullFileContent != null && widget.fullFileContent!.isNotEmpty;

    // If no diff and no full content, show empty state
    if ((widget.diffLines.isEmpty ||
        (widget.diffLines.length == 1 && widget.diffLines[0].type == DiffLineType.info)) &&
        !canShowFullFile) {
      return _buildEmptyState(context);
    }

    // Main content widget
    final contentWidget = widget.viewMode == DiffViewMode.fullFile && canShowFullFile
        ? _buildFullFileView(context)
        : _buildDiffView(context);

    // Wrap in Stack with Speed Dial FAB if we have any actions
    final allActions = <DiffViewerAction>[
      // Toggle view mode action (if available)
      if (widget.onToggleViewMode != null && canShowFullFile)
        DiffViewerAction(
          icon: widget.viewMode == DiffViewMode.diff
              ? PhosphorIconsRegular.file
              : PhosphorIconsRegular.gitDiff,
          label: widget.viewMode == DiffViewMode.diff
              ? 'Show Full File'
              : 'Show Changes Only',
          onPressed: widget.onToggleViewMode!, // Safe to use ! because we checked != null above
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
              _DraggableSpeedDial(
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
    final displayLines = widget.compactMode ? _filterCompactView(widget.diffLines) : widget.diffLines;

    if (displayLines.isEmpty) {
      return _buildEmptyState(context);
    }

    return BaseCard(
      padding: EdgeInsets.zero,
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
      padding: EdgeInsets.zero,
      content: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          return _buildFullFileLine(context, lines[index], index + 1);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description_outlined,
            size: AppTheme.iconXL * 2,
          ),
          const SizedBox(height: AppTheme.paddingM),
          TitleMediumLabel(
            AppLocalizations.of(context)!.noChanges,
          ),
        ],
      ),
    );
  }

  /// Filter diff lines for compact view - show changes with surrounding context
  List<DiffLine> _filterCompactView(List<DiffLine> allLines) {
    final result = <DiffLine>[];
    const contextLines = 2; // Number of context lines to show before/after changes

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
      if (line.type == DiffLineType.addition || line.type == DiffLineType.deletion) {
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
    String prefix = '';

    switch (line.type) {
      case DiffLineType.addition:
        backgroundColor = AppTheme.gitAdded.withValues(alpha: 0.12);
        textColor = AppTheme.gitAdded;
        prefix = '+';
        break;
      case DiffLineType.deletion:
        backgroundColor = AppTheme.gitDeleted.withValues(alpha: 0.12);
        textColor = AppTheme.gitDeleted;
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
    if (line.type == DiffLineType.addition || line.type == DiffLineType.deletion) {
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
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingS, vertical: 2),
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
                child: BodySmallLabel(
                  line.oldLineNumber?.toString() ?? '',
                  color: colorScheme.onSurfaceVariant,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
              SizedBox(
                width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,
                child: BodySmallLabel(
                  line.newLineNumber?.toString() ?? '',
                  color: colorScheme.onSurfaceVariant,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppTheme.paddingS),
            ],
            // Prefix indicator
            if (prefix.isNotEmpty)
              BodyMediumLabel(
                prefix,
                color: textColor,
              ),
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
                        fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * _getFontSizeScale(),
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
  Widget _buildFullFileLine(BuildContext context, String content, int lineNumber) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        // Copy line to clipboard on tap
        Clipboard.setData(ClipboardData(text: content));
        widget.onLineCopied?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingS, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line number
            if (widget.showLineNumbers) ...[
              SizedBox(
                width: AppTheme.iconXL + AppTheme.paddingM + AppTheme.paddingXS,
                child: BodySmallLabel(
                  lineNumber.toString(),
                  color: colorScheme.onSurfaceVariant,
                  textAlign: TextAlign.right,
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
                        fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * _getFontSizeScale(),
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

/// Draggable Speed Dial FAB for diff viewer actions
class _DraggableSpeedDial extends StatefulWidget {
  final List<DiffViewerAction> actions;
  final bool isExpanded;  // Controlled by parent
  final VoidCallback onToggle;  // Callback to toggle expansion
  final VoidCallback onCollapse;  // Callback to collapse (for actions)

  const _DraggableSpeedDial({
    required this.actions,
    required this.isExpanded,
    required this.onToggle,
    required this.onCollapse,
  });

  @override
  State<_DraggableSpeedDial> createState() => _DraggableSpeedDialState();
}

class _DraggableSpeedDialState extends State<_DraggableSpeedDial> {
  Offset _position = const Offset(AppTheme.paddingM, AppTheme.paddingM); // Default position (from bottom-right)
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: _position.dx,
      bottom: _position.dy,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          // ESC key dismissal
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              widget.isExpanded) {
            widget.onCollapse();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Update position by subtracting delta (since we're using right/bottom positioning)
              _position = Offset(
                (_position.dx - details.delta.dx).clamp(AppTheme.paddingM, MediaQuery.of(context).size.width - 80),
                (_position.dy - details.delta.dy).clamp(AppTheme.paddingM, MediaQuery.of(context).size.height - 80),
              );
            });
          },
          onTap: () {
            // Request focus when tapped so ESC key works
            _focusNode.requestFocus();
          },
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Expanded action buttons
            if (widget.isExpanded)
              ...widget.actions.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.paddingS + AppTheme.paddingXS),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(AppTheme.paddingXS),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingS + AppTheme.paddingXS,
                              vertical: AppTheme.paddingS,
                            ),
                            child: BodySmallLabel(action.label),
                          ),
                        ),
                        const SizedBox(width: AppTheme.paddingS + AppTheme.paddingXS),
                        // Action button
                        FloatingActionButton.small(
                          heroTag: action.label,
                          onPressed: () {
                            action.onPressed();
                            // Collapse after action
                            widget.onCollapse();
                          },
                          child: Icon(action.icon),
                        ),
                      ],
                    ),
                  )),
            // Main FAB
            FloatingActionButton(
              heroTag: 'main_fab',
              onPressed: () {
                widget.onToggle();
                // Request focus so ESC key works
                _focusNode.requestFocus();
              },
              child: AnimatedRotation(
                turns: widget.isExpanded ? 0.125 : 0, // 45 degrees when expanded
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.isExpanded
                      ? PhosphorIconsRegular.x
                      : PhosphorIconsRegular.list,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
