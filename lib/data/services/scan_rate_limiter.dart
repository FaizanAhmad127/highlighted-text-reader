import 'package:shared_preferences/shared_preferences.dart';

class ScanRateLimitDecision {
  const ScanRateLimitDecision.allow()
      : allowed = true,
        userMessage = null;

  const ScanRateLimitDecision.block(this.userMessage) : allowed = false;

  final bool allowed;
  final String? userMessage;
}

abstract class ScanQuotaStore {
  Future<String?> readDayKey();
  Future<int> readCount();
  Future<DateTime?> readLastAttempt();
  Future<void> write({
    required String dayKey,
    required int count,
    required DateTime lastAttempt,
  });
}

class MemoryScanQuotaStore implements ScanQuotaStore {
  String? dayKey;
  int count = 0;
  DateTime? lastAt;

  @override
  Future<String?> readDayKey() async => dayKey;

  @override
  Future<int> readCount() async => count;

  @override
  Future<DateTime?> readLastAttempt() async => lastAt;

  @override
  Future<void> write({
    required String dayKey,
    required int count,
    required DateTime lastAttempt,
  }) async {
    this.dayKey = dayKey;
    this.count = count;
    lastAt = lastAttempt;
  }
}

class SharedPrefsScanQuotaStore implements ScanQuotaStore {
  static const _dayKey = 'scan_quota_day';
  static const _countKey = 'scan_quota_count';
  static const _lastKey = 'scan_quota_last_ms';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> readDayKey() async => (await _store).getString(_dayKey);

  @override
  Future<int> readCount() async => (await _store).getInt(_countKey) ?? 0;

  @override
  Future<DateTime?> readLastAttempt() async {
    final ms = (await _store).getInt(_lastKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> write({
    required String dayKey,
    required int count,
    required DateTime lastAttempt,
  }) async {
    final prefs = await _store;
    await prefs.setString(_dayKey, dayKey);
    await prefs.setInt(_countKey, count);
    await prefs.setInt(_lastKey, lastAttempt.millisecondsSinceEpoch);
  }
}

/// Local daily cap and cooldown. Easy to bypass; Cloud quotas are the real limit.
class ScanRateLimiter {
  ScanRateLimiter({
    ScanQuotaStore? store,
    DateTime Function()? clock,
    this.maxScansPerDay = 20,
    this.cooldown = const Duration(seconds: 8),
  })  : _store = store ?? SharedPrefsScanQuotaStore(),
        _clock = clock ?? DateTime.now;

  static const cooldownMessage =
      'Wait a few seconds before scanning again.';
  static const dailyLimitMessage =
      "You've reached today's scan limit. Try again tomorrow.";

  final ScanQuotaStore _store;
  final DateTime Function() _clock;
  final int maxScansPerDay;
  final Duration cooldown;

  Future<ScanRateLimitDecision> check() async {
    final now = _clock();
    final today = _dayKey(now);
    final storedDay = await _store.readDayKey();
    final count = storedDay == today ? await _store.readCount() : 0;

    if (count >= maxScansPerDay) {
      return const ScanRateLimitDecision.block(dailyLimitMessage);
    }

    final last = await _store.readLastAttempt();
    if (last != null && now.difference(last) < cooldown) {
      return const ScanRateLimitDecision.block(cooldownMessage);
    }

    return const ScanRateLimitDecision.allow();
  }

  Future<void> recordAttempt() async {
    final now = _clock();
    final today = _dayKey(now);
    final storedDay = await _store.readDayKey();
    final count = storedDay == today ? await _store.readCount() : 0;
    await _store.write(
      dayKey: today,
      count: count + 1,
      lastAttempt: now,
    );
  }

  static String _dayKey(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}
