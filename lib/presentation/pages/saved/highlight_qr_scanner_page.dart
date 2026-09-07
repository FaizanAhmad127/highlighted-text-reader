import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/services/highlight_transfer_payload.dart';

class HighlightQrScannerPage extends StatefulWidget {
  const HighlightQrScannerPage({super.key});

  @override
  State<HighlightQrScannerPage> createState() => _HighlightQrScannerPageState();
}

class _HighlightQrScannerPageState extends State<HighlightQrScannerPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      if (HighlightTransferPayload.tryParse(raw) == null) continue;
      _handled = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan highlight QR')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
