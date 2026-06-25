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
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };

  final thresholdController = TextEditingController();
  final cycleCountController = TextEditingController();
  bool loading = true;
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

  Future<void> _autoSave() async {
    final thresholdText = thresholdController.text.trim();
    final threshold = int.tryParse(thresholdText);
    if (threshold == null || threshold <= 0) return;
    final cycleCount = int.tryParse(cycleCountController.text.trim());
    await SettingsService.setLargeOrderThreshold(threshold);
    await SettingsService.setStatsCycleCount(
      (cycleCount != null && cycleCount >= 2) ? cycleCount : AppConstants.statsCycleCountDefault,
    );
    await SettingsService.setOrderWeekday(orderWeekday);
    await SettingsService.setArrivalWeekday(arrivalWeekday);
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认值'),
        content: const Text('确定要将所有订单设置恢复为默认值吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定恢复')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SettingsService.setLargeOrderThreshold(AppConstants.largeOrderThresholdDefault);
    await SettingsService.setStatsCycleCount(AppConstants.statsCycleCountDefault);
    await SettingsService.setOrderWeekday(AppConstants.orderWeekdayDefault);
    await SettingsService.setArrivalWeekday(AppConstants.arrivalWeekdayDefault);
    if (!mounted) return;
    setState(() {
      thresholdController.text = AppConstants.largeOrderThresholdDefault.toString();
      cycleCountController.text = AppConstants.statsCycleCountDefault.toString();
      orderWeekday = AppConstants.orderWeekdayDefault;
      arrivalWeekday = AppConstants.arrivalWeekdayDefault;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复默认设置')),
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
      appBar: AppBar(title: const Text('订单设置')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: thresholdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '大单提醒阈值(条)',
                    border: OutlineInputBorder(),
                  ),
                  onEditingComplete: () {
                    FocusScope.of(context).unfocus();
                    _autoSave();
                  },
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _autoSave();
                  },
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
                  onEditingComplete: () {
                    FocusScope.of(context).unfocus();
                    _autoSave();
                  },
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _autoSave();
                  },
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
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => orderWeekday = v);
                    _autoSave();
                  },
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
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => arrivalWeekday = v);
                    _autoSave();
                  },
                ),
                const SizedBox(height: 12),
                Text('当前设置：订烟后约 $leadDays 天到货',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('恢复默认值'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
    );
  }
}
