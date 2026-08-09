import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        CodeLineSpec,
        Inset,
        Proximity,
        Skin,
        SkinScope,
        TextRole,
        TextRun,
        Tone;

import '../../generated/app_localizations.dart';
import '../../core/diff/diff_parser.dart';
import '../theme/app_theme.dart';
import 'base_label.dart';
import 'base_card.dart';
import 'base_layout.dart';

enum DiffViewMode {
  diff, // Show only changes (default)
  fullFile, // Show entire file content
}

/// Base diff viewer component for rendering diff content with syntax highlighting
///
/// **Every line is `surfaces.codeLine`** (#249, P5). This viewer knows only
/// facts: what each line means (its `Tone`), git's own gutter character, which
/// number sits on which side, and - through `CodeLineSpec.paired` - whether
/// the gutter compares two versions (a diff) or numbers a single one (the
/// full-file view). The gutter geometry, the wash each meaning paints, and
/// the code typography are the skin's answers. The user's diff font arrives
/// at the skin as `SkinRequest.monoFamily` and `SkinRequest.codeScale` - the
/// family and the size of the same "Code Font Size" decision
/// (`theme_section.dart`, `AppConfig.previewFontFamily` / `previewFontSize`)
/// - which is why this widget no longer takes a font at all.
class BaseDiffViewer extends StatefulWidget {
  final List<DiffLine> diffLines;
  final bool compactMode;
  final bool showLineNumbers;
  final VoidCallback? onLineCopied;
  final String? fullFileContent; // Full file content for untracked/new files
  final String? filePath; // File path for display
  final DiffViewMode viewMode; // View mode controlled by parent

  const BaseDiffViewer({
    super.key,
    required this.diffLines,
    this.compactMode = false,
    this.showLineNumbers = true,
    this.onLineCopied,
    this.fullFileContent,
    this.filePath,
    this.viewMode = DiffViewMode.diff,
  });

  @override
  State<BaseDiffViewer> createState() => _BaseDiffViewerState();
}

class _BaseDiffViewerState extends State<BaseDiffViewer> {
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

    // The viewer shows content and nothing else. Its actions - toggling the
    // full-file view, staging, copying - belong to whoever mounts it: the
    // changes screen's diff panel carries them in its own header (#438
    // resolved the floating speed dial that used to sit here as the site
    // asking the wrong member - a region's action set belongs to the
    // region's header, not to `ScreenSpec.primaryActions`).
    return widget.viewMode == DiffViewMode.fullFile && canShowFullFile
        ? _buildFullFileView(context)
        : _buildDiffView(context);
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
    // What the line IS. Everything the old construction derived from these
    // facts by hand - the 12% wash behind an added line, the primary band
    // behind a hunk header, the muted informational text - is the skin's own
    // tone table now (`surfaces.codeLine` documents it per skin).
    final Tone tone = switch (line.type) {
      DiffLineType.addition => Tone.gitAdded,
      DiffLineType.deletion => Tone.gitDeleted,
      DiffLineType.header => Tone.accent,
      DiffLineType.fileHeader => Tone.info,
      DiffLineType.info => Tone.muted,
      DiffLineType.context => Tone.neutral,
    };

    // The gutter character git itself writes. Content, not decoration: it is
    // what makes a copied diff still a diff, and the space on a context line
    // is what keeps its code aligned with its `+` and `-` neighbours'.
    final String? marker = switch (line.type) {
      DiffLineType.addition => '+',
      DiffLineType.deletion => '-',
      DiffLineType.context => ' ',
      _ => null,
    };

    // Extract line content (remove +/- prefix if present)
    String displayContent = line.content;
    if (line.type == DiffLineType.addition ||
        line.type == DiffLineType.deletion) {
      if (displayContent.isNotEmpty) {
        displayContent = displayContent.substring(1);
      }
    }

    // A header carries no numbers, so the skin draws it gutter-less - the
    // same rule the hand-painted line applied by type.
    final bool numbered =
        widget.showLineNumbers &&
        (line.type == DiffLineType.context ||
            line.type == DiffLineType.addition ||
            line.type == DiffLineType.deletion);

    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.surfaces.codeLine(
        inner,
        CodeLineSpec(
          runs: [TextRun(displayContent.isEmpty ? ' ' : displayContent)],
          tone: tone,
          marker: marker,
          oldNumber: numbered ? line.oldLineNumber : null,
          newNumber: numbered ? line.newLineNumber : null,
          onTap: () {
            // Copy line to clipboard on tap
            Clipboard.setData(ClipboardData(text: displayContent));
            widget.onLineCopied?.call();
          },
        ),
      );
    });
  }

  /// Build a line for full file view
  Widget _buildFullFileLine(
    BuildContext context,
    String content,
    int lineNumber,
  ) {
    return SkinScope.render(context, (Skin skin, BuildContext inner) {
      return skin.surfaces.codeLine(
        inner,
        CodeLineSpec(
          runs: [TextRun(content.isEmpty ? ' ' : content)],
          // NOT paired: a whole file has one line number, not an old and a
          // new one, so there is no absent side for the skin to reserve.
          paired: false,
          newNumber: widget.showLineNumbers ? lineNumber : null,
          onTap: () {
            // Copy line to clipboard on tap
            Clipboard.setData(ClipboardData(text: content));
            widget.onLineCopied?.call();
          },
        ),
      );
    });
  }
}
