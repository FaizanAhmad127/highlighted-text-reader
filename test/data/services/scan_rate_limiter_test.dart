import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/data/services/scan_rate_limiter.dart';

void main() {
  late MemoryScanQuotaStore store;
  late DateTime now;
  late ScanRateLimiter limiter;

  setUp(() {
    store = MemoryScanQuotaStore();
    now = DateTime(2026, 9, 5, 12, 0);
    limiter = ScanRateLimiter(
      store: store,
      clock: () => now,
      maxScansPerDay: 20,
      cooldown: const Duration(seconds: 8),
    );
  });

  test('allows the first scan of the day', () async {
    final decision = await limiter.check();
    expect(decision.allowed, isTrue);
  });

  test('blocks a second scan during the cooldown', () async {
    await limiter.recordAttempt();
    now = now.add(const Duration(seconds: 3));

    final decision = await limiter.check();

    expect(decision.allowed, isFalse);
    expect(decision.userMessage, ScanRateLimiter.cooldownMessage);
  });

  test('allows a scan after the cooldown', () async {
    await limiter.recordAttempt();
    now = now.add(const Duration(seconds: 8));

    final decision = await limiter.check();

    expect(decision.allowed, isTrue);
  });

  test('blocks after the daily scan limit', () async {
    store.count = 20;
    store.dayKey = '2026-09-05';

    final decision = await limiter.check();

    expect(decision.allowed, isFalse);
    expect(decision.userMessage, ScanRateLimiter.dailyLimitMessage);
  });

  test('resets the daily count on a new local day', () async {
    store
      ..count = 20
      ..dayKey = '2026-09-05'
      ..lastAt = now;
    now = DateTime(2026, 9, 6, 8, 0);

    final decision = await limiter.check();

    expect(decision.allowed, isTrue);
  });

  test('recordAttempt starts a new day count at 1', () async {
    store
      ..count = 20
      ..dayKey = '2026-09-05';
    now = DateTime(2026, 9, 6, 8, 0);

    await limiter.recordAttempt();

    expect(store.dayKey, '2026-09-06');
    expect(store.count, 1);
  });
}
