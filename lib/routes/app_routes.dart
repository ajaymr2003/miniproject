import 'package:flutter/material.dart';
import '../pages/landing_page.dart';
import '../pages/register_page.dart';
import '../pages/login_page.dart';
import '../pages/evuser/evuser_dashboard.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/station_owner/station_owner_dashboard.dart';
import '../pages/forgot_password_page.dart'; // <-- 1. IMPORT THE NEW PAGE

class AppRoutes {
  static const String landing = '/';
  static const String register = '/register';
  static const String login = '/login';
  static const String forgotPassword = '/forgot_password'; // <-- 2. DEFINE THE ROUTE NAME
  static const String evuserDashboard = '/evuser_dashboard';
  static const String adminDashboard = '/admin_dashboard';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landing:
        return MaterialPageRoute(builder: (_) => const LandingPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
        
      // --- 3. ADD THE CASE FOR THE NEW ROUTE ---
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      // -----------------------------------------

      case evuserDashboard:
        final args = settings.arguments;
        String role = 'EV User';
        String email = '';
        if (args is Map<String, dynamic>) {
          role = args['role'] ?? 'EV User';
          email = args['email'] ?? '';
        } else if (args is String) {
          role = args;
        }
        return MaterialPageRoute(
          builder: (_) => EVUserDashboard(role: role, email: email),
        );
      case adminDashboard:
        final role =
            (settings.arguments is String && settings.arguments != null)
            ? settings.arguments as String
            : 'Station Owner';
        if (role == 'admin') {
          return MaterialPageRoute(builder: (_) => AdminDashboard(role: role));
        } else {
          return MaterialPageRoute(
            builder: (_) => StationOwnerDashboard(role: role),
          );
        }
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}