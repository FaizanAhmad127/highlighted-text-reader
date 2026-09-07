import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/saved_highlight.dart';
import 'saved_highlights_store.dart';

class FirestoreSavedHighlightsStore implements SavedHighlightsStore {
  FirestoreSavedHighlightsStore({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    String Function()? idGenerator,
    DateTime Function()? clock,
  })  : _firestore = firestore,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _idGenerator = idGenerator ?? SavedHighlight.newId,
        _clock = clock ?? DateTime.now;

  static const databaseId = 'highlights';
  static const collectionId = 'saved_highlights';
  static const itemsCollectionId = 'items';

  final FirebaseFirestore? _firestore;
  final String? Function() _currentUid;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  FirebaseFirestore get _db =>
      _firestore ??
      FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );

  CollectionReference<Map<String, dynamic>> _items(String uid) {
    return _db.collection(collectionId).doc(uid).collection(itemsCollectionId);
  }

  String _requireUid() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Not signed in');
    }
    return uid;
  }

  SavedHighlight _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _fromData(doc.id, doc.data());
  }

  SavedHighlight _fromData(String id, Map<String, dynamic> data) {
    return SavedHighlight(
      id: id,
      highlight: Highlight(
        text: data['text'] as String? ?? '',
        literal: data['literal'] as String? ?? '',
        contextual: data['contextual'] as String? ?? '',
        color: data['color'] as String? ?? '',
      ),
      meaningLanguageId: data['meaningLanguageId'] as String? ?? '',
      savedAt: _parseSavedAt(data['savedAt']),
      scanId: _optionalScanId(data['scanId']),
    );
  }

  static String? _optionalScanId(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  static DateTime _parseSavedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }

  /// Rule-shaped fields before `savedAt` is converted to a Firestore Timestamp.
  static Map<String, Object> documentFields(SavedHighlight item) {
    return {
      'text': item.text,
      'literal': item.literal,
      'contextual': item.contextual,
      'color': item.color,
      'meaningLanguageId': item.meaningLanguageId,
      'savedAt': item.savedAt.toUtc(),
      if (item.scanId != null && item.scanId!.isNotEmpty) 'scanId': item.scanId!,
    };
  }

  Map<String, dynamic> _toData(SavedHighlight item) {
    final data = Map<String, dynamic>.from(documentFields(item));
    data['savedAt'] = Timestamp.fromDate(item.savedAt.toUtc());
    return data;
  }

  @override
  Stream<List<SavedHighlight>> watch() {
    return _items(_requireUid()).snapshots().map((snapshot) {
      return snapshot.docs.map(_fromDoc).toList();
    });
  }

  @override
  Future<List<SavedHighlight>> current() async {
    final snapshot = await _items(_requireUid()).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> put(SavedHighlight item) async {
    await _items(_requireUid()).doc(item.id).set(_toData(item));
  }

  bool _isDuplicate(List<SavedHighlight> items, Highlight highlight, String lang) {
    final key = SavedHighlight.dedupKeyFor(highlight.text, lang);
    return items.any((item) => item.dedupKey == key);
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    final existing = await current();
    if (_isDuplicate(existing, highlight, meaningLanguageId)) {
      return const SavedHighlightsWriteResult(savedCount: 0);
    }
    await put(
      SavedHighlight(
        id: _idGenerator(),
        highlight: highlight,
        meaningLanguageId: meaningLanguageId,
        savedAt: _clock(),
        scanId: scanId,
      ),
    );
    return const SavedHighlightsWriteResult(savedCount: 1);
  }

  @override
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    var savedCount = 0;
    for (final highlight in highlights) {
      final result = await save(
        highlight,
        meaningLanguageId: meaningLanguageId,
        scanId: scanId,
      );
      savedCount += result.savedCount;
    }
    return SavedHighlightsWriteResult(savedCount: savedCount);
  }

  @override
  Future<SavedHighlightsWriteResult> importAll(
    List<SavedHighlight> items,
  ) async {
    final existing = await current();
    var savedCount = 0;
    for (final item in items) {
      if (_isDuplicate(existing, item.highlight, item.meaningLanguageId)) {
        continue;
      }
      final next = SavedHighlight(
        id: _idGenerator(),
        highlight: item.highlight,
        meaningLanguageId: item.meaningLanguageId,
        savedAt: item.savedAt,
        scanId: item.scanId,
      );
      await put(next);
      existing.add(next);
      savedCount++;
    }
    return SavedHighlightsWriteResult(savedCount: savedCount);
  }

  @override
  Future<void> delete(String id) async {
    await _items(_requireUid()).doc(id).delete();
  }

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async {
    return _isDuplicate(await current(), highlight, meaningLanguageId);
  }

  @override
  Future<void> flushPendingSync() async {}
}
