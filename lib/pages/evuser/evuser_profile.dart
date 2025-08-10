import 'package:flutter/material.dart';

class EVUserProfile extends StatelessWidget {
  const EVUserProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EV User Profile")),
      body: const Center(
        child: Text(
          "Profile Page",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
