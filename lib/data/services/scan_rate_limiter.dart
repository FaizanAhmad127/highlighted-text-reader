import 'package:shared_preferences/shared_preferences.dart';

class ScanQuotaUsage {
  const ScanQuotaUsage({required this.used, required this.max});

  final int used;
  final int max;
}

class ScanRateLimitDecision {
  const ScanRateLimitDecision.allow()
      : allowed = true,
        userMessage = null;

  const ScanRateLimitDecision.block(this.userMessage) : allowed = false;

  final bool allowed;
  final String? userMessage;
}

class ScanQuotaOverride {
  const ScanQuotaOverride({this.maxOverride});

  final int? maxOverride;
}

abstract class ScanQuotaStore {
  Future<String?> readDayKey();
  Future<int> readCount();
  Future<DateTime?> readLastAttempt();
  Future<ScanQuotaOverride> readOverride() async => const ScanQuotaOverride();
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
  int? maxOverride;

  @override
  Future<String?> readDayKey() async => dayKey;

  @override
  Future<int> readCount() async => count;

  @override
  Future<DateTime?> readLastAttempt() async => lastAt;

  @override
  Future<ScanQuotaOverride> readOverride() async => ScanQuotaOverride(
        maxOverride: maxOverride,
      );

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
  Future<ScanQuotaOverride> readOverride() async => const ScanQuotaOverride();

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

/// Daily cap plus cooldown. The count store can be local or Firestore.
class ScanRateLimiter {
  ScanRateLimiter({
    ScanQuotaStore? store,
    DateTime Function()? clock,
    int maxScansPerDay = 20,
    int Function()? maxScansPerDayReader,
    this.cooldown = const Duration(seconds: 8),
  })  : _store = store ?? SharedPrefsScanQuotaStore(),
        _clock = clock ?? DateTime.now,
        _maxScansPerDay =
            maxScansPerDayReader ?? (() => maxScansPerDay);

  static const cooldownMessage =
      'Wait a few seconds before scanning again.';
  static const dailyLimitMessage =
      "You've reached today's scan limit. Try again tomorrow.";
  static const quotaUnavailableMessage =
      "Couldn't check your scan limit. Try again.";

  final ScanQuotaStore _store;
  final DateTime Function() _clock;
  final int Function() _maxScansPerDay;
  final Duration cooldown;

  int get maxScansPerDay => _maxScansPerDay();

  static int effectiveMax({
    required int globalMax,
    ScanQuotaOverride? override,
  }) {
    final maxOverride = override?.maxOverride;
    return (maxOverride != null && maxOverride >= 1) ? maxOverride : globalMax;
  }

  Future<ScanQuotaUsage> usageToday() async {
    final now = _clock();
    final today = _dayKey(now);
    final storedDay = await _store.readDayKey();
    final count = storedDay == today ? await _store.readCount() : 0;
    final cap = effectiveMax(
      globalMax: maxScansPerDay,
      override: await _store.readOverride(),
    );
    // A mid-day global cap drop must not show "3 of 2". Grandfather
    // today's used count so the label stays consistent; check() still
    // uses the real cap and blocks further scans.
    final max = count > cap ? count : cap;
    return ScanQuotaUsage(used: count, max: max);
  }

  Future<ScanRateLimitDecision> check() async {
    try {
      final now = _clock();
      final today = _dayKey(now);
      final storedDay = await _store.readDayKey();
      final count = storedDay == today ? await _store.readCount() : 0;
      final max = effectiveMax(
        globalMax: maxScansPerDay,
        override: await _store.readOverride(),
      );

      if (count >= max) {
        return const ScanRateLimitDecision.block(dailyLimitMessage);
      }

      final last = await _store.readLastAttempt();
      if (last != null && now.difference(last) < cooldown) {
        return const ScanRateLimitDecision.block(cooldownMessage);
      }

      return const ScanRateLimitDecision.allow();
    } catch (_) {
      return const ScanRateLimitDecision.block(quotaUnavailableMessage);
    }
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
