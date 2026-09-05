import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase and wires global crash reporting for mobile builds.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;

  static FirebaseAnalytics get analytics {
    final instance = _analytics;
    if (instance == null) {
      throw StateError('Firebase has not been initialized on this platform.');
    }
    return instance;
  }

  static FirebaseCrashlytics get crashlytics {
    final instance = _crashlytics;
    if (instance == null) {
      throw StateError('Firebase has not been initialized on this platform.');
    }
    return instance;
  }

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseAnalyticsObserver? get analyticsObserver {
    if (_analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics!);
  }

  static Future<void> initialize() async {
    if (!isSupported) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _analytics = FirebaseAnalytics.instance;
    _crashlytics = FirebaseCrashlytics.instance;

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        print('Firebase App Check activation failed: $e\n$st');
      }
      await _crashlytics?.recordError(e, st, fatal: false);
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e, st) {
      if (kDebugMode) {
        print('Anonymous auth failed: $e\n$st');
      }
      await _crashlytics?.recordError(e, st, fatal: false);
    }

    await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _crashlytics!.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics!.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static void runGuarded(VoidCallback runApp) {
    if (!isSupported) {
      runApp();
      return;
    }

    runZonedGuarded(
      runApp,
      (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
      },
    );
  }
}
