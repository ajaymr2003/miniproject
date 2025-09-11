import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- ADD THIS IMPORT for the platform check ---
import 'package:flutter/foundation.dart' show kIsWeb;

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

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
        _error = '';
      });
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();

        if (!doc.exists) {
          setState(() {
            _error = 'User profile not found. Please contact support.';
          });
          return;
        }

        final data = doc.data()!;
        final bool isActive = data['isActive'] ?? true;

        if (!isActive) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _error = 'Your account has been deactivated. Please contact an administrator.';
          });
          return;
        }

        if (!kIsWeb) {
          try {
            await FirebaseMessaging.instance.requestPermission();
            String? fcmToken = await FirebaseMessaging.instance.getToken();
            if (fcmToken != null) {
              await doc.reference.update({'fcmToken': fcmToken});
              print('FCM Token successfully updated for user: $email');
            }
          } catch (e) {
            print('Error updating FCM token on mobile: $e');
          }
        } else {
          print('Skipping FCM token update on web platform.');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastRole', data['role'] ?? '');
        await prefs.setString('email', email);

        // --- CHANGE: Use pushNamedAndRemoveUntil to clear the navigation stack ---
        final routePredicate = (Route<dynamic> route) => false;

        if (data['role'] == 'EV User') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.evuserDashboard,
            routePredicate,
            arguments: {'role': data['role'], 'email': email},
          );
        } else if (data['role'] == 'Station Owner') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.stationOwnerDashboard,
            routePredicate,
            arguments: {'role': data['role'], 'email': email},
          );
        } else if (data['role'] == 'admin') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.adminDashboard,
            routePredicate,
            arguments: data['role'],
          );
        } else {
          setState(() {
            _error = 'Unknown role. Please contact support.';
          });
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          _error = 'No account found for this email.';
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _error = 'Incorrect password.';
        } else {
          _error = 'Login failed: ${e.message}';
        }
      } catch (e) {
        _error = 'An unexpected error occurred: ${e.toString()}';
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
            if (_error.isNotEmpty) {
              _passwordController.clear();
            }
          });
        }
      }
    }
  }

  void _forgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void _goToSignUp() {
    Navigator.pushNamed(context, AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    // --- The build method remains exactly the same ---
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