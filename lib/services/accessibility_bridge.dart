import 'dart:convert';
import 'package:flutter/services.dart';

/// Flutter -> Android 无障碍自动化服务桥接
///
/// 通过 MethodChannel 与 LogistaAccessibilityService 通信，
/// 实现下单后自动跳转浏览器并执行预设点击操作。
class AccessibilityBridge {
  static const _channel = MethodChannel(
    'com.example.flutter_application_1/accessibility',
  );

  static bool _initialized = false;

  /// 初始化监听（从服务接收状态更新）
  /// 当前使用轮询模式，Native 端通过 Companion 暴露状态
  static void init() {
    if (_initialized) return;
    _initialized = true;
  }

  /// 检查无障碍服务是否已连接（用户在系统设置中开启后）
  static Future<bool> isServiceReady() async {
    try {
      return await _channel.invokeMethod('isServiceReady') as bool;
    } catch (e) {
      return false;
    }
  }

  /// 预设自动化步骤（每次启动前可以更新）
  static Future<bool> setSteps(List<AutomationStep> steps) async {
    try {
      final json = jsonEncode(steps.map((s) => s.toMap()).toList());
      await _channel.invokeMethod('setSteps', {'steps': json});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 开始自动化流程（需先 setSteps）
  static Future<bool> startAutomation({List<AutomationStep>? steps}) async {
    try {
      if (steps != null && steps.isNotEmpty) {
        await setSteps(steps);
      }
      await _channel.invokeMethod('startAutomation');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 停止自动化
  static Future<bool> stopAutomation() async {
    try {
      await _channel.invokeMethod('stopAutomation');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前自动化状态
  static Future<Map<String, dynamic>> getState() async {
    try {
      final state = await _channel.invokeMethod('getState');
      if (state is Map) {
        return Map<String, dynamic>.from(state);
      }
      return {'isRunning': false, 'currentStep': 0, 'totalSteps': 0, 'statusMessage': ''};
    } catch (e) {
      return {'isRunning': false, 'currentStep': 0, 'totalSteps': 0, 'statusMessage': ''};
    }
  }
}

/// 自动化步骤定义
///
/// type 说明：
/// - click_text   : 点击包含指定文字的按钮/链接
/// - click_desc   : 点击内容描述匹配的元素
/// - wait         : 等待指定毫秒数
/// - navigate_back: 模拟返回键
/// - finish       : 结束自动化流程
class AutomationStep {
  final String type;
  final String value;
  final int timeoutMs;

  const AutomationStep({
    required this.type,
    required this.value,
    this.timeoutMs = 5000,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'value': value,
    'timeoutMs': timeoutMs,
  };

  /// 用户可读的描述文本
  String get label {
    switch (type) {
      case 'click_text':
        return '点击「$value」';
      case 'click_desc':
        return '点击描述「$value」';
      case 'wait':
        return '等待 ${value}ms';
      case 'navigate_back':
        return '返回';
      case 'finish':
        return '完成';
      default:
        return '$type: $value';
    }
  }

  /// 从保存的数据恢复
  factory AutomationStep.fromMap(Map<String, dynamic> map) {
    return AutomationStep(
      type: map['type'] as String? ?? '',
      value: map['value'] as String? ?? '',
      timeoutMs: map['timeoutMs'] as int? ?? 5000,
    );
  }

  /// 预设示例步骤：登录后上传 Excel 到 Logista
  static final List<AutomationStep> defaultLogistaSteps = [
    const AutomationStep(type: 'click_text', value: 'Upload'),
    const AutomationStep(type: 'click_text', value: 'Carica'),
    const AutomationStep(type: 'click_text', value: 'File'),
    const AutomationStep(type: 'click_text', value: 'Conferma'),
  ];
}
