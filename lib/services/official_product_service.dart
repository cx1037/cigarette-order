import '../data/official_products.dart';
import '../models/product.dart';
import 'database_service.dart';

class OfficialProductService {
  static Future<void> seedIfEmpty() async {
    final count = await DatabaseService.instance.countProducts();
    if (count > 0) return;

    final products = officialProductsData.map((item) {
      final unitWeight = (item['unitWeight'] as num).toDouble();
      final priceValue = item['price'];
      final price = priceValue == null ? 0.0 : (priceValue as num).toDouble();
      final kgPriceValue = item['kgPrice'];

      return Product(
        id: item['id'].toString(),
        name: item['name'].toString(),
        aamsCode: item['aamsCode'].toString(),
        type: item['type'].toString(),
        currentStock: 0,
        safetyStock: 0,
        unitWeight: unitWeight,
        price: price,
        kgPrice: kgPriceValue == null
            ? (unitWeight > 0 ? price / unitWeight : 0)
            : (kgPriceValue as num).toDouble(),
        barcode: item['barcode']?.toString() ?? '',
        isActive: false,
      );
    }).toList();

    await DatabaseService.instance.insertMany(products);
  }
}
