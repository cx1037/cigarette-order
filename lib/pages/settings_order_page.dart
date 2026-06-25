import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/app_constants.dart';

class SettingsOrderPage extends StatefulWidget {
  const SettingsOrderPage({super.key});

  @override
  State<SettingsOrderPage> createState() => _SettingsOrderPageState();
}

class _SettingsOrderPageState extends State<SettingsOrderPage> {
  static const Map<int, String> weekdayLabels = {
    DateTime.monday: '星期一',
    DateTime.tuesday: '星期二',
    DateTime.wednesday: '星期三',
    DateTime.thursday: '星期四',
    DateTime.friday: '星期五',
    DateTime.saturday: '星期六',
    DateTime.sunday: '星期日',
  };

  final thresholdController = TextEditingController();
  final cycleCountController = TextEditingController();
  bool loading = true;
  bool saving = false;
  int orderWeekday = DateTime.wednesday;
  int arrivalWeekday = DateTime.monday;

  int get leadDays => SettingsService.calculateLeadDaysFromWeekdays(
    orderWeekday: orderWeekday, arrivalWeekday: arrivalWeekday,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final threshold = await SettingsService.getLargeOrderThreshold();
    final cycleCount = await SettingsService.getStatsCycleCount();
    final savedOrderWeekday = await SettingsService.getOrderWeekday();
    final savedArrivalWeekday = await SettingsService.getArrivalWeekday();
    if (!mounted) return;
    setState(() {
      thresholdController.text = threshold.toString();
      cycleCountController.text = cycleCount.toString();
      orderWeekday = savedOrderWeekday;
      arrivalWeekday = savedArrivalWeekday;
      loading = false;
    });
  }

  Future<void> _save() async {
    final threshold = int.tryParse(thresholdController.text.trim());
    if (threshold == null || threshold <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的大单提醒阈值')),
      );
      return;
    }
    setState(() => saving = true);
    await SettingsService.setLargeOrderThreshold(threshold);
    final cycleCount = int.tryParse(cycleCountController.text.trim());
    if (cycleCount != null && cycleCount >= 2) {
      await SettingsService.setStatsCycleCount(cycleCount);
    }
    await SettingsService.setOrderWeekday(orderWeekday);
    await SettingsService.setArrivalWeekday(arrivalWeekday);
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订单设置已保存')),
    );
  }

  @override
  void dispose() {
    thresholdController.dispose();
    cycleCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('订单设置'), actions: [
        TextButton(
          onPressed: saving ? null : _save,
          child: const Text('保存', style: TextStyle(color: Colors.white)),
        ),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: thresholdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '大单提醒阈值',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cycleCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '统计周期数',
                    hintText: '用于计算平均销量的最近订单数',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: orderWeekday,
                  decoration: const InputDecoration(
                    labelText: '订烟日', border: OutlineInputBorder(),
                  ),
                  items: weekdayLabels.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                  ).toList(),
                  onChanged: (v) { if (v != null) setState(() => orderWeekday = v); },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: arrivalWeekday,
                  decoration: const InputDecoration(
                    labelText: '到货日', border: OutlineInputBorder(),
                  ),
                  items: weekdayLabels.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                  ).toList(),
                  onChanged: (v) { if (v != null) setState(() => arrivalWeekday = v); },
                ),
                const SizedBox(height: 12),
                Text('当前设置下，到货等待天数为 $leadDays 天',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
    );
  }
}
