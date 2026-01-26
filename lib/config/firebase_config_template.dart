import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<FirebaseApp> initializeFirebase() async {
    FirebaseApp app = await Firebase.initializeApp(
      // Replace these with your actual Firebase project credentials
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: "YOUR_WEB_API_KEY",
              authDomain: "your-project-id.firebaseapp.com",
              projectId: "your-project-id",
              storageBucket: "your-project-id.appspot.com",
              messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
              appId: "YOUR_WEB_APP_ID",
            )
          : const FirebaseOptions(
              apiKey: "YOUR_ANDROID_API_KEY",
              appId: "YOUR_ANDROID_APP_ID",
              messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
              projectId: "your-project-id",
              storageBucket: "your-project-id.appspot.com",
            ),
    );

    return app;
  }
}