// lib/pages/evuser/evuser_profile.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../routes/app_routes.dart'; // Import your app routes
import 'report_issue_page.dart';
import 'faq_page.dart';

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

  Future<void> _showEditThresholdDialog() async {
    final currentThreshold = (_userData?['aiRecommendationThreshold'] as num?)?.toDouble() ?? 30.0;
    double newThreshold = currentThreshold;

    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit AI Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Notify me when battery is below ${newThreshold.round()}%',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: newThreshold,
                    min: 10,
                    max: 50,
                    divisions: 8,
                    label: '${newThreshold.round()}%',
                    onChanged: (value) {
                      setDialogState(() => newThreshold = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(newThreshold),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != currentThreshold) {
      _updateThreshold(result);
    }
  }

  Future<void> _updateThreshold(double newValue) async {
    final email = _userData?['email'];
    if (email == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving new threshold...')),
    );

    try {
      final String encodedEmail = email.toString().replaceAll('.', ',');

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'aiRecommendationThreshold': newValue,
      });

      // Update Realtime Database
      await FirebaseDatabase.instance.ref('vehicles/$encodedEmail').update({
        'aiRecommendationThreshold': newValue,
      });

      // Refresh local state to show the new value immediately
      setState(() {
        _userData?['aiRecommendationThreshold'] = newValue;
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Threshold updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update threshold: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditPhoneNumberDialog() async {
    final phoneController = TextEditingController(text: _userData?['phoneNumber'] ?? '');
    final formKey = GlobalKey<FormState>();

    final newNumber = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Phone Number'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g., 1234567890',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                if (value.length < 10) { 
                  return 'Please enter a valid 10-digit number';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(phoneController.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newNumber != null && newNumber != (_userData?['phoneNumber'] ?? '')) {
      _updatePhoneNumber(newNumber);
    }
  }

  Future<void> _updatePhoneNumber(String newNumber) async {
    final email = _userData?['email'];
    if (email == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving phone number...')),
    );

    try {
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(email).update({
        'phoneNumber': newNumber,
      });

      // Refresh local state to show the new value immediately
      setState(() {
        _userData?['phoneNumber'] = newNumber;
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update phone number: $e'), backgroundColor: Colors.red),
        );
      }
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
    
    final String thresholdInfo = 
      "${(_userData?['aiRecommendationThreshold'] as num?)?.round() ?? '30'}%";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Profile"), 
        iconTheme: const IconThemeData(color: Colors.black),
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
                       _buildActionTile(
                        icon: Icons.auto_awesome,
                        title: "AI Alert Threshold",
                        trailingText: thresholdInfo,
                        onTap: _showEditThresholdDialog,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoTile(
                        icon: Icons.electric_car_outlined,
                        title: "Vehicle",
                        subtitle: vehicleInfo,
                      ),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        icon: Icons.phone_outlined,
                        title: "Phone Number",
                        trailingText: _userData?['phoneNumber'] ?? "Not Provided",
                        onTap: _showEditPhoneNumberDialog,
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(thickness: 0.5),
                      const SizedBox(height: 16),
                      
                      // --- Section for support buttons ---
                      _buildActionTile(
                        icon: Icons.help_outline,
                        title: "Help & FAQ",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FaqPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionTile(
                        icon: Icons.bug_report_outlined,
                        title: "Report an Issue",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReportIssuePage()),
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

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
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
            // Sign out from all services to ensure a clean slate.
            await FirebaseAuth.instance.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            // Use the root navigator to ensure we are replacing the entire dashboard screen,
            // not just the content of the profile tab.
            if (mounted) {
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
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