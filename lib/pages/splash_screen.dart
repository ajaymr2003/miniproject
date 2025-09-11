import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final lastRole = prefs.getString('lastRole');
    final email = prefs.getString('email');

    String nextRoute = AppRoutes.landing;
    Object? routeArguments;
    bool clearStack = false; // Flag to determine navigation method

    if (lastRole != null && email != null) {
      clearStack = true; // A user is logged in, so we clear the stack
      switch (lastRole) {
        case 'EV User':
          nextRoute = AppRoutes.evuserDashboard;
          routeArguments = {'role': lastRole, 'email': email};
          break;
        case 'Station Owner':
          nextRoute = AppRoutes.stationOwnerDashboard;
          routeArguments = {'role': lastRole, 'email': email};
          break;
        case 'admin':
          nextRoute = AppRoutes.adminDashboard;
          routeArguments = lastRole;
          break;
        default:
          clearStack = false; // Unknown role, go to landing page
          nextRoute = AppRoutes.landing;
          break;
      }
    }

    if (clearStack) {
      // If a user is logged in, remove all previous routes.
      Navigator.pushNamedAndRemoveUntil(
        context,
        nextRoute,
        (route) => false,
        arguments: routeArguments,
      );
    } else {
      // If no user, just replace the splash screen with the landing page.
      Navigator.pushReplacementNamed(
        context,
        nextRoute,
        arguments: routeArguments,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.jpg',
              height: 180,
            ),
            const SizedBox(height: 24),
            const Text(
              'EV Smart Charge',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 80),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}