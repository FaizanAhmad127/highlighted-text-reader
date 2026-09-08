import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/saved_highlight.dart';
import 'firestore_saved_highlights_store.dart';
import 'highlight_transfer_payload.dart';

enum HighlightTransferError { empty, tooLarge, notFound, expired, invalidQr }

class HighlightTransferException implements Exception {
  const HighlightTransferException(this.error);

  final HighlightTransferError error;

  @override
  String toString() => 'HighlightTransferException.$error';
}

class HighlightTransferSession {
  const HighlightTransferSession({
    required this.id,
    required this.expiresAt,
    required this.itemCount,
  });

  final String id;
  final DateTime expiresAt;
  final int itemCount;

  String get qrPayload => HighlightTransferPayload.encode(id);
}

class HighlightTransferRecord {
  const HighlightTransferRecord({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.items,
  });

  final String id;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<SavedHighlight> items;

  int get itemCount => items.length;
}

abstract class HighlightTransferStore {
  Future<void> write(HighlightTransferRecord record);
  Future<HighlightTransferRecord?> read(String id);
}

class HighlightTransferService {
  HighlightTransferService({
    HighlightTransferStore? store,
    String? Function()? currentUid,
    DateTime Function()? clock,
  })  : _store = store ?? FirestoreHighlightTransferStore(),
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _clock = clock ?? DateTime.now;

  final HighlightTransferStore _store;
  final String? Function() _currentUid;
  final DateTime Function() _clock;

  Future<HighlightTransferSession> create(List<SavedHighlight> items) async {
    if (items.isEmpty) {
      throw const HighlightTransferException(HighlightTransferError.empty);
    }
    if (items.length > HighlightTransferPayload.maxItems) {
      throw const HighlightTransferException(HighlightTransferError.tooLarge);
    }
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw const HighlightTransferException(HighlightTransferError.notFound);
    }
    final now = _clock().toUtc();
    final record = HighlightTransferRecord(
      id: uid,
      createdBy: uid,
      createdAt: now,
      expiresAt: now.add(HighlightTransferPayload.ttl),
      items: List.unmodifiable(items),
    );
    await _store.write(record);
    return HighlightTransferSession(
      id: record.id,
      expiresAt: record.expiresAt,
      itemCount: record.itemCount,
    );
  }

  Future<List<SavedHighlight>> fetchFromQr(String raw) async {
    final id = HighlightTransferPayload.tryParse(raw);
    if (id == null) {
      throw const HighlightTransferException(HighlightTransferError.invalidQr);
    }
    return fetch(id);
  }

  Future<List<SavedHighlight>> fetch(String transferId) async {
    final record = await _store.read(transferId);
    if (record == null) {
      throw const HighlightTransferException(HighlightTransferError.notFound);
    }
    if (!record.expiresAt.toUtc().isAfter(_clock().toUtc())) {
      throw const HighlightTransferException(HighlightTransferError.expired);
    }
    return record.items;
  }
}

class MemoryHighlightTransferStore implements HighlightTransferStore {
  final Map<String, HighlightTransferRecord> _records = {};

  int get recordCount => _records.length;

  @override
  Future<void> write(HighlightTransferRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<HighlightTransferRecord?> read(String id) async => _records[id];
}

class FirestoreHighlightTransferStore implements HighlightTransferStore {
  FirestoreHighlightTransferStore({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const collectionId = 'highlight_transfers';
  static const itemsCollectionId = 'items';

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db =>
      _firestore ??
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: FirestoreSavedHighlightsStore.databaseId,
      );

  @override
  Future<void> write(HighlightTransferRecord record) async {
    final doc = _db.collection(collectionId).doc(record.id);
    final previousIds = await _previousItemIds(doc);
    final nextIds = [for (final item in record.items) item.id];
    final nextIdSet = nextIds.toSet();
    await doc.set({
      'createdBy': record.createdBy,
      'createdAt': Timestamp.fromDate(record.createdAt.toUtc()),
      'expiresAt': Timestamp.fromDate(record.expiresAt.toUtc()),
      'itemCount': record.itemCount,
      'itemIds': nextIds,
    });
    final batch = _db.batch();
    for (final id in previousIds) {
      if (!nextIdSet.contains(id)) {
        batch.delete(doc.collection(itemsCollectionId).doc(id));
      }
    }
    for (final item in record.items) {
      final fields = Map<String, Object>.from(
        FirestoreSavedHighlightsStore.documentFields(item),
      );
      fields['savedAt'] = Timestamp.fromDate(item.savedAt.toUtc());
      batch.set(doc.collection(itemsCollectionId).doc(item.id), fields);
    }
    await batch.commit();
  }

  Future<Set<String>> _previousItemIds(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final existing = await doc.collection(itemsCollectionId).get();
    return {for (final item in existing.docs) item.id};
  }

  @override
  Future<HighlightTransferRecord?> read(String id) async {
    final doc = await _db.collection(collectionId).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    final itemIds = [
      for (final id in data['itemIds'] as List? ?? const [])
        if (id is String && id.isNotEmpty) id,
    ];
    final items = <SavedHighlight>[];
    for (final itemId in itemIds) {
      final itemDoc =
          await doc.reference.collection(itemsCollectionId).doc(itemId).get();
      if (!itemDoc.exists) continue;
      items.add(_itemFromData(itemDoc.id, itemDoc.data() ?? {}));
    }
    return HighlightTransferRecord(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _parseTime(data['createdAt']),
      expiresAt: _parseTime(data['expiresAt']),
      items: items,
    );
  }

  SavedHighlight _itemFromData(String id, Map<String, dynamic> data) {
    return SavedHighlight(
      id: id,
      highlight: Highlight(
        text: data['text'] as String? ?? '',
        literal: data['literal'] as String? ?? '',
        contextual: data['contextual'] as String? ?? '',
        color: data['color'] as String? ?? '',
      ),
      meaningLanguageId: data['meaningLanguageId'] as String? ?? '',
      savedAt: _parseTime(data['savedAt']),
      scanId: _optionalScanId(data['scanId']),
    );
  }

  static String? _optionalScanId(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  static DateTime _parseTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
