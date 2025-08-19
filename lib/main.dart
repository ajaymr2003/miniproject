import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Get last role from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final lastRole = prefs.getString('lastRole');

  String initialRoute = AppRoutes.landing;
  if (lastRole == 'EV User') {
    initialRoute = AppRoutes.evuserDashboard;
  } else if (lastRole == 'Station Owner' || lastRole == 'admin') {
    initialRoute = AppRoutes.adminDashboard;
  }

  runApp(MyApp(initialRoute: initialRoute, lastRole: lastRole));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final String? lastRole;
  const MyApp({super.key, required this.initialRoute, this.lastRole});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart EV',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        // Pass role argument if needed
        if ((initialRoute == AppRoutes.evuserDashboard ||
                initialRoute == AppRoutes.adminDashboard) &&
            settings.name == initialRoute &&
            lastRole != null) {
          return AppRoutes.generateRoute(
            RouteSettings(name: initialRoute, arguments: lastRole),
          );
        }
        return AppRoutes.generateRoute(settings);
      },
    );
  }
}
