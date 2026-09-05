import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/meaning_language.dart';

class MeaningLanguageStore {
  MeaningLanguageStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const prefsKey = 'meaning_language_id';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<MeaningLanguage> read() async {
    final id = (await _store).getString(prefsKey);
    return MeaningLanguageCatalog.byId(id);
  }

  Future<void> write(MeaningLanguage language) async {
    await (await _store).setString(prefsKey, language.id);
  }
}
