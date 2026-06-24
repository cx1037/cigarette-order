import 'package:flutter/material.dart';

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  static const String _text = '''
免责声明

本软件由开发者 cx 开发，并在人工智能工具辅助下完成。

本软件仅供个人学习、研究、测试及数据整理使用，不构成商业软件、专业管理系统、官方指定工具，亦不提供采购、经营、库存、财务、税务、法律或合规建议。

本软件中的订货建议、销量统计、库存推算、Excel 导出、扫码识别及其他自动化结果，均可能因历史数据不完整、人工录入错误、条码错误、算法偏差、设备差异或第三方环境问题而产生偏差。

用户应自行核对商品名称、AAMS 编码、价格、库存、重量、订货数量、到货日期及导出内容，并自行承担人工复核责任。

本软件与 Logista Italia 及任何烟草公司、机构、平台或组织不存在从属、合作、代理、授权或官方认证关系。

继续使用本软件，即视为你已理解并接受上述说明与相关风险。
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('免责声明'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(_text),
        ),
      ),
    );
  }
}
