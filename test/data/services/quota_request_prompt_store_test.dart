import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/quota_request_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('prompts on the first day', () async {
    SharedPreferences.setMockInitialValues({});
    final store = QuotaRequestPromptStore();

    expect(await store.shouldPrompt('2026-09-06'), isTrue);
  });

  test('does not prompt again the same day', () async {
    SharedPreferences.setMockInitialValues({});
    final store = QuotaRequestPromptStore();

    await store.markPrompted('2026-09-06');

    expect(await store.shouldPrompt('2026-09-06'), isFalse);
  });

  test('prompts again on a new day', () async {
    SharedPreferences.setMockInitialValues({});
    final store = QuotaRequestPromptStore();

    await store.markPrompted('2026-09-06');

    expect(await store.shouldPrompt('2026-09-07'), isTrue);
  });
}
