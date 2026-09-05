import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/meaning_language_store.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads English when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MeaningLanguageStore();

    expect(await store.read(), MeaningLanguage.english);
  });

  test('persists a selected language', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MeaningLanguageStore();

    await store.write(const MeaningLanguage(id: 'ur', name: 'Urdu'));

    expect((await store.read()).id, 'ur');
  });
}
