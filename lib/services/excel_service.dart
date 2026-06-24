import 'dart:io';
import 'package:excel/excel.dart';
import '../models/product.dart';

class ExcelService {
  static const String _sheetName = 'Sheet1';
  static const String _filePrefix = 'logista_';

  static Future<String?> generateLogistaExcel(
    List<Product> products,
    Map<String, int> orderQty,
    String? customPath,
  ) async {
    if (customPath == null) return null;

    final excel = Excel.createExcel();
    final Sheet sheet = excel[_sheetName];

    sheet.appendRow(['AAMS', 'QUANTITA']);

    for (final p in products) {
      final qty = orderQty[p.id] ?? 0;
      if (qty <= 0) continue;

      final totalWeight = qty * p.unitWeight;

      sheet.appendRow([
        p.aamsCode,
        totalWeight.toStringAsFixed(2),
      ]);
    }

    final now = DateTime.now();
    final datePart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final filePath = '$customPath/${_filePrefix}${datePart}_${timePart}.xlsx';

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(excel.encode()!);

    return filePath;
  }

  static Future<int> clearSavedExcels(String? customPath) async {
    if (customPath == null || customPath.trim().isEmpty) return 0;

    final directory = Directory(customPath);
    if (!directory.existsSync()) return 0;

    int deletedCount = 0;
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;

      final name = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;

      if (!name.startsWith(_filePrefix) || !name.endsWith('.xlsx')) {
        continue;
      }

      entity.deleteSync();
      deletedCount++;
    }

    return deletedCount;
  }
}
