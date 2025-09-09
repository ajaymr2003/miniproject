import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart'; // Import your app routes

class EVUserProfile extends StatefulWidget {
  const EVUserProfile({super.key});

  @override
  State<EVUserProfile> createState() => _EVUserProfileState();
}

class _EVUserProfileState extends State<EVUserProfile> {
  Map<String, dynamic>? _userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (email == null || email.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      if (mounted) {
        setState(() {
          _userData = doc.data();
          _loading = false;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String vehicleInfo = "Not Provided";
    if (_userData != null) {
      final brand = _userData?['brand'];
      final variant = _userData?['variant'];
      if (brand != null && brand.isNotEmpty && variant != null && variant.isNotEmpty) {
        vehicleInfo = '$brand $variant';
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        // --- CHANGE: The title has been removed for a cleaner look ---
        title: const SizedBox.shrink(), 
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile feature coming soon!')),
              );
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(
                  child: Text(
                    'Could not load user data.\nPlease log in again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileImage(),
                      const SizedBox(height: 16),
                      Text(
                        _userData?['fullName'] ?? "EV User",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userData?['email'] ?? "No email found",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // --- Section for user details ---
                      _buildInfoTile(
                        icon: Icons.electric_car_outlined,
                        title: "Vehicle",
                        subtitle: vehicleInfo,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        icon: Icons.phone_outlined,
                        title: "Phone Number",
                        subtitle: _userData?['phoneNumber'] ?? "Not Provided",
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        icon: Icons.calendar_today_outlined,
                        title: "Member Since",
                        subtitle: _userData?['createdAt'] != null
                            ? (_userData!['createdAt'] as Timestamp)
                                .toDate()
                                .toLocal()
                                .toString()
                                .split(' ')[0]
                            : "Unknown",
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(thickness: 0.5),
                      const SizedBox(height: 16),
                      
                      // --- NEW: Section for support buttons ---
                      _buildActionTile(
                        icon: Icons.help_outline,
                        title: "Help & FAQ",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Help & FAQ page coming soon!')),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        icon: Icons.bug_report_outlined,
                        title: "Report an Issue",
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Issue reporting feature coming soon!')),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      _buildLogoutButton(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileImage() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[200],
      child: Icon(
        Icons.person_outline,
        size: 60,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  // --- NEW WIDGET: A clean, tappable tile for actions ---
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.grey[700]),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Logout'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldLogout == true) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text("Log Out"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
}