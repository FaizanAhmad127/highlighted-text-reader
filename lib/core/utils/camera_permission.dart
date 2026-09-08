import 'package:permission_handler/permission_handler.dart';

class CameraPermission {
  CameraPermission._();

  static const photoMessage = 'Camera access is off. Enable it to take a photo.';
  static const qrMessage = 'Camera access is off. Enable it to scan a QR code.';
  static const settingsAction = 'Open Settings';

  static Future<bool> request() async {
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }

  static Future<void> openSettings() => openAppSettings();

  static bool isDeniedError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('camera_access_denied') ||
        text.contains('camerapermissiondenied') ||
        text.contains('camera permission') ||
        text.contains('permissiondenied') && text.contains('camera');
  }
}
