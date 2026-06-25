import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/accessibility_bridge.dart';
import '../services/settings_service.dart';

class AutomationSettingsPage extends StatefulWidget {
  const AutomationSettingsPage({super.key});

  @override
  State<AutomationSettingsPage> createState() => _AutomationSettingsPageState();
}

class _AutomationSettingsPageState extends State<AutomationSettingsPage> {
  bool _autoEnabled = false;
  List<AutomationStep> _autoSteps = [];
  String _serviceStatus = '';
  bool _serviceReady = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await SettingsService.getAutoEnabled();
    final stepsStr = await SettingsService.getAutoSteps();
    final ready = await AccessibilityBridge.isServiceReady();

    List<AutomationStep> parsedSteps = [];
    if (stepsStr.isNotEmpty) {
      try {
        final list = jsonDecode(stepsStr) as List;
        parsedSteps = list.map((e) => AutomationStep.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _autoEnabled = enabled;
      _autoSteps = parsedSteps;
      _serviceReady = ready;
      _serviceStatus = ready ? '已连接' : '未开启';
      _loading = false;
    });
  }

  Future<void> _autoSave() async {
    await SettingsService.setAutoEnabled(_autoEnabled);
    await SettingsService.setAutoSteps(jsonEncode(_autoSteps.map((s) => s.toMap()).toList()));
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认值'),
        content: const Text('确定要清除所有自动化步骤并关闭自动下单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定恢复')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await SettingsService.setAutoEnabled(false);
    await SettingsService.setAutoSteps('');
    if (!mounted) return;
    setState(() {
      _autoEnabled = false;
      _autoSteps = [];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复默认设置')),
    );
  }

  void _addStep() {
    showDialog(
      context: context,
      builder: (ctx) => _AutomationStepDialog(
        onSave: (step) {
          setState(() => _autoSteps.add(step));
          _autoSave();
        },
      ),
    );
  }

  void _editStep(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _AutomationStepDialog(
        existing: _autoSteps[index],
        onSave: (step) {
          setState(() => _autoSteps[index] = step);
          _autoSave();
        },
      ),
    );
  }

  void _removeStep(int index) {
    setState(() => _autoSteps.removeAt(index));
    _autoSave();
  }

  Future<void> _checkServiceStatus() async {
    final ready = await AccessibilityBridge.isServiceReady();
    setState(() {
      _serviceReady = ready;
      _serviceStatus = ready ? '已连接' : '未开启';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ready ? '辅助功能服务已连接' : '辅助功能服务未开启，请前往系统设置开启')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('自动化下单')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 服务状态 + 总开关
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_serviceReady ? Icons.check_circle : Icons.error_outline,
                              color: _serviceReady ? Colors.green : Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text('无障碍服务 $_serviceStatus',
                              style: TextStyle(fontSize: 14,
                                color: _serviceReady ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500)),
                            const Spacer(),
                            SizedBox(
                              height: 30,
                              child: TextButton(
                                onPressed: _checkServiceStatus,
                                child: const Text('检测', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (!_serviceReady) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('请前往系统设置开启此服务：设置 → 辅助功能 → 已安装的应用 → 烟库库存管理',
                                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 24),
                        SwitchListTile(
                          value: _autoEnabled,
                          onChanged: (v) {
                            setState(() => _autoEnabled = v);
                            _autoSave();
                          },
                          title: const Text('下单后自动操作', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          subtitle: const Text('保存订单后自动跳转浏览器并执行预设步骤', style: TextStyle(fontSize: 12)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 步骤列表标题 + 操作按钮
                Row(
                  children: [
                    Text('自动化步骤',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    if (_autoSteps.isNotEmpty)
                      Text('（${_autoSteps.length} 步）',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    if (_autoSteps.isEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _autoSteps = List.from(AutomationStep.defaultLogistaSteps);
                          });
                          _autoSave();
                        },
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('使用预设', style: TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_autoSteps.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('暂无自动化步骤', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          Text('点击下方按钮添加步骤', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _autoSteps.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final step = _autoSteps.removeAt(oldIndex);
                        _autoSteps.insert(newIndex, step);
                      });
                      _autoSave();
                    },
                    itemBuilder: (context, index) {
                      final step = _autoSteps[index];
                      return Card(
                        key: ValueKey('step_$index'),
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('${index + 1}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary)),
                            ),
                          ),
                          title: Text(step.label, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editStep(index),
                                splashRadius: 18,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _removeStep(index),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('添加步骤'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('恢复默认值'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),

                const SizedBox(height: 24),
                Text('提示：启用此功能需要先在系统设置中开启"烟库库存管理"的无障碍服务权限。开启后，保存订单时将自动跳转到 Logista 并执行您配置的步骤。',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.5)),
              ],
            ),
    );
  }
}

/// 添加/编辑自动化步骤的对话框
class _AutomationStepDialog extends StatefulWidget {
  final AutomationStep? existing;
  final void Function(AutomationStep) onSave;

  const _AutomationStepDialog({this.existing, required this.onSave});

  @override
  State<_AutomationStepDialog> createState() => _AutomationStepDialogState();
}

class _AutomationStepDialogState extends State<_AutomationStepDialog> {
  late String _type;
  late TextEditingController _valueCtrl;

  static const _types = [
    'check_text',
    'check_input_empty',
    'click_text',
    'click_desc',
    'wait',
    'navigate_back',
    'finish',
  ];

  static const _typeLabels = {
    'check_text': '检查页面文字',
    'check_input_empty': '检查输入框是否为空',
    'click_text': '点击文字',
    'click_desc': '点击描述',
    'wait': '等待(毫秒)',
    'navigate_back': '返回',
    'finish': '结束',
  };

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? 'click_text';
    _valueCtrl = TextEditingController(text: widget.existing?.value ?? '');
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加步骤' : '编辑步骤'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: '操作类型',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _types.map((t) {
              return DropdownMenuItem(value: t, child: Text(_typeLabels[t] ?? t));
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            decoration: InputDecoration(
              labelText: _type == 'wait' ? '等待时长（毫秒）' : '目标文字/描述',
              hintText: _type == 'wait' ? '例如: 2000' : '例如: Upload',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _valueCtrl.text.trim();
            if (value.isEmpty && _type != 'navigate_back' && _type != 'finish') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入目标文字或等待时长')),
              );
              return;
            }
            widget.onSave(AutomationStep(type: _type, value: value));
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
