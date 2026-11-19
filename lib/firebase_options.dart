// aile-plani Firebase projesi ayarları (google-services.json'dan üretildi).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Aile Planı yalnızca Android için ayarlandı.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBxR-fZclL6MY0xzNVmIN8gPF2uhnXG0mE',
    appId: '1:803362342978:android:2d514c074cab63e8acc5db',
    messagingSenderId: '803362342978',
    projectId: 'aile-plani',
    storageBucket: 'aile-plani.firebasestorage.app',
  );
}
