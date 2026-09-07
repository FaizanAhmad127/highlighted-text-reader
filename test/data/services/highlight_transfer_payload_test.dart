import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/highlight_transfer_payload.dart';

void main() {
  test('encodes and parses a valid transfer id', () {
    const id = 'Abcdefghij0123456789-_';
    expect(id.length, HighlightTransferPayload.idLength);

    final payload = HighlightTransferPayload.encode(id);

    expect(payload, 'htr1:$id');
    expect(HighlightTransferPayload.tryParse(payload), id);
    expect(HighlightTransferPayload.tryParse('  $payload  '), id);
  });

  test('rejects payloads that are not this app’s transfer format', () {
    expect(HighlightTransferPayload.tryParse(''), isNull);
    expect(HighlightTransferPayload.tryParse('https://example.com'), isNull);
    expect(HighlightTransferPayload.tryParse('htr1:short'), isNull);
    expect(
      HighlightTransferPayload.tryParse('htr1:Abcdefghij0123456789!@'),
      isNull,
    );
  });

  test('newId is 22 url-safe characters', () {
    final id = HighlightTransferPayload.newId();
    expect(id.length, 22);
    expect(HighlightTransferPayload.tryParse(HighlightTransferPayload.encode(id)), id);
  });
}
