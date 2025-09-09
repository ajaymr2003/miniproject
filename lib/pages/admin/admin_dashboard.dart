import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../routes/app_routes.dart'; // <-- We use this for named routes
import 'ev_user_details_page.dart';
import 'station_owner_details_page.dart';
// We no longer need to import station_requests_page.dart here!

class AdminDashboard extends StatefulWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int _evUsers = 0;
  int _stationOwners = 0; // Renamed for clarity
  int _pendingRequests = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAllCounts();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchAllCounts();
    });
  }
  
  void _fetchAllCounts() {
    _fetchEVUserCount();
    _fetchStationOwnerCount();
    _fetchPendingRequestsCount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchEVUserCount() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'EV User').get();
      if(mounted) setState(() => _evUsers = snap.size);
    } catch (e) { print("Error fetching EV Users: $e"); }
  }

  Future<void> _fetchStationOwnerCount() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Station Owner').get();
      if(mounted) setState(() => _stationOwners = snap.size);
    } catch (e) { print("Error fetching Station Owners: $e"); }
  }

  Future<void> _fetchPendingRequestsCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('station_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      if (mounted) {
        setState(() {
          _pendingRequests = snap.size;
        });
      }
    } catch (e) {
      print("Error fetching pending requests: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        // This navigation is also direct, but let's keep it for now for consistency
        Navigator.push(context, MaterialPageRoute(builder: (context) => const StationOwnerDetailsPage()));
        break;
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to Reports')));
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to Profile')));
        break;
    }
  }

  Widget _buildSummaryCard(String title, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
        automaticallyImplyLeading: false,
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildSummaryCard('EV Users', _evUsers.toString()),
                _buildSummaryCard('Station Owners', _stationOwners.toString()),
                _buildSummaryCard(
                  'Station Requests',
                  _pendingRequests.toString(),
                  onTap: () {
                    // --- 4. USE THE NAMED ROUTE ---
                    Navigator.pushNamed(context, AppRoutes.stationRequests);
                  },
                ),
                _buildSummaryCard('History', '12'),
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
            _buildActionButton('Review Station Requests', () {
              // --- 5. USE THE NAMED ROUTE HERE TOO ---
              Navigator.pushNamed(context, AppRoutes.stationRequests);
            }),
            _buildActionButton('Manage Station Owners', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StationOwnerDetailsPage()),
              );
            }),
            _buildActionButton('User Management', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EvUserDetailsPage()),
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