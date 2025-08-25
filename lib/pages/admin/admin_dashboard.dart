// This file is deprecated. Use station_owner_dashboard.dart instead.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../routes/app_routes.dart';
import 'ev_user_details_page.dart';
import 'station_owner_details_page.dart'; // <-- Add this import

class AdminDashboard extends StatefulWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int _evUsers = 0;
  int _totalStations = 0; // <-- Add this line
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchEVUserCount();
    _fetchTotalStations(); // <-- Add this line
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchEVUserCount();
      _fetchTotalStations(); // <-- Add this line
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchEVUserCount();
    _fetchTotalStations(); // <-- Add this line
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchEVUserCount() async {
    try {
      final evUsersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'EV User')
          .get();
      final newCount = evUsersSnap.size;
      if (newCount != _evUsers) {
        setState(() {
          _evUsers = newCount;
        });
      }
    } catch (e) {
      if (_evUsers != 0) {
        setState(() {
          _evUsers = 0;
        });
      }
    }
  }

  Future<void> _fetchTotalStations() async {
    try {
      // Documents are keyed by email, but we filter by 'role' field
      final stationOwnersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Station Owner')
          .get();

      // Debug: print the number of docs and their emails
      print('Station Owner docs count: ${stationOwnersSnap.size}');
      for (var doc in stationOwnersSnap.docs) {
        print('Station Owner email: ${doc['email']}');
      }

      final newCount = stationOwnersSnap.size;
      setState(() {
        _totalStations = newCount;
      });
    } catch (e) {
      print('Error fetching Station Owners: $e');
      setState(() {
        _totalStations = 0;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here based on the index
    switch (index) {
      case 0:
        // Already on the dashboard
        break;
      case 1:
        // Navigate to Stations management page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigate to Manage Stations')),
        );
        break;
      case 2:
        // Navigate to Reports page
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Navigate to Reports')));
        break;
      case 3:
        // Navigate to Profile page
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Navigate to Profile')));
        break;
    }
  }

  Widget _buildSummaryCard(String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Use white for a clean look
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              // Clear login preference before navigating to landing page
              final prefs = await SharedPreferences.getInstance();
              await prefs
                  .clear(); // or use prefs.remove('key') for specific key
              Navigator.pushReplacementNamed(context, AppRoutes.landing);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildSummaryCard(
                  'EV Users',
                  _evUsers == -1 ? '...' : _evUsers.toString(),
                ),
                _buildSummaryCard(
                  'Total Stations',
                  _totalStations == -1
                      ? '...'
                      : _totalStations.toString(), // <-- Changed here
                ),
                _buildSummaryCard(
                  'Station Requests',
                  '5', // sample constant
                ),
                _buildSummaryCard(
                  'History',
                  '12', // sample constant
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton('Manage Stations', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StationOwnerDetailsPage(),
                ),
              );
            }),
            _buildActionButton('View Reports', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View detailed reports')),
              );
            }),
            _buildActionButton('User Management', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EvUserDetailsPage(),
                ),
              );
            }),
            _buildActionButton('Settings', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Adjust system settings')),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station),
            label: 'Stations',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// No changes needed in Dart code for counting logic.
// Make sure your Firestore rules allow read access to the 'users' collection.
