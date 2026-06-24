import '../models/order_item.dart';

class StatsService {
  static List<double> calculateSalesList(List<OrderItem> items) {
    if (items.length < 2) return [];

    List<double> sales = [];

    for (int i = 0; i < items.length - 1; i++) {
      final newer = items[i];
      final older = items[i + 1];

      final sale = older.stockBefore + older.orderedQty - newer.stockBefore;

      if (sale >= 0) {
        sales.add(sale.toDouble());
      }
    }

    return sales;
  }

  static double avg(List<double> values, {double defaultValue = 0}) {
    if (values.isEmpty) return defaultValue;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double total(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b);
  }

  static double weeklySales({
    required double avgPerCycle,
    required double avgDaysPerCycle,
  }) {
    if (avgDaysPerCycle == 0) return 0;
    return avgPerCycle * (7 / avgDaysPerCycle);
  }

  static double dailySales({
    required double avgPerCycle,
    required double avgDaysPerCycle,
  }) {
    if (avgDaysPerCycle == 0) return 0;
    return avgPerCycle / avgDaysPerCycle;
  }
}