import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';
import 'scan_page.dart';

class ScanLookupPage extends StatefulWidget {
  const ScanLookupPage({super.key});

  @override
  State<ScanLookupPage> createState() => _ScanLookupPageState();
}

class _ScanLookupPageState extends State<ScanLookupPage> {
  Product? product;
  String? scannedCode;
  bool loading = false;

  Future<void> _scanAndLookup() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );

    if (code == null) return;

    setState(() {
      loading = true;
      scannedCode = code;
      product = null;
    });

    final result = await DatabaseService.instance.findByBarcode(code);

    setState(() {
      product = result;
      loading = false;
    });
  }

  String _formatPrice(Product p) {
    if (p.price == null) return '未设置';
    return 'EUR ${p.price!.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码查找'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _scanAndLookup,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('开始扫码'),
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            if (!loading && scannedCode != null && product == null)
              Text('未找到商品\n条码：$scannedCode'),
            if (!loading && product != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('AAMS: ${product!.aamsCode}'),
                      Text('库存: ${product!.currentStock}'),
                      Text('安全库存: ${product!.safetyStock}'),
                      Text('售价: ${_formatPrice(product!)}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
