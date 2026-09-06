import 'package:shared_preferences/shared_preferences.dart';

class QuotaRequestPromptStore {
  QuotaRequestPromptStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _key = 'quota_request_prompt_day';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<bool> shouldPrompt(String todayYyyyMmDd) async {
    return (await _store).getString(_key) != todayYyyyMmDd;
  }

  Future<void> markPrompted(String todayYyyyMmDd) async {
    await (await _store).setString(_key, todayYyyyMmDd);
  }
}
