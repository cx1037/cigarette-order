class StockAdjustment {
  int? id;
  String productId;
  String date;
  int quantity; // +增加 / -减少
  String reason;

  StockAdjustment({
    this.id,
    required this.productId,
    required this.date,
    required this.quantity,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'date': date,
        'quantity': quantity,
        'reason': reason,
      };

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'],
      productId: map['productId'] ?? '',
      date: map['date'] ?? '',
      quantity: map['quantity'] ?? 0,
      reason: map['reason'] ?? '',
    );
  }
}