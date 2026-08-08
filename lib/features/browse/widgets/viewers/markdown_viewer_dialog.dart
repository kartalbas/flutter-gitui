import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart' show IconRole, Proximity;
import 'package:path/path.dart' as path;

import '../../../../shared/components/base_layout.dart';
import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced markdown viewer dialog with rendering
class MarkdownViewerDialog extends StatefulWidget {
  final String filePath;

  const MarkdownViewerDialog({super.key, required this.filePath});

  @override
  State<MarkdownViewerDialog> createState() => _MarkdownViewerDialogState();
}

class _MarkdownViewerDialogState extends State<MarkdownViewerDialog> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = 'File not found';
          _isLoading = false;
        });
        return;
      }

      // Lenient decode so non-UTF-8 markdown still renders instead of
      // failing a strict UTF-8 decode.
      final content = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading file: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.filePath);

    return BaseViewerDialog(
      icon: IconRole.fileText,
      title: 'Markdown Viewer',
      subtitle: fileName,
      widthFactor: 0.85,
      heightFactor: 0.85,
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Not `EmptyStateWidget`, and this state is blocked twice
                  // over. It says a mark and ONE line - there is no headline
                  // to hand the facade, and the facade renders its headline
                  // and its sentence unconditionally, so inventing a headline
                  // adds a line of text and passing '' paints a blank one and
                  // its gap (base_diff_viewer.dart refuses it from that same
                  // side). And the facade owns the mark's colour, answering it
                  // with `onSurfaceVariant`, which would repaint this red
                  // failure mark neutral. The read cannot move alone either:
                  // no `Tone` says "the file could not be read".
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  // The hero glyph and the message under it are two groups
                  // inside the one error-state region: `separate`, the word
                  // every other empty and error state uses at this boundary.
                  const BaseGap(Proximity.separate),
                  Text(_error!),
                ],
              ),
            )
          : Markdown(
              data: _content,
              selectable: true,
              // Nine colour words left this sheet and not one pixel moved.
              // `Tone.neutral` is "whatever this surface's ordinary foreground
              // is", and the ramp these styles are built from already carries
              // exactly that: the theme stamps the scheme's on-surface role on
              // every step of the type scale, so each of the nine restated the
              // ambient answer in Material's words and nothing else. Saying
              // nothing is how a bag of styles says neutral.
              //
              // A `MarkdownStyleSheet` is a third-party bag of `TextStyle`s,
              // not a widget, so `BaseLabel` cannot reach any of these lines -
              // which is why the one line below that is NOT neutral has to
              // stay a colour.
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium,
                h1: Theme.of(context).textTheme.displaySmall,
                h2: Theme.of(context).textTheme.headlineMedium,
                h3: Theme.of(context).textTheme.titleLarge,
                h4: Theme.of(context).textTheme.titleMedium,
                h5: Theme.of(context).textTheme.titleSmall,
                h6: Theme.of(context).textTheme.labelLarge,
                listBullet: Theme.of(context).textTheme.bodyMedium,
                // The one line in the sheet that says something: a quotation
                // is secondary to the prose around it, which is `Tone.muted`.
                // It stays a `colorScheme` read because a tone can only reach
                // text through `BaseLabel` and this is a `TextStyle` handed to
                // a renderer the application does not own. It leaves when the
                // markdown surface is a member.
                blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                code: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
              ),
            ),
    );
  }
}

/// Show markdown viewer dialog
Future<void> showMarkdownViewerDialog(
  BuildContext context, {
  required String filePath,
}) {
  return showDialog(
    context: context,
    builder: (context) => MarkdownViewerDialog(filePath: filePath),
  );
}
