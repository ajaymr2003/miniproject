// lib/pages/admin/admin_profile_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out from the admin panel?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
    }
  }

  // --- NEW METHOD TO SHOW THE ABOUT DIALOG ---
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'EV Smart Charge',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/images/logo.jpg', height: 50),
      applicationLegalese: '© 2024 Your Company Name',
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: Text(
            'This application provides a comprehensive platform for EV users to locate charging stations and for station owners to manage their infrastructure efficiently.',
            textAlign: TextAlign.justify,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Color(0xFFE8EAF6),
          child: Icon(Icons.admin_panel_settings, size: 60, color: Color(0xFF3F51B5)),
        ),
        const SizedBox(height: 16),
        const Text(
          "Administrator",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          "admin@app.com", // Static email for admin
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildOptionRow(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _buildOptionRow(
            context,
            'Change Password',
            Icons.lock_reset_outlined,
            () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
          ),
          _buildOptionRow(
            context,
            'App Settings',
            Icons.settings_outlined,
            () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings page is not yet implemented.')),
            ),
          ),
          // --- MODIFIED: The onTap callback now calls the new dialog function ---
          _buildOptionRow(
            context,
            'About',
            Icons.info_outline,
            () => _showAboutDialog(context),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text("Log Out"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}