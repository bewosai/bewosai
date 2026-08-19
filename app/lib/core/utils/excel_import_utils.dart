import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// One picked-and-parsed spreadsheet: header row lowercased into each row's
/// keys, cell values as trimmed strings (numeric parsing is the caller's
/// job, since only it knows which columns are numeric for its entity).
class ExcelPickResult {
  final String fileName;
  final List<Map<String, String>> rows;
  final String? error;
  const ExcelPickResult({required this.fileName, required this.rows, this.error});
}

/// Shared pick/parse/template-generate logic behind every "bulk import from
/// Excel" screen (products, parties, ...) — keeps the file_picker/excel
/// package plumbing in one place instead of duplicated per entity.
class ExcelImportUtils {
  static const maxEntries = 500;
  static const maxBytes = 1024 * 1024; // 1MB

  /// Builds a template .xlsx (header row + one example row) and writes it
  /// to a temp file, returning the path for the caller to share.
  static Future<String> writeTemplate({
    required String sheetName,
    required List<String> headers,
    required List<String> exampleRow,
    required String fileName,
  }) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel[sheetName];
    sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
    sheet.appendRow(exampleRow.map((v) => xls.TextCellValue(v)).toList());

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('encode failed');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Opens the native file picker and parses the chosen .xlsx/.xls into
  /// rows keyed by lowercased header. Returns null if the user cancelled.
  static Future<ExcelPickResult?> pickAndParse() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return const ExcelPickResult(fileName: '', rows: [], error: 'Could not read that file');
    }
    if (bytes.length > maxBytes) {
      return const ExcelPickResult(fileName: '', rows: [], error: 'File is larger than 1MB');
    }

    try {
      final excel = xls.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) throw Exception('no sheets');
      final sheet = excel.tables[excel.tables.keys.first]!;
      if (sheet.rows.isEmpty) throw Exception('empty sheet');

      final header = sheet.rows.first.map((c) => _cellText(c?.value).trim().toLowerCase()).toList();
      final dataRows = sheet.rows.skip(1).where((r) => r.any((c) => _cellText(c?.value).trim().isNotEmpty));

      final rows = <Map<String, String>>[];
      for (final row in dataRows) {
        final map = <String, String>{};
        for (var col = 0; col < header.length && col < row.length; col++) {
          map[header[col]] = _cellText(row[col]?.value).trim();
        }
        rows.add(map);
      }
      return ExcelPickResult(fileName: file.name, rows: rows);
    } catch (_) {
      return const ExcelPickResult(
        fileName: '',
        rows: [],
        error: "Could not read that file — make sure it's a valid .xlsx or .xls",
      );
    }
  }

  static String _cellText(xls.CellValue? cv) {
    if (cv == null) return '';
    return switch (cv) {
      xls.TextCellValue v => v.value.text ?? '',
      xls.IntCellValue v => v.value.toString(),
      xls.DoubleCellValue v => v.value.toString(),
      xls.BoolCellValue v => v.value.toString(),
      xls.FormulaCellValue v => v.formula,
      xls.DateCellValue v => v.toString(),
      xls.TimeCellValue v => v.toString(),
      xls.DateTimeCellValue v => v.toString(),
    };
  }
}
