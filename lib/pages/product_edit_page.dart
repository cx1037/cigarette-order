import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';
import 'scan_page.dart';

/// 编辑商品页面
/// 可修改条码、库存数量、预留库存、价格，以及启用/禁用商品
class ProductEditPage extends StatefulWidget {
  final Product product;

  const ProductEditPage({super.key, required this.product});

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  late final TextEditingController barcodeController;
  late final TextEditingController stockController;
  late final TextEditingController reserveStockController;
  late final TextEditingController priceController;
  bool saving = false;
  bool isActive = false;

  @override
  void initState() {
    super.initState();
    barcodeController = TextEditingController(text: widget.product.barcode);
    stockController =
        TextEditingController(text: widget.product.currentStock.toString());
    reserveStockController =
        TextEditingController(text: widget.product.safetyStock.toString());
    priceController = TextEditingController(
      text: widget.product.price == null
          ? ''
          : widget.product.price!.toStringAsFixed(2),
    );
    isActive = widget.product.isActive;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => barcodeController.text = code);
  }

  Future<void> _save() async {
    final stock = int.tryParse(stockController.text.trim());
    if (stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('库存数量格式不正确')),
      );
      return;
    }
    final reserveStock = int.tryParse(reserveStockController.text.trim());
    if (reserveStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预留库存格式不正确')),
      );
      return;
    }
    double? price;
    final priceText = priceController.text.trim();
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText.replaceAll(',', '.'));
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格格式不正确')),
        );
        return;
      }
    }

    setState(() => saving = true);

    final updated = Product(
      id: widget.product.id,
      name: widget.product.name,
      aamsCode: widget.product.aamsCode,
      type: widget.product.type,
      currentStock: stock,
      safetyStock: reserveStock,
      unitWeight: widget.product.unitWeight,
      price: price,
      kgPrice: price != null && widget.product.unitWeight > 0
          ? price / widget.product.unitWeight
          : widget.product.kgPrice,
      barcode: barcodeController.text.trim(),
      isActive: isActive,
    );

    await DatabaseService.instance.insertOrUpdateProduct(updated);
    if (!mounted) return;
    setState(() => saving = false);
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    barcodeController.dispose();
    stockController.dispose();
    reserveStockController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑商品'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 商品名称和信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.smoking_rooms,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AAMS: ${widget.product.aamsCode}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 条码字段
          Text(
            '条码',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: barcodeController,
            decoration: InputDecoration(
              hintText: '输入条码或扫码获取',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 库存字段
          Text(
            '库存数量',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: stockController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.inventory_2),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          // 预留库存字段
          Text(
            '预留库存',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: reserveStockController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          // 价格字段
          Text(
            '价格',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: priceController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.euro),
              hintText: '可选',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),

          // 启用/禁用开关
          Card(
            child: SwitchListTile(
              secondary: Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive ? Colors.green : Colors.grey,
              ),
              title: Text(
                isActive ? '已启用' : '已禁用',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
              subtitle: const Text('关闭后该烟不会出现在订烟列表中'),
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
            ),
          ),
          const SizedBox(height: 28),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(saving ? '保存中...' : '保存修改'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}