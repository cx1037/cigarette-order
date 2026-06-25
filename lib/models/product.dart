class Product {
  final String id;
  final String name;
  final String aamsCode;
  final String type;

  int currentStock;
  int safetyStock;

  final double unitWeight;
  final double? price;
  final double? kgPrice;\n  final double? cartonPrice;

  final String barcode;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    required this.aamsCode,
    required this.type,
    required this.currentStock,
    required this.safetyStock,
    required this.unitWeight,
    this.price,
    this.kgPrice,\n    this.cartonPrice,
    required this.barcode,
    this.isActive = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'aamsCode': aamsCode,
        'type': type,
        'currentStock': currentStock,
        'safetyStock': safetyStock,
        'unitWeight': unitWeight,
        'price': price,
        'kgPrice': kgPrice,
        'cartonPrice': cartonPrice,
        'barcode': barcode,
        'isActive': isActive ? 1 : 0,
      };

  factory Product.fromMap(Map<String, dynamic> map) {
    final unitWeight = (map['unitWeight'] as num?)?.toDouble() ?? 0;
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final kgPrice = (map['kgPrice'] as num?)?.toDouble() ??
        (price > 0 && unitWeight > 0 ? price / unitWeight : null);

    return Product(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      aamsCode: (map['aamsCode'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      currentStock: ((map['currentStock'] as num?)?.toInt() ?? 0),
      safetyStock: ((map['safetyStock'] as num?)?.toInt() ?? 0),
      unitWeight: unitWeight,
      price: price,
      kgPrice: kgPrice,
      cartonPrice: cartonPrice,
      barcode: (map['barcode'] ?? '').toString(),
      isActive: ((map['isActive'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? aamsCode,
    String? type,
    int? currentStock,
    int? safetyStock,
    double? unitWeight,
    double? price,
    double? kgPrice,\n    double? cartonPrice,
    bool Function()? kgPriceNull,
    String? barcode,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      aamsCode: aamsCode ?? this.aamsCode,
      type: type ?? this.type,
      currentStock: currentStock ?? this.currentStock,
      safetyStock: safetyStock ?? this.safetyStock,
      unitWeight: unitWeight ?? this.unitWeight,
      price: price ?? this.price,
      kgPrice: kgPriceNull != null ? null : (kgPrice ?? this.kgPrice),
      cartonPrice: cartonPrice ?? this.cartonPrice,
      barcode: barcode ?? this.barcode,
      isActive: isActive ?? this.isActive,
    );
  }
}
