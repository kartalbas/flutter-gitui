import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        DialogExtent,
        DialogRouteSpec,
        IconRole,
        MarkdownSpec,
        Overlays,
        Proximity,
        Skin,
        SkinScope;
import 'package:path/path.dart' as path;

import '../../../../shared/components/base_layout.dart';
import '../../../../shared/components/base_progress.dart';
import '../../../../shared/components/base_viewer_dialog.dart';

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
          ? const BaseProgress.block()
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Not `EmptyStateWidget`, and the colour is no longer why:
                  // the hero carries a tone now (#431), so a red failure mark
                  // is something the facade can say. What it still cannot say
                  // is this state's SHAPE - the same one csv_viewer_dialog.dart
                  // records beside it. It is a mark and ONE line, with no
                  // headline to hand the facade, while the facade renders its
                  // headline and its sentence unconditionally: inventing a
                  // headline adds a line of text and passing '' paints a blank
                  // one and its gap (base_diff_viewer.dart refuses it from
                  // that same side). The mark is 48 rather than the member's
                  // 64 on top of that, and the read is stranded with the size,
                  // exactly as it is inside the facade: a tone reaches a mark
                  // only through a member or `BaseIcon`, whose scales top out
                  // at 24.
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
          // **Here is a document written in Markdown**, and that is the whole
          // of what this dialog now says about it. The eleven-line
          // `MarkdownStyleSheet` that stood here - the type ramp for six
          // heading levels and the prose, the italic quotation, the inline
          // code span and the fenced block's tinted 8 dp box - is the exact
          // sheet `MaterialSurfaces.markdown` was extracted FROM, line for
          // line, so nothing about the rendering is re-decided by the move.
          // What leaves with it is the last thing the application had no
          // business owning: the code block's corner. A fenced block's corner
          // is the language's answer (M3 rounds at 8, Fluent at 4), and the
          // only reason this file could name one was that it was holding the
          // renderer's style bag itself.
          : SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.markdown(
                inner,
                // No `baseDirectory`: the viewer opens a file the user picked
                // and never resolved a relative image against it before, so
                // stating one here would be new behaviour rather than a
                // migration. Links stay inert for the same reason - this
                // dialog has never followed one.
                MarkdownSpec(source: _content),
              );
            }),
    );
  }
}

/// Show markdown viewer dialog
Future<void> showMarkdownViewerDialog(
  BuildContext context, {
  required String filePath,
}) {
  return Overlays.dialogFrom(
    context,
    route: DialogRouteSpec(
      title: 'Markdown Viewer',
      extent: DialogExtent.browser,
    ),
    builder: (context) => MarkdownViewerDialog(filePath: filePath),
  );
}
