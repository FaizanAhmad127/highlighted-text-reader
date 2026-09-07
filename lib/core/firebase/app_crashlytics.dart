import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Crashlytics helpers for breadcrumbs and non-fatal errors.
class AppCrashlytics {
  AppCrashlytics._();

  static FirebaseCrashlytics? get _crashlytics {
    if (!FirebaseBootstrap.isSupported) return null;
    try {
      return FirebaseBootstrap.crashlytics;
    } catch (_) {
      return null;
    }
  }

  static Future<void> log(String message) async {
    try {
      await _crashlytics?.log(message);
    } catch (e, st) {
      if (kDebugMode) {
        print('Crashlytics log failed: $e\n$st');
      }
    }
  }

  static Future<void> setCustomKeys(Map<String, Object?> keys) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) return;

    for (final entry in keys.entries) {
      final value = entry.value;
      if (value == null) continue;
      try {
        if (value is bool) {
          await crashlytics.setCustomKey(entry.key, value);
        } else if (value is int) {
          await crashlytics.setCustomKey(entry.key, value);
        } else if (value is double) {
          await crashlytics.setCustomKey(entry.key, value);
        } else {
          await crashlytics.setCustomKey(entry.key, value.toString());
        }
      } catch (e, st) {
        if (kDebugMode) {
          print('Crashlytics setCustomKey failed (${entry.key}): $e\n$st');
        }
      }
    }
  }

  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      print('${reason ?? 'error'} failed: $error\n$stack');
    }
    try {
      await _crashlytics?.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Crashlytics recordError failed: $e\n$st');
      }
    }
  }

  /// Records [error] without awaiting. Safe when Firebase is not initialized.
  static void record(
    Object error,
    StackTrace stack, {
    required String reason,
    bool fatal = false,
  }) {
    unawaited(
      recordNonFatal(error, stack, reason: reason, fatal: fatal),
    );
  }

  /// Awaits [future] and records a non-fatal if it fails.
  static void capture(Future<void> future, {required String reason}) {
    unawaited(() async {
      try {
        await future;
      } catch (error, stack) {
        await recordNonFatal(error, stack, reason: reason);
      }
    }());
  }
}
