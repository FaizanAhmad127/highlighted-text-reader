import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';

void main() {
  test('lists match-highlight first, then the common 10', () {
    final all = MeaningLanguageCatalog.all;

    expect(all.first, MeaningLanguage.matchHighlight);
    expect(
      all.skip(1).take(10).map((language) => language.id),
      MeaningLanguageCatalog.commonIds,
    );
    expect(MeaningLanguage.defaultLanguage.id, MeaningLanguage.englishId);
  });

  test('unknown ids fall back to English', () {
    expect(MeaningLanguageCatalog.byId(null), MeaningLanguage.english);
    expect(MeaningLanguageCatalog.byId('nope'), MeaningLanguage.english);
  });

  test('search matches language names', () {
    final results = MeaningLanguageCatalog.search('urd');
    expect(results.map((language) => language.id), contains('ur'));
  });

  test('pins the selected language to the top of the list', () {
    final listed = MeaningLanguageCatalog.listed(
      selected: const MeaningLanguage(id: 'ja', name: 'Japanese'),
    );

    expect(listed.first.id, 'ja');
    expect(
      listed.skip(1).first,
      MeaningLanguage.matchHighlight,
    );
  });
}
