import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  final String role;
  const SignUpPage({super.key, required this.role});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _termsAccepted = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept terms and conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw 'Email already in use';
      }

      await FirebaseFirestore.instance.collection('users').add({
        'fullName': _fullNameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up successful!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(role: widget.role)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up - ${widget.role}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hi - ${widget.role}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(_fullNameController, 'Full Name',
                      validator: (v) =>
                          v!.isEmpty ? 'Full name is required' : null),
                  _buildTextField(_mobileController, 'Mobile Number',
                      keyboard: TextInputType.phone,
                      validator: (v) => RegExp(r'^\+?\d{7,15}$').hasMatch(v!)
                          ? null
                          : 'Enter valid mobile number'),
                  _buildTextField(_emailController, 'Email',
                      keyboard: TextInputType.emailAddress,
                      validator: (v) => RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$')
                              .hasMatch(v!)
                          ? null
                          : 'Enter a valid email'),
                  _buildTextField(_passwordController, 'Password',
                      obscure: true,
                      validator: (v) => v!.length < 6
                          ? 'Password must be at least 6 characters'
                          : null),
                  _buildTextField(
                      _confirmPasswordController, 'Confirm Password',
                      obscure: true,
                      validator: (v) => v != _passwordController.text
                          ? 'Passwords do not match'
                          : null),
                  Row(
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) => setState(() => _termsAccepted = v!),
                      ),
                      const Expanded(
                        child: Text('I accept the Terms and Conditions'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label,
      {bool obscure = false,
      TextInputType keyboard = TextInputType.text,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        obscureText: obscure,
        keyboardType: keyboard,
        validator: validator,
      ),
    );
  }
}
