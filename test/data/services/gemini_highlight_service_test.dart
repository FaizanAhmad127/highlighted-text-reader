import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/gemini_highlight_service.dart';
import 'package:highlighted_text_reader/data/services/meaning_language_prompt.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';

void main() {
  test('constructor defers Firebase model creation', () {
    expect(GeminiHighlightService.new, returnsNormally);
  });

  test('system instruction defers language to the user message', () {
    expect(
      GeminiHighlightService.systemInstruction,
      contains('meaning-language rule in the user message'),
    );
  });

  test('match-highlight prompt asks for the phrase language', () {
    expect(
      MeaningLanguagePrompt.userInstruction(MeaningLanguage.matchHighlight),
      contains('same language as each highlighted phrase'),
    );
  });

  test('fixed-language prompt names the selected language', () {
    expect(
      MeaningLanguagePrompt.userInstruction(
        const MeaningLanguage(id: 'ur', name: 'Urdu'),
      ),
      contains('in Urdu only'),
    );
  });
}
