class AppConstants {
  static const int aiHistoryLimit = 20;
  static const int statsCycleCountDefault = 20;
  static const int largeOrderThresholdDefault = 100;
  static const int arrivalLeadDaysDefault = 5;
  static const int orderWeekdayDefault = DateTime.wednesday;
  static const int arrivalWeekdayDefault = DateTime.monday;

  static const String backupPrefix = 'smoke_backup';

  static const String developer = 'cx';
  static const String wechat = 'CHNXNG99';

  // 动画设置默认值
  static const double animationSpeedDefault = 1.0;
  static const bool animationEnabledDefault = true;

  // 应用版本
  static const String appVersion = '1.3.0+1';
  static const String appName = '香烟订单 App';

  // 更新历史
  static const List<Map<String, String>> changelog = [
    {
      'version': 'v1.3.0',
      'date': '2026-06-25',
      'changes':
          '新增关于页面\n'
          '- 显示版本号、开发者信息\n'
          '- 显示更新记录（可展开各版本详情）',
    },
    {
      'version': 'v1.2.0',
      'date': '2026-06-25',
      'changes':
          '设置页面自动保存改进\n'
          '- 所有设置页面改为自动保存，去掉手动保存按钮\n'
          '- 新增恢复默认值功能（含二次确认弹窗）\n'
          '\n'
          '自动化步骤增强\n'
          '- 新增 check_text 步骤：检测登录页面\n'
          '- 新增 check_input_empty 步骤：检查输入框是否为空\n'
          '- 更新 Logista 预设流程（登录检测→上传Excel）',
    },
    {
      'version': 'v1.1.0',
      'date': '2026-06-25',
      'changes':
          '设置页改为三级界面结构\n'
          '- 订单设置、界面设置、自动化下单、存储管理\n'
          '- 各页面独立保存按钮\n'
          '\n'
          'APK 优化\n'
          '- APK 瘦身（ProGuard/R8 混淆压缩）\n'
          '- 页面过渡动画',
    },
    {
      'version': 'v1.0.0',
      'date': '2026-06-25',
      'changes':
          '初始版本\n'
          '- 订单管理（增删改查）\n'
          '- 销售统计图表\n'
          '- 自动计算下单量\n'
          '- Excel 导出（支持 Logista 格式）\n'
          '- 设置中心',
    },
  ];
}

