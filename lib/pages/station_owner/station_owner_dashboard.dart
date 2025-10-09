import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routes/app_routes.dart';
import 'manage_stations_page.dart';
import 'station_owner_profile_page.dart';
import 'reports_page.dart';
import 'request_station_page.dart';
import 'view_issues_page.dart'; // <-- 1. IMPORT THE NEW ISSUES PAGE

class StationOwnerDashboard extends StatefulWidget {
  final String role;
  final String email;
  const StationOwnerDashboard({super.key, required this.role, required this.email});

  @override
  State<StationOwnerDashboard> createState() => _StationOwnerDashboardState();
}

class _StationOwnerDashboardState extends State<StationOwnerDashboard> {
  int _selectedIndex = 0;
  bool _isLoadingProfile = true;
  String _ownerName = '';
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardHomeView(email: widget.email),
      const ManageStationsPage(),
      const ReportsPage(),
      StationOwnerProfilePage(email: widget.email),
    ];
    _initializeAndCheckProfile();
  }

  Future<void> _initializeAndCheckProfile() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.email).get();

      if (!mounted) return;

      final data = userDoc.data();
      if (!userDoc.exists || data == null || !(data['setupComplete'] ?? false)) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.stationOwnerSetup,
          arguments: {'email': widget.email},
        );
        return;
      }

      if (mounted) {
        setState(() {
          _ownerName = data['fullName'] ?? 'Dashboard';
        });
      }

      setState(() => _isLoadingProfile = false);
    } catch (e) {
      print("Error checking profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return _ownerName.isNotEmpty ? _ownerName.toUpperCase() : 'DASHBOARD';
      case 1:
        return 'MANAGE STATIONS';
      case 2:
        return 'REPORTS';
      default:
        return 'DASHBOARD';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.grey.shade50,
              elevation: 0,
              centerTitle: false,
              title: Text(
                _getAppBarTitle(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestStationPage()));
              },
              icon: const Icon(Icons.add),
              label: const Text('New Station'),
              backgroundColor: Colors.blueAccent,
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.ev_station_rounded), label: 'Stations'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- WIDGET FOR THE HOME TAB CONTENT (MODIFIED) ---
class _DashboardHomeView extends StatefulWidget {
  final String email;
  const _DashboardHomeView({required this.email});

  @override
  State<_DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<_DashboardHomeView> {
  int _totalStations = 0;
  int _totalChargers = 0;
  double _totalRevenue = 0.0;
  int _issuesReported = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final stationsQuery =
          await FirebaseFirestore.instance.collection('stations').where('ownerEmail', isEqualTo: widget.email).get();
      // This will be zero for now, but is ready for a real 'issues' collection.
      final issuesQuery = await FirebaseFirestore.instance.collection('issues').where('ownerEmail', isEqualTo: widget.email).get();

      int totalChargersCount = 0;
      double totalRevenueAmount = 0.0;

      for (var doc in stationsQuery.docs) {
        final data = doc.data();
        totalChargersCount +=
            (data['totalSlots'] ?? 0) is int ? (data['totalSlots'] ?? 0) as int : ((data['totalSlots'] ?? 0) as num).toInt();
        totalRevenueAmount += (data['totalRevenue'] ?? 0.0) as double;
      }

      if (mounted) {
        setState(() {
          _totalStations = stationsQuery.size;
          _totalChargers = totalChargersCount;
          _totalRevenue = totalRevenueAmount;
          _issuesReported = issuesQuery.size;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching dashboard data: $e");
    }
  }

  Widget _buildSummaryCard(IconData icon, String title, String value) {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 30),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black54),
        onTap: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildSummaryCard(Icons.ev_station_rounded, 'Total Stations', _totalStations.toString()),
                    _buildSummaryCard(Icons.charging_station_rounded, 'Total Chargers', _totalChargers.toString()),
                    _buildSummaryCard(Icons.payments_rounded, 'Total Revenue', '\$${_totalRevenue.toStringAsFixed(2)}'),
                    _buildSummaryCard(Icons.warning_rounded, 'Issues Reported', _issuesReported.toString()),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  Icons.add_circle_outline,
                  'Request New Station',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestStationPage())),
                ),
                _buildActionButton(
                  Icons.business_rounded,
                  'Manage Stations',
                  // This will switch to the 'Stations' tab in the bottom nav bar
                  () => DefaultTabController.of(context)?.animateTo(1),
                ),
                _buildActionButton(
                  Icons.bar_chart_rounded,
                  'View Status Reports',
                  // --- 3. NAVIGATE TO THE NEW REPORTS PAGE ---
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                ),
                _buildActionButton(
                  Icons.bug_report_rounded,
                  'View Issues',
                  // --- 4. NAVIGATE TO THE NEW ISSUES PAGE ---
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewIssuesPage())),
                ),
              ],
            ),
          );
  }
}