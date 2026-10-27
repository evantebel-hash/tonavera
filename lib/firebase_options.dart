// File generated for MyMusic Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNOli8oBqunQaK0Uekujea__NIbbAv_KM',
    appId: '1:303373323332:android:036debd5e2a6223ff98011',
    messagingSenderId: '303373323332',
    projectId: 'my-music-24b7b',
    storageBucket: 'my-music-24b7b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_MyMusic_iOS_API_Key',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'mymusic-app',
    storageBucket: 'mymusic-app.appspot.com',
    iosBundleId: 'com.example.mymusic',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBNOli8oBqunQaK0Uekujea__NIbbAv_KM',
    appId: '1:303373323332:web:036debd5e2a6223ff98011',
    messagingSenderId: '303373323332',
    projectId: 'my-music-24b7b',
    authDomain: 'my-music-24b7b.firebaseapp.com',
    storageBucket: 'my-music-24b7b.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBNOli8oBqunQaK0Uekujea__NIbbAv_KM',
    appId: '1:303373323332:web:036debd5e2a6223ff98011',
    messagingSenderId: '303373323332',
    projectId: 'my-music-24b7b',
    authDomain: 'my-music-24b7b.firebaseapp.com',
    storageBucket: 'my-music-24b7b.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_MyMusic_macOS_API_Key',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'mymusic-app',
    storageBucket: 'mymusic-app.appspot.com',
    iosBundleId: 'com.example.mymusic',
  );
}
