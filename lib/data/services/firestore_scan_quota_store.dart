import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'scan_rate_limiter.dart';

/// Per-UID daily count in the dedicated `highlights` Firestore database.
/// Cooldown stays local so a reinstall only resets the 8s wait.
class FirestoreScanQuotaStore implements ScanQuotaStore {
  FirestoreScanQuotaStore({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    ScanQuotaStore? cooldownStore,
  })  : _firestore = firestore,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _cooldownStore = cooldownStore ?? SharedPrefsScanQuotaStore();

  static const databaseId = 'highlights';
  static const collectionId = 'scan_quota';

  final FirebaseFirestore? _firestore;
  final String? Function() _currentUid;
  final ScanQuotaStore _cooldownStore;

  FirebaseFirestore get _db =>
      _firestore ??
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _db.collection(collectionId).doc(uid);
  }

  Stream<void> snapshots() {
    return _doc(_requireUid()).snapshots().map((_) {});
  }

  String _requireUid() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Not signed in');
    }
    return uid;
  }

  @override
  Future<String?> readDayKey() async {
    final snap = await _doc(_requireUid()).get();
    if (!snap.exists) return null;
    return snap.data()?['day'] as String?;
  }

  @override
  Future<int> readCount() async {
    final snap = await _doc(_requireUid()).get();
    if (!snap.exists) return 0;
    return (snap.data()?['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<DateTime?> readLastAttempt() => _cooldownStore.readLastAttempt();

  @override
  Future<ScanQuotaOverride> readOverride() async {
    final snap = await _doc(_requireUid()).get();
    if (!snap.exists) return const ScanQuotaOverride();
    final data = snap.data();
    if (data == null) return const ScanQuotaOverride();
    final rawOverride = (data['maxOverride'] as num?)?.toInt();
    return ScanQuotaOverride(
      maxOverride: (rawOverride != null && rawOverride >= 1) ? rawOverride : null,
    );
  }

  /// Adds maxOverride=0 so it shows up in the Console, and drops leftover
  /// bonus fields. Does not change count. Clients cannot raise the cap.
  Future<void> ensureAdminPlaceholders() async {
    final ref = _doc(_requireUid());
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final update = <String, Object>{};
      if (!data.containsKey('maxOverride')) update['maxOverride'] = 0;
      if (data.containsKey('bonus')) update['bonus'] = FieldValue.delete();
      if (data.containsKey('bonusDay')) update['bonusDay'] = FieldValue.delete();
      if (update.isEmpty) return;

      update['updatedAt'] = FieldValue.serverTimestamp();
      transaction.update(ref, update);
    });
  }

  @override
  Future<void> write({
    required String dayKey,
    required int count,
    required DateTime lastAttempt,
  }) async {
    final uid = _requireUid();
    final ref = _doc(uid);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        transaction.set(ref, {
          'day': dayKey,
          'count': 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'maxOverride': 0,
        });
        return;
      }

      final data = snap.data() ?? {};
      final storedDay = data['day'] as String?;
      final storedCount = (data['count'] as num?)?.toInt() ?? 0;
      final nextCount = storedDay == dayKey ? storedCount + 1 : 1;

      final update = <String, Object>{
        'day': dayKey,
        'count': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!data.containsKey('maxOverride')) update['maxOverride'] = 0;
      if (data.containsKey('bonus')) update['bonus'] = FieldValue.delete();
      if (data.containsKey('bonusDay')) update['bonusDay'] = FieldValue.delete();

      transaction.update(ref, update);
    });

    await _cooldownStore.write(
      dayKey: dayKey,
      count: count,
      lastAttempt: lastAttempt,
    );
  }
}
