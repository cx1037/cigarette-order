import '../models/order_item.dart';

class AiOrderService {
  /// 计算加权平均销量
  /// 根据库存变化计算每两笔订单之间的销量，最近一笔权重增加 15%
  /// [items] 按时间倒序排序的订单项列表（最新在前）
  /// 返回加权平均销量，不足2条数据返回0
  static double calculateAverageSales(List<OrderItem> items) {
    if (items.length < 2) return 0;

    final sorted = List<OrderItem>.from(items);
    List<double> sales = [];
    List<double> weights = [];

    for (int i = 0; i < sorted.length - 1; i++) {
      final newer = sorted[i];
      final older = sorted[i + 1];

      // 销量 = 上次库存 + 上次订烟量 - 本次库存
      final sale = older.stockBefore + older.orderedQty - newer.stockBefore;

      if (sale >= 0) {
        sales.add(sale.toDouble());
        // 最近的销售周期权重 1.15，其他 1.0
        weights.add(i == 0 ? 1.15 : 1.0);
      }
    }

    if (sales.isEmpty) return 0;

    double weightedSum = 0;
    double totalWeight = 0;
    for (int i = 0; i < sales.length; i++) {
      weightedSum += sales[i] * weights[i];
      totalWeight += weights[i];
    }
    // 保留两位小数精度
    return (weightedSum / totalWeight * 100).roundToDouble() / 100;
  }

  /// 计算每个周期的平均需求（即平均销量）
  /// [items] 订单项列表
  /// 不足1条返回0，1条直接返回该条订货量，多条调用平均销量计算
  static double calculateDemandPerCycle(List<OrderItem> items) {
    if (items.isEmpty) return 0;
    if (items.length == 1) {
      return items.first.orderedQty.toDouble();
    }

    return calculateAverageSales(items);
  }

  /// 建议订货量计算
  /// [avgSales] 平均周期销量
  /// [currentStock] 当前库存
  /// [safetyStock] 预留库存
  /// [avgDaysPerCycle] 平均订货周期天数
  /// [leadTimeDays] 到货等待天数
  /// [lowReserveStreak] 连续库存不足次数
  /// 返回建议的订货数量（不足则返回0）
  static int suggestOrderQty({
    required double avgSales,
    required int currentStock,
    required int safetyStock,
    double avgDaysPerCycle = 7,
    int leadTimeDays = 5,
    int lowReserveStreak = 0,
  }) {
    final safeCycleDays = avgDaysPerCycle <= 0 ? 7 : avgDaysPerCycle;
    final dailySales = avgSales <= 0 ? 0 : avgSales / safeCycleDays;
    const weeklyCoverageDays = 7;
    final weeklyDemand = dailySales * weeklyCoverageDays;
    final projectedRemainingAfterWeek = currentStock - weeklyDemand;
    final suggestion = safetyStock - projectedRemainingAfterWeek;
    if (suggestion <= 0) return 0;
    return suggestion.ceil();
  }
 
  /// 建议预留库存计算
  /// 先对平均销量四舍五入，再按阶梯规则返回预留库存数量
  /// [avgSales] 平均销量
  /// [items] 订单项列表（未使用，仅保留接口兼容）
  /// 规则（四舍五入后）：
  ///   0       → 0
  ///   1-2     → 1
  ///   3-6     → 2
  ///   7-11    → 3
  ///   12-16   → 4
  ///   17-21   → 5
  ///   每 +5 递增 1
  static int suggestSafetyStock({
    required double avgSales,
    required List<OrderItem> items,
  }) {
    final rounded = avgSales.round();
    if (rounded < 1) return 0;
    if (rounded < 3) return 1;
    if (rounded < 7) return 2;
    return 3 + ((rounded - 7) / 5).floor();
  }
}
