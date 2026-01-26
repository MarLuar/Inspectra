import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<FirebaseApp> initializeFirebase() async {
    FirebaseApp app = await Firebase.initializeApp(
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: "AIzaSyBfy3ZZL9DLil5UHzHCooh-teGbV8se97A", // Web API Key
              authDomain: "inspectra-e1de5.firebaseapp.com",
              projectId: "inspectra-e1de5",
              storageBucket: "inspectra-e1de5.firebasestorage.app",
              messagingSenderId: "147206083254",
              appId: "1:147206083254:web:071a42f530c432113d8c17",
            )
          : const FirebaseOptions(
              apiKey: "AIzaSyBfy3ZZL9DLil5UHzHCooh-teGbV8se97A", // Android API Key
              appId: "1:147206083254:android:071a42f530c432113d8c17",
              messagingSenderId: "147206083254",
              projectId: "inspectra-e1de5",
              storageBucket: "inspectra-e1de5.firebasestorage.app",
            ),
    );

    return app;
  }
}