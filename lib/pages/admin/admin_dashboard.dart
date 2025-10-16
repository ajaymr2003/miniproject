// lib/pages/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../routes/app_routes.dart';
import 'ev_user_details_page.dart';
import 'station_owner_details_page.dart';
import 'admin_profile_page.dart';
import 'admin_view_issues_page.dart'; // <-- 1. IMPORT THE NEW PAGE

class AdminDashboard extends StatefulWidget {
  final String role;
  const AdminDashboard({super.key, required this.role});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _AdminHomeView(onNavigate: _onItemTapped),
      const StationOwnerDetailsPage(),
      // --- 2. REPLACE THE PLACEHOLDER WITH THE NEW PAGE ---
      const AdminViewIssuesPage(),
      const AdminProfilePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Station Owners';
      // --- 3. UPDATE THE APP BAR TITLE ---
      case 2:
        return 'Reported Issues';
      default:
        return 'Admin Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = _selectedIndex == 3
        ? null
        : AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              _getAppBarTitle(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBar,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
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
            label: 'Owners',
          ),
          // --- 4. UPDATE THE BOTTOM NAV ITEM ---
          BottomNavigationBarItem(icon: Icon(Icons.bug_report), label: 'Issues'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// The _AdminHomeView widget remains unchanged.
class _AdminHomeView extends StatefulWidget {
  final void Function(int) onNavigate;
  const _AdminHomeView({required this.onNavigate});

  @override
  State<_AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<_AdminHomeView> {
  int _evUsers = 0;
  int _stationOwners = 0;
  int _pendingRequests = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAllCounts();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchAllCounts();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _fetchAllCounts() {
    _fetchEVUserCount();
    _fetchStationOwnerCount();
    _fetchPendingRequestsCount();
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
      if (mounted) setState(() => _pendingRequests = snap.size);
    } catch (e) { print("Error fetching pending requests: $e"); }
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
    return SingleChildScrollView(
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
                onTap: () => Navigator.pushNamed(context, AppRoutes.stationRequests),
              ),
              _buildSummaryCard('History', '12'), // Placeholder
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
            Navigator.pushNamed(context, AppRoutes.stationRequests);
          }),
          _buildActionButton('Manage Station Owners', () {
            widget.onNavigate(1);
          }),
          _buildActionButton('User Management', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EvUserDetailsPage()),
            );
          }),
        ],
      ),
    );
  }
}