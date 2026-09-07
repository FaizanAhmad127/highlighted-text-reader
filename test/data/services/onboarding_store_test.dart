import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads incomplete when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore();

    expect(await store.read(), isFalse);
  });

  test('persists completion across store instances', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore();

    await store.writeCompleted();

    expect(await store.read(), isTrue);
    expect(await OnboardingStore().read(), isTrue);
  });

  test('treats an explicit false flag as incomplete', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingStore.prefsKey: false,
    });
    final store = OnboardingStore();

    expect(await store.read(), isFalse);
  });

  test('uses injected preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = OnboardingStore(prefs: prefs);

    await store.writeCompleted();

    expect(prefs.getBool(OnboardingStore.prefsKey), isTrue);
  });
}
