import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/firebase/app_crashlytics.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/highlight.dart';
import '../../domain/entities/saved_highlight.dart';
import 'firestore_saved_highlights_store.dart';
import 'saved_highlights_store.dart';
import 'shared_prefs_saved_highlights_cache.dart';

class HybridSavedHighlightsRepository implements SavedHighlightsStore {
  HybridSavedHighlightsRepository({
    SharedPrefsSavedHighlightsCache? cache,
    SavedHighlightsStore? remote,
    String? Function()? currentUid,
    String Function()? idGenerator,
    DateTime Function()? clock,
    Stream<String?>? uidChanges,
  })  : _cache = cache ?? SharedPrefsSavedHighlightsCache(),
        _remote = remote ?? _defaultRemote(),
        _currentUid = currentUid ?? _defaultUid,
        _idGenerator = idGenerator ?? SavedHighlight.newId,
        _clock = clock ?? DateTime.now {
    if (uidChanges != null) {
      _uidSub = uidChanges.listen((uid) {
        AppCrashlytics.capture(
          _rebindToUid(uid),
          reason: 'saved_highlights_flush',
        );
      });
    }
  }

  static HybridSavedHighlightsRepository? _instance;

  static HybridSavedHighlightsRepository get instance {
    return _instance ??= HybridSavedHighlightsRepository();
  }

  static SavedHighlightsStore? _defaultRemote() {
    if (!FirebaseBootstrap.isSupported) return null;
    return FirestoreSavedHighlightsStore();
  }

  static String? _defaultUid() {
    if (!FirebaseBootstrap.isSupported) return null;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'auth_uid');
      return null;
    }
  }

  final SharedPrefsSavedHighlightsCache _cache;
  final SavedHighlightsStore? _remote;
  final String? Function() _currentUid;
  final String Function() _idGenerator;
  final DateTime Function() _clock;
  final _controller = StreamController<List<SavedHighlight>>.broadcast();
  final Set<String> _pendingDeletes = {};
  final Set<String> _syncedIds = {};

  List<SavedHighlight> _items = [];
  String? _boundUid;
  StreamSubscription<List<SavedHighlight>>? _remoteSub;
  StreamSubscription<dynamic>? _uidSub;
  StreamSubscription<User?>? _authSub;
  bool _started = false;

  List<SavedHighlight> _snapshot() => List.unmodifiable(_items);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  Future<void> _ensureStarted() async {
    if (!_started) {
      _started = true;
      _listenAuthIfPossible();
    }
    await _rebindToUid(_currentUid());
  }

  Future<void> _rebindToUid(String? uid) async {
    final next = (uid == null || uid.isEmpty) ? null : uid;
    if (_boundUid == next && _remoteSub != null) {
      AppCrashlytics.capture(
        _flushPendingUploads(),
        reason: 'saved_highlights_flush',
      );
      return;
    }
    if (_boundUid == next && next == null) return;

    await _remoteSub?.cancel();
    _remoteSub = null;
    _pendingDeletes.clear();
    _syncedIds.clear();
    _boundUid = next;
    _items = await _cache.readForUid(next);
    _emit();
    _listenRemoteIfPossible();
    if (next != null) {
      await _flushPendingUploads();
    }
  }

  void _listenAuthIfPossible() {
    if (_uidSub != null || _authSub != null) return;
    if (!FirebaseBootstrap.isSupported) return;
    try {
      if (Firebase.apps.isEmpty) return;
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        AppCrashlytics.capture(
          _rebindToUid(user?.uid),
          reason: 'saved_highlights_flush',
        );
      });
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'auth_watch');
    }
  }

  void _listenRemoteIfPossible() {
    if (_remoteSub != null) return;
    if (_boundUid == null || _boundUid!.isEmpty) return;
    final remote = _remote;
    if (remote == null) return;

    try {
      _remoteSub = remote.watch().listen(
        (remoteItems) {
          unawaited(_onRemoteItems(remoteItems));
        },
        onError: (Object error, StackTrace stack) {
          _logSyncError(error, stack, reason: 'saved_highlights_watch');
        },
      );
    } catch (error, stack) {
      _logSyncError(error, stack, reason: 'saved_highlights_watch');
    }
  }

  Future<void> _onRemoteItems(List<SavedHighlight> remoteItems) async {
    try {
      final remoteIds = remoteItems.map((item) => item.id).toSet();
      _syncedIds.addAll(remoteIds);
      final toUpload = _items
          .where(
            (item) =>
                !remoteIds.contains(item.id) &&
                !_pendingDeletes.contains(item.id),
          )
          .toList();

      _items = [
        ...remoteItems.where((item) => !_pendingDeletes.contains(item.id)),
        ...toUpload,
      ];
      await _cache.writeForUid(_boundUid, _items);
      _emit();

      final remote = _remote;
      if (remote == null) return;
      for (final item in toUpload) {
        unawaited(_putRemote(remote, item));
      }
      for (final id in _pendingDeletes.toList()) {
        unawaited(_deleteRemote(remote, id));
      }
    } catch (error, stack) {
      _logSyncError(error, stack, reason: 'saved_highlights_remote_merge');
    }
  }

  void _logSyncError(Object error, StackTrace stack, {required String reason}) {
    AppCrashlytics.record(error, stack, reason: reason);
  }

  Future<bool> _putRemote(
    SavedHighlightsStore remote,
    SavedHighlight item,
  ) async {
    try {
      await remote.put(item);
      _syncedIds.add(item.id);
      return true;
    } catch (error, stack) {
      _logSyncError(error, stack, reason: 'saved_highlights_put');
      return false;
    }
  }

  Future<bool> _deleteRemote(SavedHighlightsStore remote, String id) async {
    try {
      await remote.delete(id);
      _pendingDeletes.remove(id);
      _syncedIds.remove(id);
      return true;
    } catch (error, stack) {
      _logSyncError(error, stack, reason: 'saved_highlights_delete');
      return false;
    }
  }

  Future<bool> _putRemoteWithRetry(
    SavedHighlightsStore remote,
    SavedHighlight item,
  ) async {
    if (await _putRemote(remote, item)) return true;
    return _putRemote(remote, item);
  }

  Future<void> _flushPendingUploads() async {
    if (!_canSync) return;
    final remote = _remote!;
    for (final item in _items.toList()) {
      if (_syncedIds.contains(item.id) || _pendingDeletes.contains(item.id)) {
        continue;
      }
      await _putRemote(remote, item);
    }
    for (final id in _pendingDeletes.toList()) {
      await _deleteRemote(remote, id);
    }
  }

  bool _isDuplicate(Highlight highlight, String meaningLanguageId) {
    final key = SavedHighlight.dedupKeyFor(highlight.text, meaningLanguageId);
    return _items.any((item) => item.dedupKey == key);
  }

  SavedHighlight _prepare(
    Highlight highlight,
    String meaningLanguageId, {
    String? scanId,
  }) {
    return SavedHighlight(
      id: _idGenerator(),
      highlight: highlight,
      meaningLanguageId: meaningLanguageId,
      savedAt: _clock(),
      scanId: scanId,
    );
  }

  bool get _canSync {
    final uid = _currentUid();
    return _remote != null &&
        uid != null &&
        uid.isNotEmpty &&
        uid == _boundUid;
  }

  @override
  Stream<List<SavedHighlight>> watch() async* {
    await _ensureStarted();
    yield _snapshot();
    await _flushPendingUploads();
    yield* _controller.stream;
  }

  @override
  Future<List<SavedHighlight>> current() async {
    await _ensureStarted();
    AppCrashlytics.capture(
      _flushPendingUploads(),
      reason: 'saved_highlights_flush',
    );
    return _snapshot();
  }

  @override
  Future<void> flushPendingSync() async {
    await _ensureStarted();
    await _rebindToUid(_currentUid());
  }

  @override
  Future<void> put(SavedHighlight item) async {
    await _ensureStarted();
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    _syncedIds.remove(item.id);
    await _cache.writeForUid(_boundUid, _items);
    _emit();
    if (!_canSync) return;
    await _putRemoteWithRetry(_remote!, item);
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    await _ensureStarted();
    if (_isDuplicate(highlight, meaningLanguageId)) {
      return const SavedHighlightsWriteResult(savedCount: 0);
    }
    final item = _prepare(highlight, meaningLanguageId, scanId: scanId);
    _items = [..._items, item];
    await _cache.writeForUid(_boundUid, _items);
    _emit();

    var pendingSync = !_canSync;
    if (_canSync) {
      final uploaded = await _putRemoteWithRetry(_remote!, item);
      pendingSync = !uploaded;
    }
    return SavedHighlightsWriteResult(
      savedCount: 1,
      pendingSync: pendingSync,
    );
  }

  @override
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    await _ensureStarted();
    final prepared = <SavedHighlight>[];
    for (final highlight in highlights) {
      if (_isDuplicate(highlight, meaningLanguageId)) continue;
      final item = _prepare(
        highlight,
        meaningLanguageId,
        scanId: scanId,
      );
      _items = [..._items, item];
      prepared.add(item);
    }
    if (prepared.isEmpty) {
      return const SavedHighlightsWriteResult(savedCount: 0);
    }
    await _cache.writeForUid(_boundUid, _items);
    _emit();

    var pendingSync = !_canSync;
    if (_canSync) {
      for (final item in prepared) {
        final uploaded = await _putRemoteWithRetry(_remote!, item);
        if (!uploaded) pendingSync = true;
      }
    }
    return SavedHighlightsWriteResult(
      savedCount: prepared.length,
      pendingSync: pendingSync,
    );
  }

  @override
  Future<SavedHighlightsWriteResult> importAll(
    List<SavedHighlight> items,
  ) async {
    await _ensureStarted();
    final prepared = <SavedHighlight>[];
    for (final item in items) {
      if (_isDuplicate(item.highlight, item.meaningLanguageId)) continue;
      final next = SavedHighlight(
        id: _idGenerator(),
        highlight: item.highlight,
        meaningLanguageId: item.meaningLanguageId,
        savedAt: item.savedAt,
        scanId: item.scanId,
      );
      _items = [..._items, next];
      prepared.add(next);
    }
    if (prepared.isEmpty) {
      return const SavedHighlightsWriteResult(savedCount: 0);
    }
    await _cache.writeForUid(_boundUid, _items);
    _emit();

    var pendingSync = !_canSync;
    if (_canSync) {
      for (final item in prepared) {
        final uploaded = await _putRemoteWithRetry(_remote!, item);
        if (!uploaded) pendingSync = true;
      }
    }
    return SavedHighlightsWriteResult(
      savedCount: prepared.length,
      pendingSync: pendingSync,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _ensureStarted();
    _items = _items.where((item) => item.id != id).toList();
    _pendingDeletes.add(id);
    _syncedIds.remove(id);
    await _cache.writeForUid(_boundUid, _items);
    _emit();
    if (!_canSync) return;
    await _deleteRemote(_remote!, id);
  }

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async {
    await _ensureStarted();
    return _isDuplicate(highlight, meaningLanguageId);
  }
}
