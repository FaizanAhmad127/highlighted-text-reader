import 'package:connectivity_plus/connectivity_plus.dart';

/// Network availability via connectivity_plus (Wi‑Fi / mobile / none).
class ConnectivityHelper {
  ConnectivityHelper._();

  static final Connectivity _connectivity = Connectivity();

  static Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return hasActiveInterface(results);
  }

  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// iOS can include `none` alongside wifi/mobile. Any real interface means online.
  static bool hasActiveInterface(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  static bool isOffline(List<ConnectivityResult> results) =>
      !hasActiveInterface(results);
}
