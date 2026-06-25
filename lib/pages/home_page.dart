
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
import 'about_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
const HomePage({super.key});

@override
State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
static const String _disclaimerText = '''
????

??????? cx ??,??????????????
???????? AI ????:ChatGPT(??)?DeepSeek Flash(??)?
??????????,????????????????????

????????????????????????????
??????????????,??????????????

????????????????????Excel ?????
??????????????,????????????
???????????????????????????????????

????????????AAMS ?????????????????
?????????,????????????

????????????????????,??????????????????
???????????????????????????????????,
????????????????????????????

???? Logista Italia ???????????????????
???????????????????
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
        title: const Text('????'),
        content: Text('?????\n??:$code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('??'),
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
      title: const Text('????'),
      content: Text(
        '??????????\n\n${product.name}\nAAMS: ${product.aamsCode}'
        '\n\n??????????????????????????',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('??'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('??'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await DatabaseService.instance.deleteProduct(product.id);
  await _loadProducts();
  if (!mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('??? ${product.name}')));
}

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final list = activeProducts;

  return Scaffold(
    appBar: AppBar(
      title: const Text('??????'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '????',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductPage()),
            );
            await _loadProducts();
          },
        ),
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: '????',
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
                    '??',
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
              title: const Text('??'),
              onTap: () => _openPage(const SettingsPage()),
            ),
            ListTile(
              leading: Icon(Icons.bar_chart, color: colorScheme.primary),
              title: const Text('????'),
              onTap: () =>
                  _openPage(OrderStatsPage(products: activeProducts)),
            ),
            ListTile(
              leading: Icon(Icons.history, color: colorScheme.primary),
              title: const Text('????'),
              onTap: () => _openPage(const OrderHistoryPage()),
            ),
            ListTile(
              leading: Icon(Icons.import_export, color: colorScheme.primary),
              title: const Text('????'),
              onTap: () => _openPage(const BackupPage()),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: colorScheme.primary),
              title: const Text('??'),
              onTap: () => _openPage(const AboutPage()),
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
                            '????',
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
                      '???????',
                      style: TextStyle(
                          fontSize: 18, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddProductPage()),
                        );
                        await _loadProducts();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('????'),
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
                        ? '???'
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
    floatingActionButton: FloatingActionButton(
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      tooltip: '??',
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
