import 'package:flutter/material.dart';

import '../models/order_item.dart';
import '../models/product.dart';
import '../services/ai_order_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/stats_service.dart';
import 'dart:async';
import 'scan_page.dart';

class OrderStatsPage extends StatefulWidget {
  final List<Product> products;

  const OrderStatsPage({super.key, required this.products});

  @override
  State<OrderStatsPage> createState() => _OrderStatsPageState();
}

class _OrderStatsPageState extends State<OrderStatsPage> {
  bool loading = true;
  Map<String, ProductStats> statsMap = {};
  final Map<String, GlobalKey> _cardKeys = {};
  String? _highlightedProductId;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _initCardKeys();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final temp = <String, ProductStats>{};
    final leadTimeDays = await SettingsService.getArrivalLeadDays();
    final cycleCount = await SettingsService.getStatsCycleCount();

    for (final product in widget.products) {
      final recent20 =
          await DatabaseService.instance.getOrderItemsWithDate(product.id, limit: cycleCount);
      final allRows =
          await DatabaseService.instance.getOrderItemsWithDateAll(product.id);
      final rows30 = await DatabaseService.instance.getOrderItemsWithinDays(
        productId: product.id,
        days: 30,
      );
      final rows90 = await DatabaseService.instance.getOrderItemsWithinDays(
        productId: product.id,
        days: 90,
      );

      final adjustmentCount30 = await DatabaseService.instance.getAdjustmentCount(
        productId: product.id,
        days: 30,
      );

      final adjustmentTotal30 = await DatabaseService.instance.getAdjustmentTotal(
        productId: product.id,
        days: 30,
      );

      temp[product.id] = _buildStatsFromRows(
        product: product,
        recent20Rows: recent20,
        allRows: allRows,
        rows30: rows30,
        rows90: rows90,
        adjustmentCount30: adjustmentCount30,
        adjustmentTotal30: adjustmentTotal30,
        leadTimeDays: leadTimeDays,
      );
    }

    if (!mounted) return;
    setState(() {
      statsMap = temp;
      loading = false;
    });
  }

  ProductStats _buildStatsFromRows({
    required Product product,
    required List<Map<String, dynamic>> recent20Rows,
    required List<Map<String, dynamic>> allRows,
    required List<Map<String, dynamic>> rows30,
    required List<Map<String, dynamic>> rows90,
    required int adjustmentCount30,
    required int adjustmentTotal30,
    required int leadTimeDays,
  }) {
    final recent20Items = _rowsToOrderItems(product.id, recent20Rows);
    final recent20Dates = _rowsToDates(recent20Rows);

    final salesList = StatsService.calculateSalesList(recent20Items);
    final cycleDays = _calculateCycleDays(recent20Dates);

    final avgPerCycle = StatsService.avg(salesList);
    final avgDaysPerCycle = StatsService.avg(cycleDays, defaultValue: 7);
    final avgPerWeek = StatsService.weeklySales(
      avgPerCycle: avgPerCycle,
      avgDaysPerCycle: avgDaysPerCycle,
    );
    final avgPerDay = StatsService.dailySales(
      avgPerCycle: avgPerCycle,
      avgDaysPerCycle: avgDaysPerCycle,
    );
    final totalSales = StatsService.total(salesList);

    final aiSuggestedOrder = AiOrderService.suggestOrderQty(
      avgSales: avgPerCycle,
      currentStock: product.currentStock,
      safetyStock: product.safetyStock,
      avgDaysPerCycle: avgDaysPerCycle,
      leadTimeDays: leadTimeDays,
      lowReserveStreak: _calculateLowReserveStreak(
        currentStock: product.currentStock,
        safetyStock: product.safetyStock,
        rows: recent20Rows,
      ),
    );

    final sales30 = StatsService.calculateSalesList(
      _rowsToOrderItems(product.id, rows30),
    );
    final sales90 = StatsService.calculateSalesList(
      _rowsToOrderItems(product.id, rows90),
    );

    return ProductStats(
      avgPerCycle: avgPerCycle,
      avgPerWeek: avgPerWeek,
      avgPerDay: avgPerDay,
      totalSales: totalSales,
      avgDaysPerCycle: avgDaysPerCycle,
      aiSuggestedOrder: aiSuggestedOrder,
      sold30Days: StatsService.total(sales30),
      sold90Days: StatsService.total(sales90),
      adjustmentCount30: adjustmentCount30,
      adjustmentTotal30: adjustmentTotal30,
      stockoutCount: _countStockouts(allRows),
    );
  }

  List<OrderItem> _rowsToOrderItems(
    String productId,
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map((row) {
      return OrderItem(
        orderId: '',
        productId: productId,
        stockBefore: row['stockBefore'] ?? 0,
        orderedQty: row['orderedQty'] ?? 0,
      );
    }).toList();
  }

  List<DateTime> _rowsToDates(List<Map<String, dynamic>> rows) {
    return rows.map((row) => DateTime.parse(row['date'])).toList();
  }

  List<double> _calculateCycleDays(List<DateTime> dates) {
    if (dates.length < 2) return [];

    final days = <double>[];
    for (int i = 0; i < dates.length - 1; i++) {
      final newer = dates[i];
      final older = dates[i + 1];
      final diff = newer.difference(older).inDays.abs();
      if (diff > 0) {
        days.add(diff.toDouble());
      }
    }
    return days;
  }

  int _countStockouts(List<Map<String, dynamic>> rows) {
    int count = 0;
    for (final row in rows) {
      final stockBefore = row['stockBefore'] ?? 0;
      if (stockBefore <= 0) count++;
    }
    return count;
  }

  int _calculateLowReserveStreak({
    required int currentStock,
    required int safetyStock,
    required List<Map<String, dynamic>> rows,
  }) {
    if (safetyStock <= 0) return 0;

    int streak = currentStock < safetyStock ? 1 : 0;
    for (final row in rows.take(3)) {
      final stockBefore = row['stockBefore'] ?? 0;
      if (stockBefore < safetyStock) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override

  void _initCardKeys() {
    final sortedByWeek = [...widget.products];
    sortedByWeek.sort((a, b) {
      final aWeek = statsMap[a.id]?.avgPerWeek ?? 0;
      final bWeek = statsMap[b.id]?.avgPerWeek ?? 0;
      return bWeek.compareTo(aWeek);
    });
    for (final p in sortedByWeek) {
      _cardKeys[p.id] = GlobalKey();
    }
  }

  Future<void> _scanAndJump() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    // Find product by barcode
    final matched = widget.products.cast<Product?>().firstWhere(
      (p) => p!.barcode == code,
      orElse: () => null,
    );
    if (matched == null) {
      if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到条码 \ 对应的商品')),
        );
      return;
    }

    setState(() => _highlightedProductId = matched.id);

    // Scroll to the highlighted item
    final key = _cardKeys[matched.id];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        alignment: 0.3,
      );
    }

    // Clear highlight after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedProductId = null);
    });
   }

  Widget build(BuildContext context) {
    final sortedByWeek = [...widget.products];
    sortedByWeek.sort((a, b) {
      final aWeek = statsMap[a.id]?.avgPerWeek ?? 0;
      final bWeek = statsMap[b.id]?.avgPerWeek ?? 0;
      return bWeek.compareTo(aWeek);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('涓嬪崟缁熻'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '鎵爜璺宠浆',
            onPressed: _scanAndJump,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: sortedByWeek.map((product) {
                final stats = statsMap[product.id];
                if (stats == null) {
                  return const SizedBox.shrink();
                }

                final isHighlighted = _highlightedProductId == product.id;
                return Container(
                  key: _cardKeys[product.id],
                  child: Card(
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text(product.name),
                      subtitle: Text(
                        '骞冲潎姣忓懆鏈熼攢閲? ${stats.avgPerCycle.toStringAsFixed(1)}\n'
                        '骞冲潎姣忓懆閿€閲? ${stats.avgPerWeek.toStringAsFixed(1)}\n'
                        '鏃ュ潎閿€閲? ${stats.avgPerDay.toStringAsFixed(2)}\n'
                        '杩?0澶╅攢閲? ${stats.sold30Days.toStringAsFixed(1)}\n'
                        '杩?0澶╅攢閲? ${stats.sold90Days.toStringAsFixed(1)}\n'
                        '杩?0澶╄皟鏁存鏁? ${stats.adjustmentCount30}\n'
                        '杩?0澶╄皟鏁存€婚噺: ${stats.adjustmentTotal30}\n'
                        '缂鸿揣娆℃暟: ${stats.stockoutCount}\n'
                        '寤鸿璁㈣揣閲? ${stats.aiSuggestedOrder}',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class ProductStats {
  final double avgPerCycle;
  final double avgPerWeek;
  final double avgPerDay;
  final double totalSales;
  final double avgDaysPerCycle;
  final int aiSuggestedOrder;
  final double sold30Days;
  final double sold90Days;
  final int adjustmentCount30;
  final int adjustmentTotal30;
  final int stockoutCount;

  ProductStats({
    required this.avgPerCycle,
    required this.avgPerWeek,
    required this.avgPerDay,
    required this.totalSales,
    required this.avgDaysPerCycle,
    required this.aiSuggestedOrder,
    required this.sold30Days,
    required this.sold90Days,
    required this.adjustmentCount30,
    required this.adjustmentTotal30,
    required this.stockoutCount,
  });
}
