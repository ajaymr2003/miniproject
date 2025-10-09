import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    'totalSlots': 0,
    'availableSlots': 0,
    'stationNames': <String>[],
    'primaryStationAddress': null,
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

      int totalSlots = 0;
      int availableSlots = 0;
      List<String> stationNames = [];
      String? primaryAddress;

      for (var doc in query.docs) {
        final data = doc.data();
        totalSlots += (data['totalSlots'] as num?)?.toInt() ?? 0;
        availableSlots += (data['availableSlots'] as num?)?.toInt() ?? 0;
        if (data['name'] != null) stationNames.add(data['name']);
        if (primaryAddress == null && data['address'] != null) primaryAddress = data['address'];
      }

      if (mounted) {
        _stationStats = {
          'totalStations': query.size,
          'totalSlots': totalSlots,
          'availableSlots': availableSlots,
          'stationNames': stationNames,
          'primaryStationAddress': primaryAddress,
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

  void _editProfile() {
    // This is a placeholder for navigating to a dedicated edit page.
    // For now, it shows a simple dialog.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dedicated edit page coming soon!')),
    );
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Each page in the dashboard stack should have its own Scaffold
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button in tab view
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
                    _buildInfoRow('Email', _userData?['email'] ?? 'N/A'),
                    _buildInfoRow('Phone Number', _userData?['phoneNumber'] ?? 'Not Provided'),
                    _buildInfoRow('Associated Station Name', _getAssociatedStationsText()),
                    _buildInfoRow('Station Address', _stationStats['primaryStationAddress'] ?? 'N/A'),
                    _buildInfoRow('Total Slots', _stationStats['totalSlots'].toString()),
                    _buildInfoRow('Available Slots', _stationStats['availableSlots'].toString()),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Options'),
                    _buildOptionRow('Edit Profile', Icons.edit_outlined, _editProfile),
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
        const CircleAvatar(
          radius: 50,
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.person, size: 60, color: Color(0xFF1E88E5)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
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
      ),
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