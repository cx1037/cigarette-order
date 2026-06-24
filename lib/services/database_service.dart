import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/order_record.dart';
import '../models/order_item.dart';
import '../models/stock_adjustment.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    _database ??= await _initDB('smoke.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        aamsCode TEXT,
        type TEXT,
        currentStock INTEGER,
        safetyStock INTEGER,
        unitWeight REAL,
        price REAL,
        kgPrice REAL,
        barcode TEXT,
        isActive INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId TEXT,
        productId TEXT,
        stockBefore INTEGER,
        orderedQty INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId TEXT,
        date TEXT,
        quantity INTEGER,
        reason TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN kgPrice REAL');
    }
  }

  // ─── 产品 ───

  Future<int> countProducts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> insertMany(List<Product> products) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'products',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertOrUpdateProduct(Product p) async {
    final db = await database;
    await db.insert(
      'products',
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProduct(Product p) async {
    final db = await database;
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deleteProduct(String productId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('stock_adjustments', where: 'productId = ?', whereArgs: [productId]);
      await txn.delete('order_items', where: 'productId = ?', whereArgs: [productId]);
      // 删除不再关联任何 order_items 的孤立订单
      await txn.delete('orders', where: 'id NOT IN (SELECT DISTINCT orderId FROM order_items)');
      await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
    });
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map(Product.fromMap).toList();
  }

  Future<List<Product>> getActiveProducts() async {
    final db = await database;
    final result = await db.query('products',
        where: 'isActive = ?', whereArgs: [1], orderBy: 'name ASC');
    return result.map(Product.fromMap).toList();
  }

  Future<Product?> findByAams(String aamsCode) async {
    final db = await database;
    final result = await db.query('products',
        where: 'aamsCode = ?', whereArgs: [aamsCode], limit: 1);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<List<Product>> searchByName(String query) async {
    final db = await database;
    final result = await db.query('products',
        where: 'name LIKE ?', whereArgs: ['%$query%'], orderBy: 'name ASC');
    return result.map(Product.fromMap).toList();
  }

  Future<Product?> findByBarcode(String barcode) async {
    final db = await database;
    final result = await db.query('products',
        where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<void> activateProduct({
    required String productId,
    required String barcode,
  }) async {
    final db = await database;
    await db.update('products', {'barcode': barcode, 'isActive': 1},
        where: 'id = ?', whereArgs: [productId]);
  }

  // ─── 订单 ───

  Future<void> insertOrder(OrderRecord order, List<OrderItem> items) async {
    final db = await database;
    final batch = db.batch();
    batch.insert('orders', order.toMap());
    for (final item in items) {
      batch.insert('order_items', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<OrderItem>> getRecentOrderItems(String productId,
      {int limit = 20}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT oi.id, oi.orderId, oi.productId, oi.stockBefore, oi.orderedQty
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      WHERE oi.productId = ?
      ORDER BY o.date DESC
      LIMIT ?
    ''', [productId, limit]);
    return result.map(OrderItem.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getOrderItemsWithDate(
      String productId, {int? withinDays}) async {
    final db = await database;

        String? dateFilter;
    String? dateBound;
    if (withinDays != null) {
      dateBound = DateTime.now().subtract(Duration(days: withinDays)).toIso8601String();
      dateFilter = " AND o.date >= ?";
    } else if (limit == null) {
      dateBound = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      dateFilter = " AND o.date >= ?";
    } else {
      dateFilter = null;
      dateBound = null;
    }

    String sql = "SELECT oi.stockBefore, oi.orderedQty, o.date FROM order_items oi JOIN orders o ON oi.orderId = o.id WHERE oi.productId = ?";
    if (dateFilter != null) sql += dateFilter;
    sql += " ORDER BY o.date DESC";
    if (limit != null) sql += " LIMIT ?";

    final args = <dynamic>[productId];
    if (dateBound != null) args.add(dateBound);
    if (limit != null) args.add(limit);
    return await db.rawQuery(sql, args);
  }

  /// 返回指定产品的所有订单项（无时间过滤）
  Future<List<Map<String, dynamic>>> getOrderItemsWithDateAll(
      String productId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT oi.stockBefore, oi.orderedQty, o.date
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      WHERE oi.productId = ?
      ORDER BY o.date DESC
    ''', [productId]);
  }

  /// 返回指定天内所有订单项
  Future<List<Map<String, dynamic>>> getOrderItemsWithinDays({
    required String productId,
    required int days,
  }) async =>
      getOrderItemsWithDate(productId, withinDays: days);

  Future<List<OrderRecord>> getAllOrders() async {
    final db = await database;
    final result = await db.query('orders', orderBy: 'date DESC');
    return result.map(OrderRecord.fromMap).toList();
  }

  Future<List<OrderItem>> getAllOrderItems() async {
    final db = await database;
    final result = await db.query('order_items', orderBy: 'id ASC');
    return result.map(OrderItem.fromMap).toList();
  }

  Future<List<StockAdjustment>> getAllStockAdjustments() async {
    final db = await database;
    final result =
        await db.query('stock_adjustments', orderBy: 'date DESC, id DESC');
    return result.map(StockAdjustment.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getAllOrderHistoryRows() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        o.id AS orderId,
        o.date,
        oi.productId,
        oi.stockBefore,
        oi.orderedQty,
        p.name,
        p.aamsCode,
        p.type
      FROM orders o
      JOIN order_items oi ON oi.orderId = o.id
      LEFT JOIN products p ON p.id = oi.productId
      ORDER BY o.date DESC, oi.id ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getOrderDetails(String orderId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        oi.id,
        oi.orderId,
        oi.productId,
        oi.stockBefore,
        oi.orderedQty,
        p.name,
        p.aamsCode,
        p.barcode
      FROM order_items oi
      LEFT JOIN products p ON oi.productId = p.id
      WHERE oi.orderId = ?
      ORDER BY p.name ASC
    ''', [orderId]);
  }

  Future<void> deleteOrder(String orderId) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('order_items', where: 'orderId = ?', whereArgs: [orderId]);
    batch.delete('orders', where: 'id = ?', whereArgs: [orderId]);
    await batch.commit(noResult: true);
  }

  // ─── 库存调整 ───

  Future<void> insertStockAdjustment(StockAdjustment item) async {
    final db = await database;
    await db.insert('stock_adjustments', item.toMap());
  }

  Future<int> getAdjustmentCount({
    required String productId,
    required int days,
  }) async {
    final db = await database;
    final fromDate =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM stock_adjustments
      WHERE productId = ? AND date >= ?
    ''', [productId, fromDate]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getAdjustmentTotal({
    required String productId,
    required int days,
  }) async {
    final db = await database;
    final fromDate =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) as total
      FROM stock_adjustments
      WHERE productId = ? AND date >= ?
    ''', [productId, fromDate]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // ─── 批量替换（导入/恢复） ───

  Future<void> replaceAllProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('products');
    for (final p in products) {
      batch.insert('products', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceBackupData({
    required List<Product> products,
    required List<OrderRecord> orders,
    required List<OrderItem> orderItems,
    required List<StockAdjustment> stockAdjustments,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('stock_adjustments');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('products');

      // 使用批量插入提高性能
      final productBatch = txn.batch();
      for (final product in products) {
        productBatch.insert('products', product.toMap());
      }
      await productBatch.commit(noResult: true);

      final orderBatch = txn.batch();
      for (final order in orders) {
        orderBatch.insert('orders', order.toMap());
      }
      await orderBatch.commit(noResult: true);

      final itemBatch = txn.batch();
      for (final item in orderItems) {
        itemBatch.insert('order_items', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await itemBatch.commit(noResult: true);

      final adjBatch = txn.batch();
      for (final adjustment in stockAdjustments) {
        adjBatch.insert('stock_adjustments', adjustment.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await adjBatch.commit(noResult: true);
    });
  }
}
