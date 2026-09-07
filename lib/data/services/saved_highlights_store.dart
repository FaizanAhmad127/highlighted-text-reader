import 'dart:async';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/saved_highlight.dart';

class SavedHighlightsWriteResult {
  const SavedHighlightsWriteResult({
    required this.savedCount,
    this.pendingSync = false,
  });

  final int savedCount;
  final bool pendingSync;
}

abstract class SavedHighlightsStore {
  Stream<List<SavedHighlight>> watch();
  Future<List<SavedHighlight>> current();
  Future<void> put(SavedHighlight item);
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  });
  Future<SavedHighlightsWriteResult> saveAll(
    List<Highlight> highlights, {
    required String meaningLanguageId,
    String? scanId,
  });
  Future<SavedHighlightsWriteResult> importAll(List<SavedHighlight> items);
  Future<void> delete(String id);
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  });
  Future<void> flushPendingSync();
}

class MemorySavedHighlightsStore implements SavedHighlightsStore {
  MemorySavedHighlightsStore({
    String Function()? idGenerator,
    DateTime Function()? clock,
  })  : _idGenerator = idGenerator ?? SavedHighlight.newId,
        _clock = clock ?? DateTime.now;

  final String Function() _idGenerator;
  final DateTime Function() _clock;
  final _controller = StreamController<List<SavedHighlight>>.broadcast();
  final List<SavedHighlight> _items = [];

  List<SavedHighlight> _snapshot() => List.unmodifiable(_items);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
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

  @override
  Stream<List<SavedHighlight>> watch() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<List<SavedHighlight>> current() async => _snapshot();

  @override
  Future<void> put(SavedHighlight item) async {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.add(item);
    }
    _emit();
  }

  @override
  Future<SavedHighlightsWriteResult> save(
    Highlight highlight, {
    required String meaningLanguageId,
    String? scanId,
  }) async {
    if (_isDuplicate(highlight, meaningLanguageId)) {
      return const SavedHighlightsWriteResult(savedCount: 0);
    }
    await put(_prepare(highlight, meaningLanguageId, scanId: scanId));
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
    var savedCount = 0;
    for (final item in items) {
      if (_isDuplicate(item.highlight, item.meaningLanguageId)) continue;
      await put(
        SavedHighlight(
          id: _idGenerator(),
          highlight: item.highlight,
          meaningLanguageId: item.meaningLanguageId,
          savedAt: item.savedAt,
          scanId: item.scanId,
        ),
      );
      savedCount++;
    }
    return SavedHighlightsWriteResult(savedCount: savedCount);
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Future<bool> isSaved(
    Highlight highlight, {
    required String meaningLanguageId,
  }) async {
    return _isDuplicate(highlight, meaningLanguageId);
  }

  @override
  Future<void> flushPendingSync() async {}
}
