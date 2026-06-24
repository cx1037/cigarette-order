class OrderItem {
  int? id;
  String orderId;
  String productId;
  int stockBefore;
  int orderedQty;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.stockBefore,
    required this.orderedQty,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'productId': productId,
        'stockBefore': stockBefore,
        'orderedQty': orderedQty,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        id: map['id'],
        orderId: map['orderId'] ?? '',
        productId: map['productId'] ?? '',
        stockBefore: map['stockBefore'] ?? 0,
        orderedQty: map['orderedQty'] ?? 0,
      );
}