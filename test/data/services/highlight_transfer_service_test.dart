import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/highlight_transfer_payload.dart';
import 'package:highlighted_text_reader/data/services/highlight_transfer_service.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/domain/entities/saved_highlight.dart';

void main() {
  const phrase = Highlight(
    text: 'serendipity',
    literal: 'happy accident',
    contextual: 'a pleasant surprise',
    color: '0xFFE8C547',
  );

  final item = SavedHighlight(
    id: 'src-1',
    highlight: phrase,
    meaningLanguageId: 'en',
    savedAt: DateTime.utc(2026, 9, 1, 12),
  );

  late MemoryHighlightTransferStore store;
  late HighlightTransferService service;
  var now = DateTime.utc(2026, 9, 7, 18);

  setUp(() {
    store = MemoryHighlightTransferStore();
    now = DateTime.utc(2026, 9, 7, 18);
    service = HighlightTransferService(
      store: store,
      currentUid: () => 'uid-a',
      clock: () => now,
      idGenerator: () => 'Abcdefghij0123456789-_',
    );
  });

  test('create writes metadata and items then returns a QR payload', () async {
    final session = await service.create([item]);

    expect(session.itemCount, 1);
    expect(session.qrPayload, 'htr1:Abcdefghij0123456789-_');
    expect(session.expiresAt, now.add(HighlightTransferPayload.ttl));

    final record = await store.read(session.id);
    expect(record, isNotNull);
    expect(record!.createdBy, 'uid-a');
    expect(record.items.single.text, 'serendipity');
  });

  test('create rejects an empty or oversized library', () async {
    expect(
      () => service.create(const []),
      throwsA(
        isA<HighlightTransferException>().having(
          (e) => e.error,
          'error',
          HighlightTransferError.empty,
        ),
      ),
    );

    final tooMany = List.generate(
      HighlightTransferPayload.maxItems + 1,
      (i) => SavedHighlight(
        id: 'id-$i',
        highlight: phrase,
        meaningLanguageId: 'en',
        savedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    expect(
      () => service.create(tooMany),
      throwsA(
        isA<HighlightTransferException>().having(
          (e) => e.error,
          'error',
          HighlightTransferError.tooLarge,
        ),
      ),
    );
  });

  test('fetchFromQr returns items for an unexpired transfer', () async {
    await service.create([item]);

    final items = await service.fetchFromQr('htr1:Abcdefghij0123456789-_');

    expect(items, hasLength(1));
    expect(items.single.meaningLanguageId, 'en');
    expect(items.single.savedAt, item.savedAt);
  });

  test('fetchFromQr rejects a missing, expired, or invalid QR', () async {
    expect(
      () => service.fetchFromQr('not-a-qr'),
      throwsA(
        isA<HighlightTransferException>().having(
          (e) => e.error,
          'error',
          HighlightTransferError.invalidQr,
        ),
      ),
    );
    expect(
      () => service.fetchFromQr('htr1:zzzzzzzzzzzzzzzzzzzzzz'),
      throwsA(
        isA<HighlightTransferException>().having(
          (e) => e.error,
          'error',
          HighlightTransferError.notFound,
        ),
      ),
    );

    await service.create([item]);
    now = now.add(HighlightTransferPayload.ttl);
    expect(
      () => service.fetchFromQr('htr1:Abcdefghij0123456789-_'),
      throwsA(
        isA<HighlightTransferException>().having(
          (e) => e.error,
          'error',
          HighlightTransferError.expired,
        ),
      ),
    );
  });
}
