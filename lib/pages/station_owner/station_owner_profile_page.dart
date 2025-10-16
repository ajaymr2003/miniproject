// lib/pages/station_owner/station_owner_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';

class StationOwnerProfilePage extends StatefulWidget {
  final String email;
  const StationOwnerProfilePage({super.key, required this.email});

  @override
  State<StationOwnerProfilePage> createState() => _StationOwnerProfilePageState();
}

class _StationOwnerProfilePageState extends State<StationOwnerProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _stationStats = {
    'totalStations': 0,
    'stationNames': <String>[],
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUserData(),
      _fetchStationStats(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserData() async {
    if (widget.email.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.email).get();
      if (mounted) {
        _userData = doc.data();
      }
    } catch (e) {
      print("Error fetching user data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile data.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchStationStats() async {
    if (widget.email.isEmpty) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('stations')
          .where('ownerEmail', isEqualTo: widget.email)
          .get();

      List<String> stationNames = [];
      for (var doc in query.docs) {
        final data = doc.data();
        if (data['name'] != null) stationNames.add(data['name']);
      }

      if (mounted) {
        _stationStats = {
          'totalStations': query.size,
          'stationNames': stationNames,
        };
      }
    } catch (e) {
      print("Error fetching station stats: $e");
    }
  }

  String _getAssociatedStationsText() {
    final names = _stationStats['stationNames'] as List<String>;
    final count = _stationStats['totalStations'] as int;

    if (count == 0) return "No stations registered";
    if (count == 1) return names.first;
    return '${names.first} (+${count - 1} more)';
  }

  Future<void> _showEditProfileDialog() async {
    if (_userData == null) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _userData!['fullName']);
    final phoneController = TextEditingController(text: _userData!['phoneNumber']);
    final addressController = TextEditingController(text: _userData!['address']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a phone number';
                      if (v.length != 10 || int.tryParse(v) == null) return 'Must be 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Business Address', border: OutlineInputBorder()),
                    maxLines: 2,
                    validator: (v) => v!.isEmpty ? 'Please enter an address' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _updateProfile(
        nameController.text.trim(),
        phoneController.text.trim(),
        addressController.text.trim(),
      );
    }

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
  }

  Future<void> _updateProfile(String name, String phone, String address) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.email).update({
        'fullName': name,
        'phoneNumber': phone,
        'address': address,
      });
      setState(() {
        _userData?['fullName'] = name;
        _userData?['phoneNumber'] = phone;
        _userData?['address'] = address;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Could not load profile data.'))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Profile Information'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Full Name', _userData?['fullName'] ?? 'N/A'),
                    const Divider(height: 24),
                    _buildInfoRow('Email', _userData?['email'] ?? 'N/A'),
                    const Divider(height: 24),
                    _buildInfoRow('Phone Number', _userData?['phoneNumber'] ?? 'Not Provided'),
                    const Divider(height: 24),
                    _buildInfoRow('Business Address', _userData?['address'] ?? 'Not Provided'),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Station Information'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Associated Stations', _getAssociatedStationsText()),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Options'),
                    _buildOptionRow('Edit Profile', Icons.edit_outlined, _showEditProfileDialog),
                    _buildOptionRow('Change Password', Icons.lock_outline, () {
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    }),
                    _buildOptionRow('Log Out', Icons.logout, _logout),
                  ],
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.business_center, size: 60, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 16),
        Text(
          _userData?['fullName'] ?? "Station Owner",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildOptionRow(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(icon, color: Colors.grey.shade700),
      onTap: onTap,
    );
  }
}