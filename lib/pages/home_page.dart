  
  import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';
import 'add_product_page.dart';
import 'backup_page.dart';
import 'order_history_page.dart';
import 'order_page.dart';
import 'order_stats_page.dart';
import 'product_edit_page.dart';
import 'settings_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _disclaimerText = '''
免责声明

本软件由开发者 cx 开发，并在人工智能工具辅助下完成。
开发过程中使用的 AI 模型包括：ChatGPT（前期）、DeepSeek Flash（后期）。
本软件为个人兴趣项目，仅供学习、研究、测试及个人数据整理使用。

本软件不构成任何采购建议、经营建议、库存建议、财务建议、
税务建议、法律建议或合规建议，所有数据与计算结果仅供参考。

本软件中的订货建议、销量统计、库存推算、Excel 导出内容、
扫码识别结果及其他自动化结果，均可能因历史数据不完整、
人工录入错误、条码错误、算法偏差、设备差异或第三方环境问题而产生误差。

用户应自行核对商品名称、AAMS 编码、价格、库存、重量、订货数量、
到货日期及导出内容，并自行承担人工复核义务。

本软件不保证数据绝对准确、完整、持续可用，也不保证一定满足特定经营或合规需求。
用户在实际经营、订货、报表、库存、申报、对账或其他业务场景中的一切操作，
均应遵守当地法律法规、行业规范、平台规则及相关主体要求。

本软件与 Logista Italia 及任何烟草公司、机构、平台或组织不存在
从属、合作、代理、授权或官方认证关系。
''';

  List<Product> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  List<Product> get activeProducts =>
      products.where((p) => p.isActive).toList();

  Future<void> _loadProducts() async {
    final data = await DatabaseService.instance.getAllProducts();
    if (!mounted) return;
    setState(() {
      products = data;
      loading = false;
    });
  }

  Future<void> _openPage(Widget page) async {
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _loadProducts();
  }

  Future<void> _scanAndLookupFromHome() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;

    final product = await DatabaseService.instance.findByBarcode(code);
    if (!mounted) return;

    if (product == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('扫码结果'),
          content: Text('未找到商品\n条码：$code'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditPage(product: product)),
    );
    await _loadProducts();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除这条烟吗？\n\n${product.name}\nAAMS: ${product.aamsCode}'
          '\n\n删除后会同时清除这条烟相关的库存调整和订单明细记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DatabaseService.instance.deleteProduct(product.id);
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除 ${product.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = activeProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('烟库库存管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '扫码查找',
            onPressed: _scanAndLookupFromHome,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.store, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '菜单',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: colorScheme.primary),
                title: const Text('设置'),
                onTap: () => _openPage(const SettingsPage()),
              ),
              ListTile(
                leading: Icon(Icons.bar_chart, color: colorScheme.primary),
                title: const Text('下单统计'),
                onTap: () =>
                    _openPage(OrderStatsPage(products: activeProducts)),
              ),
              ListTile(
                leading: Icon(Icons.history, color: colorScheme.primary),
                title: const Text('历史订单'),
                onTap: () => _openPage(const OrderHistoryPage()),
              ),
              ListTile(
                leading: Icon(Icons.import_export, color: colorScheme.primary),
                title: const Text('导入导出'),
                onTap: () => _openPage(const BackupPage()),
              ),
              const Divider(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '免责声明',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _disclaimerText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        '暂无已启用商品',
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击右下角 + 添加商品',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final product = list[index];
                      final priceText = product.price == null
                          ? '未设置'
                          : '€ ${product.price!.toStringAsFixed(2)}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductEditPage(product: product),
                              ),
                            );
                            await _loadProducts();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.smoking_rooms,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _InfoChip(
                                            icon: Icons.inventory,
                                            label: '${product.currentStock}',
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          _InfoChip(
                                            icon: Icons.shield_outlined,
                                            label: '${product.safetyStock}',
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          if (product.price != null)
                                            _InfoChip(
                                              icon: Icons.euro,
                                              label: priceText,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade300,
                                  ),
                                  onPressed: () => _deleteProduct(product),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'order',
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderPage(products: activeProducts),
                ),
              );
              await _loadProducts();
            },
            child: const Icon(Icons.shopping_cart),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add',
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddProductPage(),
                ),
              );
              await _loadProducts();
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style:
                TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}