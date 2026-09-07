import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/swipe_delete_hint_store.dart';

void main() {
  setUp(SwipeDeleteHintStore.resetForTest);

  test('shows the hint before it has been marked this session', () {
    final store = SwipeDeleteHintStore();

    expect(store.shouldShow(), isTrue);
  });

  test('does not show the hint again after it was played', () {
    final store = SwipeDeleteHintStore();

    store.markShown();

    expect(store.shouldShow(), isFalse);
  });

  test('shares the session flag across store instances', () {
    SwipeDeleteHintStore().markShown();

    expect(SwipeDeleteHintStore().shouldShow(), isFalse);
  });

  test('shows the hint again after the session flag is cleared', () {
    final store = SwipeDeleteHintStore();
    store.markShown();

    SwipeDeleteHintStore.resetForTest();

    expect(store.shouldShow(), isTrue);
  });
}
