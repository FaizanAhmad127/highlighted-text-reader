import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/services/highlight_transfer_service.dart';

Future<void> showHighlightTransferQrDialog(
  BuildContext context, {
  required HighlightTransferSession session,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Share saved highlights'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(
                data: session.qrPayload,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan this code on the other phone. Valid for 30 minutes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}
