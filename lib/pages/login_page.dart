import 'package:flutter/material.dart';
import 'evuser_dashboard.dart';
import 'admin_dashboard.dart'; // ✅ Import admin dashboard

class LoginPage extends StatefulWidget {
  final String role;
  const LoginPage({super.key, required this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulated login
    setState(() => _isLoading = false);

    // Navigate to correct dashboard based on role
    if (widget.role == 'Station Owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(role: widget.role),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EVUserDashboard(role: widget.role),
        ),
      );
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forgot Password tapped')),
    );
  }

  void _goToSignUp() {
    Navigator.pushNamed(context, '/signup', arguments: widget.role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ White background
      appBar: AppBar(
        title: Text('Login - ${widget.role}'),
        backgroundColor: Colors.white, // White appbar
        foregroundColor: Colors.black, // Black text/icons
        elevation: 0, // Remove shadow for clean look
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B2B2B), // Dark button
                      foregroundColor: Colors.white, // White text
                    ),
                    child: const Text('Login'),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot Password?'),
            ),
            TextButton(
              onPressed: _goToSignUp,
              child: const Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
