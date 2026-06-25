import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_item.dart';
import '../models/order_record.dart';
import '../models/product.dart';
import '../services/ai_order_service.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../services/accessibility_bridge.dart';
import 'manual_order_page.dart';
import 'product_edit_page.dart';
import 'quick_add_page.dart';
import 'scan_page.dart';

class OrderPage extends StatefulWidget {
  final List<Product> products;

  const OrderPage({super.key, required this.products});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  /// Logista 在线订烟链接
  static final Uri _logistaOrderUri =
      Uri.parse('https://webt.logistaitalia.it/Ordine');
  /// 草稿版本号，用于判断草稿兼容性
  static const String _draftVersion = 'v1';
  /// 订单利润比例（10%）
  static const double _profitRate = 0.10;
  /// 非烟草固体类型名称（用于特殊计算）
  static const String _solidNonTobaccoType =
      'PRODOTTI SENZA COMBUSTIONE - SOLIDI DIVERSI DA TABACCO';
  /// 其他烟草类型列表（用于排序）
  static const List<String> _tabaccoTypes = [
    'ALTRI TABACCHI DA FUMO',
    'TRINCIATI PER SIGARETTE',
    'FIUTI E MASTICO',
  ];

  /// 排序后的待订烟商品列表
  late final List<Product> orderedProducts;

  /// 当前查看的商品索引
  int currentIndex = 0;
  /// 是否正在加载中
  bool loading = true;
  /// 是否正在程序化更新字段（避免触发 onChanged 重算）
  bool _isProgrammaticFieldUpdate = false;

  /// 当前库存输入框控制器
  final stockController = TextEditingController();
  /// 最终订货量输入框控制器
  final orderQtyController = TextEditingController();
  /// 库存输入焦点
  final stockFocusNode = FocusNode();
  /// 订货量输入焦点
  final orderQtyFocusNode = FocusNode();

  /// 各商品的盘点库存映射（productId → stock）
  final Map<String, int> countedStock = {};
  /// 各商品的最终订货量映射（productId → qty）
  final Map<String, int> finalOrderQty = {};
  /// 手动添加的待处理订烟项列表
  final List<ManualOrderItem> _pendingManualItems = [];

  /// 当前商品平均销量/周期需求（合并）
  double currentAvgSales = 0;
  /// 当前商品的平均订货周期天数
  double currentAvgDaysPerCycle = 7;
  /// 每日卖出量
  double currentDailySales = 0;
  /// 预计一周消耗量
  double currentWeeklyDemand = 0;
  /// 一周后预计剩余库存
  double currentProjectedRemainingAfterWeek = 0;
  /// 当前商品建议订货量
  int currentSuggestedOrder = 0;
  /// 当前商品建议预留库存
  int currentSuggestedReserve = 0;
  /// 到货等待天数
  int arrivalLeadDays = 5;
  /// 连续库存不足历史记录次数
  int currentLowReserveHistoryCount = 0;
 /// 获取当前商品对象
 Product get currentProduct => orderedProducts[currentIndex];
  /// 长按快速导航是否启用
  bool _longPressNavigationEnabled = true;
  /// 长按定时器
  Timer? _holdTimer;
  /// 是否正在长按重复中
  bool _isHolding = false;
  /// 长按重复次数（用于加速）
  int _holdStepCount = 0;

 /// 获取商品类型的排序优先级，用于将商品按类型分组排序
 int _typePriority(String type) {
    final normalizedType = type.trim().toUpperCase();
    if (normalizedType == 'SIGARETTE') return 0;
    if (normalizedType == 'TABACCO SENZA COMBUSTIONE') return 1;
    if (_tabaccoTypes.contains(normalizedType)) return 2;
    if (normalizedType == 'SIGARI' || normalizedType == 'SIGARETTI') return 3;
    return 4;
  }

  @override
  void initState() {
    super.initState();
    orderedProducts = [...widget.products]
      ..sort((a, b) {
        final typeCompare = _typePriority(a.type).compareTo(_typePriority(b.type));
        if (typeCompare != 0) return typeCompare;
        final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (nameCompare != 0) return nameCompare;
        return a.id.compareTo(b.id);
      });
    stockController.addListener(_handleDraftChanged);
    orderQtyController.addListener(_handleDraftChanged);
    stockFocusNode.addListener(() {
      if (stockFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !stockFocusNode.hasFocus) return;
          _selectAllStockText();
        });
      } else {
        _restoreStockIfEmpty();
      }
    });
    orderQtyFocusNode.addListener(() {
      if (orderQtyFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !orderQtyFocusNode.hasFocus) return;
          _selectAllOrderQtyText();
        });
      } else {
        _restoreOrderQtyIfEmpty();
      }
    });
   _restoreDraftAndLoad();
    _loadLongPressSetting();
 }

  Future<void> _loadLongPressSetting() async {
    final enabled = await SettingsService.getLongPressNavigation();
    if (mounted) {
      setState(() => _longPressNavigationEnabled = enabled);
    }
  }

 /// 获取当前商品列表的唯一标识签名（用于草稿校验）
  String get _productSignature => orderedProducts.map((p) => p.id).join('|');

  /// 草稿变更回调：非程序化更新时自动保存草稿
  void _handleDraftChanged() {
    if (orderedProducts.isEmpty || _isProgrammaticFieldUpdate) return;
    _saveDraft();
  }

  void _selectAllStockText() {
    stockController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: stockController.text.length,
    );
  }

  void _selectAllOrderQtyText() {
    orderQtyController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: orderQtyController.text.length,
    );
  }

  /// 库存输入框为空时恢复为已有盘点值或系统库存
  void _restoreStockIfEmpty() {
    if (stockController.text.trim().isNotEmpty || orderedProducts.isEmpty) return;
    final fallback = countedStock[currentProduct.id] ?? currentProduct.currentStock;
    stockController.text = fallback.toString();
  }

  /// 订货量输入框为空时恢复为已有订货值或当前建议订货量
  void _restoreOrderQtyIfEmpty() {
    if (orderQtyController.text.trim().isNotEmpty || orderedProducts.isEmpty) return;
    final fallback = finalOrderQty[currentProduct.id] ?? currentSuggestedOrder;
    orderQtyController.text = fallback.toString();
  }

  /// 构建草稿数据，包含版本号、商品签名、当前索引及所有输入
  Map<String, dynamic> _buildDraft() {
    if (orderedProducts.isNotEmpty) {
      countedStock[currentProduct.id] =
          int.tryParse(stockController.text.trim()) ?? 0;
      finalOrderQty[currentProduct.id] =
          int.tryParse(orderQtyController.text.trim()) ?? 0;
    }
    return {
      'version': _draftVersion,
      'productSignature': _productSignature,
      'currentIndex': currentIndex,
      'countedStock': countedStock,
      'finalOrderQty': finalOrderQty,
    };
  }

  /// 保存当前草稿到本地存储
  Future<void> _saveDraft() => SettingsService.saveOrderDraft(_buildDraft());

  /// 从本地存储恢复草稿并加载当前商品数据
  Future<void> _restoreDraftAndLoad() async {
    final draft = await SettingsService.getOrderDraft();
    if (draft != null &&
        draft['version'] == _draftVersion &&
        draft['productSignature'] == _productSignature) {
      final savedIndex = draft['currentIndex'];
      if (savedIndex is int && savedIndex >= 0 && savedIndex < orderedProducts.length) {
        currentIndex = savedIndex;
      }
      final savedStock = draft['countedStock'];
      if (savedStock is Map) {
        countedStock.addAll(savedStock.map((key, value) => MapEntry(
          key.toString(),
          value is int ? value : int.tryParse(value.toString()) ?? 0,
        )));
      }
      final savedOrderQty = draft['finalOrderQty'];
      if (savedOrderQty is Map) {
        finalOrderQty.addAll(savedOrderQty.map((key, value) => MapEntry(
          key.toString(),
          value is int ? value : int.tryParse(value.toString()) ?? 0,
        )));
      }
    }
    await _loadCurrentProductAdvice();
  }

  Future<bool> _ensureStoragePermission() async {
    var status = await Permission.storage.status;
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    if (status.isGranted) return true;
    var manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) return true;
    manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }

  /// 持久化当前输入到内存中的 countedStock 和 finalOrderQty
  void _persistCurrentInputs() {
    final product = currentProduct;
    countedStock[product.id] = int.tryParse(stockController.text.trim()) ?? 0;
    finalOrderQty[product.id] = int.tryParse(orderQtyController.text.trim()) ?? 0;
  }

  String _formatMoney(double value) => 'EUR ${value.toStringAsFixed(2)}';
  String _formatKg(double value) => '${value.toStringAsFixed(2)} kg';

  String _formatUnitWeightHint(Product product) {
    final grams = (product.unitWeight * 1000).round();
    return '1 条/件 = ${grams}g';
  }

  bool _isSolidNonTobacco(Product product) =>
      product.type.trim().toUpperCase() == _solidNonTobaccoType;

  double _resolveLineAmount(Product product, int qty, double lineKg) {
    final normalizedType = product.type.trim().toUpperCase();
    final kgPrice = product.kgPrice;
    final price = product.price;
    if (price != null && price > 0) {
      if (normalizedType == 'SIGARETTE') return qty * price * 10;
    }
    if (kgPrice != null && kgPrice > 0) return lineKg * kgPrice;
    if (price != null && price > 0) return qty * price;
    return 0;
  }

  _OrderSummary _buildOrderSummary() {
    double totalKg = 0, totalAmount = 0, solidNonTobaccoKg = 0, otherTobaccoKg = 0;
    for (final product in orderedProducts) {
      final qty = finalOrderQty[product.id] ?? 0;
      if (qty <= 0) continue;
      final lineKg = qty * product.unitWeight;
      totalKg += lineKg;
      totalAmount += _resolveLineAmount(product, qty, lineKg);
      if (_isSolidNonTobacco(product)) {
        solidNonTobaccoKg += lineKg;
      } else {
        otherTobaccoKg += lineKg;
      }
    }
    final profit = totalAmount * _profitRate;
    return _OrderSummary(
      totalKg: totalKg,
      solidNonTobaccoKg: solidNonTobaccoKg,
      otherTobaccoKg: otherTobaccoKg,
      totalAmount: totalAmount,
      profit: profit,
      payableAmount: totalAmount - profit,
    );
  }

  Future<bool> _showOrderSummaryBeforeSave() async {
    final summary = _buildOrderSummary();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('订单汇总',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow(label: '总重量', value: _formatKg(summary.totalKg)),
                        const SizedBox(height: 12),
                        _SummaryRow(label: '其他烟草', value: _formatKg(summary.otherTobaccoKg)),
                        const SizedBox(height: 12),
                        _SummaryRow(label: '非烟草固体', value: _formatKg(summary.solidNonTobaccoKg)),
                        const SizedBox(height: 12),
                        _SummaryRow(label: '总金额', value: _formatMoney(summary.totalAmount)),
                        const SizedBox(height: 12),
                        _SummaryRow(label: '利润（10%）', value: _formatMoney(summary.profit)),
                        const Divider(height: 24),
                        _SummaryRow(label: '应付金额', value: _formatMoney(summary.payableAmount), emphasized: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('返回'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确认保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  /// 当用户手动修改库存时重新计算建议订货量并自动填入订货量输入框
  void _recalculateSuggestedOrder() {
    if (_isProgrammaticFieldUpdate) return;
    final stock = int.tryParse(stockController.text.trim()) ?? 0;
    final lowReserveStreak =
        (stock < currentProduct.safetyStock ? 1 : 0) + currentLowReserveHistoryCount;
    final safeCycleDays = currentAvgDaysPerCycle <= 0 ? 7 : currentAvgDaysPerCycle;
    final dailySales = currentAvgSales <= 0 ? 0 : currentAvgSales / safeCycleDays;
    final weeklyDemand = dailySales * 7;
    final projectedRemainingAfterWeek = stock - weeklyDemand;
    final suggestedOrder = AiOrderService.suggestOrderQty(
      avgSales: currentAvgSales,
      currentStock: stock,
      safetyStock: currentProduct.safetyStock,
      avgDaysPerCycle: currentAvgDaysPerCycle,
      leadTimeDays: arrivalLeadDays,
      lowReserveStreak: lowReserveStreak,
    );
    orderQtyController.text = suggestedOrder.toString();
    setState(() {
      currentDailySales = dailySales.toDouble();
      currentWeeklyDemand = weeklyDemand.toDouble();
      currentProjectedRemainingAfterWeek = projectedRemainingAfterWeek.toDouble();
      currentSuggestedOrder = suggestedOrder;
    });
  }

  /// 加载当前商品的分析数据：平均销量、建议库存、建议订货量等
  Future<void> _loadCurrentProductAdvice() async {
    setState(() => loading = true);
    final product = currentProduct;
    final rows = await DatabaseService.instance.getOrderItemsWithDate(product.id);
    final history = _rowsToOrderItems(product.id, rows);
    final dates = _rowsToDates(rows);
    final leadDays = await SettingsService.getArrivalLeadDays();
    final avgSales = AiOrderService.calculateAverageSales(history);
    final suggestedReserve = AiOrderService.suggestSafetyStock(avgSales: avgSales, items: history);
    final avgDaysPerCycle = _calculateAverageCycleDays(dates);
    final currentStock = countedStock[product.id] ?? product.currentStock;
    final lowReserveHistoryCount = _calculateLowReserveHistoryCount(
      safetyStock: product.safetyStock, rows: rows,
    );
    final lowReserveStreak =
        (currentStock < product.safetyStock ? 1 : 0) + lowReserveHistoryCount;
    final safeCycleDays = avgDaysPerCycle <= 0 ? 7 : avgDaysPerCycle;
    final dailySales = avgSales <= 0 ? 0 : avgSales / safeCycleDays;
    final weeklyDemand = dailySales * 7;
    final projectedRemainingAfterWeek = currentStock - weeklyDemand;
    final suggestedOrder = AiOrderService.suggestOrderQty(
      avgSales: avgSales,
      currentStock: currentStock,
      safetyStock: product.safetyStock,
      avgDaysPerCycle: avgDaysPerCycle,
      leadTimeDays: leadDays,
      lowReserveStreak: lowReserveStreak,
    );

    _isProgrammaticFieldUpdate = true;
    try {
      stockController.text = currentStock.toString();
      orderQtyController.text = (finalOrderQty[product.id] ?? 0).toString();
    } finally {
      _isProgrammaticFieldUpdate = false;
    }

    if (!mounted) return;
    setState(() {
      currentAvgSales = avgSales;
      currentAvgDaysPerCycle = avgDaysPerCycle;
      currentDailySales = dailySales.toDouble();
      currentWeeklyDemand = weeklyDemand.toDouble();
      currentProjectedRemainingAfterWeek = projectedRemainingAfterWeek.toDouble();
      currentSuggestedOrder = suggestedOrder;
      currentSuggestedReserve = suggestedReserve;
      arrivalLeadDays = leadDays;
      currentLowReserveHistoryCount = lowReserveHistoryCount;
      loading = false;
    });
  }

  List<OrderItem> _rowsToOrderItems(String productId, List<Map<String, dynamic>> rows) =>
      rows.map((row) => OrderItem(
        orderId: '', productId: productId,
        stockBefore: row['stockBefore'] ?? 0,
        orderedQty: row['orderedQty'] ?? 0,
      )).toList();

  List<DateTime> _rowsToDates(List<Map<String, dynamic>> rows) =>
      rows.map((row) => DateTime.parse(row['date'])).toList();

  double _calculateAverageCycleDays(List<DateTime> dates) {
    if (dates.length < 2) return 7;
    final days = <double>[];
    for (int i = 0; i < dates.length - 1; i++) {
      final diff = dates[i].difference(dates[i + 1]).inDays.abs();
      if (diff > 0) days.add(diff.toDouble());
    }
    if (days.isEmpty) return 7;
    return days.reduce((a, b) => a + b) / days.length;
  }

  int _calculateLowReserveHistoryCount({
    required int safetyStock, required List<Map<String, dynamic>> rows,
  }) {
    if (safetyStock <= 0) return 0;
    int streak = 0;
    for (final row in rows.take(3)) {
      final stockBefore = row['stockBefore'] ?? 0;
      if (stockBefore < safetyStock) { streak++; } else { break; }
    }
    return streak;
  }

  Future<bool> _confirmLargeOrderIfNeeded(int orderedQty) async {
    final threshold = await SettingsService.getLargeOrderThreshold();
    if (orderedQty <= threshold) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('订货量过高提醒'),
        content: Text('当前输入的订货量为 $orderedQty，已经超过阈值 $threshold，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('返回修改')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认继续')),
        ],
      ),
    );
   return result ?? false;
 }

  /// 长按"上一个"/"下一个"按钮时的按下事件
  void _handleDown(bool isPrevious) {
    // 如果是第一个商品的上一个或最后一个商品的下一个，不处理
    if (isPrevious && currentIndex <= 0) return;
    if (!isPrevious && currentIndex >= orderedProducts.length - 1) return;

    _isHolding = false;
    _holdStepCount = 0;
    // 400ms 初始延迟后开始重复
    _holdTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _isHolding = true;
      _doHoldStep(isPrevious);
    });
  }

  /// 长按按钮的释放事件
  void _handleUp(bool isPrevious) async {
    _holdTimer?.cancel();

    if (_isHolding) {
      // 长按结束，加载完整数据
      _isHolding = false;
      await _loadCurrentProductAdvice();
    } else {
      // 短按 — 正常切换
      if (isPrevious && currentIndex > 0) {
        await _previousProduct();
      } else if (!isPrevious) {
        await _nextProduct();
      }
    }
  }

  /// 长按取消（移出按钮区域）
  void _handleCancel() {
    _holdTimer?.cancel();
    if (_isHolding) {
      _isHolding = false;
    }
  }

  /// 执行长按重复步骤（轻量切换，不加载完整数据分析）
  void _doHoldStep(bool isPrevious) {
    if (!mounted) return;

    final newIndex = currentIndex + (isPrevious ? -1 : 1);
    if (newIndex < 0 || newIndex >= orderedProducts.length) {
      _isHolding = false;
      return;
    }

    // 保存当前输入
    _persistCurrentInputs();
    setState(() {
      currentIndex = newIndex;
      loading = false; // 不显示加载转圈
    });

    // 从内存快速更新文本控件
    final product = currentProduct;
    final stock = countedStock[product.id] ?? product.currentStock;
    final orderQty = finalOrderQty[product.id] ?? 0;

    _isProgrammaticFieldUpdate = true;
    stockController.text = stock.toString();
    orderQtyController.text = orderQty.toString();
    _isProgrammaticFieldUpdate = false;

    _holdStepCount++;
    final delay = _calculateHoldDelay(_holdStepCount);
    _holdTimer = Timer(Duration(milliseconds: delay), () => _doHoldStep(isPrevious));
  }

  /// 计算当前长按重复次数的延迟（逐渐加速）
  int _calculateHoldDelay(int step) {
    if (step <= 3) return 300;   // 第1~3步：300ms
    if (step <= 8) return 180;   // 第4~8步：180ms
    if (step <= 15) return 100;  // 第9~15步：100ms
    return 60;                   // 之后保持 60ms
  }

 /// 切换到上一个商品，保存当前输入后加载新商品数据
 Future<void> _previousProduct() async {
    if (currentIndex <= 0) return;
    _persistCurrentInputs();
    await _saveDraft();
    setState(() => currentIndex--);
    await _loadCurrentProductAdvice();
  }

  /// 跳转到编辑当前商品（可启用/禁用）
  Future<void> _editCurrentProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditPage(product: currentProduct),
      ),
    );
    // 重新加载商品列表以反映启用/禁用状态变更
    if (!mounted) return;
    setState(() {
      // 更新 orderedProducts 中对应商品的 isActive 状态
      // 由于 widget.products 中的引用已更新，重新排序并刷新
    });
  }

  /// 打开快速添加页面，搜索商品并添加到当前订单
  Future<void> _quickAddProduct() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QuickAddPage()),
    );
    if (!mounted || result == null) return;

    final productId = result['productId'] as String;
    final quantity = result['quantity'] as int;

    // 累加到最终订货量
    finalOrderQty[productId] = (finalOrderQty[productId] ?? 0) + quantity;

    // 如果当前正在查看该商品，更新输入框显示
    if (currentProduct.id == productId) {
      orderQtyController.text = finalOrderQty[productId].toString();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加: ${result['productName']} x $quantity')),
    );
  }

  /// 扫描条码并跳转到对应商品，未找到时显示提示
  Future<void> _scanAndJump() async {
    final barcode = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;
    final index = orderedProducts.indexWhere((p) => p.barcode.trim() == barcode.trim());
    if (index < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未找到条码 "$barcode" 对应的商品')),
      );
      return;
    }
    if (index == currentIndex) return;
    _persistCurrentInputs();
    await _saveDraft();
    setState(() => currentIndex = index);
    await _loadCurrentProductAdvice();
  }

  /// 切换到下一个商品或保存订单（最后一个商品→汇总→手动添加→完成订单）
  Future<void> _nextProduct() async {
    final stock = int.tryParse(stockController.text.trim()) ?? 0;
    final orderedQty = int.tryParse(orderQtyController.text.trim()) ?? 0;
    if (stock < 0 || orderedQty < 0) return;
    final confirmed = await _confirmLargeOrderIfNeeded(orderedQty);
    if (!confirmed) return;
    _persistCurrentInputs();
    await _saveDraft();
    if (currentIndex < orderedProducts.length - 1) {
      setState(() => currentIndex++);
      await _loadCurrentProductAdvice();
    } else {
      if (!await _showOrderSummaryBeforeSave()) return;
      await _finishOrder();
    }
  }

  /// 尝试启动辅助功能自动化（如果已启用）
  Future<void> _tryStartAutomation() async {
    try {
      final enabled = await SettingsService.getAutoEnabled();
      if (!enabled) return;
      final stepsStr = await SettingsService.getAutoSteps();
      if (stepsStr.isEmpty) return;
      final decoded = jsonDecode(stepsStr) as List;
      final steps = decoded.map((e) => AutomationStep.fromMap(e as Map<String, dynamic>)).toList();
      if (steps.isEmpty) return;
      await AccessibilityBridge.startAutomation(steps: steps);
    } catch (_) {
    }
  }

  /// 删除当前订单草稿（需二次确认）
  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订单'),
        content: const Text('确定要删除当前订单草稿吗？所有已输入的盘点库存和订货量都将丢失，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SettingsService.clearOrderDraft();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// 完成订单：导出 Excel → 更新库存 → 保存订单记录 → 清除草稿 → 打开 Logista
  Future<void> _finishOrder() async {
    if (!await _ensureStoragePermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先授予存储权限后再导出 Excel')),
      );
      return;
    }
    String? finalPath = await SettingsService.getPath();
    if (finalPath == null || finalPath.trim().isEmpty) {
      finalPath = await FilePicker.platform.getDirectoryPath();
      if (finalPath != null && finalPath.trim().isNotEmpty) {
        await SettingsService.savePath(finalPath);
      }
    }
    if (!mounted) return;
    if (finalPath == null || finalPath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择 Excel 保存目录')),
      );
      return;
    }
    _persistCurrentInputs();

    // 合并手动添加的商品到商品列表
    final allProducts = List<Product>.from(orderedProducts);
    for (final item in _pendingManualItems) {
      if (!allProducts.any((p) => p.aamsCode == item.aamsCode)) {
        allProducts.add(Product(
          id: item.aamsCode,
          name: item.productName ?? item.aamsCode,
          aamsCode: item.aamsCode, type: '',
          currentStock: 0, safetyStock: 0, unitWeight: 1.0, barcode: '',
        ));
        finalOrderQty[item.aamsCode] = (finalOrderQty[item.aamsCode] ?? 0) + item.quantity;
      }
    }

    String? excelPath;
    try {
      excelPath = await ExcelService.generateLogistaExcel(allProducts, finalOrderQty, finalPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel 导出失败：$e')));
      return;
    }
    if (!mounted || excelPath == null || excelPath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel 导出失败')));
      return;
    }

    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final order = OrderRecord(id: orderId, date: DateTime.now().toIso8601String());
    final items = <OrderItem>[];

    for (final product in orderedProducts) {
      final stockBefore = countedStock[product.id] ?? product.currentStock;
      final orderedQty = finalOrderQty[product.id] ?? 0;
      product.currentStock = stockBefore + orderedQty;
      await DatabaseService.instance.updateProduct(product);
      items.add(OrderItem(orderId: orderId, productId: product.id, stockBefore: stockBefore, orderedQty: orderedQty));
    }
    await DatabaseService.instance.insertOrder(order, items);
    await SettingsService.clearOrderDraft();

    final launched = await launchUrl(_logistaOrderUri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel 已保存：$excelPath')));
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未能自动打开下单网页')));
    }
    // 如果启用了辅助功能自动化，开始执行预设步骤
    _tryStartAutomation();

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
 void dispose() {
    _holdTimer?.cancel();
   stockController.removeListener(_handleDraftChanged);
    orderQtyController.removeListener(_handleDraftChanged);
    stockFocusNode.dispose();
    orderQtyFocusNode.dispose();
    stockController.dispose();
   orderQtyController.dispose();
   super.dispose();
 }
  /// 构建支持长按加速的导航按钮
  Widget _buildHoldNavButton({
    required bool isPrevious,
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    final enabled = isPrevious ? currentIndex > 0 : currentIndex < orderedProducts.length - 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: enabled ? bgColor : bgColor.withValues(alpha: 0.4),
        child: InkWell(
          onTapDown: enabled ? (_) => _handleDown(isPrevious) : null,
          onTapUp: enabled ? (_) => _handleUp(isPrevious) : null,
          onTapCancel: _handleCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: enabled ? fgColor : fgColor.withValues(alpha: 0.4), size: 20),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: enabled ? fgColor : fgColor.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }

 @override
 Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (orderedProducts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('下单')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('暂无可下单商品', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    final product = currentProduct;

    return Scaffold(
      appBar: AppBar(
        title: Text('下单 (${currentIndex + 1}/${orderedProducts.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '快速添加',
            onPressed: _quickAddProduct,
          ),
           IconButton(
             icon: const Icon(Icons.qr_code_scanner),
             tooltip: '扫码跳转',
             onPressed: _scanAndJump,
           ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除订单',
            onPressed: _deleteOrder,
          ),
          ],
        ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 商品信息卡片（点击进入编辑）
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _editCurrentProduct,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.smoking_rooms, color: colorScheme.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('AAMS: ${product.aamsCode}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                  const SizedBox(height: 2),
                                  Text(_formatUnitWeightHint(product),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 信息指标行 — 更紧凑的长方形格子
                  Row(
                    children: [
                      Expanded(child: _CompactCard(icon: Icons.inventory, label: '当前库存', value: '${product.currentStock}', color: colorScheme.primary)),
                      const SizedBox(width: 6),
                      Expanded(child: _CompactCard(icon: Icons.shield_outlined, label: '预留库存', value: '${product.safetyStock}', color: Colors.orange)),
                      const SizedBox(width: 6),
                      Expanded(child: _CompactCard(icon: Icons.local_shipping, label: '到货天数', value: '$arrivalLeadDays', color: Colors.teal)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 销售分析卡片 — 更紧凑
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text('销售分析', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                            ],
                          ),
                          const Divider(height: 12),
                          _AnalysisRow(icon: Icons.today, label: '每日卖出量', value: currentDailySales.toStringAsFixed(2), color: Colors.green),
                          const SizedBox(height: 6),
                          _AnalysisRow(icon: Icons.weekend, label: '一周消耗量', value: currentWeeklyDemand.toStringAsFixed(2), color: Colors.orange),
                          const SizedBox(height: 6),
                          _AnalysisRow(
                            icon: Icons.inventory,
                            label: '周期后剩余库存',
                            value: currentProjectedRemainingAfterWeek.toStringAsFixed(2),
                            color: currentProjectedRemainingAfterWeek < 0 ? Colors.red : Colors.teal,
                          ),
                          const Divider(height: 12),
                          Row(
                            children: [
                              Expanded(child: _SuggestionBadge(label: '建议订货量', value: '$currentSuggestedOrder', color: colorScheme.primary)),
                              const SizedBox(width: 8),
                              Expanded(child: _SuggestionBadge(label: '建议预留库存', value: '$currentSuggestedReserve', color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 库存输入
                  Row(children: [Icon(Icons.inventory_2, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 6), Text('盘点库存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800))]),
                  const SizedBox(height: 4),
                  TextField(
                    controller: stockController,
                    focusNode: stockFocusNode,
                    onTap: _selectAllStockText,
                    onChanged: (_) => _recalculateSuggestedOrder(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '输入当前库存',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 订货量输入
                  Row(children: [Icon(Icons.add_shopping_cart, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 6), Text('订货数量', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800))]),
                  const SizedBox(height: 4),
                  TextField(
                    controller: orderQtyController,
                    focusNode: orderQtyFocusNode,
                    onTap: _selectAllOrderQtyText,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最终订货量（按条/件）',
                      prefixIcon: Icon(Icons.add_shopping_cart),
                      helperText: '修改库存后自动计算建议订货量',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 导航按钮 — 长按加速支持（可在设置中关闭）
                  Row(
                    children: [
                      // 上一个按钮
                      Expanded(
                        child: _longPressNavigationEnabled && currentIndex > 0
                            ? _buildHoldNavButton(
                                isPrevious: true,
                                icon: Icons.arrow_back,
                                label: '上一个',
                                bgColor: colorScheme.surfaceContainerHighest,
                                fgColor: colorScheme.onSurface,
                              )
                            : ElevatedButton.icon(
                                onPressed: currentIndex > 0 ? _previousProduct : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('上一个'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                  foregroundColor: colorScheme.onSurface,
                                  elevation: 0,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // 下一个 / 保存订单按钮
                      Expanded(
                        child: _longPressNavigationEnabled && currentIndex < orderedProducts.length - 1
                            ? _buildHoldNavButton(
                                isPrevious: false,
                                icon: Icons.arrow_forward,
                                label: '下一个',
                                bgColor: colorScheme.primary,
                                fgColor: colorScheme.onPrimary,
                              )
                            : ElevatedButton.icon(
                                onPressed: _nextProduct,
                                icon: Icon(currentIndex < orderedProducts.length - 1 ? Icons.arrow_forward : Icons.check),
                                label: Text(currentIndex < orderedProducts.length - 1 ? '下一个' : '保存订单'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _OrderSummary {
  const _OrderSummary({
    required this.totalKg, required this.solidNonTobaccoKg,
    required this.otherTobaccoKg, required this.totalAmount,
    required this.profit, required this.payableAmount,
  });
  final double totalKg, solidNonTobaccoKg, otherTobaccoKg, totalAmount, profit, payableAmount;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasized = false});
  final String label, value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Row(children: [
      Expanded(child: Text(label, style: style)),
      Text(value, style: style),
    ]);
  }
}

/// 更紧凑的长方形指标卡片（用于库存、预留、到货天数等）
class _CompactCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _CompactCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    ),
  );
}

/// 分析数据行（图标 + 标签 + 数值）
class _AnalysisRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _AnalysisRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 26, height: 26,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 14, color: color),
    ),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
  ]);
}

/// 建议值徽章（用于建议订货量/预留库存）— 更紧凑
class _SuggestionBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SuggestionBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
      ]),
    ),
  );
}

