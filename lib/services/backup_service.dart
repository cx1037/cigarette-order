import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../models/order_item.dart';
import '../models/order_record.dart';
import '../models/product.dart';
import '../models/stock_adjustment.dart';
import 'database_service.dart';
import 'settings_service.dart';

class BackupService {
  static Future<String?> exportBackup() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir == null) return null;

    final products = await DatabaseService.instance.getAllProducts();
    final orders = await DatabaseService.instance.getAllOrders();
    final orderItems = await DatabaseService.instance.getAllOrderItems();
    final orderHistory = await DatabaseService.instance.getAllOrderHistoryRows();
    final stockAdjustments =
        await DatabaseService.instance.getAllStockAdjustments();
    final savePath = await SettingsService.getPath();

    final data = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'products': products.map((e) => e.toMap()).toList(),
      'orders': orders.map((e) => e.toMap()).toList(),
      'orderItems': orderItems.map((e) => e.toMap()).toList(),
      'orderHistory': orderHistory,
      'stockAdjustments': stockAdjustments.map((e) => e.toMap()).toList(),
      'settings': {'savePath': savePath},
    };

    final now = DateTime.now();
    final filePath =
        '$selectedDir/smoke_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';

    final file = File(filePath);
    await file.writeAsString(jsonEncode(data));

    return filePath;
  }

  static Future<String?> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final jsonData = jsonDecode(content);

    final List<dynamic> productsJson = jsonData['products'] ?? [];
    final List<dynamic> ordersJson = jsonData['orders'] ?? [];
    final List<dynamic> orderItemsJson = jsonData['orderItems'] ?? [];
    final List<dynamic> stockAdjustmentsJson =
        jsonData['stockAdjustments'] ?? [];
    final settingsJson = jsonData['settings'] ?? {};

    final currentProducts = await DatabaseService.instance.getAllProducts();
    final currentProductsById = {
      for (final product in currentProducts) product.id: product,
    };

    final products = productsJson
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .map((product) {
          final current = currentProductsById[product.id];
          if (current == null) return product;

          final incomingBarcode = product.barcode.trim();
          if (incomingBarcode.isNotEmpty) return product;

          return Product(
            id: product.id,
            name: product.name,
            aamsCode: product.aamsCode,
            type: product.type,
            currentStock: product.currentStock,
            safetyStock: product.safetyStock,
            unitWeight: product.unitWeight,
            price: product.price,
            kgPrice: product.kgPrice,
            barcode: current.barcode,
            isActive: product.isActive,
          );
        })
        .toList();
    final orders = ordersJson
        .map((e) => OrderRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final orderItems = orderItemsJson
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final stockAdjustments = stockAdjustmentsJson
        .map((e) => StockAdjustment.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    await DatabaseService.instance.replaceBackupData(
      products: products,
      orders: orders,
      orderItems: orderItems,
      stockAdjustments: stockAdjustments,
    );

    if (settingsJson['savePath'] != null) {
      await SettingsService.savePath(settingsJson['savePath']);
    }

    return file.path;
  }
}
