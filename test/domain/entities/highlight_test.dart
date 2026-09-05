import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';

void main() {
  test('copyWith updates contextual and keeps literal', () {
    const original = Highlight(
      text: 'due diligence',
      literal: 'careful investigation',
      contextual: 'Checking the company before buying it.',
      color: '0xFFE8C547',
      textColor: '0xFF000000',
    );

    final updated = original.copyWith(contextual: 'Updated context.');

    expect(updated.text, 'due diligence');
    expect(updated.literal, 'careful investigation');
    expect(updated.contextual, 'Updated context.');
    expect(updated.color, original.color);
  });
}
