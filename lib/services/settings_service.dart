import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_constants.dart';

class SettingsService {
  static const String _keySavePath = 'save_path';
  static const String _keyLargeOrderThreshold = 'large_order_threshold';
  static const String _keyArrivalLeadDays = 'arrival_lead_days';
  static const String _keyOrderWeekday = 'order_weekday';
 static const String _keyArrivalWeekday = 'arrival_weekday';
static const String _keyOrderDraft = 'order_draft';
static const String _keyStatsCycleCount = 'stats_cycle_count';
 static const String _keyLongPressNavigation = 'long_press_navigation';
 static const String _keyAutoEnabled = 'auto_enabled';
 static const String _keyAutoSteps = 'auto_steps';

 // 缓存 SharedPreferences 实例，避免反复调用 getInstance()
 static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> savePath(String path) async {
    final prefs = await _preferences;
    await prefs.setString(_keySavePath, path);
  }

  static Future<String?> getPath() async {
    final prefs = await _preferences;
    return prefs.getString(_keySavePath);
  }

  static Future<void> setLargeOrderThreshold(int value) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyLargeOrderThreshold, value);
  }

  static Future<int> getLargeOrderThreshold() async {
    final prefs = await _preferences;
    return prefs.getInt(_keyLargeOrderThreshold) ??
        AppConstants.largeOrderThresholdDefault;
  }

  static Future<void> setArrivalLeadDays(int value) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyArrivalLeadDays, value);
  }

  static Future<int> getArrivalLeadDays() async {
    final prefs = await _preferences;
    final orderWeekday = prefs.getInt(_keyOrderWeekday);
    final arrivalWeekday = prefs.getInt(_keyArrivalWeekday);
    if (orderWeekday != null && arrivalWeekday != null) {
      return _calculateLeadDays(orderWeekday, arrivalWeekday);
    }
    return prefs.getInt(_keyArrivalLeadDays) ??
        AppConstants.arrivalLeadDaysDefault;
  }

  static Future<void> setOrderWeekday(int value) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyOrderWeekday, value);
  }

  static Future<int> getOrderWeekday() async {
    final prefs = await _preferences;
    return prefs.getInt(_keyOrderWeekday) ?? AppConstants.orderWeekdayDefault;
  }

  static Future<void> setArrivalWeekday(int value) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyArrivalWeekday, value);
  }

  static Future<int> getArrivalWeekday() async {
    final prefs = await _preferences;
    return prefs.getInt(_keyArrivalWeekday) ??
        AppConstants.arrivalWeekdayDefault;
  }

  static Future<void> saveOrderDraft(Map<String, dynamic> draft) async {
    final prefs = await _preferences;
    await prefs.setString(_keyOrderDraft, jsonEncode(draft));
  }

  static Future<Map<String, dynamic>?> getOrderDraft() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_keyOrderDraft);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> setStatsCycleCount(int value) async {
    final prefs = await _preferences;
    await prefs.setInt(_keyStatsCycleCount, value);
  }

  static Future<int> getStatsCycleCount() async {
    final prefs = await _preferences;
   return prefs.getInt(_keyStatsCycleCount) ?? AppConstants.statsCycleCountDefault;
 }

  static Future<void> setLongPressNavigation(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyLongPressNavigation, value);
  }

 static Future<bool> getLongPressNavigation() async {
   final prefs = await _preferences;
   return prefs.getBool(_keyLongPressNavigation) ?? true;
 }

 static Future<void> setAutoEnabled(bool value) async {
   final prefs = await _preferences;
   await prefs.setBool(_keyAutoEnabled, value);
 }

 static Future<bool> getAutoEnabled() async {
   final prefs = await _preferences;
   return prefs.getBool(_keyAutoEnabled) ?? false;
 }

 static Future<void> setAutoSteps(String stepsJson) async {
   final prefs = await _preferences;
   await prefs.setString(_keyAutoSteps, stepsJson);
 }

 static Future<String> getAutoSteps() async {
   final prefs = await _preferences;
   return prefs.getString(_keyAutoSteps) ?? '';
 }

static Future<void> clearOrderDraft() async {
    final prefs = await _preferences;
    await prefs.remove(_keyOrderDraft);
  }

  static int calculateLeadDaysFromWeekdays({
    required int orderWeekday,
    required int arrivalWeekday,
  }) {
    return _calculateLeadDays(orderWeekday, arrivalWeekday);
  }

  static int _calculateLeadDays(int orderWeekday, int arrivalWeekday) {
    final diff = (arrivalWeekday - orderWeekday) % 7;
    final normalized = diff < 0 ? diff + 7 : diff;
    return normalized == 0 ? 7 : normalized;
  }
}
