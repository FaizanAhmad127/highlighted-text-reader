import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Central analytics events for the app. No PII is logged.
class AppAnalytics {
  AppAnalytics._();

  static FirebaseAnalytics? get _analytics =>
      FirebaseBootstrap.isSupported ? FirebaseBootstrap.analytics : null;

  static Future<void> logOnboardingFinished({required String method}) {
    return _logEvent(
      'onboarding_complete',
      {'method': method},
    );
  }

  static Future<void> logImageSelected({required String source}) {
    return _logEvent(
      'select_content',
      {
        'content_type': 'book_page_photo',
        'item_id': source,
      },
    );
  }

  static Future<void> logScanStarted({required bool offline}) {
    return _logEvent(
      'scan_started',
      {'offline': offline ? 1 : 0},
    );
  }

  static Future<void> logScanCompleted({
    required bool found,
    required int highlightCount,
    required bool offline,
  }) {
    return _logEvent(
      'scan_completed',
      {
        'found': found ? 1 : 0,
        'highlight_count': highlightCount,
        'offline': offline ? 1 : 0,
      },
    );
  }

  static Future<void> logScanFailed({required String reason}) {
    return _logEvent(
      'scan_failed',
      {'reason': reason},
    );
  }

  static Future<void> logHighlightExpanded({required int index}) {
    return _logEvent(
      'highlight_expanded',
      {'index': index},
    );
  }

  static Future<void> logConnectivityChanged({required bool offline}) {
    return _logEvent(
      'connectivity_changed',
      {'offline': offline ? 1 : 0},
    );
  }

  static Future<void> _logEvent(
    String name,
    Map<String, Object> parameters,
  ) async {
    final analytics = _analytics;
    if (analytics == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      parameters = {...parameters, 'auth_uid': uid};
    }
    if (kDebugMode) {
      print('Analytics $name auth_uid=${uid ?? "(none)"} $parameters');
    }

    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      if (kDebugMode) {
        print('Analytics event failed ($name): $e\n$st');
      }
    }
  }
}
