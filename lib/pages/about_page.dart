import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 应用信息
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.smoking_rooms,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${AppConstants.appVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('开发者', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(AppConstants.developer),
                  const SizedBox(height: 12),
                  Text('微信', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(AppConstants.wechat),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('更新记录', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...AppConstants.changelog.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text(
                  '${entry['version']} (${entry['date']})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      entry['changes'] ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
