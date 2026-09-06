import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/constants/app_constants.dart';
import 'firestore_scan_quota_store.dart';

/// Global daily scan cap in the dedicated `highlights` Firestore database.
/// Clients may read and listen. Writes are Console / Admin SDK only.
class FirestoreScanLimitsStore {
  FirestoreScanLimitsStore({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const collectionId = 'settings';
  static const documentId = 'scan_limits';
  static const maxScansPerDayField = 'maxScansPerDay';

  final FirebaseFirestore? _firestore;
  int _cachedMax = AppConstants.maxScansPerDay;

  int get maxScansPerDay => _cachedMax;

  FirebaseFirestore get _db =>
      _firestore ??
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: FirestoreScanQuotaStore.databaseId,
      );

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection(collectionId).doc(documentId);

  static int parseMaxScansPerDay(Map<String, dynamic>? data) {
    final value = (data?[maxScansPerDayField] as num?)?.toInt();
    if (value == null || value < 0 || value > 10000) {
      return AppConstants.maxScansPerDay;
    }
    return value;
  }

  Future<int> read() async {
    final snap = await _doc.get();
    _cachedMax = parseMaxScansPerDay(snap.data());
    return _cachedMax;
  }

  Stream<int> snapshots() {
    return _doc.snapshots().map((snap) {
      _cachedMax = parseMaxScansPerDay(snap.data());
      return _cachedMax;
    });
  }
}
