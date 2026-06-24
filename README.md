# 香烟订单

一款基于 Flutter 的香烟订单管理应用，支持扫码、手动下单、库存管理、数据统计与备份等功能。

## 功能特性

- **扫码下单** — 扫描香烟条码快速添加订单，支持历史扫码记录查询
- **手动下单** — 通过产品列表或搜索手动选择商品，支持批量添加
- **快速下单** — 快捷入口，一键进入下单流程
- **订单管理** — 查看订单详情、历史记录、订单统计
- **库存管理** — 库存调整、入库操作，实时掌握库存动态
- **产品管理** — 添加、编辑产品信息，支持官方产品数据库自动导入
- **AI 辅助下单** — 智能推荐下单数量，帮助优化订货决策
- **数据备份** — 本地备份与恢复，支持 Excel 导出
- **设置中心** — 应用配置个性化调整

## 技术栈

- **框架：** Flutter
- **语言：** Dart
- **平台支持：** Android / iOS / Web / Windows / macOS / Linux
- **本地存储：** SQLite（通过 sqflite）
- **条码扫描：** 手机摄像头扫码

## 快速开始

```bash
# 克隆项目
git clone https://github.com/cx1037/cigarette-order.git

# 进入目录
cd cigarette-order

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── data/                  # 数据文件（官方产品库）
├── models/                # 数据模型
├── pages/                 # 页面
│   ├── home_page.dart     # 首页
│   ├── scan_page.dart     # 扫码页
│   ├── order_page.dart    # 下单页
│   ├── manual_order_page.dart  # 手动下单
│   ├── quick_add_page.dart     # 快速下单
│   ├── order_detail_page.dart  # 订单详情
│   ├── order_history_page.dart # 订单历史
│   ├── order_stats_page.dart   # 订单统计
│   ├── product_edit_page.dart  # 产品编辑
│   ├── scan_lookup_page.dart   # 扫码查询
│   ├── stock_adjustment_page.dart # 库存调整
│   ├── backup_page.dart    # 备份管理
│   └── settings_page.dart  # 设置
├── services/              # 业务服务层
│   ├── database_service.dart      # 数据库服务
│   ├── backup_service.dart        # 备份服务
│   ├── excel_service.dart         # Excel 导出
│   ├── ai_order_service.dart      # AI 下单
│   └── official_product_service.dart # 官方产品服务
└── utils/                 # 工具与常量
```

## 联系方式

- 开发者：cx
- 微信：CHNXNG99