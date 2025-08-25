import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart'; // <-- ADDED: Import the service
import 'package:shared_preferences/shared_preferences.dart';

// <-- ADDED: A global key to access the Navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensure everything is initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // <-- ADDED: Initialize notification listeners right after Firebase
  await NotificationService().initNotifications();

  // Your existing logic for initial route based on saved session
  final prefs = await SharedPreferences.getInstance();
  final lastRole = prefs.getString('lastRole');
  final email = prefs.getString('email'); // Also get email for arguments

  String initialRoute = AppRoutes.landing;
  Map<String, String> routeArguments = {};

  if (lastRole == 'EV User' && email != null) {
    initialRoute = AppRoutes.evuserDashboard;
    routeArguments = {'role': lastRole!, 'email': email};
  } else if ((lastRole == 'Station Owner' || lastRole == 'admin') && email != null) {
    initialRoute = AppRoutes.adminDashboard;
    // Admin dashboard might just need the role
    routeArguments = {'role': lastRole!}; 
  }

  runApp(MyApp(
    initialRoute: initialRoute,
    routeArguments: routeArguments.isNotEmpty ? routeArguments : null,
  ));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final Map<String, String>? routeArguments;

  const MyApp({
    super.key,
    required this.initialRoute,
    this.routeArguments,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <-- ADDED: Assign the global key
      debugShowCheckedModeBanner: false,
      title: 'Smart EV',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        // If the app is starting on a protected route, pass the saved arguments
        if (settings.name == initialRoute && routeArguments != null) {
          return AppRoutes.generateRoute(
            RouteSettings(name: initialRoute, arguments: routeArguments),
          );
        }
        // Otherwise, generate routes as normal
        return AppRoutes.generateRoute(settings);
      },
    );
  }
}