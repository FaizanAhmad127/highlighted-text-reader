import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/camera_permission.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../data/services/highlight_transfer_payload.dart';

class HighlightQrScannerPage extends StatefulWidget {
  const HighlightQrScannerPage({
    super.key,
    this.openAppSettings,
  });

  final Future<void> Function()? openAppSettings;

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

  void _showDeniedSnackbar() {
    UIHelpers.showSnackbar(
      context,
      CameraPermission.qrMessage,
      actionLabel: CameraPermission.settingsAction,
      onAction: () {
        unawaited((widget.openAppSettings ?? CameraPermission.openSettings)());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan highlight QR')),
      body: MobileScanner(
        onDetect: _onDetect,
        errorBuilder: (context, error) {
          if (error.errorCode == MobileScannerErrorCode.permissionDenied &&
              !_handled) {
            _handled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showDeniedSnackbar();
            });
          }
          return const SizedBox.expand();
        },
      ),
    );
  }
}
