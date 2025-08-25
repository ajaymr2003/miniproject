import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- 1. IMPORT PACKAGE
import '../routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String _error = '';

  // =================================================================
  // --- MODIFIED LOGIN FUNCTION ---
  // =================================================================
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
        _error = '';
      });
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Fetch user document by email (document ID)
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();

        if (!doc.exists) {
          setState(() {
            _error = 'No account found for this email';
          });
          return;
        }

        final data = doc.data();
        if (data == null || data['password'] != password) {
          setState(() {
            _error = 'Incorrect password';
          });
          return;
        }

        // =====================================================================
        // <-- 2. GET AND SAVE FCM TOKEN AFTER SUCCESSFUL LOGIN -->
        // =====================================================================
        try {
          // Request permission for notifications (important for iOS and web)
          await FirebaseMessaging.instance.requestPermission();
          
          // Get the unique device token
          String? fcmToken = await FirebaseMessaging.instance.getToken();

          if (fcmToken != null) {
            // Update the user's document with the new token
            await doc.reference.update({'fcmToken': fcmToken});
            print('FCM Token successfully updated for user: $email');
          } else {
            print('Could not get FCM token. Skipping update.');
          }
        } catch (e) {
          // It's better not to block login if only the token update fails.
          // Just log the error for debugging.
          print('Error updating FCM token: $e');
        }
        // =====================================================================
        // <-- END OF NEW LOGIC -->
        // =====================================================================

        // Save session info and navigate
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastRole', data['role'] ?? '');
        await prefs.setString('email', email);

        if (data['role'] == 'EV User') {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.evuserDashboard,
            arguments: {'role': data['role'], 'email': email},
          );
        } else if (data['role'] == 'Station Owner' || data['role'] == 'admin') {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.adminDashboard,
            arguments: data['role'],
          );
        } else {
          setState(() {
            _error = 'Unknown role. Please contact support.';
          });
        }
      } on FirebaseException catch (e) {
        setState(() {
          _error = 'Login failed: ${e.message}';
        });
      } catch (e) {
        setState(() {
          _error = 'Login failed: ${e.toString()}';
        });
      } finally {
        if (mounted) { // Check if the widget is still in the tree
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }
  // --- END OF MODIFIED LOGIN FUNCTION ---


  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Forgot password functionality not implemented.'),
      ),
    );
  }

  void _goToSignUp() {
    Navigator.pushNamed(context, AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Welcome back!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'e.g., example@email.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _goToSignUp,
                  child: const Text(
                    "Don't have an account? Sign Up",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}