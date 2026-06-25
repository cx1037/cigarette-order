  
  import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';
import 'add_product_page.dart';
import 'backup_page.dart';
import 'order_history_page.dart';
import 'order_page.dart';
import 'order_stats_page.dart';
import 'product_edit_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _disclaimerText = '''
鍏嶈矗澹版槑

鏈蒋浠剁敱寮€鍙戣€?cx 寮€鍙戯紝骞跺湪浜哄伐鏅鸿兘宸ュ叿杈呭姪涓嬪畬鎴愩€?寮€鍙戣繃绋嬩腑浣跨敤鐨?AI 妯″瀷鍖呮嫭锛欳hatGPT锛堝墠鏈燂級銆丏eepSeek Flash锛堝悗鏈燂級銆?鏈蒋浠朵负涓汉鍏磋叮椤圭洰锛屼粎渚涘涔犮€佺爺绌躲€佹祴璇曞強涓汉鏁版嵁鏁寸悊浣跨敤銆?
鏈蒋浠朵笉鏋勬垚浠讳綍閲囪喘寤鸿銆佺粡钀ュ缓璁€佸簱瀛樺缓璁€佽储鍔″缓璁€?绋庡姟寤鸿銆佹硶寰嬪缓璁垨鍚堣寤鸿锛屾墍鏈夋暟鎹笌璁＄畻缁撴灉浠呬緵鍙傝€冦€?
鏈蒋浠朵腑鐨勮璐у缓璁€侀攢閲忕粺璁°€佸簱瀛樻帹绠椼€丒xcel 瀵煎嚭鍐呭銆?鎵爜璇嗗埆缁撴灉鍙婂叾浠栬嚜鍔ㄥ寲缁撴灉锛屽潎鍙兘鍥犲巻鍙叉暟鎹笉瀹屾暣銆?浜哄伐褰曞叆閿欒銆佹潯鐮侀敊璇€佺畻娉曞亸宸€佽澶囧樊寮傛垨绗笁鏂圭幆澧冮棶棰樿€屼骇鐢熻宸€?
鐢ㄦ埛搴旇嚜琛屾牳瀵瑰晢鍝佸悕绉般€丄AMS 缂栫爜銆佷环鏍笺€佸簱瀛樸€侀噸閲忋€佽璐ф暟閲忋€?鍒拌揣鏃ユ湡鍙婂鍑哄唴瀹癸紝骞惰嚜琛屾壙鎷呬汉宸ュ鏍镐箟鍔°€?
鏈蒋浠朵笉淇濊瘉鏁版嵁缁濆鍑嗙‘銆佸畬鏁淬€佹寔缁彲鐢紝涔熶笉淇濊瘉涓€瀹氭弧瓒崇壒瀹氱粡钀ユ垨鍚堣闇€姹傘€?鐢ㄦ埛鍦ㄥ疄闄呯粡钀ャ€佽璐с€佹姤琛ㄣ€佸簱瀛樸€佺敵鎶ャ€佸璐︽垨鍏朵粬涓氬姟鍦烘櫙涓殑涓€鍒囨搷浣滐紝
鍧囧簲閬靛畧褰撳湴娉曞緥娉曡銆佽涓氳鑼冦€佸钩鍙拌鍒欏強鐩稿叧涓讳綋瑕佹眰銆?
鏈蒋浠朵笌 Logista Italia 鍙婁换浣曠儫鑽夊叕鍙搞€佹満鏋勩€佸钩鍙版垨缁勭粐涓嶅瓨鍦?浠庡睘銆佸悎浣溿€佷唬鐞嗐€佹巿鏉冩垨瀹樻柟璁よ瘉鍏崇郴銆?''';

  List<Product> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  List<Product> get activeProducts =>
      products.where((p) => p.isActive).toList();

  Future<void> _loadProducts() async {
    final data = await DatabaseService.instance.getAllProducts();
    if (!mounted) return;
    setState(() {
      products = data;
      loading = false;
    });
  }

  Future<void> _openPage(Widget page) async {
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _loadProducts();
  }

  Future<void> _scanAndLookupFromHome() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;

    final product = await DatabaseService.instance.findByBarcode(code);
    if (!mounted) return;

    if (product == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('鎵爜缁撴灉'),
          content: Text('鏈壘鍒板晢鍝乗n鏉＄爜锛?code'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('纭畾'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditPage(product: product)),
    );
    await _loadProducts();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('纭鍒犻櫎'),
        content: Text(
          '纭畾瑕佸垹闄よ繖鏉＄儫鍚楋紵\n\n${product.name}\nAAMS: ${product.aamsCode}'
          '\n\n鍒犻櫎鍚庝細鍚屾椂娓呴櫎杩欐潯鐑熺浉鍏崇殑搴撳瓨璋冩暣鍜岃鍗曟槑缁嗚褰曘€?,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('鍙栨秷'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('鍒犻櫎'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DatabaseService.instance.deleteProduct(product.id);
    await _loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('宸插垹闄?${product.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = activeProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('鐑熷簱搴撳瓨绠＄悊'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加商品',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProductPage()),
              );
              await _loadProducts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '鎵爜鏌ユ壘',
            onPressed: _scanAndLookupFromHome,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.store, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '鑿滃崟',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: colorScheme.primary),
                title: const Text('璁剧疆'),
                onTap: () => _openPage(const SettingsPage()),
              ),
              ListTile(
                leading: Icon(Icons.bar_chart, color: colorScheme.primary),
                title: const Text('涓嬪崟缁熻'),
                onTap: () =>
                    _openPage(OrderStatsPage(products: activeProducts)),
              ),
              ListTile(
                leading: Icon(Icons.history, color: colorScheme.primary),
                title: const Text('鍘嗗彶璁㈠崟'),
                onTap: () => _openPage(const OrderHistoryPage()),
              ),
              ListTile(
                leading: Icon(Icons.import_export, color: colorScheme.primary),
                title: const Text('瀵煎叆瀵煎嚭'),
                onTap: () => _openPage(const BackupPage()),
              ),
              const Divider(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '鍏嶈矗澹版槑',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _disclaimerText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        '鏆傛棤宸插惎鐢ㄥ晢鍝?,
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '鐐瑰嚮鍙充笅瑙?+ 娣诲姞鍟嗗搧',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final product = list[index];
                      final priceText = product.price == null
                          ? '鏈缃?
                          : '鈧?${product.price!.toStringAsFixed(2)}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductEditPage(product: product),
                              ),
                            );
                            await _loadProducts();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.smoking_rooms,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _InfoChip(
                                            icon: Icons.inventory,
                                            label: '${product.currentStock}',
                                            color: colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          _InfoChip(
                                            icon: Icons.shield_outlined,
                                            label: '${product.safetyStock}',
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          if (product.price != null)
                                            _InfoChip(
                                              icon: Icons.euro,
                                              label: priceText,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade300,
                                  ),
                                  onPressed: () => _deleteProduct(product),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        tooltip: '下单',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderPage(products: activeProducts),
            ),
          );
          await _loadProducts();
        },
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style:
                TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
