import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';

import '../../../../generated/app_localizations.dart';
import '../../../../shared/components/base_label.dart';
import '../../../../shared/components/base_viewer_dialog.dart';
import '../../../../shared/theme/app_theme.dart';

/// Enhanced CSV/spreadsheet viewer dialog
class CsvViewerDialog extends StatefulWidget {
  final String filePath;

  const CsvViewerDialog({super.key, required this.filePath});

  @override
  State<CsvViewerDialog> createState() => _CsvViewerDialogState();
}

class _CsvViewerDialogState extends State<CsvViewerDialog> {
  List<List<dynamic>> _rows = [];
  bool _isLoading = true;
  String? _error;
  int _rowCount = 0;
  int _columnCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  Future<void> _loadCsv() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = 'File not found';
          _isLoading = false;
        });
        return;
      }

      // Lenient decode so Windows-1252 exports (e.g. from Excel) still parse
      // instead of failing a strict UTF-8 decode.
      final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);

      // The csv package defaults eol to '\r\n', which leaves LF-only files
      // as a single giant row. Normalize to LF so both styles parse.
      const converter = CsvToListConverter(eol: '\n');
      final rows = converter.convert(content.replaceAll('\r\n', '\n'));

      setState(() {
        _rows = rows;
        _rowCount = rows.length;
        // DataTable asserts every row has exactly columns.length cells, so
        // ragged CSV rows must be measured against the widest row.
        _columnCount = rows.fold(
          0,
          (max, row) => row.length > max ? row.length : max,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading CSV: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.filePath);

    return BaseViewerDialog(
      icon: PhosphorIconsRegular.table,
      title: 'CSV/Spreadsheet Viewer',
      subtitle: fileName,
      headerMetadata: !_isLoading && _error == null
          ? BodySmallLabel('$_rowCount rows × $_columnCount columns')
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
          : _rows.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.emptyCsvFile))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  columns: _buildColumns(),
                  rows: _buildRows(),
                  columnSpacing: AppTheme.paddingL,
                  horizontalMargin: AppTheme.paddingM,
                  border: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (_rows.isEmpty) return [];

    final firstRow = _rows[0];
    return List.generate(
      _columnCount,
      (index) => DataColumn(
        label: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingS,
            vertical: AppTheme.paddingXS,
          ),
          child: TitleSmallLabel(
            index < firstRow.length ? firstRow[index]?.toString() ?? '' : '',
          ),
        ),
      ),
    );
  }

  List<DataRow> _buildRows() {
    if (_rows.length <= 1) return [];

    return _rows.skip(1).map((row) {
      return DataRow(
        cells: List.generate(_columnCount, (index) {
          final cell = index < row.length ? row[index] : null;
          return DataCell(
            SelectableText(
              cell?.toString() ?? '',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          );
        }),
      );
    }).toList();
  }
}

/// Show CSV viewer dialog
Future<void> showCsvViewerDialog(
  BuildContext context, {
  required String filePath,
}) {
  return showDialog(
    context: context,
    builder: (context) => CsvViewerDialog(filePath: filePath),
  );
}
