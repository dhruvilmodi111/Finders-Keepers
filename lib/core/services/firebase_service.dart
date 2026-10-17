import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  FirebaseService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      // Configure Cloud Firestore offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase initialized successfully with offline persistence.');
    } catch (e) {
      // Allows the app to run in development before google-services.json / GoogleService-Info.plist is configured
      debugPrint('[FirebaseService] Firebase initialization warning: $e');
      debugPrint('[FirebaseService] Running in decoupled/preview mode until Firebase credentials are provided.');
    }
  }
}
