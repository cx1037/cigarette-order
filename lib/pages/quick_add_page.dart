import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';

/// 快速添加订烟页面
/// 通过搜索商品名称或 AAMS 码，选择商品并设置数量，直接添加到当前订单
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key});

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  List<Product> _searchResults = [];
  Product? _selectedProduct;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  /// 搜索商品（按名称或 AAMS 码）
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedProduct = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      // 先按 AAMS 精确查找
      Product? exact = await DatabaseService.instance.findByAams(query.trim());
      if (exact != null) {
        setState(() {
          _searchResults = [exact];
          _searching = false;
        });
        return;
      }
      // 再按名称模糊搜索
      final results = await DatabaseService.instance.searchByName(query.trim());
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  /// 选择商品后确认添加
  void _confirmAdd() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择需要添加的商品')),
      );
      return;
    }
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量')),
      );
      return;
    }
    // 返回选择的商品 ID 和数量
    Navigator.pop(context, {
      'productId': _selectedProduct!.id,
      'aamsCode': _selectedProduct!.aamsCode,
      'productName': _selectedProduct!.name,
      'quantity': qty,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速添加订烟'),
      ),
      body: Column(
        children: [
          // 搜索区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.03),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '搜索商品',
                    hintText: '输入商品名称或 AAMS 码',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _search,
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 12),
                if (_selectedProduct != null) ...[
                  // 已选商品信息
                  Card(
                    color: colorScheme.primaryContainer,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.smoking_rooms,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _selectedProduct!.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('AAMS: ${_selectedProduct!.aamsCode}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _selectedProduct = null;
                          _qtyController.clear();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 数量输入 + 确认按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          decoration: const InputDecoration(
                            labelText: '订烟数量',
                            prefixIcon: Icon(Icons.add_shopping_cart),
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _confirmAdd(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _confirmAdd,
                        icon: const Icon(Icons.check),
                        label: const Text('添加'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 搜索结果列表
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _searchController.text.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search,
                                size: 72, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              '搜索商品添加到订烟',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '输入名称或 AAMS 码搜索',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text('未找到匹配的商品',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey.shade500)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final product = _searchResults[index];
                              final isSelected =
                                  _selectedProduct?.id == product.id;
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : null,
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.smoking_rooms,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(product.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle: Text(
                                    'AAMS: ${product.aamsCode}  库存: ${product.currentStock}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle,
                                          color: colorScheme.primary)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedProduct = product;
                                      _qtyController.text = '';
                                    });
                                    FocusScope.of(context)
                                        .requestFocus(FocusNode());
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}