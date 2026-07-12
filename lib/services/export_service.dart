import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'database_service.dart';

/// One-file JSON export/import of the whole database.
///
/// Uses the system save/open dialogs (Storage Access Framework), which lands
/// in Downloads by default and needs no storage permissions on any Android
/// version.
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  /// Returns the saved path, or null if the user cancelled.
  Future<String?> exportToFile() async {
    final data = await DatabaseService.instance.exportData();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    final stamp = DateTime.now().toIso8601String().split('T').first;
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save CoreFit export',
      fileName: 'corefit-export-$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Returns import counts, or null if the user cancelled.
  /// Throws [FormatException] on malformed/incompatible files.
  Future<ImportResult?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Pick CoreFit export',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a CoreFit export file.');
    }
    return DatabaseService.instance.importData(decoded);
  }
}
