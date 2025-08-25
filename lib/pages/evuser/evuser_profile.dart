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
      // You might want to log this error for debugging
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Changed background to a very dark grey to make the white elements pop
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        // Changed Appbar background to white for contrast
        backgroundColor: Colors.white,
        // Changed foreground color to black
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit Profile Pressed'),
                  backgroundColor: Colors.black87,
                ),
              );
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
              color: Colors.white,
            ))
          : _userData == null
              ? const Center(
                  child: Text(
                    'No user data found',
                    style: TextStyle(color: Colors.white),
                  ),
                )
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
                          // Text color is white for contrast against the dark background
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userData?['email'] ?? _email ?? "evuser@email.com",
                        style: const TextStyle(
                          fontSize: 16,
                          // Lighter grey for secondary text
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildProfileDetailCard(
                        icon: Icons.electric_car_rounded,
                        title: "Vehicle",
                        subtitle: (_userData?['brand'] ?? '') +
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
                                backgroundColor: Colors.white,
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
                                    child: const Text('Logout',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (shouldLogout == true) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove('lastRole');
                              await prefs.remove('email');
                              if (mounted) {
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              }
                            }
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text("Log Out"),
                          style: ElevatedButton.styleFrom(
                            // Kept red for the logout button to indicate a clear action
                            backgroundColor: Colors.red.shade700,
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
        // Using a white border against the dark background
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 70,
        // White icon to contrast with the dark background
        color: Colors.white,
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
        // White background for the card
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 28),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
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
