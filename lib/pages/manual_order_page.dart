import 'package:flutter/material.dart';

import '../services/database_service.dart';
import 'scan_page.dart';

/// 手动添加的订烟项数据模型
class ManualOrderItem {
  /// AAMS 码
  final String aamsCode;
  /// 商品名称（可选，通过 AAMS 码查询得到）
  final String? productName;
  /// 订烟数量
  final int quantity;

  ManualOrderItem({
    required this.aamsCode,
    this.productName,
    required this.quantity,
  });
}

/// 手动添加订烟页面
class ManualOrderPage extends StatefulWidget {
  const ManualOrderPage({super.key});

  @override
  State<ManualOrderPage> createState() => _ManualOrderPageState();
}

class _ManualOrderPageState extends State<ManualOrderPage> {
  final _aamsController = TextEditingController();
  final _qtyController = TextEditingController();
  final List<ManualOrderItem> _items = [];

  @override
  void dispose() {
    _aamsController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;

    final product = await DatabaseService.instance.findByBarcode(code);
    if (product != null) {
      setState(() => _aamsController.text = product.aamsCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已找到商品: ${product.name}')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未找到条码 "$code" 对应的商品，请手动输入 AAMS 码')),
      );
    }
  }

  Future<void> _addItem() async {
    final aams = _aamsController.text.trim();
    final qtyText = _qtyController.text.trim();
    if (aams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 AAMS 码')),
      );
      return;
    }
    final qty = int.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量')),
      );
      return;
    }

    String? productName;
    try {
      final product = await DatabaseService.instance.findByAams(aams);
      productName = product?.name;
    } catch (_) {}

    setState(() {
      _items.add(ManualOrderItem(
        aamsCode: aams,
        productName: productName,
        quantity: qty,
      ));
      _aamsController.clear();
      _qtyController.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加: ${productName ?? aams} x $qty')),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _confirm() {
    Navigator.pop(context, _items.isEmpty ? null : _items);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('手动添加订烟'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: const Text('完成',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.03),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aamsController,
                        decoration: InputDecoration(
                          labelText: 'AAMS 码',
                          hintText: '输入或扫码获取',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: '扫码',
                            onPressed: _scanBarcode,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _qtyController,
                        decoration: const InputDecoration(
                          labelText: '数量',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addItem,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart_outlined,
                            size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          '暂无手动添加的订烟',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '输入 AAMS 码或扫码添加',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.smoking_rooms,
                                color: colorScheme.primary, size: 20),
                          ),
                          title: Text(item.productName ?? item.aamsCode),
                          subtitle: Text(
                            'AAMS: ${item.aamsCode}  × ${item.quantity}',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade300),
                            onPressed: () => _removeItem(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: Text('确认添加 (${_items.length} 项)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}