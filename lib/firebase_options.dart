// Firebase projesi: hatim-kardesim (Firebase konsolundan alınan değerler).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Hafız Kardeşim yalnızca Android ve iOS için yapılandırıldı.');
    }
  }

  static const _apiKey = 'AIzaSyBGE2LbB1445NNneQmwh_umMo8D6K54x0g';
  static const _projectId = 'hatim-kardesim';
  static const _senderId = '668036405824';
  static const _bucket = 'hatim-kardesim.firebasestorage.app';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:668036405824:android:62f96d7fd298f96f395da5',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:668036405824:ios:56f0fe8e76862989395da5',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
    iosBundleId: 'com.hatimkardesim.hatimKardesim',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:668036405824:web:a17dad9eeeb1d203395da5',
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: 'hatim-kardesim.firebaseapp.com',
    storageBucket: _bucket,
  );
}
