import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // This will no longer be used, but we'll leave it for now.
    // The main_parent.dart and main_child.dart files will call the options directly.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // We can default to parent, but it won't be used.
        return parent; 
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Configuration for the PARENT app
  static const FirebaseOptions parent = FirebaseOptions(
    apiKey: 'AIzaSyCRyS2d_Rr_tr6HJzrpXyTDA-6__LD9ZuY', // Use your actual key
    appId: '1:110632506055:android:3db751e05e1acc931b24e2', // The parent appId
    messagingSenderId: '110632506055',
    projectId: 'orbit-shield',
    storageBucket: 'orbit-shield.firebasestorage.app',
  );

  // Configuration for the CHILD app
  static const FirebaseOptions child = FirebaseOptions(
    apiKey: 'AIzaSyCRyS2d_Rr_tr6HJzrpXyTDA-6__LD9ZuY', // Use your actual key
    appId: '1:110632506055:android:db016fa861bac2221b24e2', // The child appId
    messagingSenderId: '110632506055',
    projectId: 'orbit-shield',
    storageBucket: 'orbit-shield.firebasestorage.app',
  );
}