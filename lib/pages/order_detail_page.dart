import 'package:flutter/material.dart';

import '../models/order_record.dart';
import '../services/database_service.dart';
import 'scan_page.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.order});

  final OrderRecord order;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool loading = true;
  List<Map<String, dynamic>> details = [];
  String? scannedCode;
  int? matchedQty;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final data = await DatabaseService.instance.getOrderDetails(widget.order.id);
    if (!mounted) return;

    setState(() {
      details = data;
      loading = false;
    });
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  int _calculateMatchedQty(String barcode) {
    var total = 0;
    for (final item in details) {
      final itemBarcode = (item['barcode'] ?? '').toString().trim();
      if (itemBarcode.isNotEmpty && itemBarcode == barcode) {
        total += (item['orderedQty'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  bool _isMatchedItem(Map<String, dynamic> item) {
    if (scannedCode == null || scannedCode!.isEmpty) return false;
    final itemBarcode = (item['barcode'] ?? '').toString().trim();
    return itemBarcode.isNotEmpty && itemBarcode == scannedCode;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );

    if (!mounted || code == null || code.isEmpty) return;

    setState(() {
      scannedCode = code;
      matchedQty = _calculateMatchedQty(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('订单明细'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading ? null : _scanBarcode,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('扫描条码'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(widget.order.date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('订单号：${widget.order.id}'),
                      if (scannedCode != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: matchedQty != null && matchedQty! > 0
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('扫描条码：$scannedCode'),
                                const SizedBox(height: 4),
                                Text(
                                  matchedQty != null && matchedQty! > 0
                                      ? '本订单包含该条码商品，共 $matchedQty 件'
                                      : '本订单不包含该条码商品',
                                  style: TextStyle(
                                    color: matchedQty != null && matchedQty! > 0
                                        ? Colors.green.shade800
                                        : Colors.orange.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: details.isEmpty
                      ? const Center(child: Text('该订单暂无明细'))
                      : ListView.builder(
                          itemCount: details.length,
                          itemBuilder: (context, index) {
                            final item = details[index];
                            final name = item['name'] ?? '未知商品';
                            final aams = item['aamsCode'] ?? '';
                            final barcode = item['barcode'] ?? '';
                            final stockBefore = item['stockBefore'] ?? 0;
                            final orderedQty = item['orderedQty'] ?? 0;
                            final matched = _isMatchedItem(item);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              color: matched ? Colors.green.shade50 : null,
                              child: ListTile(
                                leading: matched
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const Icon(Icons.inventory_2_outlined),
                                title: Text(name),
                                subtitle: Text(
                                  'AAMS：$aams\n'
                                  '条码：${barcode.toString().isEmpty ? "未设置" : barcode}\n'
                                  '下单前库存：$stockBefore\n'
                                  '订货数量：$orderedQty',
                                ),
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
