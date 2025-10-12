// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miniproject/main.dart';
import 'package:miniproject/routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- SINGLETON SETUP ---
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initNotifications() async {
    // --- 1. REQUEST PERMISSIONS AND INITIALIZE LOCAL NOTIFICATIONS ---
    // Request permissions for iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Note: Ensure you have a launcher icon at 'android/app/src/main/res/mipmap/ic_launcher.png'
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Request permissions for Android 13+
    _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();


    // --- 2. FCM SETUP (For potential future server-side notifications) ---
    try {
      if (kIsWeb) return;

      await _firebaseMessaging.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null && navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(content: Text('${message.notification!.title ?? ''}\n${message.notification!.body ?? ''}')),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleFcmMessageNavigation(message);
      });

      _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleFcmMessageNavigation(message);
        }
      });
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null && response.payload! == 'ai_recommendation') {
      print('Local low-battery notification tapped. Triggering AI.');
      _navigateToDashboard(triggerAi: true);
    }
  }
  
  void _handleFcmMessageNavigation(RemoteMessage message) {
    // This can be used for other push notifications from a server
    _navigateToDashboard();
  }

  Future<void> showLowBatteryNotification(int batteryLevel) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'low_battery_channel',
      'Low Battery Alerts',
      channelDescription: 'Notifications for low EV battery levels.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotificationsPlugin.show(
      0, // Notification ID
      'Low Battery Alert!',
      'Your EV battery is at $batteryLevel%. Tap to find a charging station.',
      notificationDetails,
      payload: 'ai_recommendation',
    );
    print("🔋 Low battery local notification has been shown.");
  }

  void _navigateToDashboard({bool triggerAi = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final role = prefs.getString('lastRole');

    if (email != null && role == 'EV User') {
      final arguments = <String, dynamic>{
        'role': role,
        'email': email,
      };
      if (triggerAi) {
        arguments['triggerAiRecommendation'] = true;
      }

      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.evuserDashboard,
        (route) => false,
        arguments: arguments,
      );
    }
  }
}