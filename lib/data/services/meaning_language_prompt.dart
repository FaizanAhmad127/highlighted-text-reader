import '../../domain/entities/meaning_language.dart';

class MeaningLanguagePrompt {
  static String userInstruction(MeaningLanguage language) {
    if (language.matchesHighlight) {
      return 'Write both literal and contextual in the same language as each highlighted phrase. '
          'Do not translate the phrase or its meanings into English unless the phrase itself is English.';
    }
    return 'Write both literal and contextual in ${language.name} only. '
        'Keep the highlighted phrase in its original language. '
        'Do not use English unless ${language.name} is English.';
  }
}
