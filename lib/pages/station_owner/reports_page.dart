import 'package:flutter/material.dart';

// A mock data model for a charging session.
// In a real app, you would fetch this data from a 'charging_sessions' collection in Firestore.
class ChargingSession {
  final String stationName;
  final DateTime date;
  final int durationMinutes;
  final double energyKWh;
  final double cost;

  ChargingSession({
    required this.stationName,
    required this.date,
    required this.durationMinutes,
    required this.energyKWh,
    required this.cost,
  });
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // In a real app, this list would be populated from a Firestore query.
  // For now, we leave it empty to show the "zero state".
  final List<ChargingSession> _sessions = [];

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 100, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No Reports Available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            Text(
              'Usage reports and analytics for your stations will appear here once there is activity.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This page is part of the dashboard, so it doesn't need its own Scaffold.
    // The main dashboard Scaffold provides the structure.
    return _sessions.isEmpty
        ? _buildEmptyState()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildSummaryCard('Revenue (30d)', '\$0.00', Icons.attach_money),
                    _buildSummaryCard('Sessions (30d)', '0', Icons.ev_station),
                    _buildSummaryCard('Avg. Duration', '0 min', Icons.timer_outlined),
                    _buildSummaryCard('Total Energy', '0 kWh', Icons.power),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // Here you would have a ListView.builder for the _sessions
              ],
            ),
          );
  }
}