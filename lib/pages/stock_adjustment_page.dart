import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/stock_adjustment.dart';
import '../services/database_service.dart';

class StockAdjustmentPage extends StatefulWidget {
  final List<Product> products;

  const StockAdjustmentPage({super.key, required this.products});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
  Product? selectedProduct;
  final qtyController = TextEditingController();
  String selectedReason = '退�?;

  final reasons = [
    '退�?,
    '换烟',
    '盘点修正',
    '其他',
  ];

  Future<void> _save() async {
    if (selectedProduct == null) return;

    final qty = int.tryParse(qtyController.text.trim());
    if (qty == null || qty == 0) return;

    final adjustment = StockAdjustment(
      productId: selectedProduct!.id,
      date: DateTime.now().toIso8601String(),
      quantity: qty,
      reason: selectedReason,
    );

    await DatabaseService.instance.insertStockAdjustment(adjustment);

    selectedProduct!.currentStock += qty;
    await DatabaseService.instance.updateProduct(selectedProduct!);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存调整'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<Product>(
              hint: const Text('选择商品'),
              items: widget.products
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedProduct = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedReason,
              items: reasons
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedReason = v!;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数量�?增加 / -减少�?,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: const Text('保存调整'),
            ),
          ],
        ),
      ),
    );
  }
}
