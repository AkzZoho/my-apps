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
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAozpBL9WdENY1fo7XBws-4d_n9H-417x8',
    authDomain: 'projectkuri-c284d.firebaseapp.com',
    databaseURL: 'https://projectkuri-c284d-default-rtdb.asia-southeast1.firebasedatabase.app',
    projectId: 'projectkuri-c284d',
    storageBucket: 'projectkuri-c284d.firebasestorage.app',
    messagingSenderId: '638627598431',
    appId: '1:638627598431:web:c1201144f3399be0544bea',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAozpBL9WdENY1fo7XBws-4d_n9H-417x8',
    appId: '1:638627598431:web:c1201144f3399be0544bea',
    messagingSenderId: '638627598431',
    projectId: 'projectkuri-c284d',
    databaseURL: 'https://projectkuri-c284d-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'projectkuri-c284d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAozpBL9WdENY1fo7XBws-4d_n9H-417x8',
    appId: '1:638627598431:web:c1201144f3399be0544bea',
    messagingSenderId: '638627598431',
    projectId: 'projectkuri-c284d',
    databaseURL: 'https://projectkuri-c284d-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'projectkuri-c284d.firebasestorage.app',
    iosBundleId: 'com.akzzoho.kuriApp',
  );
}
