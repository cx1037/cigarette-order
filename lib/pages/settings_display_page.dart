import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsDisplayPage extends StatefulWidget {
  const SettingsDisplayPage({super.key});

  @override
  State<SettingsDisplayPage> createState() => _SettingsDisplayPageState();
}

class _SettingsDisplayPageState extends State<SettingsDisplayPage> {
  bool longPressNavigation = true;
  bool animationEnabled = true;
  double animationSpeed = 1.0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final longPress = await SettingsService.getLongPressNavigation();
    final animEnabled = await SettingsService.getAnimationEnabled();
    final animSpeed = await SettingsService.getAnimationSpeed();
    if (!mounted) return;
    setState(() {
      longPressNavigation = longPress;
      animationEnabled = animEnabled;
      animationSpeed = animSpeed;
      loading = false;
    });
  }

  Future<void> _save() async {
    await SettingsService.setLongPressNavigation(longPressNavigation);
    await SettingsService.setAnimationEnabled(animationEnabled);
    await SettingsService.setAnimationSpeed(animationSpeed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('界面设置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('界面设置'), actions: [
        TextButton(
          onPressed: _save,
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: longPressNavigation,
                          onChanged: (v) => setState(() => longPressNavigation = v),
                          title: const Text('长按快速导航', style: TextStyle(fontSize: 14)),
                          subtitle: const Text('按住"上一个"/"下一个"按钮持续切换商品，速度逐渐加快',
                            style: TextStyle(fontSize: 11)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(),
                        SwitchListTile(
                          value: animationEnabled,
                          onChanged: (v) => setState(() => animationEnabled = v),
                          title: const Text('页面切换动画', style: TextStyle(fontSize: 14)),
                          subtitle: const Text('页面切换时的滑动淡入效果', style: TextStyle(fontSize: 11)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (animationEnabled) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('动画速度', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              Expanded(
                                child: Slider(
                                  value: animationSpeed,
                                  min: 0.25, max: 2.0, divisions: 7,
                                  label: '${animationSpeed.toStringAsFixed(1)}x',
                                  onChanged: (v) => setState(() => animationSpeed = v),
                                ),
                              ),
                              Text('${animationSpeed.toStringAsFixed(1)}x',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Center(
                            child: Text('慢速 ← ———————— → 快速',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
