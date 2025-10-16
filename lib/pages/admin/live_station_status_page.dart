// lib/pages/admin/live_station_status_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class LiveStationStatusPage extends StatefulWidget {
  const LiveStationStatusPage({super.key});

  @override
  State<LiveStationStatusPage> createState() => _LiveStationStatusPageState();
}

class _LiveStationStatusPageState extends State<LiveStationStatusPage> {
  // A future to hold the static station data from Firestore
  late final Future<List<DocumentSnapshot>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch all active stations once when the page loads
    _stationsFuture = FirebaseFirestore.instance
        .collection('stations')
        .where('isActive', isEqualTo: true)
        .get()
        .then((snapshot) => snapshot.docs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Station Status'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active stations found.'));
          }

          final stations = snapshot.data!;
          // Sort stations alphabetically by name for a consistent order
          stations.sort((a, b) {
            final aName = (a.data() as Map<String, dynamic>)['name'] ?? '';
            final bName = (b.data() as Map<String, dynamic>)['name'] ?? '';
            return aName.compareTo(bName);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final stationDoc = stations[index];
              // Each card will have its own real-time listener
              return _LiveStationCard(stationDoc: stationDoc);
            },
          );
        },
      ),
    );
  }
}

// A dedicated widget for a single station card to manage its own state
class _LiveStationCard extends StatelessWidget {
  final DocumentSnapshot stationDoc;

  const _LiveStationCard({required this.stationDoc});

  @override
  Widget build(BuildContext context) {
    final stationData = stationDoc.data() as Map<String, dynamic>;
    final stationId = stationDoc.id;
    final stationName = stationData['name'] ?? 'Unknown Station';
    final ownerEmail = stationData['ownerEmail'] ?? 'N/A';
    
    // Reference to the specific station's status in the Realtime Database
    final stationStatusRef = FirebaseDatabase.instance.ref('station_status/$stationId');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stationName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Owner: $ownerEmail',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const Divider(height: 24),
            // StreamBuilder to listen for live updates from RTDB
            StreamBuilder<DatabaseEvent>(
              stream: stationStatusRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading live status...'),
                    ],
                  );
                }
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return _buildStatusRow(Icons.error_outline, Colors.orange, 'No live data available');
                }

                int availableSlots = 0;
                int totalSlots = 0;
                final data = snapshot.data!.snapshot.value;

                if (data is List) {
                  totalSlots = data.length;
                  availableSlots = data.where((slot) => slot == true).length;
                }
                
                final bool isFull = totalSlots > 0 && availableSlots == 0;
                final statusColor = isFull ? Colors.orange.shade700 : Colors.green.shade700;
                final statusIcon = isFull ? Icons.power_off_rounded : Icons.power_rounded;

                return _buildStatusRow(
                  statusIcon,
                  statusColor,
                  '$availableSlots / $totalSlots slots available',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}