// lib/routes/app_routes.dart

import 'package:flutter/material.dart';
import '../pages/splash_screen.dart'; // <-- ADD THIS IMPORT
import '../pages/landing_page.dart';
import '../pages/register_page.dart';
import '../pages/login_page.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/station_owner/station_owner_dashboard.dart';
import '../pages/forgot_password_page.dart';
import '../pages/evuser/evuser_dashboard.dart';
import '../pages/admin/station_requests_page.dart'; 
import '../pages/station_owner/request_station_page.dart'; 
import '../pages/station_owner/station_owner_setup.dart';
import '../pages/station_owner/manage_stations_page.dart'; // <-- 1. IMPORT THE NEW PAGE

class AppRoutes {
  // --- CHANGE: The app now starts at the splash screen ---
  static const String splash = '/';
  // --- CHANGE: The landing page gets its own route name ---
  static const String landing = '/landing';

  static const String register = '/register';
  static const String login = '/login';
  static const String forgotPassword = '/forgot_password';
  static const String evuserDashboard = '/evuser_dashboard';
  static const String adminDashboard = '/admin_dashboard';
  static const String stationOwnerDashboard = '/station_owner_dashboard';
  static const String stationRequests = '/station_requests'; 
  static const String requestStation = '/request_station';
  static const String stationOwnerSetup = '/station_owner_setup';
  static const String manageStations = '/manage_stations'; // <-- 2. ADD THE NEW ROUTE CONSTANT

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // --- ADD: Route for the new splash screen ---
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case landing:
        return MaterialPageRoute(builder: (_) => const LandingPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      
      case stationRequests:
        return MaterialPageRoute(builder: (_) => const StationRequestsPage());

      case requestStation:
        return MaterialPageRoute(builder: (_) => const RequestStationPage());

      case stationOwnerSetup:
        final args = settings.arguments;
        String email = '';
        if (args is Map<String, dynamic>) {
          email = args['email'] ?? '';
        } else if (args is String) {
          email = args;
        }
        return MaterialPageRoute(builder: (_) => StationOwnerSetupPage(email: email));

      // <-- 3. ADD A CASE FOR THE NEW ROUTE ---
      case manageStations:
        return MaterialPageRoute(builder: (_) => const ManageStationsPage());

      case evuserDashboard:
        String role = 'EV User';
        String email = '';
        bool triggerAi = false;

        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          role = args['role'] as String? ?? 'EV User';
          email = args['email'] as String? ?? '';
          triggerAi = args['triggerAiRecommendation'] as bool? ?? false;
        } else if (settings.arguments is String) {
          // Old way of passing only role string
          role = settings.arguments as String;
        }
        return MaterialPageRoute(
          builder: (_) => EVUserDashboard(role: role, email: email, triggerAiRecommendation: triggerAi),
        );
      case adminDashboard:
        final role =
            (settings.arguments is String && settings.arguments != null)
            ? settings.arguments as String
            : 'admin';
        return MaterialPageRoute(builder: (_) => AdminDashboard(role: role));
      case stationOwnerDashboard:
        final args = settings.arguments;
        String role = 'Station Owner';
        String email = '';
        if (args is Map<String, dynamic>) {
          role = args['role'] ?? 'Station Owner';
          email = args['email'] ?? '';
        } else if (args is String) {
          role = args;
        }
        return MaterialPageRoute(
          builder: (_) => StationOwnerDashboard(role: role, email: email),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}