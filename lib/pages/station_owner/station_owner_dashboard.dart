import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';

class StationOwnerDashboard extends StatefulWidget {
  final String role;
  const StationOwnerDashboard({super.key, required this.role});

  @override
  State<StationOwnerDashboard> createState() => _StationOwnerDashboardState();
}

class _StationOwnerDashboardState extends State<StationOwnerDashboard> {
  int _selectedIndex = 0;
  // State variables for dashboard data
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

  // Fetches dashboard data from Firestore
  Future<void> _fetchDashboardData() async {
    // In a real application, you would filter this data by the current user's ID
    // For example: .where('ownerId', isEqualTo: currentUserId)
    try {
      final stationsQuery = await FirebaseFirestore.instance
          .collection('stations')
          .get();
      final issuesQuery = await FirebaseFirestore.instance
          .collection('issues')
          .get();

      int totalChargersCount = 0;
      double totalRevenueAmount = 0.0;

      // Loop through stations to get total chargers and revenue
      for (var doc in stationsQuery.docs) {
        final data = doc.data();
        totalChargersCount += (data['chargerCount'] ?? 0) is int
            ? (data['chargerCount'] ?? 0) as int
            : ((data['chargerCount'] ?? 0) as num).toInt();
        totalRevenueAmount += data['totalRevenue'] ?? 0.0;
      }

      setState(() {
        _totalStations = stationsQuery.size;
        _totalChargers = totalChargersCount;
        _totalRevenue = totalRevenueAmount;
        _issuesReported = issuesQuery.size;
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors gracefully
      setState(() {
        _isLoading = false;
        // Optionally, show a toast or a snackbar with an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: ${e.toString()}'),
          ),
        );
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
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'STATION',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black),
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.landing);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildSummaryCard(
                        Icons.ev_station_rounded,
                        'Total Stations',
                        _totalStations.toString(),
                      ),
                      _buildSummaryCard(
                        Icons.charging_station_rounded,
                        'Total Chargers',
                        _totalChargers.toString(),
                      ),
                      _buildSummaryCard(
                        Icons.payments_rounded,
                        'Total Revenue',
                        '\$${_totalRevenue.toStringAsFixed(2)}',
                      ),
                      _buildSummaryCard(
                        Icons.warning_rounded,
                        'Issues Reported',
                        _issuesReported.toString(),
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
                  _buildActionButton(
                    Icons.add_circle_outline,
                    'Request New Station',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Requesting a new station'),
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    Icons.business_rounded,
                    'Manage Stations',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigating to manage stations'),
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    Icons.bar_chart_rounded,
                    'View Status Reports',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Viewing status reports')),
                      );
                    },
                  ),
                  _buildActionButton(
                    Icons.bug_report_rounded,
                    'View Issues',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Viewing reported issues'),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station_rounded),
            label: 'Stations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
