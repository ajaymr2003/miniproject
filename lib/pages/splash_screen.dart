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
    // Wait for 3 seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return; // Check if the widget is still in the tree

    // Determine the next route based on the saved user session
    final prefs = await SharedPreferences.getInstance();
    final lastRole = prefs.getString('lastRole');
    final email = prefs.getString('email');

    String nextRoute = AppRoutes.landing;
    Object? routeArguments;

    if (lastRole == 'EV User' && email != null) {
      nextRoute = AppRoutes.evuserDashboard;
      routeArguments = {'role': lastRole, 'email': email};
    } else if (lastRole == 'Station Owner' && email != null) {
      nextRoute = AppRoutes.stationOwnerDashboard;
      routeArguments = {'role': lastRole, 'email': email};
    } else if (lastRole == 'admin') {
      nextRoute = AppRoutes.adminDashboard;
      routeArguments = lastRole;
    }
    
    // Navigate and replace the splash screen in the stack so the user can't go back to it
    Navigator.pushReplacementNamed(
      context,
      nextRoute,
      arguments: routeArguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your Logo Image
            Image.asset(
              'assets/images/logo.jpg', // Make sure this path is correct
              height: 180,
            ),
            const SizedBox(height: 24),
            // Your App Name
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
            // A loading indicator for a better UX
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}