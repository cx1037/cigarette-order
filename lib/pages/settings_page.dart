import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/excel_service.dart';
import '../services/settings_service.dart';
import 'automation_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  String? savePath;
  bool loading = true;
  bool saving = false;
  bool clearing = false;
  int orderWeekday = DateTime.wednesday;
  int arrivalWeekday = DateTime.monday;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get leadDays => SettingsService.calculateLeadDaysFromWeekdays(
        orderWeekday: orderWeekday,
        arrivalWeekday: arrivalWeekday,
      );

  Future<void> _load() async {
    final threshold = await SettingsService.getLargeOrderThreshold();
    final cycleCount = await SettingsService.getStatsCycleCount();
    final path = await SettingsService.getPath();
    final savedOrderWeekday = await SettingsService.getOrderWeekday();
    final savedArrivalWeekday = await SettingsService.getArrivalWeekday();

    if (!mounted) return;
    setState(() {
      thresholdController.text = threshold.toString();
      cycleCountController.text = cycleCount.toString();
      savePath = path;
      orderWeekday = savedOrderWeekday;
      arrivalWeekday = savedArrivalWeekday;
      loading = false;
    });
  }

  Future<void> _pickSavePath() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (!mounted || selectedDir == null) return;

    setState(() {
      savePath = selectedDir;
    });
  }

  Future<void> _save() async {
    final threshold = int.tryParse(thresholdController.text.trim());
    if (threshold == null || threshold <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的大单提醒阈值')),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    await SettingsService.setLargeOrderThreshold(threshold);

    final cycleCount = int.tryParse(cycleCountController.text.trim());
    if (cycleCount != null && cycleCount >= 2) {
      await SettingsService.setStatsCycleCount(cycleCount);
    }

    await SettingsService.setOrderWeekday(orderWeekday);
    await SettingsService.setArrivalWeekday(arrivalWeekday);

    if (savePath != null && savePath!.trim().isNotEmpty) {
      await SettingsService.savePath(savePath!.trim());
    }

    if (!mounted) return;
    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  Future<void> _clearSavedExcels() async {
    if (savePath == null || savePath!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置 Excel 保存目录')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除已保存Excel'),
        content: const Text('将删除当前保存目录中本应用导出的 Excel 文件，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      clearing = true;
    });

    final deletedCount = await ExcelService.clearSavedExcels(savePath);

    if (!mounted) return;
    setState(() {
      clearing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清除 $deletedCount 个 Excel 文件')),
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
      appBar: AppBar(
        title: const Text('设置'),
      ),
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
                    labelText: '订烟日',
                    border: OutlineInputBorder(),
                  ),
                  items: weekdayLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      orderWeekday = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: arrivalWeekday,
                  decoration: const InputDecoration(
                    labelText: '到货日',
                    border: OutlineInputBorder(),
                  ),
                  items: weekdayLabels.entries
                      .map(
                        (entry) => DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      arrivalWeekday = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text('当前设置下，到货等待天数为 $leadDays 天'),
                const SizedBox(height: 20),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '订单 Excel 保存地址',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    savePath == null || savePath!.isEmpty ? '未设置' : savePath!,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickSavePath,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件夹'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: clearing ? null : _clearSavedExcels,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(clearing ? '清除中...' : '清除已保存Excel'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.smart_button),
                  title: const Text('自动化下单'),
                  subtitle: const Text('配置下单后自动跳转浏览器并执行点击'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AutomationSettingsPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? '保存中...' : '保存'),
                ),
              ],
            ),
    );
  }
}

