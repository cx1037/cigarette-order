import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_service.dart';
import 'scan_page.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  static const List<String> _productTypes = [
    'SIGARETTE',
    'TABACCO SENZA COMBUSTIONE',
    'TRINCIATI PER SIGARETTE',
    'SIGARI',
    'SIGARETTI',
    'SIGARETTE ELETTRONICHE RICARICABILI E RICARICHE',
    'ALTRI TABACCHI DA FUMO',
  ];

  final aamsController = TextEditingController();
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final stockController = TextEditingController();
  final priceController = TextEditingController();
  final unitWeightController = TextEditingController();

  List<Product> results = [];
  Product? selected;
  int searchRequestId = 0;
  bool saving = false;
  bool manualMode = false;
  String selectedType = _productTypes.first;

  Future<void> _searchByAams([String? value]) async {
    if (manualMode) return;

    final query = (value ?? aamsController.text).trim();
    final requestId = ++searchRequestId;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        results = [];
        if (nameController.text.trim().isEmpty) {
          selected = null;
        }
      });
      return;
    }

    final product = await DatabaseService.instance.findByAams(query);
    if (!mounted || requestId != searchRequestId) return;

    setState(() {
      results = product == null ? [] : [product];
      selected = null;
    });
  }

  Future<void> _searchByName([String? value]) async {
    if (manualMode) return;

    final query = (value ?? nameController.text).trim();
    final requestId = ++searchRequestId;

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        results = [];
        if (aamsController.text.trim().isEmpty) {
          selected = null;
        }
      });
      return;
    }

    final list = await DatabaseService.instance.searchByName(query);
    if (!mounted || requestId != searchRequestId) return;

    setState(() {
      results = list;
      selected = null;
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      selected = product;
      aamsController.text = product.aamsCode;
      nameController.text = product.name;
      barcodeController.text = product.barcode;
      stockController.text =
          product.currentStock > 0 ? product.currentStock.toString() : '';
      priceController.text =
          product.price == null ? '' : product.price!.toStringAsFixed(2);
      unitWeightController.text = product.unitWeight.toStringAsFixed(2);
      selectedType = product.type.isNotEmpty ? product.type : selectedType;
      results = [];
    });
  }

  void _setManualMode(bool value) {
    setState(() {
      manualMode = value;
      results = [];
      selected = null;
      if (value) {
        aamsController.clear();
        nameController.clear();
        barcodeController.clear();
        stockController.clear();
        priceController.clear();
        unitWeightController.clear();
        selectedType = _productTypes.first;
      }
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );

    if (!mounted || code == null || code.isEmpty) return;

    setState(() {
      barcodeController.text = code;
    });
  }

  double? _parseDecimal(String raw) {
    return double.tryParse(raw.trim().replaceAll(',', '.'));
  }

  Future<void> _save() async {
    final stock = int.tryParse(stockController.text.trim()) ?? 0;
    final aams = aamsController.text.trim();
    final name = nameController.text.trim();
    final barcode = barcodeController.text.trim();

    if (manualMode) {
      if (aams.isEmpty || name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AAMS 编码和名称必填')),
        );
        return;
      }

      final price = _parseDecimal(priceController.text);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格必填')),
        );
        return;
      }

      final unitWeight = _parseDecimal(unitWeightController.text);
      if (unitWeight == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('每条重量必填')),
        );
        return;
      }

      setState(() {
        saving = true;
      });

      final existing = await DatabaseService.instance.findByAams(aams);
      final manualProduct = Product(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        aamsCode: aams,
        type: selectedType,
        currentStock: stock,
        safetyStock: existing?.safetyStock ?? 0,
        unitWeight: unitWeight,
        price: price,
        kgPrice: unitWeight > 0 ? price / unitWeight : null,
        barcode: barcode,
        isActive: true,
      );

      await DatabaseService.instance.insertOrUpdateProduct(manualProduct);

      if (!mounted) return;
      setState(() {
        saving = false;
      });
      Navigator.pop(context);
      return;
    }

    if (selected == null) return;

    double? price;
    final priceText = priceController.text.trim();
    if (priceText.isNotEmpty) {
      price = _parseDecimal(priceText);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格格式不正确')),
        );
        return;
      }
    }

    setState(() {
      saving = true;
    });

    final updated = Product(
      id: selected!.id,
      name: selected!.name,
      aamsCode: selected!.aamsCode,
      type: selected!.type,
      currentStock: stock,
      safetyStock: selected!.safetyStock,
      unitWeight: selected!.unitWeight,
      price: price,
      kgPrice: price != null && selected!.unitWeight > 0
          ? price / selected!.unitWeight
          : selected!.kgPrice,
      barcode: barcodeController.text.trim(),
      isActive: true,
    );

    await DatabaseService.instance.insertOrUpdateProduct(updated);

    if (!mounted) return;
    setState(() {
      saving = false;
    });
    Navigator.pop(context);
  }

  @override
  void dispose() {
    aamsController.dispose();
    nameController.dispose();
    barcodeController.dispose();
    stockController.dispose();
    priceController.dispose();
    unitWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selected != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('启用商品'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('搜索选择'),
                  icon: Icon(Icons.search),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('手动输入'),
                  icon: Icon(Icons.edit),
                ),
              ],
              selected: {manualMode},
              onSelectionChanged: (value) => _setManualMode(value.first),
            ),
            const SizedBox(height: 16),
            if (!manualMode) ...[
              TextField(
                controller: aamsController,
                onChanged: _searchByAams,
                decoration: const InputDecoration(
                  labelText: '按 AAMS 搜索',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                onChanged: _searchByName,
                decoration: const InputDecoration(
                  labelText: '按名称搜索',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (!hasSelection && results.isNotEmpty)
                ...results.map(
                  (product) => Card(
                    child: ListTile(
                      title: Text(product.name),
                      subtitle: Text('AAMS: ${product.aamsCode}'),
                      onTap: () => _selectProduct(product),
                    ),
                  ),
                ),
              if (hasSelection) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    title: Text(selected!.name),
                    subtitle: Text(
                      'AAMS: ${selected!.aamsCode}'
                      '${selected!.type.isNotEmpty ? '\n类型: ${selected!.type}' : ''}',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        setState(() {
                          selected = null;
                          barcodeController.clear();
                          stockController.clear();
                          priceController.clear();
                          unitWeightController.clear();
                        });
                      },
                      child: const Text('重新选择'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: barcodeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: '条码',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: '库存'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: '价格（可选）',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? '保存中...' : '保存并启用'),
                ),
              ],
            ] else ...[
              const Text(
                '手动录入时，名称、AAMS、每条重量和单包价格为必填项。',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: _productTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedType = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '名称 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aamsController,
                decoration: const InputDecoration(
                  labelText: 'AAMS 编码 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitWeightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '每条重量(kg) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '单包价格 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '条码',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '库存',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? '保存中...' : '创建并启用'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
