import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gitui/shared/icons/phosphor_icons.dart';
import 'package:gitui_skin_api/gitui_skin_api.dart'
    show
        ContentPort,
        DataGridSpec,
        IconRole,
        Proximity,
        Skin,
        SkinScope,
        TextRole;
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';

import '../../../../generated/app_localizations.dart';
import '../../../../shared/components/base_label.dart';
import '../../../../shared/components/base_layout.dart';
import '../../../../shared/components/base_viewer_dialog.dart';

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
      final content = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );

      // csv 8's decoder auto-detects the line ending and delimiter, so LF-only
      // and CRLF files (and ';'-separated exports) all parse without the old
      // explicit eol workaround.
      final rows = Csv().decode(content);

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
      icon: IconRole.table,
      title: 'CSV/Spreadsheet Viewer',
      subtitle: fileName,
      headerMetadata: !_isLoading && _error == null
          ? BaseLabel(
              '$_rowCount rows × $_columnCount columns',
              role: TextRole.detail,
            )
          : null,
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Not `EmptyStateWidget`, and the colour is no longer why:
                  // the hero carries a tone now (#431), so a red failure mark
                  // is something the facade can say. What it still cannot say
                  // is this state's SHAPE. It is a mark and ONE line - there
                  // is no headline to hand the facade, and the facade renders
                  // its headline and its sentence unconditionally, so
                  // inventing a headline adds a line of text and passing ''
                  // paints a blank one and its gap (base_diff_viewer.dart
                  // refuses it from that same side). The mark is 48 rather
                  // than the member's 64 on top of that. The read is stranded
                  // with the size, exactly as it is inside the facade: a tone
                  // reaches a mark only through a member or `BaseIcon`, whose
                  // scales top out at 24.
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
          : _rows.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.emptyCsvFile))
          // The table is `surfaces.dataGrid` (#249, P5). Every metric this
          // dialog used to state - the column spacing, the horizontal margin,
          // the heading fill, the rule between cells and the row height - is
          // the grid member's, because "how tightly packed a table of values
          // is" is one question and answering half of it here is what let the
          // hand-built copy drift from the skin's own answer.
          : SkinScope.render(context, (Skin skin, BuildContext inner) {
              return skin.surfaces.dataGrid(
                inner,
                DataGridSpec(columns: _headings(), rows: _cells()),
              );
            }),
    );
  }

  /// The first CSV row, padded to the widest row so a ragged file still names
  /// every column the rows below can fill.
  List<String> _headings() {
    if (_rows.isEmpty) return const <String>[];

    final firstRow = _rows[0];
    return List.generate(
      _columnCount,
      (index) =>
          index < firstRow.length ? firstRow[index]?.toString() ?? '' : '',
    );
  }

  /// Every row but the heading, as content the grid mounts in its own cells.
  ///
  /// Short rows are handed over short rather than padded here: the member
  /// fills the missing cells itself, which is what keeps "a ragged CSV still
  /// renders" one answer instead of two.
  List<List<ContentPort>> _cells() {
    if (_rows.length <= 1) return const <List<ContentPort>>[];

    return <List<ContentPort>>[
      for (final row in _rows.skip(1))
        <ContentPort>[
          for (final cell in row)
            // A spreadsheet cell is machine-written text the user reads in a
            // column and copies out of it, which is `TextRole.code` -
            // monospaced because a column of numbers only lines up that way.
            ContentPort(
              BaseLabel(
                cell?.toString() ?? '',
                role: TextRole.code,
                selectable: true,
              ),
            ),
        ],
    ];
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
