// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart'; // <-- 1. IMPORT THIS

// Replace 'smart_ev' with your actual project name from pubspec.yaml
import 'package:miniproject/main.dart';
import 'package:miniproject/routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    try {
      // Skip FCM initialization on web if service worker is not available
      if (kIsWeb) {
        print('Running on web - FCM may have limited functionality');
        return;
      }

      await _firebaseMessaging.requestPermission();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received!');
        if (message.notification != null &&
            navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification!.title ?? ''}\n${message.notification!.body ?? ''}',
              ),
            ),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification tapped (from background)');
        _handleMessageNavigation(message);
      });

      _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print('Notification tapped (from terminated)');
          _handleMessageNavigation(message);
        }
      });
    } catch (e) {
      print('Error initializing notifications: $e');
      // Don't throw the error, just log it to prevent app crash
    }
  }

  // =========================================================================
  // --- MODIFIED NAVIGATION LOGIC ---
  // =========================================================================
  void _handleMessageNavigation(RemoteMessage message) async {
    // Check the 'data' payload sent from your Node.js server
    if (message.data['screen'] == 'charging_station_finder') {
      // --- FOR THE FUTURE ---
      // WHEN YOU CREATE THE STATION FINDER SCREEN, YOU WILL UNCOMMENT THIS:
      // navigatorKey.currentState?.pushNamed(AppRoutes.findStations);
      // print('Navigating to station finder screen...');

      // --- FOR NOW: Navigate to the User Dashboard as a safe default ---
      print('Station finder not built yet. Navigating to EV User Dashboard.');
      _navigateToDashboard();
    } else {
      // If the notification doesn't specify a screen, also go to the dashboard.
      _navigateToDashboard();
    }
  }

  // New helper function to navigate to the dashboard
  void _navigateToDashboard() async {
    // Get user info from storage, because the app might be closed.
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final role = prefs.getString('lastRole');

    if (email != null && role == 'EV User') {
      // We use pushNamedAndRemoveUntil to make the dashboard the new home screen,
      // clearing any previous screens.
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.evuserDashboard,
        (route) => false, // This predicate removes all routes below it
        arguments: {'role': role, 'email': email},
      );
    }
  }

  // =========================================================================
}
