import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_service.dart';

void main() {
  test('constructor defers Firebase model creation', () {
    expect(GeminiHighlightService.new, returnsNormally);
  });
}
