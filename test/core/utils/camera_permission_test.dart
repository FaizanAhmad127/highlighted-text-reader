import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/utils/camera_permission.dart';

void main() {
  test('detects camera permission errors from image_picker and scanner', () {
    expect(
      CameraPermission.isDeniedError(
        Exception('camera_access_denied'),
      ),
      isTrue,
    );
    expect(
      CameraPermission.isDeniedError(
        Exception('MobileScannerErrorCode.permissionDenied camera'),
      ),
      isTrue,
    );
    expect(CameraPermission.isDeniedError(Exception('offline')), isFalse);
  });
}
