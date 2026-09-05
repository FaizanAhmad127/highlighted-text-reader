// File generated from existing Firebase project configuration.
// Project: highlighted-text-reader

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvaiZoskmSjhTMs6Xq3dxwPHfH0jo9x9w',
    appId: '1:27576664803:android:38ee7ca8f836f724ed3bd6',
    messagingSenderId: '27576664803',
    projectId: 'highlighted-text-reader',
    storageBucket: 'highlighted-text-reader.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCOsmEObsuP-8FM4OifW_8xDHfxKNZnxSs',
    appId: '1:27576664803:ios:a85e84bf0d50c8afed3bd6',
    messagingSenderId: '27576664803',
    projectId: 'highlighted-text-reader',
    storageBucket: 'highlighted-text-reader.firebasestorage.app',
    iosBundleId: 'com.faizan.highlightedtextreader',
  );
}
