import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;

import '../../../generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/base_label.dart';
import '../../../shared/components/base_button.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import 'viewers/markdown_viewer_dialog.dart';
import 'viewers/image_viewer_dialog.dart';
import 'viewers/pdf_viewer_dialog.dart';
import 'viewers/csv_viewer_dialog.dart';

/// File preview panel - shows file content with basic syntax highlighting
class FilePreviewPanel extends ConsumerStatefulWidget {
  final String filePath;

  const FilePreviewPanel({
    super.key,
    required this.filePath,
  });

  @override
  ConsumerState<FilePreviewPanel> createState() => _FilePreviewPanelState();
}

class _FilePreviewPanelState extends ConsumerState<FilePreviewPanel> {
  String _content = '';
  bool _isLoading = true;
  bool _isBinary = false;
  String? _error;
  int _lineCount = 0;
  int _fileSize = 0;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  @override
  void didUpdateWidget(FilePreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadFileContent();
    }
  }

  Future<void> _loadFileContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isBinary = false;
    });

    try {
      final file = File(widget.filePath);

      if (!await file.exists()) {
        setState(() {
          _error = 'File not found'; // Will be displayed with l10n in UI
          _isLoading = false;
        });
        return;
      }

      // Get file size
      final stat = await file.stat();
      _fileSize = stat.size;

      // Check if file is too large (> 1MB)
      if (_fileSize > 1024 * 1024) {
        setState(() {
          _error = _formatFileSize(_fileSize); // Will be formatted with l10n in UI
          _isLoading = false;
        });
        return;
      }

      // Try to read as text
      try {
        final content = await file.readAsString();

        // Check if content appears to be binary
        if (_containsBinaryCharacters(content)) {
          setState(() {
            _isBinary = true;
            _isLoading = false;
          });
          return;
        }

        // Remove carriage returns to prevent double line spacing
        final cleanContent = content.replaceAll('\r', '');
        final lineCount = cleanContent.split('\n').length;

        setState(() {
          _content = cleanContent;
          _lineCount = lineCount;
          _isLoading = false;
        });
      } catch (e) {
        // Failed to read as text, probably binary
        setState(() {
          _isBinary = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading file: $e';
        _isLoading = false;
      });
    }
  }

  bool _containsBinaryCharacters(String content) {
    // Check for null bytes or high percentage of non-printable characters
    if (content.contains('\x00')) return true;

    final nonPrintable = content.codeUnits.where((c) => c < 32 && c != 9 && c != 10 && c != 13).length;
    return nonPrintable > content.length * 0.3;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get font size scale factor based on AppFontSize
  double _getFontSizeScale(AppFontSize fontSize) {
    switch (fontSize) {
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

  bool _hasEnhancedViewer() {
    final ext = path.extension(widget.filePath).toLowerCase();
    return ext == '.md' ||
        ext == '.pdf' ||
        ext == '.csv' ||
        ext == '.png' ||
        ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.gif' ||
        ext == '.bmp' ||
        ext == '.webp';
  }

  Future<void> _openEnhancedViewer() async {
    final ext = path.extension(widget.filePath).toLowerCase();

    switch (ext) {
      case '.md':
        await showMarkdownViewerDialog(context, filePath: widget.filePath);
        break;
      case '.pdf':
        await showPdfViewerDialog(context, filePath: widget.filePath);
        break;
      case '.csv':
        await showCsvViewerDialog(context, filePath: widget.filePath);
        break;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.bmp':
      case '.webp':
        await showImageViewerDialog(context, filePath: widget.filePath);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.filePreview),
            BodySmallLabel(
              fileName,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        actions: [
          if (!_isLoading && !_isBinary && _error == null) ...[
            // File info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingM),
              child: Center(
                child: BodySmallLabel(
                  AppLocalizations.of(context)!.messageFileInfo(_lineCount, _formatFileSize(_fileSize)),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          // Enhanced viewer button
          if (_hasEnhancedViewer())
            BaseIconButton(
              icon: PhosphorIconsRegular.eye,
              tooltip: AppLocalizations.of(context)!.tooltipOpenEnhancedViewer,
              onPressed: _openEnhancedViewer,
              variant: ButtonVariant.primary,
            ),
          if (_hasEnhancedViewer()) const SizedBox(width: AppTheme.paddingS),
          BaseIconButton(
            icon: PhosphorIconsRegular.arrowClockwise,
            tooltip: AppLocalizations.of(context)!.refresh,
            onPressed: _loadFileContent,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      // Determine if error is "File not found" or "File too large"
      final isFileNotFound = _error == 'File not found';
      final errorMessage = isFileNotFound
          ? AppLocalizations.of(context)!.messageFileNotFound
          : AppLocalizations.of(context)!.messageFileTooLargeToPreview(_error!);

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.paddingL),
            TitleLargeLabel(
              AppLocalizations.of(context)!.labelCannotPreviewFile,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              errorMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isBinary) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.fileCode,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.paddingL),
            TitleLargeLabel(
              AppLocalizations.of(context)!.labelBinaryFile,
            ),
            const SizedBox(height: AppTheme.paddingS),
            BodyMediumLabel(
              AppLocalizations.of(context)!.labelThisFileCannotBePreviewed,
            ),
            const SizedBox(height: AppTheme.paddingXS),
            BodySmallLabel(
              _formatFileSize(_fileSize),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      );
    }

    return _buildTextPreview();
  }

  Widget _buildTextPreview() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  _lineCount,
                  (index) => BodyMediumLabel(
                    '${index + 1}',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.paddingM),
                      child: SelectableText(
                        _content,
                        style: GoogleFonts.getFont(
                          ref.watch(previewFontFamilyProvider),
                          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.2,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * _getFontSizeScale(ref.watch(previewFontSizeProvider)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
