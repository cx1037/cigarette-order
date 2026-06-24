int predictSales(List<int> lastWeeksSales) {
  if (lastWeeksSales.isEmpty) return 0;
  if (lastWeeksSales.length < 4) return lastWeeksSales.last;

  double base = lastWeeksSales[0] * 0.4 +
      lastWeeksSales[1] * 0.3 +
      lastWeeksSales[2] * 0.2 +
      lastWeeksSales[3] * 0.1;

  if (lastWeeksSales[0] > lastWeeksSales[1] &&
      lastWeeksSales[1] > lastWeeksSales[2]) {
    base *= 1.1; // 趋势调整
  }

  return base.round();
}

int calculateSuggestedOrder({
  required int currentStock,
  required int safetyStock,
  required int prediction,
  required bool isOutOfStock,
}) {
  int suggest = prediction + safetyStock - currentStock;

  if (isOutOfStock) {
    suggest = suggest <
            (safetyStock + (prediction * 0.5).round())
        ? (safetyStock + (prediction * 0.5).round())
        : suggest;
  }

  return suggest < 0 ? 0 : suggest;
}