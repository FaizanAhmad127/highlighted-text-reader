import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/firebase/saved_highlights_identity.dart';
import 'package:highlighted_text_reader/data/services/firestore_saved_highlights_store.dart';
import 'package:highlighted_text_reader/data/services/hybrid_saved_highlights_repository.dart';
import 'package:highlighted_text_reader/data/services/saved_highlights_store.dart';
import 'package:highlighted_text_reader/data/services/shared_prefs_saved_highlights_cache.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/saved_highlight.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const phrase = Highlight(
    text: '  Serendipity  ',
    literal: 'happy accident',
    contextual: 'a pleasant surprise',
    color: '0xFFE8C547',
  );

  const other = Highlight(
    text: 'eloquent',
    literal: 'fluent',
    contextual: 'spoke eloquently',
    color: '0xFF4CAF50',
  );

  group('MemorySavedHighlightsStore', () {
    late MemorySavedHighlightsStore store;
    var ids = 0;
    var now = DateTime(2026, 9, 7, 12, 0);

    setUp(() {
      ids = 0;
      now = DateTime(2026, 9, 7, 12, 0);
      store = MemorySavedHighlightsStore(
        idGenerator: () => 'id-${++ids}',
        clock: () => now,
      );
    });

    test('save skips a duplicate phrase and meaning language', () async {
      final first = await store.save(phrase, meaningLanguageId: 'en');
      final second = await store.save(phrase, meaningLanguageId: 'en');

      expect(first.savedCount, 1);
      expect(second.savedCount, 0);
      expect(await store.isSaved(phrase, meaningLanguageId: 'en'), isTrue);
      expect(await store.current(), hasLength(1));
    });

    test('same phrase in another meaning language is not a duplicate', () async {
      await store.save(phrase, meaningLanguageId: 'en');
      final otherLang = await store.save(phrase, meaningLanguageId: 'ur');

      expect(otherLang.savedCount, 1);
      expect(await store.current(), hasLength(2));
    });

    test('saveAll skips phrases already saved for that language', () async {
      await store.save(phrase, meaningLanguageId: 'en');
      now = now.add(const Duration(minutes: 1));

      final result = await store.saveAll(
        [phrase, other],
        meaningLanguageId: 'en',
      );

      expect(result.savedCount, 1);
      final items = await store.current();
      expect(items.map((e) => e.text), ['  Serendipity  ', 'eloquent']);
    });

    test('save persists scanId on the stored item', () async {
      await store.save(phrase, meaningLanguageId: 'en', scanId: 'scan-1');

      expect((await store.current()).single.scanId, 'scan-1');
    });

    test('saveAll uses the same scanId for every new item', () async {
      await store.saveAll(
        [phrase, other],
        meaningLanguageId: 'en',
        scanId: 'scan-9',
      );

      final items = await store.current();
      expect(items, hasLength(2));
      expect(items.every((item) => item.scanId == 'scan-9'), isTrue);
    });

    test('delete removes the item', () async {
      await store.save(phrase, meaningLanguageId: 'en');
      final id = (await store.current()).single.id;

      await store.delete(id);

      expect(await store.current(), isEmpty);
      expect(await store.isSaved(phrase, meaningLanguageId: 'en'), isFalse);
    });

    test('watch emits the current list after saves', () async {
      final events = <int>[];
      final sub = store.watch().listen((items) => events.add(items.length));
      await Future<void>.delayed(Duration.zero);

      await store.save(phrase, meaningLanguageId: 'en');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events.first, 0);
      expect(events.last, 1);
    });
  });

  group('SharedPrefsSavedHighlightsCache', () {
    test('round-trips a saved highlight through JSON', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = SharedPrefsSavedHighlightsCache();
      final item = SavedHighlight(
        id: 'abc',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 9, 7, 12, 0),
      );

      await cache.writeForUid('uid-1', [item]);
      final loaded = await cache.readForUid('uid-1');

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'abc');
      expect(loaded.single.text, phrase.text);
      expect(loaded.single.literal, phrase.literal);
      expect(loaded.single.contextual, phrase.contextual);
      expect(loaded.single.color, phrase.color);
      expect(loaded.single.meaningLanguageId, 'en');
      expect(loaded.single.savedAt.toUtc(), item.savedAt.toUtc());
      expect(loaded.single.scanId, isNull);
    });

    test('round-trips scanId and loads legacy JSON without it', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = SharedPrefsSavedHighlightsCache();
      final item = SavedHighlight(
        id: 'scan-item',
        highlight: phrase,
        meaningLanguageId: 'ur',
        savedAt: DateTime.utc(2026, 9, 7, 12, 0),
        scanId: 'scan-42',
      );

      await cache.writeForUid('uid-1', [item]);
      final loaded = await cache.readForUid('uid-1');

      expect(loaded.single.scanId, 'scan-42');
      expect(loaded.single.meaningLanguageId, 'ur');

      final legacy = SavedHighlight.fromJson({
        'id': 'old',
        'text': phrase.text,
        'literal': phrase.literal,
        'contextual': phrase.contextual,
        'color': phrase.color,
        'meaningLanguageId': 'en',
        'savedAt': DateTime.utc(2026, 9, 7, 12, 0).toIso8601String(),
      });
      expect(legacy.scanId, isNull);
    });

    test('does not adopt leftover cache when no user was signed in at start',
        () async {
      final cached = SavedHighlight(
        id: 'legacy-1',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 9, 7, 13, 28),
      );
      SavedHighlightsIdentity.reset();
      SharedPreferences.setMockInitialValues({
        SharedPrefsSavedHighlightsCache.prefsKey: jsonEncode([cached.toJson()]),
      });

      final loaded =
          await SharedPrefsSavedHighlightsCache().readForUid('new-uid');

      expect(loaded, isEmpty);
    });
  });

  group('Firestore saved-highlight payload', () {
    const allowedKeys = {
      'text',
      'literal',
      'contextual',
      'color',
      'meaningLanguageId',
      'savedAt',
      'scanId',
    };

    SavedHighlight sample({
      required String text,
      required String meaningLanguageId,
      String? scanId,
    }) {
      return SavedHighlight(
        id: '910016a4-2a30-4ea0-bc57-959929074049',
        highlight: Highlight(
          text: text,
          literal: 'literal',
          contextual: 'contextual',
          color: '0xFFFFEB3B',
        ),
        meaningLanguageId: meaningLanguageId,
        savedAt: DateTime.utc(2026, 9, 7, 15, 46, 12),
        scanId: scanId,
      );
    }

    void expectRulesShaped(Map<String, Object> data) {
      expect(data.keys.toSet().difference(allowedKeys), isEmpty);
      expect(data.keys, containsAll(allowedKeys.difference({'scanId'})));
      expect(data['text'], isA<String>());
      expect((data['text'] as String).isNotEmpty, isTrue);
      expect((data['text'] as String).length, lessThanOrEqualTo(5000));
      expect(data['literal'], isA<String>());
      expect((data['literal'] as String).length, lessThanOrEqualTo(5000));
      expect(data['contextual'], isA<String>());
      expect((data['contextual'] as String).length, lessThanOrEqualTo(5000));
      expect(data['color'], isA<String>());
      expect((data['color'] as String).length, inInclusiveRange(1, 32));
      expect(data['meaningLanguageId'], isA<String>());
      expect(
        (data['meaningLanguageId'] as String).length,
        inInclusiveRange(1, 16),
      );
      expect(data['savedAt'], isA<DateTime>());
      if (data.containsKey('scanId')) {
        expect(data['scanId'], isA<String>());
        expect((data['scanId'] as String).length, inInclusiveRange(1, 64));
      }
    }

    test('encodes optional scanId and unicode text for ar/en/match', () {
      final arabic = FirestoreSavedHighlightsStore.documentFields(
        sample(
          text: 'پیار نہیں کرتا ہو گا',
          meaningLanguageId: 'ar',
          scanId: 'dbd09264-aaaa-bbbb-cccc-ddddeeeeffff',
        ),
      );
      final spanish = FirestoreSavedHighlightsStore.documentFields(
        sample(
          text: '¡No me lo puedo creer!',
          meaningLanguageId: 'en',
          scanId: '8fcb7f32-aaaa-bbbb-cccc-ddddeeeeffff',
        ),
      );
      final matched = FirestoreSavedHighlightsStore.documentFields(
        sample(
          text: 'پھر کیا ہوا؟',
          meaningLanguageId: 'match',
        ),
      );

      expectRulesShaped(arabic);
      expectRulesShaped(spanish);
      expectRulesShaped(matched);
      expect(arabic['scanId'], 'dbd09264-aaaa-bbbb-cccc-ddddeeeeffff');
      expect(spanish['meaningLanguageId'], 'en');
      expect(matched.containsKey('scanId'), isFalse);
    });
  });

  group('HybridSavedHighlightsRepository', () {
    late MemorySavedHighlightsStore remote;
    late HybridSavedHighlightsRepository store;
    var ids = 0;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('uid-1');
      ids = 0;
      remote = MemorySavedHighlightsStore(
        idGenerator: () => 'remote-${++ids}',
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );
      store = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => 'uid-1',
        idGenerator: () => 'local-${++ids}',
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );
    });

    test('keeps a local write when Firestore put fails', () async {
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: _ThrowingSavedHighlightsStore(),
        currentUid: () => 'uid-1',
        idGenerator: () => 'offline-1',
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );

      final result = await hybrid.save(phrase, meaningLanguageId: 'en');

      expect(result.savedCount, 1);
      expect(result.pendingSync, isTrue);
      expect(await hybrid.isSaved(phrase, meaningLanguageId: 'en'), isTrue);
      expect(await hybrid.current(), hasLength(1));
    });

    test('dedups across saveAll using phrase text and language', () async {
      final first = await store.save(phrase, meaningLanguageId: 'en');
      final all = await store.saveAll([phrase, other], meaningLanguageId: 'en');

      expect(first.savedCount, 1);
      expect(all.savedCount, 1);
      expect(await store.current(), hasLength(2));
    });

    test('watch uploads cache-only items when remote never emits', () async {
      final cached = SavedHighlight(
        id: '910016a4-2a30-4ea0-bc57-959929074049',
        highlight: const Highlight(
          text: 'پیار نہیں کرتا ہو گا',
          literal: 'he will not love',
          contextual: 'he probably does not love',
          color: '0xFFFFEB3B',
        ),
        meaningLanguageId: 'ar',
        savedAt: DateTime.utc(2026, 9, 7, 15, 46),
        scanId: 'dbd09264-aaaa-bbbb-cccc-ddddeeeeffff',
      );
      SharedPreferences.setMockInitialValues({
        SharedPrefsSavedHighlightsCache.prefsKey: jsonEncode([cached.toJson()]),
      });
      final remote = _SilentRemote();
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => 'uid-1',
      );

      final sub = hybrid.watch().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(remote.uploaded.map((item) => item.id), [cached.id]);
      expect(remote.uploaded.single.scanId, cached.scanId);
    });

    test('put failure sets pendingSync and later retry succeeds', () async {
      final remote = _FailThenSucceedStore(failuresRemaining: 2);
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => 'uid-1',
        idGenerator: () => 'pending-1',
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );

      final result = await hybrid.save(
        phrase,
        meaningLanguageId: 'en',
        scanId: 'scan-retry',
      );

      expect(result.savedCount, 1);
      expect(result.pendingSync, isTrue);
      expect(remote.uploaded, isEmpty);

      await hybrid.flushPendingSync();

      expect(remote.uploaded, hasLength(1));
      expect(remote.uploaded.single.scanId, 'scan-retry');
      expect(await hybrid.current(), hasLength(1));
    });

    test('does not upload previous user cache after uid change', () async {
      var uid = 'old-uid';
      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('old-uid');
      final remote = _SilentRemote();
      final uidChanges = StreamController<String?>();
      addTearDown(uidChanges.close);
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => uid,
        uidChanges: uidChanges.stream,
        idGenerator: () => 'owned-1',
        clock: () => DateTime(2026, 9, 7, 12, 0),
      );

      await hybrid.save(phrase, meaningLanguageId: 'en', scanId: 'scan-old');
      expect(remote.putCount, 1);
      expect(await hybrid.current(), hasLength(1));

      uid = 'new-uid';
      uidChanges.add('new-uid');
      await Future<void>.delayed(Duration.zero);
      await hybrid.flushPendingSync();

      expect(await hybrid.current(), isEmpty);
      expect(remote.putCount, 1);
    });

    test('does not adopt legacy cache when process started as another user', () async {
      final cached = SavedHighlight(
        id: 'legacy-1',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 9, 7, 13, 28),
        scanId: 'f20a69d5-2bc0-419a-9f10-c66e6cde0e1f',
      );
      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('cQC44fZuDyRQmHZsZfjyfG0gIj52');
      SharedPreferences.setMockInitialValues({
        SharedPrefsSavedHighlightsCache.prefsKey: jsonEncode([cached.toJson()]),
      });
      final remote = _SilentRemote();
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => '2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2',
      );

      expect(await hybrid.current(), isEmpty);
      expect(remote.putCount, 0);
    });

    test('does not upload leftover cache after a later launch as the replacement user',
        () async {
      final cached = SavedHighlight(
        id: 'legacy-1',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 9, 7, 13, 28),
        scanId: 'f20a69d5-2bc0-419a-9f10-c66e6cde0e1f',
      );
      SharedPreferences.setMockInitialValues({
        SharedPrefsSavedHighlightsCache.prefsKey: jsonEncode([cached.toJson()]),
      });

      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('cQC44fZuDyRQmHZsZfjyfG0gIj52');
      final firstRemote = _SilentRemote();
      final first = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: firstRemote,
        currentUid: () => '2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2',
      );
      expect(await first.current(), isEmpty);
      expect(firstRemote.putCount, 0);

      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2');
      final secondRemote = _SilentRemote();
      final second = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: secondRemote,
        currentUid: () => '2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2',
      );

      expect(await second.current(), isEmpty);
      expect(secondRemote.putCount, 0);
    });

    test('does not adopt leftover cache owned by another uid', () async {
      final cached = SavedHighlight(
        id: 'legacy-owned',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 9, 7, 13, 28),
      );
      SavedHighlightsIdentity.reset();
      SavedHighlightsIdentity.capture('2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2');
      SharedPreferences.setMockInitialValues({
        SharedPrefsSavedHighlightsCache.prefsKey: jsonEncode([cached.toJson()]),
        SharedPrefsSavedHighlightsCache.ownerKey: 'cQC44fZuDyRQmHZsZfjyfG0gIj52',
      });
      final remote = _SilentRemote();
      final hybrid = HybridSavedHighlightsRepository(
        cache: SharedPrefsSavedHighlightsCache(),
        remote: remote,
        currentUid: () => '2FgkGQ7dQDZQ2uuEXqYuh0V1vsa2',
      );

      expect(await hybrid.current(), isEmpty);
      expect(remote.putCount, 0);
    });
  });
}

class _SilentRemote implements SavedHighlightsStore {
  final uploaded = <SavedHighlight>[];
  int putCount = 0;

  @override
  Stream<List<SavedHighlight>> watch() => const Stream.empty();

  @override
  Future<List<SavedHighlight>> current() async => List.unmodifiable(uploaded);

  @override
  Future<void> put(SavedHighlight item) async {
    putCount += 1;
    uploaded
      ..removeWhere((existing) => existing.id == item.id)
      ..add(item);
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw UnsupportedError('use put');
  }

  @override
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw UnsupportedError('use put');
  }

  @override
  Future<void> delete(String id) async {
    uploaded.removeWhere((item) => item.id == id);
  }

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async =>
      false;

  @override
  Future<void> flushPendingSync() async {}
}

class _FailThenSucceedStore implements SavedHighlightsStore {
  _FailThenSucceedStore({required this.failuresRemaining});

  int failuresRemaining;
  final uploaded = <SavedHighlight>[];

  @override
  Stream<List<SavedHighlight>> watch() => const Stream.empty();

  @override
  Future<List<SavedHighlight>> current() async => List.unmodifiable(uploaded);

  @override
  Future<void> put(SavedHighlight item) async {
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('PERMISSION_DENIED: scanId not allowed');
    }
    uploaded
      ..removeWhere((existing) => existing.id == item.id)
      ..add(item);
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw UnsupportedError('use put');
  }

  @override
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw UnsupportedError('use put');
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async =>
      false;

  @override
  Future<void> flushPendingSync() async {}
}

class _ThrowingSavedHighlightsStore implements SavedHighlightsStore {
  @override
  Stream<List<SavedHighlight>> watch() async* {}

  @override
  Future<List<SavedHighlight>> current() async => const [];

  @override
  Future<void> put(SavedHighlight item) async {
    throw StateError('offline');
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw StateError('offline');
  }

  @override
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    throw StateError('offline');
  }

  @override
  Future<void> delete(String id) async {
    throw StateError('offline');
  }

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async =>
      false;

  @override
  Future<void> flushPendingSync() async {}
}
