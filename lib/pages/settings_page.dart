import 'package:flutter/material.dart';
import 'automation_settings_page.dart';
import 'settings_order_page.dart';
import 'settings_display_page.dart';
import 'settings_storage_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _categories = [
    _Category(icon: Icons.shopping_cart, title: '订单设置', subtitle: '订烟日、到货日、大单提醒、统计周期'),
    _Category(icon: Icons.palette, title: '界面设置', subtitle: '快速导航、页面动画、动画速度'),
    _Category(icon: Icons.smart_button, title: '自动化下单', subtitle: '配置下单后自动跳转浏览器并执行点击'),
    _Category(icon: Icons.folder, title: '存储管理', subtitle: 'Excel 保存路径、清理历史文件'),
  ];

  void _openPage(int index) {
    Widget page;
    switch (index) {
      case 0: page = const SettingsOrderPage(); break;
      case 1: page = const SettingsDisplayPage(); break;
      case 2: page = const AutomationSettingsPage(); break;
      case 3: page = const SettingsStoragePage(); break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cat.icon, color: theme.colorScheme.primary, size: 22),
            ),
            title: Text(cat.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            subtitle: Text(cat.subtitle, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _openPage(index),
          );
        },
      ),
    );
  }
}

class _Category {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Category({required this.icon, required this.title, required this.subtitle});
}