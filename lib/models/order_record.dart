class OrderRecord {
  String id;
  String date;

  OrderRecord({
    required this.id,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
      };

  factory OrderRecord.fromMap(Map<String, dynamic> map) => OrderRecord(
        id: map['id'] ?? '',
        date: map['date'] ?? '',
      );
}