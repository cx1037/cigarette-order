import 'package:flutter/material.dart';

import '../models/order_record.dart';
import '../services/database_service.dart';
import 'order_detail_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  bool loading = true;
  List<OrderRecord> orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final data = await DatabaseService.instance.getAllOrders();
    if (!mounted) return;

    setState(() {
      orders = data;
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

  Future<void> _openOrderDetail(OrderRecord order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order),
      ),
    );
  }

  Future<void> _deleteOrder(OrderRecord order) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除这条历史订单吗？\n\n订单号：${order.id}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    await DatabaseService.instance.deleteOrder(order.id);
    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史订单'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? const Center(child: Text('暂无历史订单'))
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    return Card(
                      child: ListTile(
                        title: Text(_formatDate(order.date)),
                        subtitle: Text('订单号：${order.id}'),
                        onTap: () => _openOrderDetail(order),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteOrder(order),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
