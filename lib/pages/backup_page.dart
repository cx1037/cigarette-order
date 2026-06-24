import 'package:flutter/material.dart';

import '../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String message = '';

  Future<void> _exportData() async {
    final path = await BackupService.exportBackup();
    setState(() {
      message = path == null ? '已取消导出' : '导出成功：\n$path';
    });
  }

  Future<void> _importData() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('确认导入'),
            content: const Text('导入会覆盖当前数据，是否继续？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    final path = await BackupService.importBackup();
    setState(() {
      message = path == null ? '已取消导入' : '导入成功：\n$path';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入导出'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: _exportData,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('导出数据'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importData,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('导入数据'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}