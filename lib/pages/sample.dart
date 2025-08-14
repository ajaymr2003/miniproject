import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class SamplePage extends StatelessWidget {
  final String role;
  const SamplePage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 60, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text(
                    "Get Started now",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Create an account or log in to explore\nabout our app",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 29),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black,
                      indicator: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      tabs: [
                        Tab(text: "Log In"),
                        Tab(text: "Sign Up"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 450,
                    child: TabBarView(
                      children: [
                        LoginPage(role: role), // Pass the required role argument
                        SignUpPage(role: role), // Pass the required role argument
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
