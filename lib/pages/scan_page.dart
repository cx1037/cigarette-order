import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (scanned) return;

          final code = capture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            scanned = true;
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}
