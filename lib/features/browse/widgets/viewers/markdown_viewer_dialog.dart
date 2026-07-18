import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;

import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced markdown viewer dialog with rendering
class MarkdownViewerDialog extends StatefulWidget {
  final String filePath;

  const MarkdownViewerDialog({
    super.key,
    required this.filePath,
  });

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

      final content = await file.readAsString();
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
      icon: PhosphorIconsRegular.fileText,
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
                      Icon(
                        PhosphorIconsRegular.warningCircle,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: AppTheme.paddingM),
                      Text(_error!),
                    ],
                  ),
                )
              : Markdown(
                  data: _content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h1: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h3: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h4: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h5: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    h6: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                    code: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurface,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                    codeblockDecoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.paddingS),
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
