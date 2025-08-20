import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EVUserProfile extends StatefulWidget {
  const EVUserProfile({super.key});

  @override
  State<EVUserProfile> createState() => _EVUserProfileState();
}

class _EVUserProfileState extends State<EVUserProfile> {
  String? _email;
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
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _email = email;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      setState(() {
        _userData = doc.data();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Profile Pressed')),
              );
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
          ? const Center(child: Text('No user data found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  _buildProfileImage(),
                  const SizedBox(height: 24),
                  Text(
                    _userData?['fullName'] ?? "EV User Name",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['email'] ?? _email ?? "evuser@email.com",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileDetailCard(
                    icon: Icons.electric_car_rounded,
                    title: "Vehicle",
                    subtitle:
                        (_userData?['brand'] ?? '') +
                        ' ' +
                        (_userData?['variant'] ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileDetailCard(
                    icon: Icons.phone_rounded,
                    title: "Phone",
                    subtitle: _userData?['phoneNumber'] ?? "Not Provided",
                  ),
                  const SizedBox(height: 16),
                  _buildProfileDetailCard(
                    icon: Icons.location_on_rounded,
                    title: "Location",
                    subtitle: _userData?['location'] ?? "Not Provided",
                  ),
                  const SizedBox(height: 16),
                  _buildProfileDetailCard(
                    icon: Icons.calendar_today_rounded,
                    title: "Member Since",
                    subtitle: _userData?['createdAt'] != null
                        ? (_userData!['createdAt'] is Timestamp
                              ? (_userData!['createdAt'] as Timestamp)
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0]
                              : _userData!['createdAt'].toString())
                        : "Unknown",
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Logout'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout == true) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('lastRole');
                          await prefs.remove('email');
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("Log Out"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent, width: 2),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 70,
        color: Colors.blueAccent,
      ),
    );
  }

  Widget _buildProfileDetailCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
