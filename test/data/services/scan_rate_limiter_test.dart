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

  test('uses a live max so the global cap can raise or lower', () async {
    var max = 2;
    limiter = ScanRateLimiter(
      store: store,
      clock: () => now,
      maxScansPerDayReader: () => max,
      cooldown: const Duration(seconds: 8),
    );
    store
      ..count = 2
      ..dayKey = '2026-09-05';

    expect((await limiter.check()).allowed, isFalse);

    max = 5;
    expect((await limiter.check()).allowed, isTrue);
  });

  test('usageToday reports used count and the live max', () async {
    store
      ..count = 3
      ..dayKey = '2026-09-05';

    final usage = await limiter.usageToday();

    expect(usage.used, 3);
    expect(usage.max, 20);
  });

  test('usageToday is 0 on a new local day', () async {
    store
      ..count = 20
      ..dayKey = '2026-09-05';
    now = DateTime(2026, 9, 6, 8, 0);

    final usage = await limiter.usageToday();

    expect(usage.used, 0);
    expect(usage.max, 20);
  });

  test('override only raises the daily cap', () async {
    expect(
      ScanRateLimiter.effectiveMax(
        globalMax: 20,
        override: const ScanQuotaOverride(maxOverride: 5),
      ),
      20,
    );
    expect(
      ScanRateLimiter.effectiveMax(
        globalMax: 20,
        override: const ScanQuotaOverride(maxOverride: 50),
      ),
      50,
    );
    expect(
      ScanRateLimiter.effectiveMax(
        globalMax: 20,
        override: const ScanQuotaOverride(maxOverride: 0),
      ),
      20,
    );
    expect(ScanRateLimiter.effectiveMax(globalMax: 20), 20);

    store
      ..count = 5
      ..dayKey = '2026-09-05'
      ..maxOverride = 5;
    expect((await limiter.check()).allowed, isTrue);

    store.count = 19;
    expect((await limiter.check()).allowed, isTrue);

    store.count = 20;
    expect((await limiter.check()).allowed, isFalse);

    store
      ..count = 20
      ..maxOverride = 50;
    expect((await limiter.check()).allowed, isTrue);

    store.count = 50;
    final decision = await limiter.check();
    expect(decision.allowed, isFalse);
    expect(decision.userMessage, ScanRateLimiter.dailyLimitMessage);
  });

  test('usageToday grandfathers used when the live cap is set to 0', () async {
    limiter = ScanRateLimiter(
      store: store,
      clock: () => now,
      maxScansPerDayReader: () => 0,
      cooldown: const Duration(seconds: 8),
    );
    store
      ..count = 1
      ..dayKey = '2026-09-05';

    final usage = await limiter.usageToday();
    final decision = await limiter.check();

    expect(usage.used, 1);
    expect(usage.max, 1);
    expect(decision.allowed, isFalse);
  });

  test('usageToday grandfathers used when the live cap drops mid-day', () async {
    var max = 5;
    limiter = ScanRateLimiter(
      store: store,
      clock: () => now,
      maxScansPerDayReader: () => max,
      cooldown: const Duration(seconds: 8),
    );
    store
      ..count = 3
      ..dayKey = '2026-09-05';

    max = 2;
    final usage = await limiter.usageToday();
    final decision = await limiter.check();

    expect(usage.used, 3);
    expect(usage.max, 3);
    expect(decision.allowed, isFalse);
  });

  test('usageToday.max reflects effective max', () async {
    store
      ..count = 3
      ..dayKey = '2026-09-05'
      ..maxOverride = 50;

    final usage = await limiter.usageToday();

    expect(usage.used, 3);
    expect(usage.max, 50);

    store.maxOverride = 5;
    final ignored = await limiter.usageToday();
    expect(ignored.max, 20);
  });

  test('blocks when the quota store cannot be read', () async {
    limiter = ScanRateLimiter(
      store: _ThrowingScanQuotaStore(),
      clock: () => now,
    );

    final decision = await limiter.check();

    expect(decision.allowed, isFalse);
    expect(decision.userMessage, ScanRateLimiter.quotaUnavailableMessage);
  });
}

class _ThrowingScanQuotaStore implements ScanQuotaStore {
  @override
  Future<int> readCount() async => throw StateError('unavailable');

  @override
  Future<String?> readDayKey() async => throw StateError('unavailable');

  @override
  Future<DateTime?> readLastAttempt() async => throw StateError('unavailable');

  @override
  Future<ScanQuotaOverride> readOverride() async =>
      throw StateError('unavailable');

  @override
  Future<void> write({
    required String dayKey,
    required int count,
    required DateTime lastAttempt,
  }) async {
    throw StateError('unavailable');
  }
}
