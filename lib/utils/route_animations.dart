import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 按设置中的动画速度包装路由切换
///
/// 如果动画关闭（speed=0 或 disabled），使用无动画跳转；
/// 否则使用 SlideTransition + FadeTransition，速度由 SettingsService 控制。
class AnimatedRoute {
  /// 创建一个带动画的页面路由，速度从设置读取
  static PageRouteBuilder<T> build<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _RouteTransition(
          animation: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// 完全无动画的直接跳转（用于动画关闭时）
  static MaterialPageRoute<T> instant<T>(Widget page) {
    return MaterialPageRoute<T>(builder: (_) => page);
  }

  /// 根据设置选择带动画或无动画跳转
  static Future<PageRoute<T>> create<T>(Widget page) async {
    final enabled = await SettingsService.getAnimationEnabled();
    final speed = await SettingsService.getAnimationSpeed();
    if (!enabled || speed <= 0) return instant<T>(page);
    return build<T>(page);
  }

  /// 便捷跳转方法：直接 push 带动画的页面
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, build<T>(page));
  }

  /// 便捷跳转方法：带动画的 pushReplacement
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, TO>(context, build<T>(page));
  }
}

/// 内部：组合 Slide + Fade 过渡，速度由 SettingsService 控制
class _RouteTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _RouteTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final slideTween = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    );
    final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

    return SlideTransition(
      position: slideTween.animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: fadeTween.animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}

/// 全局页面切换过渡构建器
///
/// 通过 ThemeData.pageTransitionsTheme 注册后，
/// 所有 Navigator.push 会自动使用此过渡效果，
/// 无需逐个修改 push 调用。
class AnimationSpeedPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final speed = AnimationSpeed.current;
    if (speed <= 0) return child;

    final slideTween = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    );
    final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

    return SlideTransition(
      position: slideTween.animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: fadeTween.animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}

/// 便捷：在 State 中使用的动画速度
/// 调用 [initAnimationSpeed] 获取当前速度倍率，用于自定义动画。
class AnimationSpeed {
  static double _cached = 1.0;

  static double get current => _cached;

  static Future<void> load() async {
    final enabled = await SettingsService.getAnimationEnabled();
    if (!enabled) {
      _cached = 0.0;
      return;
    }
    _cached = await SettingsService.getAnimationSpeed();
  }
}
