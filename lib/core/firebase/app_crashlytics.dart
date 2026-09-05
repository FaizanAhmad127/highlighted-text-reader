import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Crashlytics helpers for breadcrumbs and non-fatal errors.
class AppCrashlytics {
  AppCrashlytics._();

  static FirebaseCrashlytics? get _crashlytics =>
      FirebaseBootstrap.isSupported ? FirebaseBootstrap.crashlytics : null;

  static Future<void> log(String message) async {
    try {
      await _crashlytics?.log(message);
    } catch (_) {}
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
      } catch (_) {}
    }
  }

  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics?.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      if (kDebugMode) {
        print('Crashlytics recordError failed: $error');
      }
    }
  }
}
