// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart';
import 'services/ai_recommendation_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppInitializer.initializeApp();
    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint("❌ App failed to initialize: $e\n$stack");
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("App failed to start. Please restart."),
        ),
      ),
    ));
  }
}

/// Handles all async startup tasks
class AppInitializer {
  static Future<void> initializeApp() async {
    // --- Firebase ---
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // --- Notifications (Local and FCM) ---
    // Use the singleton instance to initialize
    await NotificationService.instance.initNotifications();

    // --- AI Service ---
    try {
      await AiRecommendationService.instance.initialize();
      debugPrint("✅ AI Service initialized successfully");
    } catch (e) {
      debugPrint("⚠️ AI Service initialization failed: $e");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Smart EV',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}