import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_parser.dart';

void main() {
  test('parses highlights with literal and contextual', () {
    const raw = '''
{
  "highlights": [
    {
      "text": "due diligence",
      "literal": "careful investigation before a decision",
      "contextual": "Here it means checking the company thoroughly before buying it.",
      "color": "0xFFE8C547"
    }
  ]
}
''';
    final result = GeminiHighlightParser.parse(raw);
    expect(result.found, isTrue);
    expect(result.highlights, hasLength(1));
    expect(result.highlights!.first.text, 'due diligence');
    expect(result.highlights!.first.literal, contains('investigation'));
    expect(result.highlights!.first.contextual, contains('company'));
    expect(result.highlights!.first.color, '0xFFE8C547');
  });

  test('empty highlights means not found', () {
    final result = GeminiHighlightParser.parse('{"highlights":[]}');
    expect(result.found, isFalse);
    expect(result.highlights, isEmpty);
  });

  test('null or invalid json means not found', () {
    expect(GeminiHighlightParser.parse(null).found, isFalse);
    expect(GeminiHighlightParser.parse('not-json').found, isFalse);
  });

  test('keeps non-English meanings as returned', () {
    final result = GeminiHighlightParser.parse(
      '{"highlights":[{"text":"محنت","literal":"کوشش","contextual":"یہاں محنت کا مطلب لگاتار کوشش ہے۔","color":"0xFFE8C547"}]}',
    );
    expect(result.highlights!.first.literal, 'کوشش');
    expect(result.highlights!.first.contextual, contains('کوشش'));
  });

  test('drops items with empty text', () {
    final result = GeminiHighlightParser.parse(
      '{"highlights":[{"text":"","literal":"x","contextual":"y"}]}',
    );
    expect(result.found, isFalse);
  });
}
