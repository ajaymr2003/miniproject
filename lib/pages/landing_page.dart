import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'login_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  Future<void> _showRoleSelectionDialog(BuildContext context) async {
    String? selectedRole = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: const Text('Select Your Role'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'EV User'),
              child: const Text('EV User'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'Station Owner'),
              child: const Text('Station Owner'),
            ),
          ],
        );
      },
    );

    if (selectedRole != null) {
      _showAuthSelectionDialog(context, selectedRole);
    }
  }

  Future<void> _showAuthSelectionDialog(BuildContext context, String role) async {
    String? selectedAuth = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: Text('Choose for $role'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'signup'),
              child: const Text('Signup'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'login'),
              child: const Text('Login'),
            ),
          ],
        );
      },
    );

    if (selectedAuth == 'signup') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SignUpPage(role: role)),
      );
    } else if (selectedAuth == 'login') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(role: role)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.jpg', height: 140),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () => _showRoleSelectionDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B2B),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
