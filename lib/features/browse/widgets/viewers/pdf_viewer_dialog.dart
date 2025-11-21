import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';

import '../../../../generated/app_localizations.dart';
import '../../../../shared/components/base_label.dart';
import '../../../../shared/components/base_button.dart';
import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced PDF viewer dialog
class PdfViewerDialog extends StatefulWidget {
  final String filePath;

  const PdfViewerDialog({
    super.key,
    required this.filePath,
  });

  @override
  State<PdfViewerDialog> createState() => _PdfViewerDialogState();
}

class _PdfViewerDialogState extends State<PdfViewerDialog> {
  late PdfController _pdfController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.filePath),
      );

      // Get total pages
      final document = await PdfDocument.openFile(widget.filePath);
      setState(() {
        _totalPages = document.pagesCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.filePath);
    final l10n = AppLocalizations.of(context)!;

    return BaseViewerDialog(
      icon: PhosphorIconsRegular.filePdf,
      title: 'PDF Viewer',
      subtitle: fileName,
      headerMetadata: !_isLoading && _error == null
          ? BodySmallLabel('Page $_currentPage of $_totalPages')
          : null,
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
              : PdfView(
                  controller: _pdfController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  scrollDirection: Axis.vertical,
                ),
      footer: !_isLoading && _error == null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BaseIconButton(
                    icon: PhosphorIconsRegular.caretLeft,
                    tooltip: l10n.tooltipPreviousPage,
                    onPressed: _currentPage > 1
                        ? () {
                            _pdfController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                  const SizedBox(width: AppTheme.paddingL),
                  TitleSmallLabel(
                    '$_currentPage / $_totalPages',
                  ),
                  const SizedBox(width: AppTheme.paddingL),
                  BaseIconButton(
                    icon: PhosphorIconsRegular.caretRight,
                    tooltip: l10n.tooltipNextPage,
                    onPressed: _currentPage < _totalPages
                        ? () {
                            _pdfController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

/// Show PDF viewer dialog
Future<void> showPdfViewerDialog(
  BuildContext context, {
  required String filePath,
}) {
  return showDialog(
    context: context,
    builder: (context) => PdfViewerDialog(filePath: filePath),
  );
}
