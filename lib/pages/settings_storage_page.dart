import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';

class SettingsStoragePage extends StatefulWidget {
  const SettingsStoragePage({super.key});

  @override
  State<SettingsStoragePage> createState() => _SettingsStoragePageState();
}

class _SettingsStoragePageState extends State<SettingsStoragePage> {
  String? savePath;
  bool loading = true;
  bool clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await SettingsService.getPath();
    if (!mounted) return;
    setState(() { savePath = path; loading = false; });
  }

  Future<void> _pickSavePath() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath();
    if (!mounted || selectedDir == null) return;
    setState(() => savePath = selectedDir);
  }

  Future<void> _savePath() async {
    if (savePath != null && savePath!.trim().isNotEmpty) {
      await SettingsService.savePath(savePath!.trim());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存路径已更新')),
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
        title: const Text('清除已保存 Excel'),
        content: const Text('将删除当前保存目录中本应用导出的 Excel 文件，是否继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认清除')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => clearing = true);
    final deletedCount = await ExcelService.clearSavedExcels(savePath!);
    if (!mounted) return;
    setState(() => clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清除 $deletedCount 个 Excel 文件')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('存储管理'), actions: [
        TextButton(
          onPressed: _savePath,
          child: const Text('保存', style: TextStyle(color: Colors.white)),
        ),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Excel 保存地址', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            savePath == null || savePath!.isEmpty ? '未设置' : savePath!,
                            style: TextStyle(fontSize: 13, color: savePath != null ? null : Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickSavePath,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择文件夹'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: clearing ? null : _clearSavedExcels,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text(clearing ? '清除中...' : '清除已保存 Excel',
                    style: TextStyle(color: clearing ? null : Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
    );
  }
}
