import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  OnboardingStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const prefsKey = 'onboarding_completed';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<bool> read() async {
    return (await _store).getBool(prefsKey) ?? false;
  }

  Future<void> writeCompleted() async {
    await (await _store).setBool(prefsKey, true);
  }
}
