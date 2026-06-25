import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/official_product_service.dart';
import '../services/accessibility_bridge.dart';
import '../utils/route_animations.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _status = '正在初始化数据库...';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await _step('正在初始化数据库...', () async {
        await DatabaseService.instance.database.timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('数据库初始化超时'),
        );
      });

      await _step('正在加载产品数据...', () async {
        await OfficialProductService.seedIfEmpty().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('产品数据加载超时'),
        );
      });

      AccessibilityBridge.init();

      await _step('正在加载设置...', () async {
        await AnimationSpeed.load().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _step(String label, Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() => _status = label);
    await fn();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smoking_rooms,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '烟库库存管理',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              if (_hasError) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '启动出错',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    });
                    _initApp();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
