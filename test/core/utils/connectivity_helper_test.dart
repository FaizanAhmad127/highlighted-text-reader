import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/utils/connectivity_helper.dart';

void main() {
  test('wifi only is online', () {
    expect(
      ConnectivityHelper.isOffline([ConnectivityResult.wifi]),
      isFalse,
    );
  });

  test('none only is offline', () {
    expect(
      ConnectivityHelper.isOffline([ConnectivityResult.none]),
      isTrue,
    );
  });

  test('wifi plus a spurious none is still online', () {
    expect(
      ConnectivityHelper.isOffline([
        ConnectivityResult.wifi,
        ConnectivityResult.none,
      ]),
      isFalse,
    );
  });

  test('other interface (common on iOS) is online', () {
    expect(
      ConnectivityHelper.isOffline([ConnectivityResult.other]),
      isFalse,
    );
  });

  test('empty results are offline', () {
    expect(ConnectivityHelper.isOffline(const []), isTrue);
  });
}
