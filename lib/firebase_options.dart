import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-YT2OH0V-ZAzfB8Qxuvow5Pn1mEim_bI',
    appId: '1:686719671388:web:6d827f6bef546fb29dda99',
    messagingSenderId: '686719671388',
    projectId: 'qtv-asrvtech',
    authDomain: 'qtv-asrvtech.firebaseapp.com',
    databaseURL: 'https://qtv-asrvtech-default-rtdb.firebaseio.com',
    storageBucket: 'qtv-asrvtech.firebasestorage.app',
    measurementId: 'G-NVHM9RTSG7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBEt-fs4gVHxg280WKV5rxeCbVMCyehBAU',
    appId: '1:686719671388:android:f956c97f07b8dbf39dda99',
    messagingSenderId: '686719671388',
    projectId: 'qtv-asrvtech',
    databaseURL: 'https://qtv-asrvtech-default-rtdb.firebaseio.com',
    storageBucket: 'qtv-asrvtech.firebasestorage.app',
  );
}
