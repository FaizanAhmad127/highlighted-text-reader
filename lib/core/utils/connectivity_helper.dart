import 'package:connectivity_plus/connectivity_plus.dart';

/// Network availability via connectivity_plus (Wi‑Fi / mobile / none).
class ConnectivityHelper {
  ConnectivityHelper._();

  static final Connectivity _connectivity = Connectivity();

  static Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  static bool isOffline(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.none);
}
